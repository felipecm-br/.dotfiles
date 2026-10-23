// Turn a keymap snapshot (from dump-keymap.mjs) into keymap-drawer inputs and a text table.
// Usage: node render-keymap.mjs <keymap.json> <out-dir> [table.md]
// Writes: <out-dir>/layout.json (QMK info format), <out-dir>/keymap.yaml (keymap-drawer),
//         and the per-position Markdown table (default <out-dir>/keymap.md).
import fs from "node:fs";
import os from "node:os";

const STUDIO = process.env.ZMK_STUDIO_DIR || `${os.homedir()}/dev/github/zmk-studio`;
const [inPath, outDir, mdPath = `${outDir}/keymap.md`] = process.argv.slice(2);
if (!inPath || !outDir) throw new Error("usage: render-keymap.mjs <keymap.json> <out-dir> [table.md]");

const data = JSON.parse(fs.readFileSync(inPath, "utf8"));
const { UsagePages } = JSON.parse(fs.readFileSync(`${STUDIO}/src/keyboard-and-consumer-usage-tables.json`, "utf8"));
const overrides = JSON.parse(fs.readFileSync(`${STUDIO}/src/hid-usage-name-overrides.json`, "utf8"));

const MODS = ["LCtrl", "LShift", "LAlt", "LGui", "RCtrl", "RShift", "RAlt", "RGui"];
// Studio labels the unshifted bracket usages with their shifted glyphs; show what is typed.
overrides["7"] = { ...overrides["7"], 47: { short: "[" }, 48: { short: "]" } };

function hidLabel(usage) {
  const mods = (usage >>> 24) & 0xff;
  const page = (usage >>> 16) & 0xff;
  const id = usage & 0xffff;
  const o = overrides[page]?.[id];
  const tableName = UsagePages.find((p) => p.Id === page)?.UsageIds?.find((u) => u.Id === id)?.Name;
  let name = o?.med || o?.short || tableName || `0x${page.toString(16)}:${id.toString(16)}`;
  // Studio's short labels use emoji glyphs that PDF fonts rarely carry.
  if (/\p{Extended_Pictographic}/u.test(name)) name = o?.long || tableName || name;
  name = name.replace(/^Keyboard /, "").replace(/^Keypad /, "KP ");
  const modNames = MODS.filter((_, i) => mods & (1 << i));
  return modNames.length ? `${modNames.join("+")}+${name}` : name;
}

const behaviors = new Map(data.behaviors.map((b) => [b.id, b]));
const layerName = (id) => {
  const l = data.keymap.layers.find((l) => l.id === id) ?? data.keymap.layers[id];
  return l?.name || `Layer ${id}`;
};

// Describe one param value using the behavior's metadata, mirroring Studio's picker.
function describe(descs, value) {
  for (const d of descs ?? []) {
    if (d.constant !== undefined && d.constant === value) return d.name;
  }
  for (const d of descs ?? []) {
    if (d.hidUsage) return hidLabel(value);
    if (d.layerId) return layerName(value);
    if (d.range && value >= d.range.min && value <= d.range.max) return `${d.name ? d.name + " " : ""}${value}`;
  }
  return undefined;
}

// Pointing behaviors ship without Studio metadata; decode ZMK's own encodings.
const MOUSE_BUTTONS = ["Left Click", "Right Click", "Middle Click", "Mouse 4", "Mouse 5"];
const int16 = (v) => ((v & 0xffff) << 16) >> 16;
function mouseLabel(name, p1) {
  if (name === "mouse_key_press") {
    return { name: "Mouse Button", p1: MOUSE_BUTTONS.filter((_, i) => p1 & (1 << i)).join("+") || `0x${p1.toString(16)}` };
  }
  if (name === "mouse_move" || name === "mouse_scroll") {
    const x = int16(p1 >>> 16), y = int16(p1);
    const dir = [y < 0 && "Up", y > 0 && "Down", x < 0 && "Left", x > 0 && "Right"].filter(Boolean).join("+");
    return { name: name === "mouse_move" ? "Mouse Move" : "Mouse Scroll", p1: dir || "0" };
  }
}

function bindingLabel(b) {
  const beh = behaviors.get(b.behaviorId);
  const name = beh?.displayName ?? `behavior ${b.behaviorId}`;
  const mouse = mouseLabel(name, b.param1);
  if (mouse) return mouse;
  const sets = beh?.metadata ?? [];
  // Pick the param set whose param1 matches (constants first), else the first one.
  const set = sets.find((s) => s.param1.some((d) => d.constant === b.param1)) ?? sets[0];
  const p1 = set && set.param1.length ? describe(set.param1, b.param1) : undefined;
  const p2 = set && set.param2.length ? describe(set.param2, b.param2) : undefined;
  return { name, p1, p2 };
}

