# RemoteLaser

A lightweight macOS laser pointer overlay controlled directly from your phone's touch screen.

- **Non-intrusive Overlay**: Transparent, click-through overlay window that never steals focus or interferes with your mouse pointer.
- **Embedded Web Server**: Serves a mobile-friendly touch interface directly at `http://<mac-ip>:8080/` (no manual file sharing or app install on the phone).
- **Zero-Latency WebSocket**: High-performance JSON communication over `ws://<mac-ip>:8080/laser`.
- **CLI Connection Confirmation**: Prompts `[y/N]` in your Mac's terminal when a client requests access.
- **Smooth 60Hz Lerp & Ink Trails**: Smooth tracking with configurable smoothing and fading ink trails for circling items during presentations.

---

## Quick Start

### 1. Build
```bash
./build.sh
```

### 2. Run
```bash
# Launch default app
open ./build/RemoteLaser.app

# Or run with custom CLI flags
./build/RemoteLaser.app/Contents/MacOS/RemoteLaser --dot-size 6 --port 8080
```

### 3. Connect Phone
1. Open your phone browser (Brave, Safari, Chrome) and navigate to `http://<mac-ip>:8080/`.
2. In your Mac's terminal, type `y` + Enter to approve the incoming WebSocket connection.
3. Drag your finger across the tap pad to point and circle anywhere on your Mac screen.

---

## Command-Line Options

| Flag | Range | Default | Description |
|---|---|---|---|
| `--port <n>` | 1–65535 | `8080` | Web server & WebSocket port |
| `--dot-size <n>` | 1–200 | `4` | Laser dot radius in points |
| `--smooth <n>` | 0–1 | `0.2` | 60Hz frame lerp alpha (lower = silkier glide, 1 = instant snap) |
| `--sensitivity <n>` | 0.1–10 | `1.0` | Input gain multiplier around screen center |
| `--auto-hide <sec>` | 0–3600 | `1.0` | Inactivity seconds before dot fades (0 = stay visible) |
| `--trail-length <n>` | 0–500 | `50` | Maximum number of stamped trail segments (0 = no trail) |
| `--trail-fade <sec>` | 0–60 | `5.0` | Seconds for ink trail to completely fade out |
| `--allowed-ips <ips>` | `all` or IP list | `all` | Comma-separated list of allowed client IP addresses (e.g. `192.168.1.50,192.168.1.51`). If specific IPs are provided, matching clients connect directly without CLI `[y/N]` prompt while unauthorized IPs receive 401. |
| `-h, --help` | - | - | Show usage and exit |

---

## Wire Protocol (`ws://<mac-ip>:<port>/laser`)

### Client → Server
```json
{ "type": "move", "x": 0.5, "y": 0.5 }
{ "type": "hide" }
```
*(Coordinates normalized `0.0` to `1.0` with top-left origin).*

### Server → Client
```json
{ "type": "ready", "screen": { "w": 1920, "h": 1080 } }
```

---

