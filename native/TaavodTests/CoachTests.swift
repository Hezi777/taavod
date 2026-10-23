import Foundation
import Testing
@testable import Taavod

@Suite("Taavod coach")
@MainActor struct CoachTests {
    @Test func currentContextContainsDraftSelectionResultProgressAndSafeProfile() throws {
        let store = try WorkspaceStore(inMemory: true)
        try store.importRecords([
            WorkspaceRecord(kind: "profile", id: "me", payload: ["name": .string("Ada"), "email": .string("private@example.test")]),
            WorkspaceRecord(kind: "attempts", id: "attempt-1", payload: ["title": .string("Join practice"), "passed": .bool(false)]),
            WorkspaceRecord(kind: "jobs", id: "role-1", payload: ["title": .string("Analyst")])
        ])
        let app = AppModel(store: store)
        app.route = .practice
        app.study.trackID = "sql"
        app.study.draft = "SELECT 1; -- learner draft"
        app.study.selectedText = "COUNT(*) includes unmatched rows"
        app.study.hintsUsed = 2
        app.study.mode = "practice"
        app.study.outcome = PracticeOutcome(passed: false, feedback: "Check the left join", results: nil, output: "syntax error at line 4", plot: nil, checks: 1, error: "column missing")
        app.coachEditorContext = "Interview answer draft: I built a dashboard."

        let context = CoachContextBuilder.systemContext(app: app)
        #expect(context.contains("Current screen: Practice"))
        #expect(context.contains("SELECT 1; -- learner draft"))
        #expect(context.contains("COUNT(*) includes unmatched rows"))
        #expect(context.contains("column missing"))
        #expect(context.contains("syntax error at line 4"))
        #expect(context.contains("hints used: 2"))
        #expect(context.contains("jobs(1): role-1: Analyst"))
        #expect(context.contains("Interview answer draft"))
        #expect(context.contains("Exercise runner: idle; status=Ready"))
        #expect(context.contains("Ada"))
        #expect(!context.contains("private@example.test"))
    }

    @Test func activeExerciseContextCarriesPromptHintsAndRubricWithoutSolution() {
        let exercise = Exercise(id: "join-one", skillId: "sql", title: "Count carefully", prompt: "What is the output grain?", kind: "written", difficulty: "Foundation", minutes: 5, starter: nil, solution: "secret reference solution", explanation: "explanation", hints: ["Name one row first."], rubric: ["State the grain."], options: nil, correctOption: nil, source: nil)
        let context = CoachContextBuilder.exerciseContext(exercise)
        #expect(context.contains("Active exercise: Count carefully [join-one]"))
        #expect(context.contains("What is the output grain?"))
        #expect(context.contains("Name one row first."))
        #expect(context.contains("State the grain."))
        #expect(!context.contains("secret reference solution"))
    }

    @Test func workspaceToolReadsActualJSONValueRecordWithCitation() throws {
        let store = try WorkspaceStore(inMemory: true)
        try store.importRecords([WorkspaceRecord(kind: "jobs", id: "role-1", payload: ["title": .string("BI developer"), "requirements": .array([.string("SQL")])])])
        let app = AppModel(store: store)
        let call = CoachToolCall(id: "call-1", name: "read_record", arguments: ["kind":"jobs", "id":"role-1"])
        let result = try CoachAPI.toolResult(call, app: app)
        #expect(result.contains("[jobs:role-1]"))
        #expect(result.contains("BI developer"))
        #expect(result.contains("SQL"))
    }

    @Test func workspaceRetrievalExcludesPrivateRecordKindsAndRedactsNestedCredentials() throws {
        let store = try WorkspaceStore(inMemory: true)
        try store.importRecords([
            WorkspaceRecord(kind: "jobs", id: "role-1", payload: [
                "title": .string("Analyst"),
                "contact": .object(["email": .string("private@example.test")]),
                "providerToken": .string("secret-token")
            ]),
            WorkspaceRecord(kind: "profile", id: "profile-1", payload: ["name": .string("Ada"), "email": .string("private@example.test"), "targetRole": .string("Analyst")]),
            WorkspaceRecord(kind: "conversations", id: "chat-1", payload: ["title": .string("Analyst private coaching chat")]),
            WorkspaceRecord(kind: "usage", id: "usage-1", payload: ["title": .string("Analyst private usage")])
        ])
        let app = AppModel(store: store)
        let search = try CoachAPI.toolResult(CoachToolCall(id: "s", name: "search_workspace", arguments: ["query":"Analyst"]), app: app)
        #expect(search.contains("[jobs:role-1]"))
        #expect(!search.contains("private@example.test"))
        #expect(!search.contains("secret-token"))

        let profileRead = try CoachAPI.toolResult(CoachToolCall(id: "p", name: "read_record", arguments: ["kind":"profile", "id":"profile-1"]), app: app)
        let conversationRead = try CoachAPI.toolResult(CoachToolCall(id: "c", name: "read_record", arguments: ["kind":"conversations", "id":"chat-1"]), app: app)
        #expect(profileRead.contains("No record found"))
        #expect(conversationRead.contains("No record found"))
        #expect(!search.contains("private coaching chat"))
        #expect(!search.contains("private usage"))
    }

