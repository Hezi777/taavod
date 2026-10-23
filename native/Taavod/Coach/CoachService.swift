import Foundation
import Security
import Observation

enum CoachProvider: String, CaseIterable, Identifiable {
    case anthropic, groq
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var modelDefaultsKey: String { "com.hezi777.taavod.coach.model.\(rawValue)" }
}

struct CoachMessage: Codable, Identifiable, Equatable {
    var id: String
    var role: String
    var content: String
    var createdAt: String
    init(role: String, content: String) {
        id = UUID().uuidString; self.role = role; self.content = content; createdAt = Date.now.ISO8601Format()
    }
    init(id: String, role: String, content: String, createdAt: String = Date.now.ISO8601Format()) {
        self.id = id; self.role = role; self.content = content; self.createdAt = createdAt
    }
    var storedValue: JSONValue {
        .object(["id": .string(id), "role": .string(role), "content": .string(content), "createdAt": .string(createdAt)])
    }
    static func decode(_ value: JSONValue) -> CoachMessage? {
        let object = value.object
        guard !object.text("role").isEmpty else { return nil }
        return CoachMessage(id: object.text("id").isEmpty ? UUID().uuidString : object.text("id"), role: object.text("role"), content: object.text("content"), createdAt: object.text("createdAt").isEmpty ? Date.now.ISO8601Format() : object.text("createdAt"))
    }
}

@MainActor @Observable final class CoachCredentials {
    static let shared = CoachCredentials()
    var provider: CoachProvider = .anthropic
    var model = ""
    var keyPresent = false
    var tavilyPresent = false
    var status = ""
    var models: [String] = []
    var loadingModels = false

    init() {
        provider = CoachProvider(rawValue: UserDefaults.standard.string(forKey: "com.hezi777.taavod.coach.provider") ?? "") ?? .anthropic
        model = UserDefaults.standard.string(forKey: provider.modelDefaultsKey) ?? ""
        refreshPresence()
    }
    func refreshPresence() {
        keyPresent = KeychainSecret.read(service: "com.hezi777.taavod", account: provider.rawValue) != nil
        tavilyPresent = KeychainSecret.read(service: "com.hezi777.taavod", account: "tavily") != nil
    }
    func save(_ key: String, account: String? = nil) {
        let item = account ?? provider.rawValue
        do {
            try KeychainSecret.write(key, service: "com.hezi777.taavod", account: item)
            status = "Saved securely in Keychain."
            if item == provider.rawValue { keyPresent = true }
            if item == "tavily" { tavilyPresent = true }
        } catch { status = "Could not save the key: \(error.localizedDescription)" }
    }
    func remove(account: String? = nil) {
        let item = account ?? provider.rawValue
        KeychainSecret.delete(service: "com.hezi777.taavod", account: item)
        refreshPresence()
        status = "Removed from Keychain."
    }
    func select(_ provider: CoachProvider) {
        self.provider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "com.hezi777.taavod.coach.provider")
        model = UserDefaults.standard.string(forKey: provider.modelDefaultsKey) ?? ""
        models = []; refreshPresence()
    }
    func selectModel(_ model: String) {
        self.model = model
        UserDefaults.standard.set(model, forKey: provider.modelDefaultsKey)
    }
    func loadModels() async {
        guard let key = KeychainSecret.read(service: "com.hezi777.taavod", account: provider.rawValue) else { status = "Add an API key first."; return }
        loadingModels = true; defer { loadingModels = false }
        do {
            models = try await CoachAPI.models(provider: provider, key: key)
            if !models.contains(model) { selectModel(models.first ?? "") }
            status = "Loaded \(models.count) models."
        } catch { status = error.localizedDescription.replacingOccurrences(of: key, with: "[redacted]") }
    }
}

enum CoachServiceError: LocalizedError, Equatable {
    case missingKey, http(Int, String), malformedResponse, unsupportedTool
    var errorDescription: String? {
        switch self {
        case .missingKey: "Add an API key in Coach Settings to start a conversation."
        case .http(_, let message): message
        case .malformedResponse: "The provider returned an unreadable response. Check the model and try again."
        case .unsupportedTool: "The provider requested an unsupported tool."
        }
    }
}

struct CoachToolCall: @unchecked Sendable { var id: String; var name: String; var arguments: [String: Any] }
struct CoachTurn: @unchecked Sendable {
    var text: String
    var calls: [CoachToolCall]
    var inputTokens: Int
    var outputTokens: Int
}
struct CoachTokenUsage: Equatable { var input: Int = 0; var output: Int = 0 }

