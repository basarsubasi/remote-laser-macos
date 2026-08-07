# RemoteLaser (phase 1 — server)

A macOS laser-pointer overlay controlled from a phone over WebSocket.

- Borderless, transparent `NSWindow` at screen-saver level with `ignoresMouseEvents` — does not interfere with the mouse or any app underneath.
- Hummingbird WebSocket server on `0.0.0.0:<port>/laser` (default `8080`, configurable via `--port`), reachable from a phone on the same LAN.
- The laser dot is a single solid `CALayer` (no glow) whose position is updated by a 60Hz timer that lerps toward the latest WS-incoming target. Smoothness is decoupled from the WS frame rate.
- Optional **persistent ink trail** for circling things: every 60Hz position the dot visits gets "stamped" on screen and stays there, fading out over `--trail-fade <sec>`. The ink is independent of the dot — when you stop or auto-hide, the mark lingers and fades on screen. `--trail-length <n>` caps the stamp buffer; `0` disables the trail entirely.

  Stamps are auto-interpolated: if the dot moves a long distance in a single tick (high speed / big jump), the segment is subdivided into stamps at ~half-dot-radius spacing so the trail always reads as a continuous line, never separated dots. A stroke-break heuristic suppresses connector lines when the dot re-appears after being hidden.

  UX: draw a circle on screen → let go → the dot auto-hides after `--auto-hide` seconds, but the circle you drew remains visible and fades over `--trail-fade` seconds. Great for annotating live demos.
- Size configurable via `--dot-size <points>` (radius), and the smoothing factor via `--smooth <0-1>` (lerp alpha per 60Hz frame).
- Coordinates are normalized `0..1` per axis; the server maps to the active screen's `visibleFrame` and clamps (never under menu bar / Dock).
- Menu-bar app: `LSUIElement` (no Dock icon), single-icon menu with Quit.
- Auto-hides the dot after `--auto-hide <sec>` seconds of inactivity (default 1s; 0 = never).

## Layout

```
Sources/RemoteLaser/
  main.swift                      NSApplication entry, accessory policy
  AppDelegate.swift               menu bar, permission prompt, server wiring
  Overlay/
    LaserOverlayController.swift  pass-through NSWindow + screen mapping
    LaserDotView.swift            CALayer dot + glow, Core Animation tween
  Server/
    LaserServer.swift             Hummingbird WS route on /laser, 0.0.0.0:8080
    LaserEvent.swift              Codable {type, x?, y?}
    EventProcessor.swift          @MainActor: clamp + animate + auto-hide
  Util/
    ScreenGeometry.swift          main NSScreen frame helpers
Package.swift                     SwiftPM, macOS 14+, Hummingbird deps
build.sh                          release .app bundle (codesign ad-hoc)
install.sh [autostart]            copies to /Applications, optional LaunchAgent
uninstall.sh                      stops, removes app + LaunchAgent + resets TCC
run                               quick debug launch without bundling
```

## Wire protocol (WS)

Client → Server, JSON text frames:
```json
{ "type": "move", "x": 0.5, "y": 0.5 }   // x,y in 0..1, top-left origin
{ "type": "hide" }
```
`down` / `up` are accepted (reserved for phase 2, no behavior yet).

Server → Client:
```json
{ "type": "ready", "screen": { "w": 1920, "h": 1080 } }
```

## Build & run

Requires Swift 5.10+ and macOS 14+.

```bash
./build.sh            # produces build/RemoteLaser.app
./run                 # quick debug run via swift run (defaults: port 8080, dot 10pt, smooth 0.35)
./run --port 9000
./run --dot-size 14 --smooth 0.5            # bigger dot, snappier chase
./run --dot-size 6  --smooth 0.2           # tiny dot, dreamy glide
./run --sensitivity 2 --dot-size 20        # amplified movement, big dot
./build/RemoteLaser.app/Contents/MacOS/RemoteLaser --port 9000 --dot-size 16 --smooth 0.4
```

Flag reference:

| Flag | Range | Default | What it does |
|---|---|---|---|
| `--port <n>` | 1-65535 | `8080` | WebSocket server port |
| `--dot-size <n>` | 1-200 | `5` | Dot radius in points |
| `--smooth <n>` | 0-1 | `0.2` | Lerp alpha per 60Hz frame. 1 = instant snap, smaller = smoother/slower chase |
| `--sensitivity <n>` | 0.1-10 | `1.0` | Input gain around screen center. >1 amplifies finger movement |
| `--auto-hide <n>` | 0-3600 | `1.0` | Seconds of inactivity before the dot hides. 0 = never hide |
| `--trail-length <n>` | 0-500 | `50` | Max number of stamp segments kept in the trail buffer. 0 = no trail. Stamps persist on screen independent of the dot |
| `--trail-fade <n>` | 0-60 | `5.0` | Seconds for a stamped segment to fully fade. 0 = never fade (only capped by `--trail-length`) |

The bundled `.app` (via `open build/RemoteLaser.app`) always uses the default port because `open` does not forward args; to set a port on the bundled binary, invoke the executable inside the bundle directly as above, or rebuild with `build.sh` after editing the default in `Sources/RemoteLaser/Util/Options.swift`.

Or install to /Applications:
```bash
./install.sh              # install and open; default port
./install.sh autostart    # install + LaunchAgent that runs on login (default port)
./uninstall.sh            # stop + remove app, LaunchAgent, build artifacts;
                          # defensively resets TCC entries
```

## Permissions

The overlay is non-interactive (`ignoresMouseEvents`) and is drawn with a plain `NSWindow`/`CALayer`, so **no Accessibility permission is required** in phase 1. No CGEventTap, no synthetic input, no AppleScript control of other apps.

The only prompt you may see is the **macOS Application Firewall** asking whether to allow "incoming network connections" the first time the WS binds to `0.0.0.0:8080`. That is unrelated to Accessibility (it's ALF / `socketfilterfw`) and expected for any ad-hoc-signed server app. Approve it so the phone can reach the mac.

`uninstall.sh` resets `com.remotelaser.app` TCC entries defensively; this is vestigial for phase 1 and harmless.

## Testing the server without the phone

```bash
.build/release/RemoteLaser --port 8080 &
# then send a JSON frame to ws://<mac-LAN-IP>:8080/laser with any WS client, e.g.:
# websocat ws://127.0.0.1:8080/laser
# > {"type":"move","x":0.5,"y":0.5}
```

## Phase 2 (not in this build)

LAN auto-discovery, pairing token, relative-delta mode, multi-display, comet trail, off-LAN relay.