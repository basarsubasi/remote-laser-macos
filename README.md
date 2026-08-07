# RemoteLaser (phase 1 — server)

A macOS laser-pointer overlay controlled from a phone over WebSocket.

- Borderless, transparent `NSWindow` at screen-saver level with `ignoresMouseEvents` — does not interfere with the mouse or any app underneath.
- Hummingbird WebSocket server on `0.0.0.0:<port>/laser` (default `8080`, configurable via `--port`), reachable from a phone on the same LAN.
- The laser dot is a `CALayer` (crisp core + radial gradient glow) animated with a short Core Animation tween so discrete WS move samples interpolate smoothly.
- Coordinates are normalized `0..1` per axis; the server maps to the active screen's `visibleFrame` and clamps (never under menu bar / Dock).
- Menu-bar app: `LSUIElement` (no Dock icon), single-icon menu with Quit.
- Auto-hides the dot after ~4s of inactivity.

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
./run                 # quick debug run via swift run (port 8080, speed 0.12s)
./run --port 9000     # quick debug run on a custom port
./run --speed 0.05    # snappier slide (lower = faster)
./run --speed 0.3     # smoother/slower slide
./run --speed 0       # no animation, instant jumps
./build/RemoteLaser.app/Contents/MacOS/RemoteLaser --port 9000 --speed 0.2   # bundled binary w/ flags
```

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