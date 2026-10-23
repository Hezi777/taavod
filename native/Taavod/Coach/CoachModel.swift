import Foundation
import Observation

enum CoachConversationPersistence {
    static func messages(from record: WorkspaceRecord?) -> [CoachMessage] {
        guard let value = record?.payload["messages"] else { return [] }
        if case .array(let values) = value { return values.compactMap(CoachMessage.decode) }
        if case .string(let raw) = value, let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return json.compactMap { item in
                guard let role = item["role"] as? String, let content = item["content"] as? String else { return nil }
                let createdAt: String
                if let date = item["createdAt"] as? String { createdAt = date }
                else if let seconds = item["createdAt"] as? Double { createdAt = Date(timeIntervalSince1970: seconds).ISO8601Format() }
                else { createdAt = Date.now.ISO8601Format() }
                return CoachMessage(id: item["id"] as? String ?? UUID().uuidString, role: role, content: content, createdAt: createdAt)
            }
        }
        return []
    }

    static func save(_ messages: [CoachMessage], id: String, to store: WorkspaceStore) {
        let oldTitle = store.record("conversations", id: id)?.title ?? ""
        let firstMessage = messages.first(where: { $0.role == "user" })?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = oldTitle.isEmpty ? (firstMessage.isEmpty ? "New conversation" : firstMessage) : oldTitle
        store.update("conversations", id: id, patch: [
            "title": .string(String(title.prefix(80))),
            "messages": .array(messages.map(\.storedValue)),
            "updatedAt": .string(Date.now.ISO8601Format())
        ])
    }
}

@MainActor @Observable final class CoachModel {
    let credentials = CoachCredentials.shared
    private(set) var messages: [CoachMessage]
    private(set) var conversationID: String
    var input = ""
    var isSending = false
    var error: String?
    var canRetry = false
    private(set) var lastInputTokens = 0
    private(set) var lastOutputTokens = 0
    private var task: Task<Void, Never>?
    private weak var app: AppModel?

    var conversations: [WorkspaceRecord] {
        (app?.store.list("conversations") ?? []).sorted { $0.payload.text("updatedAt") > $1.payload.text("updatedAt") }
    }

    init(app: AppModel) {
        self.app = app
        let records = app.store.list("conversations")
        let savedID = UserDefaults.standard.string(forKey: "com.hezi777.taavod.coach.activeConversation")
        let first = records.first { $0.id == savedID } ?? records.sorted { $0.payload.text("updatedAt") > $1.payload.text("updatedAt") }.first
        let selectedID = first?.id ?? UUID().uuidString
        conversationID = selectedID
        messages = CoachConversationPersistence.messages(from: first)
        UserDefaults.standard.set(selectedID, forKey: "com.hezi777.taavod.coach.activeConversation")
    }

    func selectConversation(_ id: String) {
        guard !isSending, let app, let record = app.store.record("conversations", id: id) else { return }
        conversationID = id; messages = CoachConversationPersistence.messages(from: record)
        error = nil; canRetry = false; lastInputTokens = 0; lastOutputTokens = 0
        UserDefaults.standard.set(id, forKey: "com.hezi777.taavod.coach.activeConversation")
    }

