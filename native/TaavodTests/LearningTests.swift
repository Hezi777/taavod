import Testing
@testable import Taavod

@Test @MainActor func lessonExerciseGroupingCoversTheWholeCurriculumOnce() throws {
    let app = AppModel(store: try WorkspaceStore(inMemory: true))
    #expect(app.tracks.count == 10)
    #expect(app.tracks.reduce(0) { $0 + $1.lessons.count } == 30)
    #expect(app.tracks.reduce(0) { $0 + $1.exercises.count } == 81)

    for track in app.tracks {
        let grouped = track.lessons.indices.flatMap { LearnView.exercises(for: track, lessonIndex: $0) }
        #expect(grouped.map(\.id) == track.exercises.map(\.id), "Every exercise in \(track.id) should appear under exactly one lesson.")
    }
}

@Test @MainActor func exerciseSwitchSavesAndRestoresTheOutgoingDraft() throws {
    let app = AppModel(store: try WorkspaceStore(inMemory: true))
    let first = Exercise(id: "draft-one", skillId: "sql", title: "First", prompt: "Write a query", kind: "sql", difficulty: "Foundation", minutes: 5, starter: "SELECT 1;", solution: "SELECT 1;", explanation: "", hints: [], rubric: [], options: nil, correctOption: nil, source: nil)
    let second = Exercise(id: "draft-two", skillId: "sql", title: "Second", prompt: "Write another query", kind: "sql", difficulty: "Foundation", minutes: 5, starter: "SELECT 2;", solution: "SELECT 2;", explanation: "", hints: [], rubric: [], options: nil, correctOption: nil, source: nil)

    app.openExercise(first)
    app.study.draft = "SELECT 7 AS learner_answer;"
    app.openExercise(second)

    #expect(app.store.record("drafts", id: first.id)?.payload.text("code") == "SELECT 7 AS learner_answer;")
    app.openExercise(first)
    #expect(app.study.draft == "SELECT 7 AS learner_answer;")
}
