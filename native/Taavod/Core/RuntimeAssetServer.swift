import Foundation
import Network

/// Only generic lesson/runtime resources are served. No workspace or Keychain route exists.
nonisolated final class RuntimeAssetServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.hezi777.taavod.runtime-assets", qos: .utility)
    private let resources: URL
    private let runtimes: URL

    init(resources: URL, runtimes: URL) throws {
        self.resources = resources; self.runtimes = runtimes
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ServerStartGate(continuation)
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    guard let port = self?.listener.port else {
                        gate.finish(.failure(URLError(.cannotCreateFile)))
                        return
                    }
                    gate.finish(.success(URL(string: "http://127.0.0.1:\(port.rawValue)")!))
                case .waiting(let error):
                    gate.finish(.failure(error))
                case .failed(let error): gate.finish(.failure(error))
                case .cancelled: gate.finish(.failure(CancellationError()))
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { connection.cancel(); return }
                connection.start(queue: self.queue)
                self.receive(connection, accumulated: Data())
            }
            listener.start(queue: queue)
        }
    }
    func stop() { listener.cancel() }
    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            let request = accumulated + (data ?? Data())
            guard request.count <= 16384, error == nil else { connection.cancel(); return }
            if request.range(of: Data("\r\n\r\n".utf8)) != nil { self.respond(connection, request: request) }
            else if complete { connection.cancel() }
            else { self.receive(connection, accumulated: request) }
        }
    }
    private func respond(_ connection: NWConnection, request: Data) {
        let components = String(decoding: request.prefix(8192), as: UTF8.self).components(separatedBy: "\r\n").first?.split(separator: " ") ?? []
        guard components.count >= 2, components[0] == "GET",
              let path = String(components[1]).components(separatedBy: "?").first?.removingPercentEncoding,
              !path.contains(".."), !path.contains("\\"), !path.contains("\0") else {
            send(connection, status: "400 Bad Request", mime: "text/plain", data: Data()); return
        }
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let root: URL
        let file: URL
        if relative.hasPrefix("packs/sql/") || relative.hasPrefix("packs/python/") {
            root = runtimes; file = runtimes.appendingPathComponent(String(relative.dropFirst(6)))
        } else if relative.hasPrefix("engine/") || relative.hasPrefix("datasets/") {
            root = resources; file = resources.appendingPathComponent(relative)
        } else { send(connection, status: "404 Not Found", mime: "text/plain", data: Data()); return }
        let resolved = file.resolvingSymlinksInPath()
        guard resolved.path.hasPrefix(root.resolvingSymlinksInPath().path + "/"),
              let data = try? Data(contentsOf: resolved, options: .mappedIfSafe) else {
            send(connection, status: "404 Not Found", mime: "text/plain", data: Data()); return
        }
        let mime = switch resolved.pathExtension {
        case "js", "mjs": "text/javascript"
        case "html": "text/html"
        case "json": "application/json"
        case "wasm": "application/wasm"
        default: "application/octet-stream"
        }
        send(connection, status: "200 OK", mime: mime, data: data)
    }
    private func send(_ connection: NWConnection, status: String, mime: String, data: Data) {
        let policy = "default-src 'none'; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval'; worker-src 'self' blob:; connect-src 'self'; img-src data: blob:; style-src 'unsafe-inline';"
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(mime)\r\nContent-Length: \(data.count)\r\nConnection: close\r\nCache-Control: no-store\r\nContent-Security-Policy: \(policy)\r\nX-Content-Type-Options: nosniff\r\n\r\n"
        connection.send(content: Data(header.utf8) + data, completion: .contentProcessed { _ in connection.cancel() })
    }
}

nonisolated private final class ServerStartGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, any Error>?
    init(_ continuation: CheckedContinuation<URL, any Error>) { self.continuation = continuation }
    func finish(_ result: Result<URL, any Error>) {
        lock.lock(); let saved = continuation; continuation = nil; lock.unlock()
        saved?.resume(with: result)
    }
}