    func newConversation() {
        guard !isSending else { return }
        conversationID = UUID().uuidString; messages = []; error = nil; canRetry = false
        lastInputTokens = 0; lastOutputTokens = 0
        UserDefaults.standard.set(conversationID, forKey: "com.hezi777.taavod.coach.activeConversation")
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, let app else { return }
        guard KeychainSecret.read(service: "com.hezi777.taavod", account: credentials.provider.rawValue) != nil else {
            error = CoachServiceError.missingKey.localizedDescription; canRetry = false; return
        }
        guard !credentials.model.isEmpty else { error = "Fetch and choose a model in Coach Settings first."; canRetry = false; return }
        input = ""; error = nil; canRetry = false; lastInputTokens = 0; lastOutputTokens = 0
        beginTurn(userMessage: text)
        let provider = credentials.provider, model = credentials.model
        let history = messages.dropLast().suffix(30).map { ["role": $0.role, "content": CoachContextBuilder.bounded($0.content, limit: 12_000)] }
        let system = CoachContextBuilder.systemContext(app: app)
        let conversationID = self.conversationID
        isSending = true
        task = Task { [weak self, weak app] in
            guard let self, let app else { return }
            defer { isSending = false; task = nil }
            guard let key = KeychainSecret.read(service: "com.hezi777.taavod", account: provider.rawValue) else {
                error = CoachServiceError.missingKey.localizedDescription; persist(); return
            }
            var providerHistory: [[String: Any]] = history.map { ["role": $0["role"] ?? "user", "content": $0["content"] ?? ""] }
            var toolSteps = 0, inputTokens = 0, outputTokens = 0
            do {
                while toolSteps <= 6 {
                    try Task.checkCancellation()
                    let turn = try await CoachAPI.complete(provider: provider, model: model, key: key, history: providerHistory, system: system) { [weak self] delta in
                        self?.appendStreamDelta(delta)
                    }
                    inputTokens += turn.inputTokens; outputTokens += turn.outputTokens
                    guard !turn.calls.isEmpty else { break }
                    guard toolSteps < 6 else { break }
                    toolSteps += 1
                    if provider == .anthropic {
                        var blocks: [[String: Any]] = []
                        if !turn.text.isEmpty { blocks.append(["type":"text", "text":turn.text]) }
                        for call in turn.calls { blocks.append(["type":"tool_use", "id":call.id, "name":call.name, "input":call.arguments]) }
                        providerHistory.append(["role":"assistant", "content":blocks])
                        var results: [[String: Any]] = []
                        for call in turn.calls { results.append(["type":"tool_result", "tool_use_id":call.id, "content":try CoachAPI.toolResult(call, app: app)]) }
                        providerHistory.append(["role":"user", "content":results])
                    } else {
                        let toolCalls: [[String: Any]] = turn.calls.map { ["id":$0.id,"type":"function","function":["name":$0.name,"arguments":(try? String(data: JSONSerialization.data(withJSONObject: $0.arguments), encoding: .utf8)) ?? "{}"]] }
                        providerHistory.append(["role":"assistant", "content":turn.text, "tool_calls":toolCalls])
                        for call in turn.calls { providerHistory.append(["role":"tool", "tool_call_id":call.id, "content":try CoachAPI.toolResult(call, app: app)]) }
                    }
                }
                recordUsage(app: app, provider: provider, model: model, input: inputTokens, output: outputTokens)
                if messages.last?.content.isEmpty == true { error = "The provider returned no text. Try again or choose another model."; canRetry = true }
                persist(id: conversationID)
            } catch is CancellationError {
                canRetry = true
                recordUsage(app: app, provider: provider, model: model, input: inputTokens, output: outputTokens)
                persist(id: conversationID)
            } catch {
                self.error = error.localizedDescription.replacingOccurrences(of: key, with: "[redacted]")
                canRetry = true
                recordUsage(app: app, provider: provider, model: model, input: inputTokens, output: outputTokens)
                persist(id: conversationID)
            }
        }
    }

    func beginTurn(userMessage: String) {
        messages.append(CoachMessage(role: "user", content: userMessage))
        messages.append(CoachMessage(role: "assistant", content: ""))
    }

    func appendStreamDelta(_ delta: String) {
        guard let index = messages.lastIndex(where: { $0.role == "assistant" }) else { return }
        messages[index].content += delta
    }

    func cancel() { task?.cancel() }
    func retry() {
        guard !isSending, canRetry else { return }
        if messages.last?.role == "assistant" { messages.removeLast() }
        guard let lastUser = messages.last(where: { $0.role == "user" }) else { return }
        input = lastUser.content
        if messages.last?.role == "user" { messages.removeLast() }
        send()
    }
    func clear() { newConversation() }

    func saveConversationSnapshot() { persist() }

    private func recordUsage(app: AppModel, provider: CoachProvider, model: String, input: Int, output: Int) {
        lastInputTokens = input; lastOutputTokens = output
        app.store.update("usage", id: UUID().uuidString, patch: ["provider":.string(provider.rawValue), "model":.string(model), "inputTokens":.number(Double(input)), "outputTokens":.number(Double(output)), "createdAt":.string(Date.now.ISO8601Format())])
    }

    private func persist(id: String? = nil) {
        guard let app else { return }
        CoachConversationPersistence.save(messages, id: id ?? conversationID, to: app.store)
    }
}
