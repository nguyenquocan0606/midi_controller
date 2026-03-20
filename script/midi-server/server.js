const WebSocket = require("ws");
const http = require("http");
const fs = require("fs");
const path = require("path");
const easymidi = require("easymidi");
const osc = require("osc");
const os = require("os");

// ─── Configuration ───────────────────────────────────
const WS_PORT = process.env.WS_PORT || 8765;
const HTTP_PORT = process.env.HTTP_PORT || 8080;
const WS_HOST = "0.0.0.0";

// MIDI
const MIDI_OUTPUT_PORT = process.env.MIDI_OUT || "loopMIDI Port";
const MIDI_INPUT_PORT = process.env.MIDI_IN || "loopMIDI output";

// OSC
const OSC_LISTEN_PORT = 7001;
const OSC_SEND_PORT = 7000;
const OSC_SEND_HOST = "127.0.0.1";

// ─── Config Management ────────────────────────────────
const CONFIG_FILE = path.join(__dirname, "config.json");
const PADS_DIR = path.join(__dirname, "gui", "pads");

// Lấy server URL thực (dùng network IP, không phải 0.0.0.0)
function getServerUrl() {
  // Ưu tiên USB tethering IP (172.x.x.x)
  const tetherIP = detectUsbTetheringIP();
  if (tetherIP) return `http://${tetherIP}:${HTTP_PORT}`;
  // Fallback: lấy IP đầu tiên không phải internal
  const ips = getLocalIPs();
  if (ips.length > 0) return `http://${ips[0].address}:${HTTP_PORT}`;
  return `http://localhost:${HTTP_PORT}`;
}
const GUI_DIR = path.join(__dirname, "gui");

// Default app config
const DEFAULT_CONFIG = {
  groups: [
    {
      id: 0,
      name: "Group 1",
      channels: [
        { id: 0, name: "CH 1", color: null },
        { id: 1, name: "CH 2", color: null },
        { id: 2, name: "CH 3", color: null },
      ],
      isActive: true,
    },
    {
      id: 1,
      name: "Group 2",
      channels: [
        { id: 0, name: "CH 4", color: null },
        { id: 1, name: "CH 5", color: null },
        { id: 2, name: "CH 6", color: null },
      ],
      isActive: false,
    },
    {
      id: 2,
      name: "Group 3",
      channels: [
        { id: 0, name: "CH 7", color: null },
        { id: 1, name: "CH 8", color: null },
        { id: 2, name: "CH 9", color: null },
      ],
      isActive: false,
    },
  ],
  activeGroupId: 0,
  padLayout: "grid5x3",
  pads: Array.from({ length: 15 }, (_, i) => ({
    id: i,
    name: `PAD ${i + 1}`,
    imageUrl: null,
    color: null,
    type: "trigger",
    layerId: 0, // Layer 0 mặc định (Layer 1)
  })),
};

let appConfig = loadConfig();

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const raw = fs.readFileSync(CONFIG_FILE, "utf-8");
      const loaded = JSON.parse(raw);
      console.log("[CFG] Loaded config from file");
      return { ...DEFAULT_CONFIG, ...loaded };
    }
  } catch (e) {
    console.warn("[CFG] Failed to load config:", e.message);
  }
  return DEFAULT_CONFIG;
}

function saveConfig() {
  try {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(appConfig, null, 2), "utf-8");
    console.log("[CFG] Config saved");
    // Notify all clients that config is persisted
    broadcastToClients(JSON.stringify({ type: "configSaved", saved: true }));
  } catch (e) {
    console.error("[CFG] Failed to save config:", e.message);
  }
}

// Auto-save: every 30s if config has changed since last save
let _configDirty = false;
let _lastSaveTime = Date.now();

function markConfigDirty() {
  _configDirty = true;
}

setInterval(() => {
  if (_configDirty) {
    saveConfig();
    _configDirty = false;
    console.log("[CFG] Auto-saved config");
  }
}, 30_000);

// Ensure pads directory exists
if (!fs.existsSync(PADS_DIR)) {
  fs.mkdirSync(PADS_DIR, { recursive: true });
}

// ─── Log Files ────────────────────────────────────────
const OSC_LOG = path.join(__dirname, "osc-log.txt");
const MIDI_LOG = path.join(__dirname, "midi-log.txt");
const oscLogStream = fs.createWriteStream(OSC_LOG, { flags: "a" });
const midiLogStream = fs.createWriteStream(MIDI_LOG, { flags: "a" });