    @Test func selectedRecordUsesRouteKindWhenIDsCollide() throws {
        let store = try WorkspaceStore(inMemory: true)
        try store.importRecords([
            WorkspaceRecord(kind: "jobs", id: "shared", payload: ["title": .string("Selected analyst role")]),
            WorkspaceRecord(kind: "projects", id: "shared", payload: ["name": .string("Different project")])
        ])
        let app = AppModel(store: store)
        app.route = .jobs
        app.selectedRecordID = "shared"
        let context = CoachContextBuilder.systemContext(app: app)
        #expect(context.contains("Selected record [jobs:shared]"))
        #expect(!context.contains("Selected record [projects:shared]"))
    }

    @Test func weeklyTasksAndLessonProgressAreAvailableToTheCoach() throws {
        let store = try WorkspaceStore(inMemory: true)
        try store.importRecords([
            WorkspaceRecord(kind: "tasks", id: "weekly-one", payload: ["title": .string("Practice left joins"), "done": .bool(false), "minutes": .number(30)]),
            WorkspaceRecord(kind: "lessons", id: "joins", payload: ["title": .string("Left joins"), "completed": .bool(true)])
        ])
        let app = AppModel(store: store)
        let result = try CoachAPI.toolResult(CoachToolCall(id: "task-read", name: "read_record", arguments: ["kind": "tasks", "id": "weekly-one"]), app: app)
        #expect(result.contains("Practice left joins"))
        #expect(CoachContextBuilder.systemContext(app: app).contains("tasks(1): weekly-one"))
        #expect(CoachContextBuilder.search("joins", records: store.records).count == 2)
    }

    @Test func currentUnsavedWrittenAnswerIsPresentInCoachContext() throws {
        let store = try WorkspaceStore(inMemory: true)
        let app = AppModel(store: store)
        app.study.exerciseID = "written-one"
        app.coachEditorContext = "Exercise answer draft [written-one]:\nA live unsaved answer"
        let context = CoachContextBuilder.systemContext(app: app)
        #expect(context.contains("A live unsaved answer"))
    }

    @Test func attemptPersistenceUsesCapturedExerciseAndDraftMetadata() throws {
        let store = try WorkspaceStore(inMemory: true)
        let app = AppModel(store: store)
        app.study.draft = "current exercise draft"
        app.study.hintsUsed = 3
        let capturedExercise = Exercise(id: "captured", skillId: "sql", title: "Captured", prompt: "", kind: "sql", difficulty: "Foundation", minutes: 1, starter: nil, solution: "", explanation: "", hints: [], rubric: [], options: nil, correctOption: nil, source: nil)
        let outcome = PracticeOutcome(passed: true, feedback: "Passed", results: nil, output: nil, plot: nil, checks: 1, error: nil)

        app.saveAttempt(outcome, exercise: capturedExercise, answer: "captured answer", hintsUsed: 1, mode: "practice")

        let attempt = try #require(store.list("attempts").first)
        #expect(attempt.payload.text("exerciseId") == "captured")
        #expect(attempt.payload.text("answer") == "captured answer")
        #expect(attempt.payload.number("hintsUsed") == 1)
        #expect(attempt.payload.text("mode") == "practice")
    }

