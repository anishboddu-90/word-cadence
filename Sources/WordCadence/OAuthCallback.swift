import Foundation
import Network

final class OAuthCallback {
    static let path = "/auth/callback"

    private let ready: AsyncThrowingStream<UInt16, Error>
    private let events: AsyncThrowingStream<URLComponents, Error>
    private let listener: NWListener
    private let queue = DispatchQueue(label: "WordCadence.OAuthCallback")

    init(state: String) throws {
        let readiness = AsyncThrowingStream<UInt16, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let callbacks = AsyncThrowingStream<URLComponents, Error>.makeStream(bufferingPolicy: .bufferingOldest(1))
        ready = readiness.stream
        events = callbacks.stream

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak listener] update in
            switch update {
            case .ready:
                if let port = listener?.port?.rawValue { readiness.continuation.yield(port) }
                readiness.continuation.finish()
            case .failed(let error):
                readiness.continuation.finish(throwing: error)
                callbacks.continuation.finish(throwing: error)
            case .cancelled:
                readiness.continuation.finish()
                callbacks.continuation.finish()
            default: break
            }
        }
        let queue = self.queue
        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            Self.read(connection, state: state, callbacks: callbacks.continuation)
            queue.asyncAfter(deadline: .now() + 8) { connection.cancel() }
        }
        listener.start(queue: queue)
    }

    deinit { listener.cancel() }

    func redirectURI() async throws -> String {
        var iterator = ready.makeAsyncIterator()
        guard let port = try await iterator.next() else {
            throw AppFailure.setup("Could not start the local ChatGPT sign-in callback.")
        }
        return "http://127.0.0.1:\(port)\(Self.path)"
    }

    func wait() async throws -> URLComponents {
        var iterator = events.makeAsyncIterator()
        guard let callback = try await iterator.next() else { throw CancellationError() }
        return callback
    }

    private static func read(
        _ connection: NWConnection, state: String,
        callbacks: AsyncThrowingStream<URLComponents, Error>.Continuation,
        received: Data = Data()
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { incoming, _, complete, error in
            let bytes = received + (incoming ?? Data())
            if let end = bytes.range(of: Data([13, 10]))?.lowerBound {
                let request = String(decoding: bytes.prefix(upTo: end), as: UTF8.self).split(separator: " ")
                if request.count == 3, request[0] == "GET", request[1].hasPrefix("/auth/callback?"),
                   let url = URLComponents(string: "http://127.0.0.1" + request[1]),
                   url.path == path,
                   let query = url.queryItems,
                   query.filter({ $0.name == "state" }).map(\.value) == [state] {
                    reply(connection, status: "200 OK", body: "Return to Word Cadence to finish signing in.")
                    callbacks.yield(url)
                } else {
                    reply(connection, status: "400 Bad Request", body: "Invalid sign-in callback.")
                }
            } else if !complete && error == nil && bytes.count < 8192 {
                read(connection, state: state, callbacks: callbacks, received: bytes)
            } else {
                connection.cancel()
            }
        }
    }

    private static func reply(_ connection: NWConnection, status: String, body: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/plain; charset=utf-8\r\n"
            + "Cache-Control: no-store\r\nReferrer-Policy: no-referrer\r\n"
            + "Connection: close\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}
