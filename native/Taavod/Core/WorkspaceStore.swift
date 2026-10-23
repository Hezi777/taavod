import Foundation
import Observation
import SwiftData

@Model final class StoredRecord {
    @Attribute(.unique) var key: String
    var kind: String
    var recordID: String
    var data: Data
    init(_ record: WorkspaceRecord) throws {
        key = record.kind + ":" + record.id
        kind = record.kind
        recordID = record.id
        data = try JSONEncoder().encode(record.payload)
    }
}

@Observable final class WorkspaceStore {
    private let container: ModelContainer
    private let context: ModelContext
    private(set) var records: [WorkspaceRecord] = []
    var error: String?

    init(inMemory: Bool = false) throws {
        try FileManager.default.createDirectory(at: AppPaths.support, withIntermediateDirectories: true)
        let configuration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(url: AppPaths.support.appendingPathComponent("workspace.sqlite"))
        container = try ModelContainer(for: StoredRecord.self, configurations: configuration)
        context = ModelContext(container)
        context.autosaveEnabled = false
        try reload()
        if !inMemory {
            let pending = AppPaths.support.appendingPathComponent("pending-import.json")
            if FileManager.default.fileExists(atPath: pending.path) {
                let incoming = try JSONDecoder().decode([WorkspaceRecord].self, from: Data(contentsOf: pending))
                try importRecords(incoming)
                try FileManager.default.moveItem(at: pending, to: AppPaths.support.appendingPathComponent("imported-" + UUID().uuidString + ".json"))
            }
            let connections = AppPaths.support.appendingPathComponent("pending-credentials.json")
            if FileManager.default.fileExists(atPath: connections.path) {
                struct Connection: Decodable { var key: String; var model: String }
                let incoming = try JSONDecoder().decode([String: Connection].self, from: Data(contentsOf: connections))
                for (provider, connection) in incoming {
                    try KeychainSecret.write(connection.key, service: "com.hezi777.taavod", account: provider)
                    if !connection.model.isEmpty { UserDefaults.standard.set(connection.model, forKey: "coach.model." + provider) }
                }
                try FileManager.default.removeItem(at: connections)
            }
        }
    }
    var profile: [String: JSONValue] { records.first { $0.kind == "profile" }?.payload ?? [:] }
    var profileID: String { records.first { $0.kind == "profile" }?.id ?? "profile" }
    func list(_ kind: String) -> [WorkspaceRecord] { records.filter { $0.kind == kind } }
    func record(_ kind: String, id: String) -> WorkspaceRecord? { records.first { $0.kind == kind && $0.id == id } }

    func update(_ kind: String, id: String, patch: [String: JSONValue]) {
        do {
            var payload = record(kind, id: id)?.payload ?? ["id": .string(id)]
            payload.merge(patch) { _, new in new }
            let record = WorkspaceRecord(kind: kind, id: id, payload: payload)
            try put(record)
            try context.save()
            if let index = records.firstIndex(where: { $0.kind == kind && $0.id == id }) { records[index] = record }
            else { records.append(record) }
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
    func remove(_ kind: String, id: String) {
        do {
            let key = kind + ":" + id
            let descriptor = FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.key == key })
            for item in try context.fetch(descriptor) { context.delete(item) }
            try context.save(); records.removeAll { $0.kind == kind && $0.id == id }
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
    @discardableResult func importRecords(_ incoming: [WorkspaceRecord], overwrite: Bool = false) throws -> Int {
        var count = 0
        for record in incoming where overwrite || self.record(record.kind, id: record.id) == nil {
            try put(record); count += 1
        }
        try context.save(); try reload()
        return count
    }
    func exportData() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }
    private func put(_ record: WorkspaceRecord) throws {
        let key = record.kind + ":" + record.id
        let descriptor = FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.key == key })
        if let existing = try context.fetch(descriptor).first { existing.data = try JSONEncoder().encode(record.payload) }
        else { context.insert(try StoredRecord(record)) }
    }
    private func reload() throws {
        records = try context.fetch(FetchDescriptor<StoredRecord>()).map {
            WorkspaceRecord(kind: $0.kind, id: $0.recordID, payload: try JSONDecoder().decode([String: JSONValue].self, from: $0.data))
        }
    }
}
