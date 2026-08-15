#!/usr/bin/env node

import crypto from "node:crypto";
import net from "node:net";

const socketPath = process.argv[2];
const websocketPath = process.env.CODEX_ANYWHERE_WS_PATH || "/rpc";
if (!socketPath) {
  console.error("Usage: codex-stdio-ws-bridge.mjs SOCKET_PATH");
  process.exit(2);
}
if (!websocketPath.startsWith("/")) {
  console.error("CODEX_ANYWHERE_WS_PATH must begin with '/'.");
  process.exit(2);
}

let handshakeComplete = false;
let receiveBuffer = Buffer.alloc(0);
let stdinBuffer = "";
const pendingLines = [];
let fragmentedOpcode = null;
let fragmentedPayloads = [];

const websocketKey = crypto.randomBytes(16).toString("base64");
const expectedAccept = crypto
  .createHash("sha1")
  .update(`${websocketKey}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
  .digest("base64");

const socket = net.createConnection({ path: socketPath });

function fail(message) {
  console.error(`codex-anywhere bridge: ${message}`);
  socket.destroy();
  process.exitCode = 1;
}

function encodeClientFrame(opcode, payload = Buffer.alloc(0)) {
  if (!Buffer.isBuffer(payload)) payload = Buffer.from(payload);

  const mask = crypto.randomBytes(4);
  let header;
  if (payload.length < 126) {
    header = Buffer.allocUnsafe(2);
    header[1] = 0x80 | payload.length;
  } else if (payload.length <= 0xffff) {
    header = Buffer.allocUnsafe(4);
    header[1] = 0x80 | 126;
    header.writeUInt16BE(payload.length, 2);
  } else {
    header = Buffer.allocUnsafe(10);
    header[1] = 0x80 | 127;
    header.writeBigUInt64BE(BigInt(payload.length), 2);
  }
  header[0] = 0x80 | opcode;

  const masked = Buffer.allocUnsafe(payload.length);
  for (let i = 0; i < payload.length; i += 1) {
    masked[i] = payload[i] ^ mask[i & 3];
  }
  return Buffer.concat([header, mask, masked]);
}

function sendFrame(opcode, payload) {
  if (!socket.destroyed) socket.write(encodeClientFrame(opcode, payload));
}

function emitMessage(payload) {
  process.stdout.write(payload);
  if (payload.length === 0 || payload[payload.length - 1] !== 0x0a) {
    process.stdout.write("\n");
  }
}

function handleFrame(fin, opcode, payload) {
  if (opcode === 0x8) {
    sendFrame(0x8, payload);
    socket.end();
    return;
  }
  if (opcode === 0x9) {
    sendFrame(0xA, payload);
    return;
  }
  if (opcode === 0xA) return;

  if (opcode === 0x1 || opcode === 0x2) {
    if (fin) {
      emitMessage(payload);
    } else {
      fragmentedOpcode = opcode;
      fragmentedPayloads = [payload];
    }
    return;
  }
  if (opcode === 0x0 && fragmentedOpcode !== null) {
    fragmentedPayloads.push(payload);
    if (fin) {
      emitMessage(Buffer.concat(fragmentedPayloads));
      fragmentedOpcode = null;
      fragmentedPayloads = [];
    }
  }
}

function parseFrames() {
  while (receiveBuffer.length >= 2) {
    const first = receiveBuffer[0];
    const second = receiveBuffer[1];
    const fin = (first & 0x80) !== 0;
    const opcode = first & 0x0f;
    const masked = (second & 0x80) !== 0;
    let payloadLength = second & 0x7f;
    let offset = 2;

    if (payloadLength === 126) {
      if (receiveBuffer.length < 4) return;
      payloadLength = receiveBuffer.readUInt16BE(2);
      offset = 4;
    } else if (payloadLength === 127) {
      if (receiveBuffer.length < 10) return;
      const length64 = receiveBuffer.readBigUInt64BE(2);
      if (length64 > BigInt(Number.MAX_SAFE_INTEGER)) {
        fail("received an oversized WebSocket frame");
        return;
      }
      payloadLength = Number(length64);
      offset = 10;
    }

    const maskLength = masked ? 4 : 0;
    const frameLength = offset + maskLength + payloadLength;
    if (receiveBuffer.length < frameLength) return;

    let payload = receiveBuffer.subarray(
      offset + maskLength,
      offset + maskLength + payloadLength,
    );
    if (masked) {
      const mask = receiveBuffer.subarray(offset, offset + 4);
      const unmasked = Buffer.allocUnsafe(payload.length);
      for (let i = 0; i < payload.length; i += 1) {
        unmasked[i] = payload[i] ^ mask[i & 3];
      }
      payload = unmasked;
    }

    receiveBuffer = receiveBuffer.subarray(frameLength);
    handleFrame(fin, opcode, payload);
  }
}

function sendJsonLine(line) {
  if (!line) return;
  if (!handshakeComplete) {
    pendingLines.push(line);
    return;
  }
  sendFrame(0x1, Buffer.from(line, "utf8"));
}

socket.on("connect", () => {
  socket.write(
    [
      `GET ${websocketPath} HTTP/1.1`,
      "Host: localhost",
      "Connection: Upgrade",
      "Upgrade: websocket",
      "Sec-WebSocket-Version: 13",
      `Sec-WebSocket-Key: ${websocketKey}`,
      "",
      "",
    ].join("\r\n"),
  );
});

socket.on("data", (chunk) => {
  receiveBuffer = Buffer.concat([receiveBuffer, chunk]);
  if (!handshakeComplete) {
    const end = receiveBuffer.indexOf("\r\n\r\n");
    if (end === -1) return;

    const response = receiveBuffer.subarray(0, end).toString("utf8");
    receiveBuffer = receiveBuffer.subarray(end + 4);
    const lines = response.split("\r\n");
    const shiftedStatus = lines.shift();
    const status = shiftedStatus === undefined ? "" : shiftedStatus;
    const headers = new Map(
      lines.map((line) => {
        const colon = line.indexOf(":");
        return [
          line.slice(0, colon).trim().toLowerCase(),
          line.slice(colon + 1).trim(),
        ];
      }),
    );
    if (!/^HTTP\/1\.1 101\b/.test(status)) {
      fail(`WebSocket upgrade failed: ${status}`);
      return;
    }
    if (headers.get("sec-websocket-accept") !== expectedAccept) {
      fail("WebSocket upgrade returned an invalid accept key");
      return;
    }

    handshakeComplete = true;
    for (const line of pendingLines.splice(0)) sendJsonLine(line);
  }
  parseFrames();
});

socket.on("error", (error) => fail(error.message));
socket.on("close", () => {
  if (!process.stdin.destroyed) process.stdin.destroy();
});

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  stdinBuffer += chunk;
  while (true) {
    const newline = stdinBuffer.indexOf("\n");
    if (newline === -1) break;
    const line = stdinBuffer.slice(0, newline).replace(/\r$/, "");
    stdinBuffer = stdinBuffer.slice(newline + 1);
    sendJsonLine(line);
  }
});
process.stdin.on("end", () => {
  if (stdinBuffer) sendJsonLine(stdinBuffer.replace(/\r$/, ""));
  sendFrame(0x8, Buffer.from([0x03, 0xe8]));
});
