import Foundation

struct Options {
    var port: Int = 8080
    var smooth: Double = 0.2          // lerp alpha per 60Hz frame [0..1] — low = silkier chase
    var sensitivity: Double = 1.0
    var dotSize: Double = 10         // dot radius in points
    var autoHide: Double = 1.0       // seconds of inactivity before the dot hides (0 = never)
    var trailLength: Int = 0         // number of trailing segments to render (0 = no trail)
    var help: Bool = false

    static let usage = """
    Usage: RemoteLaser [options]

    Options:
      --port <1-65535>        WebSocket server port (default: 8080)
      --smooth <0-1>          Lerp factor per 60Hz frame (default: 0.2).
                              0 = never moves, 1 = instant snap,
                              ~0.2 = silk-smooth chase of incoming targets.
      --sensitivity <0.1-10>  Input gain around screen center (default: 1.0).
                              >1 amplifies finger movement, <1 dampens it.
      --dot-size <1-200>      Dot radius in points (default: 10).
      --auto-hide <sec>       Seconds of inactivity before the dot hides (default: 1.0).
                              0 = never auto-hide.
      --trail-length <0-200>  Number of fading trailing segments behind the dot
                              (default: 0 = no trail). Larger = longer/more dramatic tail.
      -h, --help              Show this message and exit
    """

    static func parse(_ args: [String]) -> Options {
        var opts = Options()
        var i = 1
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-h", "--help":
                opts.help = true
                i += 1
            case "--port":
                guard i + 1 < args.count, let value = Int(args[i + 1]) else {
                    fail("--port requires a numeric value")
                }
                opts.port = validatePort(value)
                i += 2
            case "--smooth":
                guard i + 1 < args.count, let value = Double(args[i + 1]) else {
                    fail("--smooth requires a numeric value")
                }
                opts.smooth = validateAlpha(value, flag: "--smooth")
                i += 2
            case "--sensitivity":
                guard i + 1 < args.count, let value = Double(args[i + 1]) else {
                    fail("--sensitivity requires a numeric value")
                }
                opts.sensitivity = validateSensitivity(value)
                i += 2
            case "--dot-size":
                guard i + 1 < args.count, let value = Double(args[i + 1]) else {
                    fail("--dot-size requires a numeric value")
                }
                opts.dotSize = validateDotSize(value)
                i += 2
            case "--auto-hide":
                guard i + 1 < args.count, let value = Double(args[i + 1]) else {
                    fail("--auto-hide requires a numeric value")
                }
                opts.autoHide = validateAutoHide(value)
                i += 2
            case "--trail-length":
                guard i + 1 < args.count, let value = Int(args[i + 1]) else {
                    fail("--trail-length requires an integer value")
                }
                opts.trailLength = validateTrailLength(value)
                i += 2
            default:
                if let (_, v) = parseEquals(arg, "--port") {
                    guard let n = Int(v) else { fail("--port requires a numeric value") }
                    opts.port = validatePort(n)
                } else if let (_, v) = parseEquals(arg, "--smooth") {
                    guard let n = Double(v) else { fail("--smooth requires a numeric value") }
                    opts.smooth = validateAlpha(n, flag: "--smooth")
                } else if let (_, v) = parseEquals(arg, "--sensitivity") {
                    guard let n = Double(v) else { fail("--sensitivity requires a numeric value") }
                    opts.sensitivity = validateSensitivity(n)
                } else if let (_, v) = parseEquals(arg, "--dot-size") {
                    guard let n = Double(v) else { fail("--dot-size requires a numeric value") }
                    opts.dotSize = validateDotSize(n)
                } else if let (_, v) = parseEquals(arg, "--auto-hide") {
                    guard let n = Double(v) else { fail("--auto-hide requires a numeric value") }
                    opts.autoHide = validateAutoHide(n)
                } else if let (_, v) = parseEquals(arg, "--trail-length") {
                    guard let n = Int(v) else { fail("--trail-length requires an integer value") }
                    opts.trailLength = validateTrailLength(n)
                } else {
                    fail("Unknown argument: \(arg)")
                }
                i += 1
            }
        }
        return opts
    }

    private static func parseEquals(_ arg: String, _ key: String) -> (String, String)? {
        let prefix = key + "="
        guard arg.hasPrefix(prefix) else { return nil }
        return (key, String(arg.dropFirst(prefix.count)))
    }

    private static func validatePort(_ value: Int) -> Int {
        guard (1...65_535).contains(value) else {
            fail("--port must be between 1 and 65535")
        }
        return value
    }

    private static func validateAlpha(_ value: Double, flag: String) -> Double {
        guard (0...1).contains(value) else {
            fail("\(flag) must be between 0 and 1")
        }
        return value
    }

    private static func validateSensitivity(_ value: Double) -> Double {
        guard (0.1...10).contains(value) else {
            fail("--sensitivity must be between 0.1 and 10")
        }
        return value
    }

    private static func validateDotSize(_ value: Double) -> Double {
        guard (1...200).contains(value) else {
            fail("--dot-size must be between 1 and 200 points")
        }
        return value
    }

    private static func validateAutoHide(_ value: Double) -> Double {
        guard (0...3600).contains(value) else {
            fail("--auto-hide must be between 0 (never) and 3600 seconds")
        }
        return value
    }

    private static func validateTrailLength(_ value: Int) -> Int {
        guard (0...200).contains(value) else {
            fail("--trail-length must be between 0 and 200")
        }
        return value
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("RemoteLaser: \(message)\n".utf8))
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(1)
    }
}