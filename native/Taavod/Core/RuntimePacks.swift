import CryptoKit
import Foundation
import Observation

enum PackKind: String, CaseIterable, Identifiable, Codable { case sql, python; var id: String { rawValue } }

struct RuntimeManifest: Decodable {
    struct Pack: Decodable {
        struct File: Decodable { var path: String; var url: URL; var sha256: String; var bytes: Int }
        var version: String
        var files: [File]
    }
    var sql: Pack
    var python: Pack
    subscript(_ kind: PackKind) -> Pack { kind == .sql ? sql : python }
    static func load() throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: AppPaths.resources.appendingPathComponent("runtime-manifest.json")))
    }
}

@Observable final class RuntimePacks {
    private(set) var installing: PackKind?
    private(set) var progress = 0.0
    var error: String?
    private var task: Task<Void, Error>?
    private var revision = 0
    static var root: URL { AppPaths.support.appendingPathComponent("Runtimes", isDirectory: true) }

    func isInstalled(_ kind: PackKind) -> Bool {
        _ = revision
        guard let manifest = try? RuntimeManifest.load() else { return false }
        let folder = Self.root.appendingPathComponent(kind.rawValue, isDirectory: true)
        let version = try? String(contentsOf: folder.appendingPathComponent(".version"), encoding: .utf8)
        return version == manifest[kind].version && manifest[kind].files.allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.path).path)
        }
    }
    func sizeLabel(_ kind: PackKind) -> String {
        guard let pack = try? RuntimeManifest.load()[kind] else { return "One-time download" }
        return ByteCountFormatter.string(fromByteCount: Int64(pack.files.reduce(0) { $0 + $1.bytes }), countStyle: .file)
    }
    func install(_ kind: PackKind) async throws {
        guard installing == nil else { return }
        installing = kind; progress = 0; error = nil
        let operation = Task { try await self.download(kind) }
        task = operation
        defer { installing = nil; task = nil; revision += 1 }
        do { try await operation.value }
        catch is CancellationError { throw CancellationError() }
        catch { self.error = error.localizedDescription; throw error }
    }
    func cancel() { task?.cancel() }
    func remove(_ kind: PackKind) throws {
        guard installing != kind else { return }
        try FileManager.default.removeItem(at: Self.root.appendingPathComponent(kind.rawValue))
        revision += 1
    }
    private func download(_ kind: PackKind) async throws {
        let pack = try RuntimeManifest.load()[kind]
        let directory = Self.root.appendingPathComponent(kind.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, file) in pack.files.enumerated() {
            try Task.checkCancellation()
            let target = directory.appendingPathComponent(file.path)
            if let data = try? Data(contentsOf: target, options: .mappedIfSafe), Self.digest(data) == file.sha256 {
                progress = Double(index + 1) / Double(pack.files.count); continue
            }
            var request = URLRequest(url: file.url); request.timeoutInterval = 180
            let (temporary, response) = try await URLSession.shared.download(for: request)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PackError.download(file.path) }
            let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
            guard Self.digest(data) == file.sha256 else { throw PackError.checksum(file.path) }
            try data.write(to: target, options: .atomic)
            progress = Double(index + 1) / Double(pack.files.count)
        }
        try Task.checkCancellation()
        try pack.version.write(to: directory.appendingPathComponent(".version"), atomically: true, encoding: .utf8)
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    enum PackError: LocalizedError {
        case download(String), checksum(String)
        var errorDescription: String? {
            switch self {
            case .download(let file): "Could not download \(file). Your completed files are retained; try again."
            case .checksum(let file): "The downloaded \(file) did not match the verified version. Please retry."
            }
        }
    }
}
