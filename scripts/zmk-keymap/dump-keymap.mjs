// Read-only dump of the live ZMK keymap over the Studio RPC serial port.
// Usage: node dump-keymap.mjs [/dev/ttyACM1] [out.json]
// Only issues get*/list* requests; never sets, saves or discards anything.
import fs from "node:fs";
import tty from "node:tty";
import { execFileSync } from "node:child_process";
// The ts-client is published for bundlers, so run.sh bundles this file with esbuild.
import { Request, Response } from "@zmkfirmware/zmk-studio-ts-client/studio";

const port = process.argv[2] || "/dev/ttyACM1";
const outPath = process.argv[3] || "keymap.json";

const SOF = 0xab, ESC = 0xac, EOF = 0xad;

function frame(bytes) {
  const out = [SOF];
  for (const b of bytes) {
    if (b === SOF || b === ESC || b === EOF) out.push(ESC);
    out.push(b);
  }
  out.push(EOF);
  return Buffer.from(out);
}

execFileSync("stty", ["-F", port, "raw", "-echo"]);
const fd = fs.openSync(port, fs.constants.O_RDWR | fs.constants.O_NOCTTY | fs.constants.O_NONBLOCK);
// tty.ReadStream polls on the event loop; a plain fs stream would park a blocking read in
// the thread pool and keep the process alive after we are done.
const rx = new tty.ReadStream(fd);
rx.setRawMode(true);

// Frame decoder feeding a queue of decoded Response messages.
const pending = new Map();
let state = "idle", buf = [];
rx.on("data", (chunk) => {
  for (const b of chunk) {
    if (state === "idle") { if (b === SOF) { state = "data"; buf = []; } continue; }
    if (state === "esc") { buf.push(b); state = "data"; continue; }
    if (b === ESC) { state = "esc"; continue; }
    if (b === EOF) {
      state = "idle";
      const msg = Response.decode(Uint8Array.from(buf));
      const rr = msg.requestResponse;
      if (rr && pending.has(rr.requestId)) {
        pending.get(rr.requestId)(rr);
        pending.delete(rr.requestId);
      }
      continue;
    }
    buf.push(b);
  }
});

let nextId = 1;
function call(req, timeoutMs = 3000) {
  const requestId = nextId++;
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => {
      pending.delete(requestId);
      reject(new Error(`no reply for ${JSON.stringify(req)}`));
    }, timeoutMs);
    pending.set(requestId, (rr) => { clearTimeout(t); resolve(rr); });
    fs.writeSync(fd, frame(Request.encode({ requestId, ...req }).finish()));
  });
}

try {
  const device = (await call({ core: { getDeviceInfo: true } })).core.getDeviceInfo;
  const lock = (await call({ core: { getLockState: true } })).core.getLockState;
  if (lock !== 1) throw new Error("keyboard is locked: press &studio_unlock and retry");

  const layouts = (await call({ keymap: { getPhysicalLayouts: true } })).keymap.getPhysicalLayouts;
  const keymap = (await call({ keymap: { getKeymap: true } })).keymap.getKeymap;
  const ids = (await call({ behaviors: { listAllBehaviors: true } })).behaviors.listAllBehaviors.behaviors;
  const behaviors = [];
  for (const behaviorId of ids) {
    behaviors.push((await call({ behaviors: { getBehaviorDetails: { behaviorId } } })).behaviors.getBehaviorDetails);
  }

  fs.writeFileSync(outPath, JSON.stringify({ device: { name: device.name }, layouts, keymap, behaviors }, null, 2));
  console.log(`${device.name}: ${keymap.layers.length} layers, ${behaviors.length} behaviors -> ${outPath}`);
} catch (e) {
  console.error(e.message);
  process.exitCode = 1;
} finally {
  rx.destroy();
}
