const WebSocket = require("ws");
const easymidi = require("easymidi");
const os = require("os");

// --- Configuration ---
const WS_PORT = process.env.WS_PORT || 8765;
const WS_HOST = "0.0.0.0";
const MIDI_PORT_NAME = process.env.MIDI_PORT || "loopMIDI Port";
const DEBUG = process.env.DEBUG === "1";

// --- Constants ---
const MIDI_EVENTS = {
  CC: "cc",
  NOTE_ON: "noteon",
  NOTE_OFF: "noteoff",
};

const MSG_TYPES = {
  CC: "controlChange",
  NOTE_ON: "noteOn",
  NOTE_OFF: "noteOff",
};

const RESPONSE_TYPES = {
  CONNECTED: "connected",
};

const LOG_PREFIX = {
  [MSG_TYPES.CC]: "[CC]      ",
  [MSG_TYPES.NOTE_ON]: "[NOTE ON] ",
  [MSG_TYPES.NOTE_OFF]: "[NOTE OFF]",
};

// --- MIDI Setup ---
let midiOutput;
try {
  const outputs = easymidi.getOutputs();
  console.log("\n[MIDI] Available MIDI output ports:");
  outputs.forEach((name, i) => console.log(`  ${i}: ${name}`));

  if (!outputs.includes(MIDI_PORT_NAME)) {
    console.error(
      `\n[ERROR] MIDI port "${MIDI_PORT_NAME}" not found.` +
        "\n  1. Install loopMIDI: https://www.tobias-erichsen.de/software/loopmidi.html" +
        `\n  2. Create a virtual port named "${MIDI_PORT_NAME}"` +
        "\n  3. Restart this server.\n"
    );
    process.exit(1);
  }

  midiOutput = new easymidi.Output(MIDI_PORT_NAME);
  console.log(`[MIDI] Connected to "${MIDI_PORT_NAME}"\n`);
} catch (err) {
  console.error("[ERROR] Failed to initialize MIDI:", err.message);
  process.exit(1);
}

// --- WebSocket Server ---
const wss = new WebSocket.Server({ host: WS_HOST, port: WS_PORT });

wss.on("connection", (ws, req) => {
  const clientIP = req.socket.remoteAddress;
  console.log(`[WS] Client connected from ${clientIP} (${wss.clients.size} active)`);

  ws.send(JSON.stringify({ type: RESPONSE_TYPES.CONNECTED, message: "Server ready" }), (err) => {
    if (err) console.warn("[WS] Failed to send welcome message:", err.message);
  });

  ws.on("message", (data) => {
    const raw = data.toString();
    console.log(`[RX] ${raw}`);

    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      console.warn("[WS] Invalid JSON received, ignoring.");
      return;
    }
    handleMidiMessage(msg);
  });

  ws.on("close", () => {
    console.log(`[WS] Client disconnected (${wss.clients.size} active)`);
  });

  ws.on("error", (err) => {
    console.error("[WS] Client error:", err.message);
  });
});

// --- MIDI Message Handler ---
function isValidMidiMessage(msg) {
  const { channel, control, value } = msg;
  if (channel == null || control == null || value == null) return false;
  if (typeof channel !== "number" || channel < 0 || channel > 15) return false;
  if (typeof control !== "number" || control < 0 || control > 127) return false;
  if (typeof value !== "number" || value < 0 || value > 127) return false;
  return true;
}

function handleMidiMessage(msg) {
  const { type, channel, control, value } = msg;

  if (!isValidMidiMessage(msg)) {
    console.warn("[MIDI] Invalid message, ignoring:", msg);
    return;
  }

  try {
    switch (type) {
      case MSG_TYPES.CC:
        midiOutput.send(MIDI_EVENTS.CC, { controller: control, value, channel });
        console.log(`[CC]      Ch:${channel} CC:${control} Val:${value}`);
        break;

      case MSG_TYPES.NOTE_ON:
        midiOutput.send(MIDI_EVENTS.NOTE_ON, { note: control, velocity: value, channel });
        console.log(`[NOTE ON] Ch:${channel} Note:${control} Vel:${value}`);
        break;

      case MSG_TYPES.NOTE_OFF:
        midiOutput.send(MIDI_EVENTS.NOTE_OFF, { note: control, velocity: value, channel });
        console.log(`[NOTE OFF] Ch:${channel} Note:${control} Vel:${value}`);
        break;

      default:
        console.warn(`[MIDI] Unknown type: ${type}`);
    }
  } catch (err) {
    console.error("[MIDI] Send failed:", err.message);
  }
}

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

// --- Startup ---
console.log("=".repeat(50));
console.log("  MIDI WebSocket Server");
console.log("=".repeat(50));
console.log(`\n[SERVER] Listening on ws://${WS_HOST}:${WS_PORT}`);
console.log("\n[NETWORK] Connect your iPad using one of these IPs:");
getLocalIPs().forEach(({ name, address }) => {
  console.log(`  ${address}  (${name})`);
});
console.log(`\n  Port: ${WS_PORT}`);
console.log(DEBUG ? "\n[DEBUG] MIDI logging enabled\n" : "\n[READY] Waiting for connections...\n");

// --- Graceful Shutdown ---
function shutdown(signal) {
  console.log(`\n[SERVER] Received ${signal}, shutting down...`);

  // Terminate all connected clients
  for (const client of wss.clients) {
    client.terminate();
  }

  wss.close(() => {
    if (midiOutput) {
      midiOutput.close();
      console.log("[SERVER] MIDI port closed.");
    }
    console.log("[SERVER] Goodbye!\n");
    process.exit(0);
  });

  // Force exit after timeout
  setTimeout(() => {
    console.error("[SERVER] Forced exit after timeout.");
    process.exit(1);
  }, 5000);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