function logOsc(direction, address, args) {
  const ts = new Date().toISOString();
  const argsStr = args.map((a) => `${a.type}:${a.value}`).join(", ");
  const line = `[${ts}] ${direction} ${address} | ${argsStr}`;
  console.log(`[OSC ${direction}] ${address} [${argsStr}]`);
  oscLogStream.write(line + "\n");
}

function logMidiIO(direction, type, channel, data1, data2, velocity) {
  const ts = new Date().toISOString();
  const tsShort = ts.split("T")[1].replace("Z", "").slice(0, 12);
  let line;

  if (type === "CC") {
    line = `[${tsShort}] ${direction} CC Ch:${channel} CC:${data1} Val:${data2}`;
  } else if (type === "NOTE_ON") {
    line = `[${tsShort}] ${direction} NOTE_ON Ch:${channel} Note:${data1} Vel:${velocity}`;
  } else if (type === "NOTE_OFF") {
    line = `[${tsShort}] ${direction} NOTE_OFF Ch:${channel} Note:${data1} Vel:${velocity}`;
  } else if (type === "PC") {
    line = `[${tsShort}] ${direction} PC Ch:${channel} Prog:${data1}`;
  } else {
    line = `[${tsShort}] ${direction} ${type} Ch:${channel} D1:${data1} D2:${data2}`;
  }

  console.log(`[MIDI ${direction}] ${line.split("] ").pop()}`);
  midiLogStream.write(line + "\n");
}

// ─── Constants ────────────────────────────────────────
const MIDI_EVENTS = { CC: "cc", NOTE_ON: "noteon", NOTE_OFF: "noteoff" };
const MSG_TYPES = {
  CC: "controlChange",
  NOTE_ON: "noteOn",
  NOTE_OFF: "noteOff",
};
const RESPONSE_TYPES = {
  CONNECTED: "connected",
  STATE_SYNC: "stateSync",
  OSC: "osc",
  CONFIG: "config",
};
const COMMAND_TYPES = {
  GET_STATE: "getState",
  OSC_SEND: "oscSend",
  GET_CONFIG: "getConfig",
  UPDATE_CONFIG: "updateConfig",
  UPDATE_PAD_IMAGE: "updatePadImage",
};

// ─── State Cache ──────────────────────────────────────
const midiState = { cc: new Map(), note: new Map() };
const oscState = new Map();

// ─── MIDI Setup ──────────────────────────────────────
let midiOutput;
let midiInput;

try {
  const outputs = easymidi.getOutputs();
  const inputs = easymidi.getInputs();
  console.log("\n[MIDI] Available output ports:");
  outputs.forEach((name, i) => console.log(`  ${i}: ${name}`));
  console.log("[MIDI] Available input ports:");
  inputs.forEach((name, i) => console.log(`  ${i}: ${name}`));

  if (!outputs.includes(MIDI_OUTPUT_PORT)) {
    console.error(`\n[ERROR] MIDI output "${MIDI_OUTPUT_PORT}" not found.\n`);
    process.exit(1);
  }

  midiOutput = new easymidi.Output(MIDI_OUTPUT_PORT);
  console.log(`[MIDI] Output: "${MIDI_OUTPUT_PORT}" -> Resolume`);

  if (inputs.includes(MIDI_INPUT_PORT)) {
    midiInput = new easymidi.Input(MIDI_INPUT_PORT);
    console.log(`[MIDI] Input:  Resolume -> "${MIDI_INPUT_PORT}"`);
    setupMidiInputListeners();
  } else {
    console.warn(`[MIDI] Input "${MIDI_INPUT_PORT}" not found — MIDI feedback disabled`);
  }
  console.log();
} catch (err) {
  console.error("[ERROR] MIDI init failed:", err.message);
  process.exit(1);
}

// ─── OSC Setup ───────────────────────────────────────
const oscPort = new osc.UDPPort({
  localAddress: "0.0.0.0",
  localPort: OSC_LISTEN_PORT,
  remoteAddress: OSC_SEND_HOST,
  remotePort: OSC_SEND_PORT,
  metadata: true,
});

oscPort.on("ready", () => {
  console.log(`[OSC] Listening on port ${OSC_LISTEN_PORT}`);
  console.log(`[OSC] Sending to ${OSC_SEND_HOST}:${OSC_SEND_PORT}`);
  console.log(`[OSC] Log: ${OSC_LOG}`);
  console.log(`[MIDI] Log:  ${MIDI_LOG}`);
  console.log();
});