    @Test func schemaToolReturnsAllNamesExactColumnsAndForeignKeyRelationship() throws {
        let fixture = Data(#"{"columns":[{"table_name":"payment","column_name":"payment_id","data_type":"integer"},{"table_name":"rental","column_name":"rental_id","data_type":"integer"},{"table_name":"actor","column_name":"actor_id","data_type":"integer"}],"constraints":[{"table_name":"payment","kind":"f","definition":"FOREIGN KEY (rental_id) REFERENCES rental(rental_id)"},{"table_name":"rental","kind":"p","definition":"PRIMARY KEY (rental_id)"}]}"#.utf8)
        let result = try CoachAPI.schemaResult(query: "payment", schemaData: fixture)
        #expect(result.contains("\"all_tables\":[\"actor\",\"payment\",\"rental\"]"))
        #expect(result.contains("\"payment_id\""))
        #expect(result.contains("\"rental_id\""))
        #expect(result.contains("REFERENCES rental(rental_id)"))
        #expect(!result.contains("\"actor_id\""))
    }

    @Test func legacyConversationArrayRoundTripsTheEstablishedRecordShape() throws {
        let legacy = WorkspaceRecord(kind: "conversations", id: "legacy-chat", payload: [
            "title": .string("Legacy"),
            "messages": .array([
                .object(["id": .string("u1"), "role": .string("user"), "content": .string("Hello"), "createdAt": .string("2026-10-22T08:00:00Z")]),
                .object(["id": .string("a1"), "role": .string("assistant"), "content": .string("Hi"), "createdAt": .string("2026-10-22T08:00:02Z")])
            ])
        ])
        let decoded = CoachConversationPersistence.messages(from: legacy)
        #expect(decoded.map(\.id) == ["u1", "a1"])
        #expect(decoded.map(\.role) == ["user", "assistant"])
        #expect(decoded.first?.createdAt == "2026-10-22T08:00:00Z")

        let store = try WorkspaceStore(inMemory: true)
        try store.importRecords([legacy])
        CoachConversationPersistence.save(decoded, id: "legacy-chat", to: store)
        let saved = store.record("conversations", id: "legacy-chat")
        #expect(saved?.payload.text("title") == "Legacy")
        if case .array(let messages) = saved?.payload["messages"] {
            #expect(messages.count == 2)
            #expect(messages[0].object.text("createdAt") == "2026-10-22T08:00:00Z")
        } else { Issue.record("Conversation messages must remain an array of message records.") }
    }

    @Test func streamedDeltasStayInMemoryUntilConversationSnapshotIsSaved() throws {
        let store = try WorkspaceStore(inMemory: true)
        let app = AppModel(store: store)
        let coach = CoachModel(app: app)
        coach.beginTurn(userMessage: "Help me reason about this join.")
        coach.appendStreamDelta("Start with the grain.")
        #expect(store.record("conversations", id: coach.conversationID) == nil)
        coach.saveConversationSnapshot()
        #expect(store.record("conversations", id: coach.conversationID) != nil)
    }

    @Test func providerModelAndTokenParsersHandleMockedPayloadsWithoutCredentials() throws {
        let valid = Data(#"{"data":[{"id":"claude-sonnet-4-5"},{"id":"claude-haiku-4-5"}]}"#.utf8)
        #expect(try CoachAPI.decodeModels(valid, provider: .anthropic) == ["claude-haiku-4-5", "claude-sonnet-4-5"])

        do {
            _ = try CoachAPI.decodeModels(Data("{}".utf8), provider: .groq)
            Issue.record("Malformed provider model data should be rejected.")
        } catch { #expect(error as? CoachServiceError == .malformedResponse) }

        let anthropicStart = CoachAPI.parseUsage(provider: .anthropic, event: "message_start", payload: ["message":["usage":["input_tokens":123]]])
        let anthropicEnd = CoachAPI.parseUsage(provider: .anthropic, event: "message_delta", payload: ["usage":["output_tokens":45]])
        let groq = CoachAPI.parseUsage(provider: .groq, payload: ["x_groq":["usage":["prompt_tokens":88,"completion_tokens":19]]])
        #expect(anthropicStart.input == 123)
        #expect(anthropicEnd.output == 45)
        #expect(groq == CoachTokenUsage(input: 88, output: 19))

        let rejected = Data(#"{"error":{"message":"bad key sk-secret"}}"#.utf8)
        let error = CoachAPI.providerError(status: 401, data: rejected)
        #expect(error.localizedDescription == "The API key was not accepted. Check the key in Coach Settings.")
        #expect(!error.localizedDescription.contains("sk-secret"))
    }

    @Test func contextAndRecordLimitsPreventUnboundedProviderPayloads() {
        let large = String(repeating: "x", count: 40)
        #expect(CoachContextBuilder.bounded(large, limit: 10).hasSuffix("… [truncated]"))
        #expect(CoachContextBuilder.bounded(large, limit: 10).count <= 24)
    }
}