// Compact key-cap legends for the drawing; the Markdown table keeps the full names.
const SHORT = {
  "Turn On": "On", "Turn OFF": "Off", "Toggle On/Off": "Toggle",
  "Next Effect": "Effect +", "Previous Effect": "Effect -", "Speed Up": "Speed +", "Speed Down": "Speed -",
  "Brightness Up": "Bright +", "Brightness Down": "Bright -", "Hue Up": "Hue +", "Hue Down": "Hue -",
  "Saturation Up": "Sat +", "Saturation Down": "Sat -",
  "Increase Brightness": "Bright +", "Decrease Brightness": "Bright -", "Cycle Brightness": "Bright cycle",
  "Left Click": "L Click", "Right Click": "R Click", "Middle Click": "M Click",
};
const short = (s) => SHORT[s] ?? s;
const profileNo = (s) => s?.match(/(\d+)$/)?.[1];

// Map a binding to a keymap-drawer key: tap label + optional hold label.
function drawerKey(b) {
  const { name, p1, p2 } = bindingLabel(b);
  const n = name.toLowerCase();
  if (n.includes("transparent")) return { t: "▽", type: "trans" };
  if (n === "none") return "";
  if (n.includes("key press")) return p1 ?? name;
  if (n.includes("layer-tap") || n.includes("mod-tap")) return { t: p2 ?? "", h: p1 ?? "" };
  if (n.includes("momentary layer")) return { t: p1 ?? "MO", type: "held" };
  if (n.includes("toggle layer")) return { t: p1 ?? "TOG", h: "toggle" };
  if (n.includes("to layer")) return { t: p1 ?? "TO", h: "to" };
  if (n.includes("sticky")) return { t: p1 ?? "", h: "sticky" };
  if (n.startsWith("mouse")) return { t: short(p1 ?? ""), h: n.replace("mouse ", "") === "button" ? "mouse" : n };
  if (n === "bluetooth") {
    if (p1 === "Select Profile") return { t: `BT ${profileNo(p2)}`, h: "select" };
    if (p1 === "Disconnect Profile") return { t: `BT ${profileNo(p2)}`, h: "disconnect" };
    if (p1 === "Clear All Profiles") return { t: "BT clear", h: "all" };
    if (p1 === "Clear Selected Profile") return { t: "BT clear", h: "current" };
    return { t: short(p1 ?? "BT"), h: "bluetooth" };
  }
  if (n === "underglow") return { t: short(p1 ?? ""), h: "RGB" };
  if (n === "backlight") return { t: p2 ? p2.replace("Brightness ", "Bright ") : short(p1 ?? ""), h: "backlight" };
  return { t: [p1, p2].filter(Boolean).map(short).join(" ") || name, h: [p1, p2].some(Boolean) ? name : undefined };
}

const layout = data.layouts.layouts[data.layouts.activeLayoutIndex];
const qmk = {
  layouts: {
    [layout.name || "LAYOUT"]: {
      layout: layout.keys.map((k) => ({
        x: k.x / 100, y: k.y / 100, w: k.width / 100, h: k.height / 100,
        ...(k.r ? { r: k.r / 100, rx: k.rx / 100, ry: k.ry / 100 } : {}),
      })),
    },
  },
};
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(`${outDir}/layout.json`, JSON.stringify(qmk, null, 2));

const yamlStr = (v) => JSON.stringify(v ?? "");
const yamlKey = (k) => {
  if (typeof k === "string") return yamlStr(k);
  return `{${Object.entries(k).filter(([, v]) => v !== undefined).map(([a, v]) => `${a}: ${yamlStr(v)}`).join(", ")}}`;
};
let yaml = `layout:\n  qmk_info_json: ${yamlStr(`${outDir}/layout.json`)}\nlayers:\n`;
for (const l of data.keymap.layers) {
  yaml += `  ${yamlStr(l.name || `Layer ${l.id}`)}:\n`;
  for (const b of l.bindings) yaml += `    - ${yamlKey(drawerKey(b))}\n`;
}
fs.writeFileSync(`${outDir}/keymap.yaml`, yaml);

const cell = (s) => (s ?? "").replaceAll("|", "\\|");
let md = `# ${data.device.name} keymap table\n\nGenerated by \`scripts/zmk-keymap/run.sh\` from the live keyboard. Do not edit by hand.\n\n`;
for (const l of data.keymap.layers) {
  md += `## ${l.name || `Layer ${l.id}`}\n\n| # | Behavior | Param 1 | Param 2 |\n|---|---|---|---|\n`;
  l.bindings.forEach((b, i) => {
    const { name, p1, p2 } = bindingLabel(b);
    md += `| ${i} | ${cell(name)} | ${cell(p1)} | ${cell(p2)} |\n`;
  });
  md += "\n";
}
fs.writeFileSync(mdPath, md);
console.log(`layers: ${data.keymap.layers.map((l) => l.name || l.id).join(", ")}; keys: ${layout.keys.length}`);
