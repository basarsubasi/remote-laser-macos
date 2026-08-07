import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOCore

final class LaserServer: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private let port: Int
    private let onEvent: @Sendable (LaserEvent) -> Void

    init(port: Int = 8080, onEvent: @escaping @Sendable (LaserEvent) -> Void) {
        self.port = port
        self.onEvent = onEvent
    }

    func start() {
        guard task == nil else { return }
        let onEvent = self.onEvent
        let port = self.port

        task = Task.detached { [weak self] in
            let wsRouter = Router(context: BasicWebSocketRequestContext.self)

            wsRouter.ws("/laser") { _, _ in
                .upgrade()
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

            let router = Router(context: BasicWebSocketRequestContext.self)
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
}