oscPort.on("message", (msg) => {
  const { address, args } = msg;
  logOsc("RX", address, args);

  if (args.length > 0) {
    oscState.set(address, args);
  }

  const forwardMsg = JSON.stringify({
    type: RESPONSE_TYPES.OSC,
    address: address,
    args: args.map((a) => ({ type: a.type, value: a.value })),
  });
  broadcastToClients(forwardMsg);
});

oscPort.on("error", (err) => {
  console.error("[OSC] Error:", err.message);
});

oscPort.open();

function sendOsc(address, ...args) {
  const oscMsg = { address, args };
  logOsc("TX", address, args);
  oscPort.send(oscMsg);
}

// ─── HTTP Server (Web GUI + Image Proxy) ─────────────
const mimeTypes = {
  ".html": "text/html",
  ".css": "text/css",
  ".js": "application/javascript",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

const httpServer = http.createServer((req, res) => {
  // CORS headers for development
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  let urlPath = req.url.split("?")[0];

  // ── Save pad image endpoint ──────────────────────
  if (req.method === "POST" && urlPath === "/save-pad-image") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const { filename, data } = JSON.parse(body);
        if (!filename || !data) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "Missing filename or data" }));
          return;
        }
        const safeName = path.basename(filename);
        const filePath = path.join(PADS_DIR, safeName);
        const buffer = Buffer.from(data, "base64");
        fs.writeFileSync(filePath, buffer);
        console.log(`[GUI] Saved pad image: ${safeName} (${buffer.length} bytes)`);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, path: `/pads/${safeName}` }));
      } catch (e) {
        console.error("[GUI] Failed to save image:", e.message);
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // Root -> index.html
  if (urlPath === "/" || urlPath === "/index.html") {
    urlPath = "/index.html";
  }

  let filePath;
  if (urlPath.startsWith("/pads/")) {
    filePath = path.join(GUI_DIR, urlPath);
  } else {
    filePath = path.join(GUI_DIR, urlPath);
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = mimeTypes[ext] || "application/octet-stream";

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === "ENOENT") {
        fs.readFile(path.join(GUI_DIR, "index.html"), (err2, html) => {
          if (err2) {
            res.writeHead(404, { "Content-Type": "text/plain" });
            res.end("404 Not Found");
          } else {
            res.writeHead(200, { "Content-Type": "text/html" });
            res.end(html);
          }
        });
      } else {
        res.writeHead(500, { "Content-Type": "text/plain" });
        res.end("500 Server Error");
      }
    } else {
      res.writeHead(200, { "Content-Type": contentType });
      res.end(data);
    }
  });
});

httpServer.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.error(`[GUI] ERROR: Port ${HTTP_PORT} is already in use!`);
    console.error(`[GUI] Try closing other apps or change HTTP_PORT env variable.`);
  } else {
    console.error("[GUI] HTTP Server error:", err.message);
  }
});

httpServer.listen(HTTP_PORT, "0.0.0.0", () => {
  console.log(`[GUI] Web GUI started: http://localhost:${HTTP_PORT}`);
  console.log(`[GUI] GUI dir: ${GUI_DIR}`);
  console.log(`[GUI] Pads dir: ${PADS_DIR}`);

  // Test: can we read the index.html?
  const testPath = path.join(GUI_DIR, "index.html");
  if (fs.existsSync(testPath)) {
    console.log(`[GUI] ✓ index.html found (${fs.statSync(testPath).size} bytes)`);
  } else {
    console.error(`[GUI] ✗ index.html NOT FOUND at ${testPath}`);
  }
});

// ─── WebSocket Server ─────────────────────────────────
const wss = new WebSocket.Server({ host: WS_HOST, port: WS_PORT });

wss.on("error", (err) => {
  console.error("[WS] Server error:", err.message);
});

function broadcastToClients(msg) {
  wss.clients.forEach((c) => {
    if (c.readyState === WebSocket.OPEN) c.send(msg);
  });
}

