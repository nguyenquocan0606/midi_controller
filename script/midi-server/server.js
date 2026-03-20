const WebSocket = require("ws");
const easymidi = require("easymidi");
const osc = require("osc");
const os = require("os");
const fs = require("fs");
const path = require("path");

// --- Configuration ---
const WS_PORT = process.env.WS_PORT || 8765;
const WS_HOST = "0.0.0.0";

// MIDI: iPad -> Server -> Resolume, Resolume -> Server -> iPad
const MIDI_OUTPUT_PORT = process.env.MIDI_OUT || "loopMIDI Port";
const MIDI_INPUT_PORT = process.env.MIDI_IN || "loopMIDI output";

// OSC: Resolume <-> Server (feedback + state query)
const OSC_LISTEN_PORT = 7001;  // Server receives from Resolume
const OSC_SEND_PORT = 7000;    // Server sends to Resolume
const OSC_SEND_HOST = "127.0.0.1";

// --- OSC Log File ---
const LOG_FILE = path.join(__dirname, "osc-log.txt");
const logStream = fs.createWriteStream(LOG_FILE, { flags: "a" });

function logOsc(direction, address, args) {
  const ts = new Date().toISOString();
  const argsStr = args.map(a => `${a.type}:${a.value}`).join(", ");
  const line = `[${ts}] ${direction} ${address} | ${argsStr}`;
  console.log(`[OSC ${direction}] ${address} [${argsStr}]`);
  logStream.write(line + "\n");
}

// --- Constants ---
const MIDI_EVENTS = { CC: "cc", NOTE_ON: "noteon", NOTE_OFF: "noteoff" };
const MSG_TYPES = { CC: "controlChange", NOTE_ON: "noteOn", NOTE_OFF: "noteOff" };
const RESPONSE_TYPES = { CONNECTED: "connected", STATE_SYNC: "stateSync", OSC: "osc" };
const COMMAND_TYPES = { GET_STATE: "getState", OSC_SEND: "oscSend" };

// --- State Cache ---
const midiState = {
  cc: new Map(),
  note: new Map(),
};
const oscState = new Map(); // OSC address -> value

// --- MIDI Setup ---
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

  // MIDI Input for feedback (optional — skip if port not found)
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

// --- OSC Setup ---
const oscPort = new osc.UDPPort({
  localAddress: "0.0.0.0",
  localPort: OSC_LISTEN_PORT,
  remoteAddress: OSC_SEND_HOST,
  remotePort: OSC_SEND_PORT,
  metadata: true,
});
// --- OSC Handlers ---
oscPort.on("ready", () => {
  console.log(`[OSC] Listening on port ${OSC_LISTEN_PORT}`);
  console.log(`[OSC] Sending to ${OSC_SEND_HOST}:${OSC_SEND_PORT}`);
  console.log(`[OSC] Log file: ${LOG_FILE}\n`);
});

oscPort.on("message", (msg) => {
  const { address, args } = msg;
  logOsc("RX", address, args);

  // Cache state
  if (args.length > 0) {
    oscState.set(address, args);
  }

  // Forward to iPad as JSON
  const forwardMsg = JSON.stringify({
    type: RESPONSE_TYPES.OSC,
    address: address,
    args: args.map(a => ({ type: a.type, value: a.value }))
  });
  broadcastToClients(forwardMsg);
});

oscPort.on("error", (err) => {
  console.error("[OSC] Error:", err.message);
});

// Open the OSC port!
oscPort.open();

// --- Send OSC to Resolume ---
function sendOsc(address, ...args) {
  const oscMsg = { address, args };
  logOsc("TX", address, args);
  oscPort.send(oscMsg);
}

// --- WebSocket Server ---
const wss = new WebSocket.Server({ host: WS_HOST, port: WS_PORT });

