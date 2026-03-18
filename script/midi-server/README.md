# MIDI WebSocket Server

Receives MIDI signals from a Flutter iPad app over WebSocket and forwards them to a virtual MIDI port for DAW software (FL Studio, Ableton, Cubase, etc.).

## Setup Guide

### Step 1: Install loopMIDI (Virtual MIDI Port)

1. Download loopMIDI from: https://www.tobias-erichsen.de/software/loopmidi.html
2. Install and open loopMIDI
3. In the bottom-left text field, type: `loopMIDI Port`
4. Click the **+** button to create the virtual port
5. Keep loopMIDI running in the background

### Step 2: Install Dependencies

```bash
cd midi-server
npm install
```

### Step 3: Start the Server

```bash
node server.js
```

The console will display your local IP addresses — note the one on the same network as your iPad.

### Step 4: Configure Your DAW

- **FL Studio**: Options → MIDI Settings → Enable `loopMIDI Port` as input
- **Ableton Live**: Preferences → Link/Tempo/MIDI → Enable `loopMIDI Port` Input (Track + Remote)
- **Cubase**: Studio → Studio Setup → MIDI Port Setup → Enable `loopMIDI Port`

### Step 5: Connect the iPad App

1. Open the Flutter MIDI Controller app on your iPad
2. Go to Settings
3. Enter the IP address shown in the server console
4. Tap Connect

## USB Tethering (Zero-Latency Connection)

For the lowest possible latency, connect your iPad to the PC via USB tethering:

1. Connect iPad to PC with a USB cable
2. On iPad: Settings → Personal Hotspot → enable "Allow Others to Join"
3. On PC: a new network adapter will appear (usually named "Apple" or "iPhone")
4. Restart the server — the USB tethering IP will show in the console (typically `172.20.10.x`)
5. Enter that IP in the Flutter app

USB tethering provides ~1-2ms latency vs ~5-10ms over Wi-Fi.

## Configuration

Set a custom MIDI port name via environment variable:

```bash
MIDI_PORT=MyCustomPort node server.js
```

Enable MIDI message logging for debugging:

```bash
DEBUG=1 node server.js
```

## Message Format

The server expects JSON messages from the Flutter app:

```json
{"type": "controlChange", "channel": 0, "control": 1, "value": 127}
{"type": "noteOn", "channel": 9, "control": 36, "value": 100}
{"type": "noteOff", "channel": 9, "control": 36, "value": 0}
```

## Troubleshooting

- **"MIDI port not found"**: Make sure loopMIDI is running and the port name matches exactly
- **iPad can't connect**: Check that both devices are on the same network, and Windows Firewall allows Node.js
- **No MIDI in DAW**: Verify the DAW's MIDI input is set to `loopMIDI Port` and the track is armed for recording