wss.on("connection", (ws, req) => {
  const clientIP = req.socket.remoteAddress;
  const userAgent = req.headers["user-agent"] || "unknown";
  console.log(`[WS] Client connected from ${clientIP} (${wss.clients.size} active)`);
  console.log(`[WS] User-Agent: ${userAgent}`);

  // Send welcome + current config
  ws.send(
    JSON.stringify({
      type: RESPONSE_TYPES.CONNECTED,
      message: "Server ready",
      config: appConfig,
      serverUrl: getServerUrl(),
    })
  );

  ws.on("message", (data) => {
    const raw = data.toString();
    console.log(`[RX] ${raw}`);

    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      console.warn("[WS] Invalid JSON");
      return;
    }

    switch (msg.type) {
      case COMMAND_TYPES.GET_STATE:
        sendMidiStateSync(ws);
        return;

      case COMMAND_TYPES.OSC_SEND:
        if (msg.address && msg.args) {
          sendOsc(msg.address, ...msg.args);
        }
        return;

      case COMMAND_TYPES.GET_CONFIG:
        ws.send(
          JSON.stringify({
            type: RESPONSE_TYPES.CONFIG,
            config: appConfig,
          })
        );
        return;

      case COMMAND_TYPES.UPDATE_CONFIG:
        // Update config from GUI, broadcast to all iPad clients
        // Merge GUI config into appConfig, preserving full pad image URLs
        const guiConfig = msg.config || {};
        // Pads from GUI may have relative URLs, convert to full URLs
        if (guiConfig.pads) {
          guiConfig.pads = guiConfig.pads.map((pad) => ({
            ...pad,
            imageUrl: pad.imageUrl && !pad.imageUrl.startsWith("http")
              ? `${getServerUrl()}${pad.imageUrl}`
              : pad.imageUrl,
          }));
        }
        appConfig = { ...appConfig, ...guiConfig };
        markConfigDirty();
        broadcastToClients(
          JSON.stringify({
            type: RESPONSE_TYPES.CONFIG,
            config: { ...appConfig, serverUrl: getServerUrl() },
          })
        );
        console.log("[CFG] Config updated by GUI");
        return;

      case COMMAND_TYPES.UPDATE_PAD_IMAGE:
        if (msg.padId != null && msg.imageName) {
          const pad = appConfig.pads.find((p) => p.id === msg.padId);
          if (pad) {
            pad.imageUrl = `${getServerUrl()}/pads/${msg.imageName}`;
            markConfigDirty();
            broadcastToClients(
              JSON.stringify({
                type: RESPONSE_TYPES.CONFIG,
                config: { ...appConfig, serverUrl: getServerUrl() },
              })
            );
            console.log(`[CFG] Pad ${msg.padId} image: ${getServerUrl()}/pads/${msg.imageName}`);
          }
        }
        return;

      default:
        // MIDI message
        handleMidiMessage(msg);
    }
  });

  ws.on("close", () =>
    console.log(`[WS] Client disconnected (${wss.clients.size} active)`)
  );
  ws.on("error", (err) => console.error("[WS] Client error:", err.message));
});

// ─── MIDI Handler ─────────────────────────────────────
function isValidMidiMessage(msg) {
  const { channel, control, value } = msg;
  return (
    channel != null &&
    control != null &&
    value != null &&
    typeof channel === "number" &&
    channel >= 0 &&
    channel <= 15 &&
    typeof control === "number" &&
    control >= 0 &&
    control <= 127 &&
    typeof value === "number" &&
    value >= 0 &&
    value <= 127
  );
}

function handleMidiMessage(msg) {
  const { type, channel, control, value } = msg;
  if (!isValidMidiMessage(msg)) {
    console.warn("[MIDI] Invalid:", msg);
    return;
  }

  try {
    switch (type) {
      case MSG_TYPES.CC:
        midiOutput.send(MIDI_EVENTS.CC, {
          controller: control,
          value,
          channel,
        });
        logMidiIO("OUT", "CC", channel, control, value);
        break;
      case MSG_TYPES.NOTE_ON:
        midiOutput.send(MIDI_EVENTS.NOTE_ON, {
          note: control,
          velocity: value,
          channel,
        });
        logMidiIO("OUT", "NOTE_ON", channel, control, 0, value);
        break;
      case MSG_TYPES.NOTE_OFF:
        midiOutput.send(MIDI_EVENTS.NOTE_OFF, {
          note: control,
          velocity: value,
          channel,
        });
        logMidiIO("OUT", "NOTE_OFF", channel, control);
        break;
      default:
        console.warn(`[MIDI] Unknown type: ${type}`);
    }
  } catch (err) {
    console.error("[MIDI] Send failed:", err.message);
  }
}

function sendMidiStateSync(client) {
  const state = {
    type: RESPONSE_TYPES.STATE_SYNC,
    cc: {},
    note: {},
  };
  midiState.cc.forEach((v, k) => (state.cc[k] = v));
  midiState.note.forEach((v, k) => (state.note[k] = v));
  client.send(JSON.stringify(state));
}