wss.on("connection", (ws, req) => {
  const clientIP = req.socket.remoteAddress;
  console.log(`[WS] Client connected from ${clientIP} (${wss.clients.size} active)`);

  ws.send(JSON.stringify({ type: RESPONSE_TYPES.CONNECTED, message: "Server ready" }), (err) => {
    if (err) console.warn("[WS] Failed to send welcome:", err.message);
  });

  ws.on("message", (data) => {
    const raw = data.toString();
    console.log(`[RX] ${raw}`);

    let msg;
    try { msg = JSON.parse(raw); }
    catch { console.warn("[WS] Invalid JSON"); return; }

    // iPad requests MIDI state
    if (msg.type === COMMAND_TYPES.GET_STATE) {
      sendMidiStateSync(ws);
      return;
    }

    // iPad sends OSC directly to Resolume
    if (msg.type === COMMAND_TYPES.OSC_SEND) {
      if (msg.address && msg.args) {
        sendOsc(msg.address, ...msg.args);
      }
      return;
    }

    // Default: MIDI message
    handleMidiMessage(msg);
  });

  ws.on("close", () => console.log(`[WS] Client disconnected (${wss.clients.size} active)`));
  ws.on("error", (err) => console.error("[WS] Client error:", err.message));
});

// --- MIDI Handler ---
function isValidMidiMessage(msg) {
  const { channel, control, value } = msg;
  return channel != null && control != null && value != null
    && typeof channel === "number" && channel >= 0 && channel <= 15
    && typeof control === "number" && control >= 0 && control <= 127
    && typeof value === "number" && value >= 0 && value <= 127;
}

function handleMidiMessage(msg) {
  const { type, channel, control, value } = msg;
  if (!isValidMidiMessage(msg)) { console.warn("[MIDI] Invalid:", msg); return; }

  try {
    switch (type) {
      case MSG_TYPES.CC:
        midiOutput.send(MIDI_EVENTS.CC, { controller: control, value, channel });
        console.log(`[PAD->PC] Ch:${channel} CC:${control} Val:${value}`);
        break;
      case MSG_TYPES.NOTE_ON:
        midiOutput.send(MIDI_EVENTS.NOTE_ON, { note: control, velocity: value, channel });
        console.log(`[PAD->PC] Ch:${channel} Note:${control} Vel:${value}`);
        break;
      case MSG_TYPES.NOTE_OFF:
        midiOutput.send(MIDI_EVENTS.NOTE_OFF, { note: control, velocity: value, channel });
        console.log(`[PAD->PC] Ch:${channel} Note:${control} (OFF)`);
        break;
      default:
        console.warn(`[MIDI] Unknown type: ${type}`);
    }
  } catch (err) { console.error("[MIDI] Send failed:", err.message); }
}

// --- Helpers ---
function broadcastToClients(msg) {
  wss.clients.forEach(c => { if (c.readyState === WebSocket.OPEN) c.send(msg); });
}

function sendMidiStateSync(client) {
  const state = { type: RESPONSE_TYPES.STATE_SYNC, cc: {}, note: {} };
  midiState.cc.forEach((v, k) => state.cc[k] = v);
  midiState.note.forEach((v, k) => state.note[k] = v);
  console.log(`[STATE] MIDI sync (CCs:${Object.keys(state.cc).length}, Notes:${Object.keys(state.note).length})`);
  client.send(JSON.stringify(state));
}