enum KeychainSecret {
    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func write(_ value: String, service: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data
            let added = SecItemAdd(add as CFDictionary, nil)
            guard added == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(added)) }
        } else if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func delete(service: String, account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}

enum CoachAPI {
    private static let tools: [[String: Any]] = [
        ["name":"search_workspace", "description":"Search jobs, projects, interviews, attempts, and drafts. Returns matching records with kind and id citations. Does not search profiles, coach conversations, or usage metadata. Read-only.", "input_schema":["type":"object", "properties":["query":["type":"string"]], "required":["query"]]],
        ["name":"read_record", "description":"Read one jobs, projects, interviews, attempts, or drafts record by its exact kind and id. Private profile data, coach conversations, and usage metadata are unavailable. Read-only.", "input_schema":["type":"object", "properties":["kind":["type":"string"], "id":["type":"string"]], "required":["kind","id"]]],
        ["name":"get_curriculum", "description":"Search lessons and exercises in the learning curriculum. Read-only.", "input_schema":["type":"object", "properties":["query":["type":"string"]], "required":["query"]]],
        ["name":"get_schema", "description":"Read the bundled Pagila database schema, including all table names, columns, keys, and foreign-key relationships. Pass table names in query or tables. Always return the complete list of available tables.", "input_schema":["type":"object", "properties":["query":["type":"string"], "tables":["type":"array", "items":["type":"string"]]], "required":["query"]]]
    ]

