import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdWebSocket
import NIOCore

struct LaserRequestContext: RequestContext, WebSocketRequestContext {
    var coreContext: CoreRequestContextStorage
    let channel: any Channel
    let webSocket: WebSocketHandlerReference<Self>

    init(source: ApplicationRequestContextSource) {
        self.coreContext = .init(source: source)
        self.channel = source.channel
        self.webSocket = .init()
    }

    var remoteAddress: SocketAddress? {
        channel.remoteAddress
    }
}

final class LaserServer: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private let port: Int
    private let allowedIPs: [String]
    private let onEvent: @Sendable (LaserEvent) -> Void

    init(port: Int = 8080, allowedIPs: [String] = ["all"], onEvent: @escaping @Sendable (LaserEvent) -> Void) {
        self.port = port
        self.allowedIPs = allowedIPs
        self.onEvent = onEvent
    }

    func start() {
        guard task == nil else { return }
        let onEvent = self.onEvent
        let port = self.port
        let allowedIPs = self.allowedIPs

        task = Task.detached { [weak self] in
            let wsRouter = Router(context: LaserRequestContext.self)

            wsRouter.ws("/laser") { request, context in
                let clientIP = Self.extractClientIP(request: request, remoteAddress: context.remoteAddress)

                guard Self.isIPAllowed(clientIP, allowedIPs: allowedIPs) else {
                    print("\n[RemoteLaser] Rejected WebSocket connection from unauthorized IP: \(clientIP ?? "<unknown>") (allowed: \(allowedIPs.joined(separator: ", ")))")
                    context.logger.warning("Rejected WebSocket connection from unauthorized IP: \(clientIP ?? "<unknown>")")
                    throw HTTPError(.unauthorized)
                }

                let origin = request.headers[.origin]
                        ?? request.headers[values: .origin].first
                        ?? "<unknown>"
                let userAgent = request.headers[.userAgent] ?? "<unknown>"
                let remoteHint: String = request.head.authority ?? "<unknown>"

                print("\n[RemoteLaser] Incoming WebSocket connection request:")
                print("  Client IP:    \(clientIP ?? "<unknown>")")
                print("  Origin:       \(origin)")
                print("  User-Agent:   \(userAgent)")
                print("  Remote hint:  \(remoteHint)")
                print("  Allow this connection? [y/N] ", terminator: "")

                let allowed = await Self.confirmOnCLI()
                context.logger.info("Connection \(allowed ? "allowed" : "denied") by CLI")
                return allowed ? .upgrade([:]) : .dontUpgrade
            } onUpgrade: { inbound, outbound, context in
                context.logger.info("Client connected")
                let size = await MainActor.run {
                    ScreenGeometry.mainVisibleFrame().size
                }
                let ready: [String: Any] = [
                    "type": "ready",
                    "screen": ["w": Int(size.width), "h": Int(size.height)]
                ]
                if let data = try? JSONSerialization.data(withJSONObject: ready),
                   let str = String(data: data, encoding: .utf8) {
                    try? await outbound.write(.text(str))
                }

                do {
                    for try await message in inbound.messages(maxSize: .max) {
                        if case .text(let text) = message {
                            #if DEBUG
                            print("[Server] received text frame: \(text)")
                            #endif
                            if let payload = text.data(using: .utf8),
                               let event = try? JSONDecoder().decode(LaserEvent.self, from: payload) {
                                onEvent(event)
                            } else {
                                context.logger.info("Ignored malformed event: \(text)")
                            }
                        }
                    }
                } catch {
                    context.logger.info("Client ended: \(error)")
                }
            }

            let router = Router(context: LaserRequestContext.self)

            // Serve the touch-control web UI at the root URL.
            // This is critical: mobile browsers (Brave, Chrome) with HTTPS-First
            // mode will block ws:// connections from file:// or https:// pages.
            // Serving the HTML from the SAME http:// origin avoids mixed content.
            router.get("/") { request, context -> Response in
                let clientIP = Self.extractClientIP(request: request, remoteAddress: context.remoteAddress)
                guard Self.isIPAllowed(clientIP, allowedIPs: allowedIPs) else {
                    print("\n[RemoteLaser] Rejected HTTP request from unauthorized IP: \(clientIP ?? "<unknown>") (allowed: \(allowedIPs.joined(separator: ", ")))")
                    throw HTTPError(.unauthorized)
                }
                let html = ClientHTML.content
                return Response(
                    status: .ok,
                    headers: [
                        .contentType: "text/html; charset=utf-8",
                        .cacheControl: "no-cache",
                    ],
                    body: .init(byteBuffer: .init(string: html))
                )
            }

            let app = Application(
                router: router,
                server: .http1WebSocketUpgrade(webSocketRouter: wsRouter),
                configuration: .init(address: .hostname("0.0.0.0", port: port))
            )

            _ = self
            do {
                try await app.runService()
            } catch {
                print("Server error: \(error)")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Clean IP string (e.g. strip IPv4-mapped IPv6 prefix `::ffff:`).
    static func cleanIP(_ ip: String) -> String {
        let lower = ip.lowercased()
        if lower.hasPrefix("::ffff:") {
            return String(ip.dropFirst(7))
        }
        return ip
    }

    /// Extract the client IP from context remoteAddress or proxy headers.
    static func extractClientIP(request: Request, remoteAddress: SocketAddress?) -> String? {
        if let remoteAddress = remoteAddress, let ip = remoteAddress.ipAddress {
            return cleanIP(ip)
        }
        if let fieldName = HTTPField.Name("x-forwarded-for"),
           let xff = request.headers[fieldName] {
            let first = xff.split(separator: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = first, !first.isEmpty {
                return cleanIP(first)
            }
        }
        if let fieldName = HTTPField.Name("x-real-ip"),
           let realIP = request.headers[fieldName] {
            let trimmed = realIP.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return cleanIP(trimmed)
            }
        }
        return nil
    }

    /// Check if the incoming IP is permitted by the configured `allowedIPs`.
    static func isIPAllowed(_ ip: String?, allowedIPs: [String]) -> Bool {
        if allowedIPs.isEmpty || allowedIPs.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "all" }) {
            return true
        }
        guard let ip = ip, !ip.isEmpty else {
            return false
        }
        let cleanedIP = cleanIP(ip)
        for allowed in allowedIPs {
            let trimmed = allowed.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() == "all" {
                return true
            }
            let cleanedAllowed = cleanIP(trimmed)
            if cleanedIP == cleanedAllowed {
                return true
            }
            // Handle localhost aliases (127.0.0.1 / ::1 / localhost)
            if (cleanedAllowed == "127.0.0.1" || cleanedAllowed == "localhost") && (cleanedIP == "127.0.0.1" || cleanedIP == "::1") {
                return true
            }
            if cleanedAllowed == "::1" && (cleanedIP == "::1" || cleanedIP == "127.0.0.1") {
                return true
            }
        }
        return false
    }

    /// Prompt the user on the CLI for a yes/no confirmation.
    /// Accepts `y` / `yes` (case-insensitive). Anything else, including
    /// EOF/empty input, is treated as "no". Blocks until input is received.
    private static func confirmOnCLI() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let lower = line.lowercased()
                let allowed = lower == "y" || lower == "yes"
                continuation.resume(returning: allowed)
            }
        }
    }
}