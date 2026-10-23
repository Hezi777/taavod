import Foundation

enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .object(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }
    var string: String { if case .string(let s) = self { return s }; return "" }
    var number: Double { if case .number(let n) = self { return n }; return 0 }
    var bool: Bool { if case .bool(let b) = self { return b }; return false }
    var array: [JSONValue] { if case .array(let a) = self { return a }; return [] }
    var object: [String: JSONValue] { if case .object(let o) = self { return o }; return [:] }
}

extension Dictionary where Key == String, Value == JSONValue {
    func text(_ key: String) -> String { self[key]?.string ?? "" }
    func flag(_ key: String) -> Bool { self[key]?.bool ?? false }
    func number(_ key: String) -> Double { self[key]?.number ?? 0 }
    func strings(_ key: String) -> [String] { self[key]?.array.map(\.string) ?? [] }
}

struct WorkspaceRecord: Codable, Identifiable, Equatable {
    var kind: String
    var id: String
    var payload: [String: JSONValue]
    var title: String { payload.text("title").isEmpty ? payload.text("name") : payload.text("title") }
}

struct SkillTrack: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var accent: String
    var prerequisites: [String]
    var lessons: [Lesson]
    var exercises: [Exercise]
}

struct Lesson: Codable, Identifiable {
    struct Source: Codable { var title: String; var url: String }
    var id: String
    var title: String
    var minutes: Int
    var paragraphs: [String]
    var example: String
    var takeaway: String
    var source: Source
}

struct Exercise: Codable, Identifiable {
    var id: String
    var skillId: String
    var title: String
    var prompt: String
    var kind: String
    var difficulty: String
    var minutes: Int
    var starter: String?
    var solution: String
    var explanation: String
    var hints: [String]
    var rubric: [String]
    var options: [String]?
    var correctOption: Int?
    var source: String?
}

struct ResultSet: Codable, Equatable {
    struct Field: Codable, Equatable { var name: String }
    var fields: [Field]
    var rows: [[String: JSONValue]]
}

struct PracticeOutcome: Codable, Equatable {
    var passed: Bool?
    var feedback: String
    var results: [ResultSet]?
    var output: String?
    var plot: String?
    var checks: Int?
    var error: String?
}

enum AppRoute: String, CaseIterable, Identifiable {
    case today = "Today", learn = "Learn", practice = "Practice", jobs = "Jobs", portfolio = "Portfolio", interviews = "Interviews"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .learn: "book.closed"
        case .practice: "chevron.left.forwardslash.chevron.right"
        case .jobs: "briefcase"
        case .portfolio: "square.stack.3d.up"
        case .interviews: "bubble.left.and.bubble.right"
        }
    }
}

enum AppPaths {
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Taavod", isDirectory: true)
    }
    static var resources: URL { Bundle.main.resourceURL!.appendingPathComponent("Resources", isDirectory: true) }
}