    static func models(provider: CoachProvider, key: String) async throws -> [String] {
        let url = provider == .anthropic ? URL(string: "https://api.anthropic.com/v1/models?limit=1000")! : URL(string: "https://api.groq.com/openai/v1/models")!
        var request = URLRequest(url: url); request.timeoutInterval = 20
        if provider == .anthropic { request.setValue(key, forHTTPHeaderField: "x-api-key"); request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") }
        else { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw httpError(data, response) }
        return try decodeModels(data, provider: provider)
    }

    static func decodeModels(_ data: Data, provider: CoachProvider) throws -> [String] {
        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let entries = body["data"] as? [[String: Any]] else { throw CoachServiceError.malformedResponse }
        return entries.compactMap { item in
            guard let id = item["id"] as? String, (item["active"] as? Bool) != false else { return nil }
            if provider == .groq && id.range(of: "llama|gpt-oss|qwen|gemma|mixtral|kimi", options: .regularExpression) == nil { return nil }
            return id
        }.sorted()
    }

    static func parseUsage(provider: CoachProvider, event: String = "", payload: [String: Any]) -> CoachTokenUsage {
        if provider == .anthropic {
            let usage = (payload["usage"] as? [String: Any]) ?? ((payload["message"] as? [String: Any])?["usage"] as? [String: Any]) ?? [:]
            if event == "message_start" { return CoachTokenUsage(input: usage["input_tokens"] as? Int ?? 0, output: 0) }
            if event == "message_delta" { return CoachTokenUsage(input: 0, output: usage["output_tokens"] as? Int ?? 0) }
            return CoachTokenUsage()
        }
        let usage = (payload["usage"] as? [String: Any]) ?? ((payload["x_groq"] as? [String: Any])?["usage"] as? [String: Any]) ?? [:]
        return CoachTokenUsage(input: usage["prompt_tokens"] as? Int ?? 0, output: usage["completion_tokens"] as? Int ?? 0)
    }

    static func complete(provider: CoachProvider, model: String, key: String, history: [[String: Any]], system: String, onText: @escaping @MainActor (String) -> Void) async throws -> CoachTurn {
        if provider == .anthropic { return try await anthropic(model: model, key: key, history: history, system: system, onText: onText) }
        return try await groq(model: model, key: key, history: history, system: system, onText: onText)
    }

    private static func anthropic(model: String, key: String, history: [[String: Any]], system: String, onText: @escaping @MainActor (String) -> Void) async throws -> CoachTurn {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!); request.httpMethod = "POST"; request.timeoutInterval = 180
        request.setValue(key, forHTTPHeaderField: "x-api-key"); request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": model, "max_tokens": 4096, "system": system, "messages": history, "tools": tools, "stream": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try check(response, initialData: Data())
        var text = "", calls: [String: CoachToolCall] = [:], currentID = "", currentName = "", currentJSON = "", event = "", inputTokens = 0, outputTokens = 0
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if line.hasPrefix("event: ") { event = String(line.dropFirst(7)); continue }
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6)); guard data != "[DONE]", let raw = data.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            let usage = parseUsage(provider: .anthropic, event: event, payload: object)
            inputTokens = usage.input == 0 ? inputTokens : usage.input
            outputTokens = usage.output == 0 ? outputTokens : usage.output
            switch event {
            case "message_start": break
            case "content_block_start":
                let block = object["content_block"] as? [String: Any] ?? [:]
                if block["type"] as? String == "tool_use" { currentID = block["id"] as? String ?? UUID().uuidString; currentName = block["name"] as? String ?? ""; currentJSON = "" }
            case "content_block_delta":
                let delta = object["delta"] as? [String: Any] ?? [:]
                if delta["type"] as? String == "text_delta", let value = delta["text"] as? String { text += value; onText(value) }
                if delta["type"] as? String == "input_json_delta" { currentJSON += delta["partial_json"] as? String ?? "" }
            case "content_block_stop":
                if !currentName.isEmpty {
                    let args = (try? JSONSerialization.jsonObject(with: Data(currentJSON.utf8))) as? [String: Any] ?? [:]
                    calls[currentID] = CoachToolCall(id: currentID, name: currentName, arguments: args); currentName = ""
                }
            case "message_delta": break
            default: break
            }
            event = ""
        }
        return CoachTurn(text: text, calls: calls.values.sorted { $0.id < $1.id }, inputTokens: inputTokens, outputTokens: outputTokens)
    }

    private static func groq(model: String, key: String, history: [[String: Any]], system: String, onText: @escaping @MainActor (String) -> Void) async throws -> CoachTurn {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!); request.httpMethod = "POST"; request.timeoutInterval = 180
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let messages = [["role":"system", "content":system]] + history
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model":model,"messages":messages,"tools":tools.map { ["type":"function","function":["name":$0["name"]!,"description":$0["description"]!,"parameters":$0["input_schema"]!]] },"tool_choice":"auto","stream":true,"stream_options":["include_usage":true]])
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try check(response, initialData: Data())
        var text = "", calls: [Int: (String, String, String)] = [:], inputTokens = 0, outputTokens = 0
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6)); guard data != "[DONE]", let raw = data.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            let usage = parseUsage(provider: .groq, payload: object)
            inputTokens = usage.input == 0 ? inputTokens : usage.input
            outputTokens = usage.output == 0 ? outputTokens : usage.output
            guard let choice = (object["choices"] as? [[String: Any]])?.first, let delta = choice["delta"] as? [String: Any] else { continue }
            if let content = delta["content"] as? String, !content.isEmpty { text += content; onText(content) }
            for tool in delta["tool_calls"] as? [[String: Any]] ?? [] {
                let index = tool["index"] as? Int ?? 0, fn = tool["function"] as? [String: Any] ?? [:]
                var value = calls[index] ?? ("", "", "")
                value.0 += tool["id"] as? String ?? ""; value.1 += fn["name"] as? String ?? ""; value.2 += fn["arguments"] as? String ?? ""
                calls[index] = value
            }
        }
        let parsed = calls.keys.sorted().compactMap { i -> CoachToolCall? in
            guard let value = calls[i], let raw = value.2.data(using: .utf8), let args = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return nil }
            return CoachToolCall(id: value.0.isEmpty ? UUID().uuidString : value.0, name: value.1, arguments: args)
        }
        return CoachTurn(text: text, calls: parsed, inputTokens: inputTokens, outputTokens: outputTokens)
    }

    static func toolResult(_ call: CoachToolCall, app: AppModel) throws -> String {
        let query = call.arguments["query"] as? String ?? ""
        switch call.name {
        case "search_workspace":
            let found = CoachContextBuilder.search(query, records: app.store.records)
            return found.isEmpty ? "No matching workspace records." : try encode(found.map { ["citation":"[\($0.kind):\($0.id)]", "kind":$0.kind, "id":$0.id, "record":$0.payload] })
        case "read_record":
            guard let kind = call.arguments["kind"] as? String, let id = call.arguments["id"] as? String else { return "Provide both kind and id." }
            guard let record = CoachContextBuilder.record(kind, id: id, records: app.store.records) else { return "No record found for [\(kind):\(id)]." }
            return try encode(["citation":"[\(record.kind):\(record.id)]", "record":record.payload])
        case "get_curriculum": return CoachContextBuilder.curriculum(query, tracks: app.tracks).joined(separator: "\n")
        case "get_schema":
            let tables = call.arguments["tables"] as? [String] ?? []
            return try schemaResult(query: query, requestedTables: tables)
        default: throw CoachServiceError.unsupportedTool
        }
    }

    static func schemaResult(query: String, requestedTables: [String] = [], schemaData: Data? = nil) throws -> String {
        let data = try schemaData ?? Data(contentsOf: AppPaths.resources.appendingPathComponent("pagila-schema.json"))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let columns = root["columns"] as? [[String: Any]],
              let constraints = root["constraints"] as? [[String: Any]] else { throw CoachServiceError.malformedResponse }
        let allNames = Set(columns.compactMap { $0["table_name"] as? String }).union(constraints.compactMap { $0["table_name"] as? String })
        let allTables = allNames.sorted()
        let queryTerms = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).map(String.init)
        let exactRequest = requestedTables.map { $0.lowercased() }.filter(allNames.contains)
        var selected = Set(exactRequest)
        for table in allTables where queryTerms.contains(table.lowercased()) { selected.insert(table) }
        let direct = Set(selected)
        let relationships = constraints.filter { ($0["kind"] as? String)?.lowercased() == "f" }
        var relatedTables = Set<String>()
        for constraint in relationships {
            guard let source = constraint["table_name"] as? String,
                  let definition = constraint["definition"] as? String,
                  let target = referencedTable(in: definition), direct.contains(source) || direct.contains(target) else { continue }
            relatedTables.insert(source); relatedTables.insert(target)
        }
        if selected.isEmpty { selected = allNames }
        else { selected.formUnion(relatedTables) }
        let selectedColumns = columns.filter { selected.contains(($0["table_name"] as? String) ?? "") }
        let selectedConstraints = constraints.filter { constraint in
            guard let table = constraint["table_name"] as? String else { return false }
            if direct.isEmpty { return true }
            if ["p", "u", "c"].contains((constraint["kind"] as? String)?.lowercased() ?? ""), selected.contains(table) { return true }
            guard (constraint["kind"] as? String)?.lowercased() == "f" else { return false }
            let definition = constraint["definition"] as? String
            return relationships.contains { ($0["table_name"] as? String) == table && ($0["definition"] as? String) == definition && relatedTables.contains(table) }
        }
        let object: [String: Any] = ["all_tables": allTables, "requested_tables": direct.sorted(), "related_tables": selected.subtracting(direct).sorted(), "columns": selectedColumns, "constraints": selectedConstraints]
        let encoded = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: encoded, as: UTF8.self)
    }

    private static func referencedTable(in definition: String) -> String? {
        guard let range = definition.range(of: #"REFERENCES\s+([a-zA-Z_][a-zA-Z0-9_]*)"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let match = String(definition[range])
        return match.split(whereSeparator: \.isWhitespace).last.map(String.init)
    }

    private static func encode(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: jsonCompatible(value), options: [.sortedKeys, .fragmentsAllowed])
        return CoachContextBuilder.bounded(String(decoding: data, as: UTF8.self), limit: 9_000)
    }
    private static func jsonCompatible(_ value: Any) -> Any {
        if let json = value as? JSONValue {
            switch json {
            case .string(let v): return v
            case .number(let v): return v
            case .bool(let v): return v
            case .array(let v): return v.map(jsonCompatible)
            case .object(let v): return v.mapValues(jsonCompatible)
            case .null: return NSNull()
            }
        }
        if let dictionary = value as? [String: Any] { return dictionary.mapValues(jsonCompatible) }
        if let array = value as? [Any] { return array.map(jsonCompatible) }
        return value
    }
    private static func check(_ response: URLResponse, initialData: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw httpError(initialData, response) }
    }
    static func providerError(status: Int, data: Data) -> CoachServiceError {
        if status == 401 || status == 403 { return .http(status, "The API key was not accepted. Check the key in Coach Settings.") }
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let error = body?["error"] as? [String: Any]
        let message = (error?["message"] as? String) ?? (body?["message"] as? String) ?? "Provider request failed (\(status)). Check your API key and selected model."
        return .http(status, CoachContextBuilder.bounded(message, limit: 500))
    }

    private static func httpError(_ data: Data, _ response: URLResponse) -> CoachServiceError {
        providerError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
    }
}