// ─── MIDI Input Listeners ─────────────────────────────
function setupMidiInputListeners() {
  // Feedback từ Resolume về iPad app (feedback channel)
  midiInput.on("cc", (msg) => {
    const key = `${msg.channel}-${msg.controller}`;
    midiState.cc.set(key, msg.value);
    logMidiIO("IN", "CC", msg.channel, msg.controller, msg.value);
    const feedbackMsg = JSON.stringify({
      type: MSG_TYPES.CC,
      channel: msg.channel,
      control: msg.controller,
      value: msg.value,
    });
    broadcastToClients(feedbackMsg);
  });

  midiInput.on("noteon", (msg) => {
    const key = `${msg.channel}-${msg.note}`;
    if (msg.velocity === 0) {
      midiState.note.set(key, 0);
      logMidiIO("IN", "NOTE_OFF", msg.channel, msg.note, 0);
      const feedbackMsg = JSON.stringify({
        type: MSG_TYPES.NOTE_OFF,
        channel: msg.channel,
        control: msg.note,
        value: 0,
      });
      broadcastToClients(feedbackMsg);
      return;
    }
    midiState.note.set(key, msg.velocity);
    logMidiIO("IN", "NOTE_ON", msg.channel, msg.note, 0, msg.velocity);
    const feedbackMsg = JSON.stringify({
      type: MSG_TYPES.NOTE_ON,
      channel: msg.channel,
      control: msg.note,
      value: msg.velocity,
    });
    broadcastToClients(feedbackMsg);
  });

  midiInput.on("noteoff", (msg) => {
    const key = `${msg.channel}-${msg.note}`;
    midiState.note.set(key, 0);
    logMidiIO("IN", "NOTE_OFF", msg.channel, msg.note, 0);
    const feedbackMsg = JSON.stringify({
      type: MSG_TYPES.NOTE_OFF,
      channel: msg.channel,
      control: msg.note,
      value: 0,
    });
    broadcastToClients(feedbackMsg);
  });
}

// ─── Startup ─────────────────────────────────────────
console.log("=".repeat(50));
console.log("  MIDI + OSC + Web GUI Server");
console.log("=".repeat(50));
console.log(`\n[WS] WebSocket: ws://${WS_HOST}:${WS_PORT}`);
console.log(`[GUI] Web GUI:   http://localhost:${HTTP_PORT}`);
console.log(`[OSC] UDP: ${OSC_LISTEN_PORT} (in), ${OSC_SEND_PORT} (out)`);

const usbIP = detectUsbTetheringIP();
if (usbIP) {
  console.log(`\n[USB] iPad USB Tethering: ws://${usbIP}:${WS_PORT}`);
  console.log(`[USB] -> Recommended! Use this IP in the iPad app\n`);
} else {
  console.log("\n[NETWORK] Available IPs:");
  getLocalIPs().forEach(({ name, address }) =>
    console.log(`  ${address} (${name})`)
  );
  console.log(`\n[!] If connecting via USB cable, enable Personal Hotspot on iPad.\n`);
}
console.log("[READY] Waiting for connections...\n");

// ─── Graceful Shutdown ────────────────────────────────
function shutdown(sig) {
  console.log(`\n[SERVER] ${sig}, shutting down...`);
  wss.clients.forEach((c) => c.terminate());
  wss.close(() => {
    httpServer.close();
    if (midiOutput) midiOutput.close();
    if (midiInput) midiInput.close();
    oscPort.close();
    oscLogStream.end();
    midiLogStream.end();
    console.log("[SERVER] Goodbye!\n");
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 5000);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

// ─── Network Helpers ──────────────────────────────────
function getLocalIPs() {
  const interfaces = os.networkInterfaces();
  const ips = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === "IPv4" && !iface.internal) {
        ips.push({ name, address: iface.address });
      }
    }
  }
  return ips;
}

function getIPByKeywords(keywords) {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    const lowerName = name.toLowerCase();
    if (keywords.some((kw) => lowerName.includes(kw))) {
      for (const iface of interfaces[name]) {
        if (iface.family === "IPv4" && !iface.internal) {
          return { name, address: iface.address };
        }
      }
    }
  }
  return null;
}

function detectUsbTetheringIP() {
  const usbKeywords = [
    "usb",
    "ethernet",
    "apple",
    "mobile",
    "tethering",
    "broadband",
  ];
  const usbIP = getIPByKeywords(usbKeywords);
  if (usbIP) {
    console.log(`[NET] USB tethering detected: ${usbIP.address} (${usbIP.name})`);
    return usbIP.address;
  }
  const allIPs = getLocalIPs();
  const tetherIP = allIPs.find((ip) => ip.address.startsWith("172."));
  if (tetherIP) {
    console.log(
      `[NET] USB tethering IP (172.x range): ${tetherIP.address} (${tetherIP.name})`
    );
    return tetherIP.address;
  }
  return null;
}
