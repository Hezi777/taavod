import Foundation
import Observation

@Observable final class StudySession {
    var trackID = "sql"
    var lessonID = ""
    var exerciseID = ""
    var draft = ""
    var selectedText = ""
    var outcome: PracticeOutcome?
    var hintsUsed = 0
    var mode = "practice"
}

@Observable final class AppModel {
    let store: WorkspaceStore
    let tracks: [SkillTrack]
    let study = StudySession()
    let packs = RuntimePacks()
    let runner = ExerciseRunner()
    var route: AppRoute = .today
    var coachOpen = false
    var coachExpanded = false
    var search = ""
    var selectedRecordID: String?
    var lessonToOpen: String?
    var coachEditorContext = ""
    var dashboardHasAppeared = false
    @ObservationIgnored lazy var coach = CoachModel(app: self)

    init(store: WorkspaceStore) {
        self.store = store
        do { tracks = try JSONDecoder().decode([SkillTrack].self, from: Data(contentsOf: AppPaths.resources.appendingPathComponent("curriculum.json"))) }
        catch { tracks = []; store.error = "The learning library could not be loaded: \(error.localizedDescription)" }
    }
    var activeTrack: SkillTrack? { tracks.first { $0.id == study.trackID } }
    var activeLesson: Lesson? { activeTrack?.lessons.first { $0.id == study.lessonID } }
    var activeExercise: Exercise? { tracks.flatMap(\.exercises).first { $0.id == study.exerciseID } }
    func openLesson(_ lesson: Lesson, in track: SkillTrack) {
        if runner.isRunning { runner.cancel() }
        saveDraft()
        study.trackID = track.id
        study.lessonID = lesson.id
        study.mode = "learn"
        lessonToOpen = lesson.id
        route = .learn
    }
    func openExercise(_ exercise: Exercise) {
        if runner.isRunning { runner.cancel() }
        saveDraft()
        study.trackID = exercise.skillId; study.exerciseID = exercise.id
        study.draft = store.record("drafts", id: exercise.id)?.payload.text("code") ?? exercise.starter ?? ""
        study.outcome = nil; study.hintsUsed = 0; route = .practice
    }
    func saveDraft() {
        guard !study.exerciseID.isEmpty else { return }
        store.update("drafts", id: study.exerciseID, patch: ["code": .string(study.draft), "updatedAt": .string(Date.now.ISO8601Format())])
    }
    func saveAttempt(_ outcome: PracticeOutcome, selfReviewed: Bool = false, exercise: Exercise? = nil, answer: String? = nil, hintsUsed: Int? = nil, mode: String? = nil) {
        guard let exercise = exercise ?? activeExercise else { return }
        store.update("attempts", id: UUID().uuidString, patch: [
            "exerciseId": .string(exercise.id), "skillId": .string(exercise.skillId), "answer": .string(answer ?? study.draft),
            "passed": outcome.passed.map(JSONValue.bool) ?? .null, "feedback": .string(outcome.feedback),
            "hintsUsed": .number(Double(hintsUsed ?? study.hintsUsed)), "createdAt": .string(Date.now.ISO8601Format()),
            "mode": .string(mode ?? study.mode), "selfReported": .bool(selfReviewed)
        ])
    }
}