// --- MIDI Input Listeners (feedback from Resolume) ---
function setupMidiInputListeners() {

  // CC Feedback (Fader, Knob)
  midiInput.on("cc", (msg) => {
    const key = `${msg.channel}-${msg.controller}`;
    midiState.cc.set(key, msg.value);

    const feedbackMsg = JSON.stringify({
      type: MSG_TYPES.CC,
      channel: msg.channel,
      control: msg.controller,
      value: msg.value
    });
    console.log(`[MIDI FB] Ch:${msg.channel} CC:${msg.controller} Val:${msg.value}`);
    broadcastToClients(feedbackMsg);
  });

  // NoteOn Feedback (Pad)
  midiInput.on("noteon", (msg) => {
    const key = `${msg.channel}-${msg.note}`;

    if (msg.velocity === 0) {
      midiState.note.set(key, 0);
      const feedbackMsg = JSON.stringify({
        type: MSG_TYPES.NOTE_OFF, channel: msg.channel, control: msg.note, value: 0
      });
      console.log(`[MIDI FB] Ch:${msg.channel} Note:${msg.note} (OFF vel=0)`);
      broadcastToClients(feedbackMsg);
      return;
    }

    midiState.note.set(key, msg.velocity);
    const feedbackMsg = JSON.stringify({
      type: MSG_TYPES.NOTE_ON, channel: msg.channel, control: msg.note, value: msg.velocity
    });
    console.log(`[MIDI FB] Ch:${msg.channel} Note:${msg.note} Vel:${msg.velocity}`);
    broadcastToClients(feedbackMsg);
  });

  // NoteOff Feedback
  midiInput.on("noteoff", (msg) => {
    const key = `${msg.channel}-${msg.note}`;
    midiState.note.set(key, 0);
    const feedbackMsg = JSON.stringify({
      type: MSG_TYPES.NOTE_OFF, channel: msg.channel, control: msg.note, value: msg.velocity
    });
    console.log(`[MIDI FB] Ch:${msg.channel} Note:${msg.note} (OFF)`);
    broadcastToClients(feedbackMsg);
  });
}

// --- Startup ---
console.log("=".repeat(50));
console.log("  MIDI + OSC Server for Resolume");
console.log("=".repeat(50));
console.log(`\n[WS] WebSocket: ws://${WS_HOST}:${WS_PORT}`);
console.log(`[OSC] UDP: ${OSC_LISTEN_PORT} (in), ${OSC_SEND_PORT} (out)`);
// Show USB tethering IP prominently
const usbIP = detectUsbTetheringIP();
if (usbIP) {
  console.log(`\n[USB] iPad USB Tethering: ws://${usbIP}:${WS_PORT}`);
  console.log(`[USB] -> Recommended! Use this IP in the iPad app for fastest connection\n`);
} else {
  console.log("\n[NETWORK] Available IPs:");
  getLocalIPs().forEach(({ name, address }) => console.log(`  ${address} (${name})`));
  console.log(`\n[!] If connecting via USB cable, enable Personal Hotspot on iPad.\n`);
}
console.log("[READY] Waiting for connections...\n");

// --- Graceful Shutdown ---
function shutdown(sig) {
  console.log(`\n[SERVER] ${sig}, shutting down...`);
  wss.clients.forEach(c => c.terminate());
  wss.close(() => {
    if (midiOutput) midiOutput.close();
    if (midiInput) midiInput.close();
    oscPort.close();
    logStream.end();
    console.log("[SERVER] Goodbye!\n");
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 5000);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

// --- Display Local IPs ---
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

// --- Get IP by Interface Type ---
function getIPByKeywords(keywords) {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    const lowerName = name.toLowerCase();
    // Match USB/Ethernet interfaces that appear when iPad is tethered
    if (keywords.some(kw => lowerName.includes(kw))) {
      for (const iface of interfaces[name]) {
        if (iface.family === "IPv4" && !iface.internal) {
          return { name, address: iface.address };
        }
      }
    }
  }
  return null;
}

// --- Detect USB Tethering IP ---
function detectUsbTetheringIP() {
  // Keywords that appear in USB tethering interface names on Windows
  const usbKeywords = ["usb", "ethernet", "apple", "mobile", "tethering", "broadband"];

  // Try USB-related interfaces first
  const usbIP = getIPByKeywords(usbKeywords);
  if (usbIP) {
    console.log(`[NET] USB tethering detected: ${usbIP.address} (${usbIP.name})`);
    return usbIP.address;
  }

  // Fallback: look for 172.x.x.x range (common for USB tethering)
  const allIPs = getLocalIPs();
  const tetherIP = allIPs.find(ip => ip.address.startsWith("172."));
  if (tetherIP) {
    console.log(`[NET] USB tethering IP (172.x range): ${tetherIP.address} (${tetherIP.name})`);
    return tetherIP.address;
  }

  return null;
}
