import SwiftUI
import AppKit

struct LearnView: View {
    @Bindable var app: AppModel
    @State private var selectedLessonID = ""
    @State private var screen: Screen = .paths

    private enum Screen { case paths, path, lesson }

    private var track: SkillTrack? { app.activeTrack ?? app.tracks.first }
    private var lesson: Lesson? {
        track?.lessons.first { $0.id == (selectedLessonID.isEmpty ? app.study.lessonID : selectedLessonID) }
            ?? track?.lessons.first
    }
    private var lessons: [Lesson] { track?.lessons ?? [] }
    private var lessonIndex: Int { lessons.firstIndex { $0.id == lesson?.id } ?? 0 }
    private var lessonExercises: [Exercise] {
        guard let track else { return [] }
        return Self.exercises(for: track, lessonIndex: lessonIndex)
    }
    static func exercises(for track: SkillTrack, lessonIndex: Int) -> [Exercise] {
        let exercises = track.exercises
        guard !exercises.isEmpty else { return [] }
        let sameTrack = exercises.filter { $0.skillId == track.id }
        let available = sameTrack.isEmpty ? exercises : sameTrack
        let perLesson = max(1, (available.count + max(1, track.lessons.count) - 1) / max(1, track.lessons.count))
        let boundedIndex = min(max(lessonIndex, 0), max(track.lessons.count - 1, 0))
        let start = min(boundedIndex * perLesson, available.count - 1)
        return Array(available[start..<min(start + perLesson, available.count)])
    }
    private var completed: Set<String> {
        Set(app.store.list("lessons").filter { $0.payload.flag("completed") }.map(\.id))
    }
    private var totalLessons: Int { app.tracks.reduce(0) { $0 + $1.lessons.count } }
    private var totalExercises: Int { app.tracks.reduce(0) { $0 + $1.exercises.count } }

    var body: some View {
        Group {
            switch screen {
            case .paths: pathsOverview
            case .path: pathOverview
            case .lesson: lessonReader
            }
        }
        .background(TaavodPalette.canvas)
        .onAppear {
            if selectedLessonID.isEmpty { selectedLessonID = app.study.lessonID }
            if selectedLessonID.isEmpty { selectedLessonID = nextLesson(in: track)?.id ?? "" }
            if app.study.lessonID.isEmpty { app.study.lessonID = selectedLessonID }
            openRequestedLesson()
        }
        .onChange(of: app.study.trackID) { _, _ in
            guard !lessons.contains(where: { $0.id == selectedLessonID }) else { return }
            selectedLessonID = lessons.first(where: { $0.id == app.study.lessonID })?.id ?? nextLesson(in: track)?.id ?? ""
            if !selectedLessonID.isEmpty { app.study.lessonID = selectedLessonID }
        }
        .onChange(of: app.lessonToOpen) { _, _ in openRequestedLesson() }
    }

    private var pathsOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("LEARN", systemImage: "books.vertical")
                        .font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(TaavodPalette.accent)
                    Text("Choose your next skill")
                        .font(.largeTitle.weight(.semibold)).tracking(-0.7).foregroundStyle(TaavodPalette.ink)
                    Text("Build practical BI and career skills through short lessons and hands-on practice.")
                        .font(.body).foregroundStyle(TaavodPalette.muted).fixedSize(horizontal: false, vertical: true)
                    Text("\(app.tracks.count) paths  ·  \(totalLessons) lessons  ·  \(totalExercises) exercises")
                        .font(.subheadline.weight(.medium)).foregroundStyle(TaavodPalette.ink)
                        .padding(.top, 3)
                }
                .frame(maxWidth: 900, alignment: .leading)

                if app.tracks.isEmpty {
                    ContentUnavailableView("Learning paths unavailable", systemImage: "books.vertical",
                                           description: Text("The curriculum could not be loaded."))
                } else {
                    if let track, let next = nextLesson(in: track) {
                        continueCard(track: track, lesson: next)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Learning paths").font(.title2.weight(.semibold)).foregroundStyle(TaavodPalette.ink)
                            Spacer()
                            Text("Choose a path to see its lessons")
                                .font(.subheadline).foregroundStyle(TaavodPalette.muted)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], alignment: .leading, spacing: 14) {
                            ForEach(app.tracks) { item in pathCard(item) }
                        }
                    }
                    .frame(maxWidth: 1100, alignment: .leading)
                }
            }
            .padding(.horizontal, 34).padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private func continueCard(track: SkillTrack, lesson: Lesson) -> some View {
        Button { openLesson(lesson, in: track) } label: {
            HStack(spacing: 18) {
                Image(systemName: pathSymbol(track))
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(TaavodPalette.accent)
                    .frame(width: 58, height: 58)
                    .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text("NEXT LESSON")
                        .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(TaavodPalette.muted)
                    Text(track.title).font(.headline).foregroundStyle(TaavodPalette.ink)
                    Text(lesson.title).font(.subheadline).foregroundStyle(TaavodPalette.muted).lineLimit(2)
                }
                Spacer(minLength: 12)
                Label("Open lesson", systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(TaavodPalette.surface)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(TaavodPalette.accent, in: Capsule())
            }
            .padding(20)
            .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 0.7))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(TaavodPressButtonStyle())
        .taavodInteractiveCard(cornerRadius: 20)
        .accessibilityHint("Opens \(lesson.title) in \(track.title)")
        .frame(maxWidth: 900, alignment: .leading)
    }

    private func pathCard(_ item: SkillTrack) -> some View {
        let completeCount = item.lessons.filter { completed.contains($0.id) }.count
        return Button { showPath(item) } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    Image(systemName: pathSymbol(item))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(TaavodPalette.accent)
                        .frame(width: 44, height: 44)
                        .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.muted)
                        .padding(8).background(TaavodPalette.canvas, in: Circle())
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(.headline).foregroundStyle(TaavodPalette.ink).fixedSize(horizontal: false, vertical: true)
                    Text(item.description).font(.subheadline).foregroundStyle(TaavodPalette.muted)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                HStack {
                    Label("\(item.lessons.count) lessons", systemImage: "book.closed")
                    Text("·").foregroundStyle(TaavodPalette.muted)
                    Label("\(item.exercises.count) exercises", systemImage: "checkmark.circle")
                    Spacer(minLength: 0)
                    Text("\(completeCount)/\(item.lessons.count)")
                        .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(TaavodPalette.ink)
                }
                .font(.caption).foregroundStyle(TaavodPalette.muted)
                ProgressView(value: Double(completeCount), total: Double(max(1, item.lessons.count)))
                    .tint(TaavodPalette.accent)
                    .accessibilityHidden(true)
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 0.7))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(TaavodPressButtonStyle())
        .taavodInteractiveCard(cornerRadius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(item.title). \(item.lessons.count) lessons, \(item.exercises.count) exercises. \(completeCount) lessons completed.")
        .accessibilityHint("Opens the path overview")
    }

    private var pathOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { screen = .paths } label: {
                    Label("All learning paths", systemImage: "chevron.left")
                }
                .buttonStyle(TaavodPressButtonStyle()).foregroundStyle(TaavodPalette.muted)

                if let track {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: pathSymbol(track))
                            .font(.system(size: 27, weight: .medium)).foregroundStyle(TaavodPalette.accent)
                            .frame(width: 62, height: 62)
                            .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LEARNING PATH").font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(TaavodPalette.muted)
                            Text(track.title).font(.largeTitle.weight(.semibold)).tracking(-0.6).foregroundStyle(TaavodPalette.ink)
                            Text(track.description).font(.body).foregroundStyle(TaavodPalette.muted).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 15) {
                                Label("\(track.lessons.count) lessons", systemImage: "book.closed")
                                Label("\(track.exercises.count) exercises", systemImage: "checkmark.circle")
                            }.font(.subheadline).foregroundStyle(TaavodPalette.muted).padding(.top, 3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(22)
                    .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 0.7))

                    let count = track.lessons.filter { completed.contains($0.id) }.count
                    HStack(spacing: 12) {
                        ProgressView(value: Double(count), total: Double(max(1, track.lessons.count)))
                            .tint(TaavodPalette.accent).frame(maxWidth: 220)
                        Text("\(count) of \(track.lessons.count) lessons complete")
                            .font(.subheadline.weight(.medium)).foregroundStyle(TaavodPalette.ink)
                        Spacer()
                        if let next = nextLesson(in: track) {
                        Button { openLesson(next, in: track) } label: {
                                Label(count == track.lessons.count ? "Review path" : "Continue path", systemImage: "arrow.right")
                        }.buttonStyle(.borderedProminent).tint(TaavodPalette.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lessons").font(.title2.weight(.semibold)).foregroundStyle(TaavodPalette.ink)
                        ForEach(Array(track.lessons.enumerated()), id: \.element.id) { index, item in
                            pathLessonRow(item, index: index, in: track)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 34).padding(.vertical, 28)
            .frame(maxWidth: 980, alignment: .leading).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private func pathLessonRow(_ item: Lesson, index: Int, in track: SkillTrack) -> some View {
        let isComplete = completed.contains(item.id)
        let isNext = nextLesson(in: track)?.id == item.id && !isComplete
        return Button { openLesson(item, in: track) } label: {
            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(TaavodPalette.canvas)
                    if isComplete {
                        Image(systemName: "checkmark").font(.subheadline.weight(.semibold)).foregroundStyle(TaavodPalette.accent)
                    } else {
                        Text("\(index + 1)").font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(TaavodPalette.muted)
                    }
                }.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline).foregroundStyle(TaavodPalette.ink).multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        Label("\(item.minutes) min", systemImage: "clock")
                        Text("\(Self.exercises(for: track, lessonIndex: index).count) exercises")
                    }.font(.caption).foregroundStyle(TaavodPalette.muted)
                }
                Spacer(minLength: 8)
                if isNext {
                    Text("NEXT UP").font(.caption2.weight(.semibold)).tracking(0.7).foregroundStyle(TaavodPalette.accent)
                } else if isComplete {
                    Text("Complete").font(.caption.weight(.medium)).foregroundStyle(TaavodPalette.muted)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TaavodPalette.muted)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(isNext ? TaavodPalette.accent.opacity(0.48) : TaavodPalette.line, lineWidth: isNext ? 1 : 0.65))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(TaavodPressButtonStyle())
        .taavodInteractiveCard(cornerRadius: 15)
        .accessibilityLabel("Lesson \(index + 1), \(item.title), \(item.minutes) minutes, \(isComplete ? "completed" : (isNext ? "next up" : "not completed"))")
    }

    private var lessonReader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { screen = .paths } label: { Text("All paths") }
                    .buttonStyle(TaavodPressButtonStyle()).foregroundStyle(TaavodPalette.muted)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(TaavodPalette.muted)
                Button { screen = .path } label: { Text(track?.title ?? "Learning path") }
                    .buttonStyle(TaavodPressButtonStyle()).foregroundStyle(TaavodPalette.muted)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(TaavodPalette.muted)
                Text(lesson?.title ?? "Lesson").font(.subheadline.weight(.medium)).foregroundStyle(TaavodPalette.ink).lineLimit(1)
                Spacer()
                if lesson != nil {
                    Text("Lesson \(lessonIndex + 1) of \(lessons.count)")
                        .font(.subheadline.weight(.medium)).foregroundStyle(TaavodPalette.muted)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            lessonContent.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func openRequestedLesson() {
        guard let id = app.lessonToOpen, lessons.contains(where: { $0.id == id }) else { return }
        selectedLessonID = id
        screen = .lesson
        app.lessonToOpen = nil
    }

    private func showPath(_ item: SkillTrack) {
        app.study.trackID = item.id
        selectedLessonID = nextLesson(in: item)?.id ?? ""
        if !selectedLessonID.isEmpty { app.study.lessonID = selectedLessonID }
        app.study.mode = "learn"
        screen = .path
    }

    private func openLesson(_ item: Lesson, in track: SkillTrack) {
        app.study.trackID = track.id
        selectedLessonID = item.id
        app.study.lessonID = item.id
        app.study.mode = "learn"
        screen = .lesson
    }

    private func nextLesson(in track: SkillTrack?) -> Lesson? {
        guard let track else { return nil }
        if app.study.trackID == track.id,
           let saved = track.lessons.first(where: { $0.id == app.study.lessonID }),
           !completed.contains(saved.id) {
            return saved
        }
        return track.lessons.first(where: { !completed.contains($0.id) }) ?? track.lessons.first
    }

    private func pathSymbol(_ track: SkillTrack) -> String {
        switch track.id {
        case "sql": "tablecells"
        case "modeling": "shippingbox"
        case "etl": "arrow.triangle.2.circlepath"
        case "powerbi": "chart.bar.xaxis"
        case "excel": "tablecells"
        case "qlik": "point.3.connected.trianglepath.dotted"
        case "python": "chevron.left.forwardslash.chevron.right"
        case "metrics": "chart.xyaxis.line"
        case "git-ai": "arrow.triangle.branch"
        case "communication": "bubble.left.and.bubble.right"
        default: "book.closed"
        }
    }

    private var lessonContent: some View {
        Group {
            if let lesson {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Label("LESSON \(lessonIndex + 1)", systemImage: "book.closed")
                                .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(TaavodPalette.muted)
                            Spacer()
                            Text("\(lesson.minutes) MIN").font(.caption.weight(.medium)).foregroundStyle(.tertiary)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            Text(lesson.title).font(.system(size: 30, weight: .semibold)).tracking(-0.45).fixedSize(horizontal: false, vertical: true)
                            Text(track?.description ?? "")
                                .font(.title3).foregroundStyle(TaavodPalette.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.7))
                        if !lesson.paragraphs.isEmpty {
                            LearningSection(number: "01", title: "Understand the idea") {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(Array(lesson.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                        Text(paragraph).font(.body).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        LearningSection(number: "02", title: "See it in action") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("WORKED EXAMPLE").font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
                                CodeSampleView(code: lesson.example, language: track?.id ?? "sql")
                                if !lesson.takeaway.isEmpty {
                                    Label(lesson.takeaway, systemImage: "lightbulb")
                                        .font(.callout.weight(.medium)).foregroundStyle(.primary)
                                        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        if !lessonExercises.isEmpty {
                            LearningSection(number: "03", title: "Try it yourself") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), alignment: .top)], alignment: .leading, spacing: 14) {
                                    ForEach(Array(lessonExercises.enumerated()), id: \.element.id) { index, item in
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                                    .foregroundStyle(TaavodPalette.accent)
                                                Spacer()
                                                Text("EXERCISE \(index + 1)").font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(TaavodPalette.muted)
                                            }
                                            Text(item.title).font(.subheadline.weight(.semibold))
                                            Text(item.prompt).font(.callout).lineSpacing(3).lineLimit(5).fixedSize(horizontal: false, vertical: true)
                                            HStack(spacing: 8) {
                                                Text(item.difficulty.capitalized).padding(.horizontal, 9).padding(.vertical, 5).background(TaavodPalette.canvas, in: Capsule())
                                                Label("\(item.minutes) min", systemImage: "clock")
                                            }.font(.caption.weight(.medium)).foregroundStyle(TaavodPalette.ink)
                                            Button {
                                                app.saveDraft()
                                                app.study.lessonID = lesson.id
                                                app.openExercise(item)
                                                app.study.mode = "practice"
                                            } label: {
                                                Label("Open practice", systemImage: "arrow.right")
                                            }
                                            .buttonStyle(.borderedProminent).tint(TaavodPalette.accent)
                                        }
                                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.7))
                                    }
                                }
                            }
                        }
                        if let sourceURL = URL(string: lesson.source.url), !lesson.source.url.isEmpty {
                            Link(destination: sourceURL) {
                                Label("Source: \(lesson.source.title)", systemImage: "arrow.up.right.square")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Button("Previous") { moveLesson(-1) }
                                .disabled(lessonIndex == 0)
                            Spacer()
                            Button {
                                markComplete(lesson)
                                moveLesson(1)
                            } label: {
                                Label(completed.contains(lesson.id) ? "Completed" : "Mark complete", systemImage: completed.contains(lesson.id) ? "checkmark.circle.fill" : "checkmark.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Next") { markComplete(lesson); moveLesson(1) }
                                .disabled(lessonIndex >= lessons.count - 1)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: 900, alignment: .leading)
                    .padding(.horizontal, 34).padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(TaavodPalette.canvas)
            } else {
                ContentUnavailableView("Choose a learning path", systemImage: "book.closed", description: Text("Your lessons will appear here."))
            }
        }
    }

    private func markComplete(_ lesson: Lesson) {
        app.store.update("lessons", id: lesson.id, patch: [
            "trackId": .string(track?.id ?? app.study.trackID),
            "completed": .bool(true),
            "completedAt": .string(Date.now.ISO8601Format())
        ])
    }

    private func moveLesson(_ offset: Int) {
        let target = min(max(lessonIndex + offset, 0), max(lessons.count - 1, 0))
        guard lessons.indices.contains(target) else { return }
        selectedLessonID = lessons[target].id
        app.study.lessonID = lessons[target].id
    }
}

private struct LearningSection<Content: View>: View {
    var number: String
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Text(number).font(.caption.monospaced().weight(.bold)).foregroundStyle(TaavodPalette.accent)
                Text(title).font(.title3.weight(.semibold))
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.7))
    }
}

private struct CodeSampleView: View {
    let code: String
    let language: String
    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(TaavodPalette.line))
        .accessibilityLabel("Worked \(language) code example")
    }
}

struct PracticeView: View {
    @Bindable var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editorFind = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showingSchema = false
    @State private var writtenAnswer = ""
    @State private var selfReviewChecks: Set<Int> = []
    @State private var packTask: Task<Void, Never>?
    @State private var instructionsExpanded = false
    @State private var codeTab: CodeTab = .editor

    private enum CodeTab: String, CaseIterable { case editor = "Code", results = "Results" }

    private var exercise: Exercise? { app.activeExercise }
    private var track: SkillTrack? { app.activeTrack }
    private var kind: PackKind { (exercise?.kind.lowercased().contains("python") == true || app.study.trackID.lowercased().contains("python")) ? .python : .sql }
    private var language: String { kind == .sql ? "SQL" : "Python" }
    private var isWritten: Bool {
        let kind = exercise?.kind.lowercased() ?? ""
        return kind.contains("written") || kind.contains("reflection") || kind.contains("external")
    }
    private var isQuiz: Bool { exercise?.options?.isEmpty == false }
    private var isSchemaLesson: Bool { app.study.trackID == "sql" }
    private var attemptCount: Int { app.store.list("attempts").filter { $0.payload.text("exerciseId") == exercise?.id }.count }
    private var draftBinding: Binding<String> {
        Binding(get: { app.study.draft }, set: { app.study.draft = $0 })
    }
    private var selectedTextBinding: Binding<String> {
        Binding(get: { app.study.selectedText }, set: { app.study.selectedText = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if let exercise {
                VStack(alignment: .leading, spacing: 14) {
                    exerciseInstructions(exercise)
                    if !isQuiz && !isWritten {
                        Picker("Practice view", selection: $codeTab) {
                            ForEach(CodeTab.allCases, id: \.self) { tab in Text(tab.rawValue).tag(tab) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                        .accessibilityHint("Switch between your code editor and the latest run results")
                    }
                    workspace(exercise)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
            } else {
                emptyPractice
            }
        }
        .background(TaavodPalette.canvas)
        .background(alignment: .topLeading) {
            RuntimeWebViewHost(runner: app.runner)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onAppear { restoreAnswer() }
        .onChange(of: exercise?.id) { _, _ in
            flushAndSave(); restoreAnswer(); updateCoachEditorContext()
            codeTab = .editor
            instructionsExpanded = false
        }
        .onChange(of: writtenAnswer) { _, answer in
            updateCoachEditorContext()
            if isWritten { app.study.draft = answer }
        }
        .onChange(of: selfReviewChecks, initial: true) { _, _ in updateCoachEditorContext() }
        .onChange(of: app.study.draft) { _, _ in scheduleSave() }
        .onDisappear { flushAndSave(); app.coachEditorContext = ""; packTask?.cancel(); app.runner.cancel() }
        .sheet(isPresented: $showingSchema) { SchemaExplorerView(app: app) }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: kind == .sql ? "tablecells" : "chart.bar.xaxis")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(TaavodPalette.accent)
                .frame(width: 38, height: 38).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
            Text("Practice").font(.headline).foregroundStyle(TaavodPalette.ink)
                Text("\(track?.title ?? "Choose an exercise") · \(language)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !app.study.selectedText.isEmpty {
                Label("Selection ready for Coach", systemImage: "text.quote").font(.caption).foregroundStyle(.secondary)
            }
            Button {
                app.coachOpen = true
                app.coachExpanded = true
            } label: { Label("Coach", systemImage: "sparkles") }
                .buttonStyle(.bordered)
                .help("Ask about your current lesson and selected code")
            if isSchemaLesson {
                Button { showingSchema = true } label: { Label("Explore data", systemImage: "point.3.connected.trianglepath.dotted") }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(TaavodPalette.surface)
    }

    private func exerciseInstructions(_ exercise: Exercise) -> some View {
        DisclosureGroup(isExpanded: $instructionsExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                Text(exercise.prompt).font(.body).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                if !exercise.hints.isEmpty {
                    Divider()
                    HStack {
                        Text("Hints").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(min(app.study.hintsUsed, exercise.hints.count)) of \(exercise.hints.count) revealed")
                            .font(.caption).foregroundStyle(TaavodPalette.muted)
                    }
                    if app.study.hintsUsed > 0 {
                        Text(exercise.hints[min(app.study.hintsUsed, exercise.hints.count) - 1])
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    if app.study.hintsUsed < exercise.hints.count {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { app.study.hintsUsed += 1 }
                        } label: { Label(app.study.hintsUsed == 0 ? "Show a hint" : "Show next hint", systemImage: "lightbulb") }
                            .buttonStyle(.borderless)
                    }
                }
                if let outcome = app.study.outcome { feedbackPanel(outcome, exercise: exercise) }
                if !exercise.rubric.isEmpty && isWritten { rubricPanel(exercise) }
                HStack(spacing: 16) {
                    if attemptCount > 0 {
                        Label("\(attemptCount) saved attempt\(attemptCount == 1 ? "" : "s")", systemImage: "clock.arrow.circlepath")
                    }
                    if let lesson = app.activeLesson { Label(lesson.title, systemImage: "book.closed").lineLimit(1) }
                }
                .font(.caption).foregroundStyle(TaavodPalette.muted)
            }
            .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(exercise.title).font(.title3.weight(.semibold)).foregroundStyle(TaavodPalette.ink)
                    Spacer()
                    Text(exercise.difficulty.capitalized)
                        .font(.caption.weight(.medium)).foregroundStyle(TaavodPalette.muted)
                    Label("\(exercise.minutes) min", systemImage: "clock")
                        .font(.caption).foregroundStyle(TaavodPalette.muted)
                }
                Text(exercise.prompt).font(.callout).foregroundStyle(TaavodPalette.muted)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .padding(16)
        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TaavodPalette.line))
    }

    @ViewBuilder private func workspace(_ exercise: Exercise) -> some View {
        VStack(spacing: 0) {
            if isQuiz {
                quizWorkspace(exercise)
            } else if isWritten {
                writtenWorkspace(exercise)
            } else {
                if codeTab == .editor {
                    editorToolbar(exercise)
                        .zIndex(1)
                    NativeCodeEditor(text: draftBinding, selectedText: selectedTextBinding, findText: $editorFind, language: kind)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .zIndex(0)
                } else if let outcome = app.study.outcome {
                    resultView(outcome).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("No results yet", systemImage: "terminal", description: Text("Run your code to see its output here."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                runtimeBar(exercise)
                    .zIndex(1)
            }
        }
        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func editorToolbar(_ exercise: Exercise) -> some View {
        HStack(spacing: 10) {
            Text(language).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Circle().fill(app.packs.isInstalled(kind) ? .green : .orange).frame(width: 7, height: 7)
            Text(app.packs.isInstalled(kind) ? "Available offline" : "Runtime installs on first run")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            TextField("Find in code", text: $editorFind)
                .textFieldStyle(.roundedBorder).frame(width: 150)
                .accessibilityLabel("Find in code")
            Button { app.study.draft = exercise.starter ?? ""; app.study.outcome = nil; app.runner.cancel() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(TaavodPalette.canvas)
    }

    private func runtimeBar(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !app.packs.isInstalled(kind) {
                if app.packs.installing == kind {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preparing the \(language) practice environment").font(.callout.weight(.medium))
                            Text("\(app.packs.sizeLabel(kind)) · downloads once, then works offline")
                                .font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: app.packs.progress).tint(TaavodPalette.accent)
                        }
                        Button("Cancel") { app.packs.cancel(); packTask?.cancel() }.buttonStyle(.bordered)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.packs.error == nil ? "Ready to practice?" : "Setup needs another try")
                                .font(.callout.weight(.medium))
                            Text(app.packs.error ?? "\(app.packs.sizeLabel(kind)) · stored locally for offline practice")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Button(app.packs.error == nil ? "Install & run" : "Retry") { installThenRun(exercise) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Label("Saved locally · available offline", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if app.runner.isRunning {
                        Button("Cancel") { app.runner.cancel() }.buttonStyle(.bordered)
                    } else {
                        Button { run(exercise) } label: { Label("Run", systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: [.command])
                    }
                }
            }
        }
        .padding(13).background(TaavodPalette.canvas)
    }

    private func quizWorkspace(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose your answer").font(.title3.weight(.semibold))
            ForEach(Array((exercise.options ?? []).enumerated()), id: \.offset) { index, option in
                Button {
                    let passed = index == exercise.correctOption
                    app.study.draft = option
                    let outcome = PracticeOutcome(passed: passed, feedback: passed ? "That’s right. \(exercise.explanation)" : "Not quite. Revisit the explanation and try again.", results: nil, output: nil, plot: nil, checks: nil, error: nil)
                    app.study.outcome = outcome
                    app.study.mode = "quiz"
                    app.saveAttempt(outcome)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle").foregroundStyle(TaavodPalette.accent)
                        Text(option).multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let outcome = app.study.outcome { feedbackPanel(outcome, exercise: exercise) }
        }
        .padding(28).frame(maxWidth: 700, maxHeight: .infinity, alignment: .topLeading)
    }

    private func writtenWorkspace(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your response").font(.headline)
                Spacer()
                Text("Saved as self-reviewed work").font(.caption).foregroundStyle(.secondary)
            }
            TextEditor(text: $writtenAnswer)
                .font(.body).scrollContentBackground(.hidden)
                .padding(10).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
            if !exercise.rubric.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELF-REVIEW").font(.caption.weight(.bold)).tracking(0.9).foregroundStyle(.secondary)
                    ForEach(Array(exercise.rubric.enumerated()), id: \.offset) { index, criterion in
                        Toggle(isOn: Binding(get: { selfReviewChecks.contains(index) }, set: { value in
                            if value { selfReviewChecks.insert(index) } else { selfReviewChecks.remove(index) }
                        })) { Text(criterion).font(.callout) }
                            .toggleStyle(.checkbox)
                    }
                }.padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                Text("This response is saved as self-reviewed. It does not count as a verified pass.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Save self-review") { saveWritten(exercise) }
                    .buttonStyle(.borderedProminent).disabled(writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }

    private func rubricPanel(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Self-review guide", systemImage: "checklist").font(.subheadline.weight(.semibold))
            ForEach(exercise.rubric, id: \.self) { item in
                Label(item, systemImage: "circle.dashed").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(TaavodPalette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }

    private func feedbackPanel(_ outcome: PracticeOutcome, exercise: Exercise) -> some View {
        let positive = outcome.passed == true
        return VStack(alignment: .leading, spacing: 10) {
            Label(positive ? "Passed" : (outcome.passed == false ? "Keep working" : "Result saved"), systemImage: positive ? "checkmark.circle.fill" : "arrow.trianglehead.2.clockwise")
                .font(.subheadline.weight(.semibold)).foregroundStyle(positive ? .green : .orange)
            Text(outcome.feedback).font(.callout).fixedSize(horizontal: false, vertical: true)
                if !exercise.explanation.isEmpty {
                    Text(exercise.explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if !positive, let results = outcome.results, !results.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHAT YOUR RESULT SHOWS").font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(.secondary)
                    Text(resultEvidence(results)).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .padding(10).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            }
            if outcome.passed != nil && !isWritten { Text("Verified by the local exercise checks").font(.caption2).foregroundStyle(.tertiary) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background((positive ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func resultEvidence(_ sets: [ResultSet]) -> String {
        guard let first = sets.first else { return "Compare the columns and first rows with the requested output." }
        let columns = first.fields.map(\.name).joined(separator: ", ")
        let rowCount = first.rows.count
        let preview = first.rows.prefix(2).map { row in
            first.fields.prefix(4).map { field in "\(field.name): \(display(row[field.name]))" }.joined(separator: " · ")
        }.joined(separator: "\n")
        return "Returned \(rowCount) row\(rowCount == 1 ? "" : "s") with columns: \(columns.isEmpty ? "none" : columns).\(preview.isEmpty ? "" : "\n\(preview)")"
    }

    private func resultView(_ outcome: PracticeOutcome) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Run output", systemImage: "terminal").font(.subheadline.weight(.semibold))
                    Spacer()
                    if let checks = outcome.checks { Text("\(checks) checks").font(.caption).foregroundStyle(.secondary) }
                }
                if let error = outcome.error, !error.isEmpty {
                    Text(error).font(.system(.caption, design: .monospaced)).foregroundStyle(.red)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let output = outcome.output, !output.isEmpty {
                    ScrollView(.horizontal) {
                        Text(output).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 100)
                }
                if let results = outcome.results {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(results.count > 1 ? "Result \(index + 1) · \(result.rows.count) rows" : "\(result.rows.count) rows")
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            ScrollView([.horizontal, .vertical]) {
                                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                                    GridRow {
                                        ForEach(Array(result.fields.enumerated()), id: \.offset) { _, field in
                                            Text(field.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        }
                                    }
                                    ForEach(Array(result.rows.prefix(50).enumerated()), id: \.offset) { _, row in
                                        GridRow {
                                            ForEach(Array(result.fields.enumerated()), id: \.offset) { _, field in
                                                Text(display(row[field.name])).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                            }
                                        }
                                    }
                                }.padding(8)
                            }
                            .frame(maxHeight: 150)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func display(_ value: JSONValue?) -> String {
        guard let value else { return "—" }
        switch value {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        case .array, .object: return "value"
        }
    }

    private var emptyPractice: some View {
        ContentUnavailableView {
            Label("Choose a practice exercise", systemImage: "chevron.left.forwardslash.chevron.right")
        } description: {
            Text("Open an exercise from a lesson to start writing, exploring data, or reviewing your work.")
        } actions: {
            Button("Browse lessons") { app.route = .learn }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func run(_ exercise: Exercise) {
        flushAndSave()
        let exerciseID = exercise.id
        let answer = app.study.draft
        let hintsUsed = app.study.hintsUsed
        let mode = app.study.mode
        Task {
            let result = await app.runner.run(exercise: exercise, code: answer)
            guard let result, app.study.exerciseID == exerciseID else { return }
            app.study.outcome = result
            codeTab = .results
            if result.passed != nil {
                app.saveAttempt(result, exercise: exercise, answer: answer, hintsUsed: hintsUsed, mode: mode)
            }
        }
    }

    private func installThenRun(_ exercise: Exercise) {
        packTask?.cancel()
        packTask = Task {
            do {
                try await app.packs.install(kind)
                guard !Task.isCancelled, app.packs.isInstalled(kind) else { return }
                run(exercise)
            } catch {
                // RuntimePacks exposes the actionable setup error in its observable state.
            }
        }
    }

    private func saveWritten(_ exercise: Exercise) {
        app.study.draft = writtenAnswer
        app.study.mode = "self-review"
        app.saveDraft()
        app.store.update("drafts", id: exercise.id, patch: [
            "answer": .string(writtenAnswer),
            "rubricChecked": .array(selfReviewChecks.sorted().map { .number(Double($0)) })
        ])
        let outcome = PracticeOutcome(
            passed: nil,
            feedback: "Saved as self-reviewed work. No automatic correctness check was run.",
            results: nil, output: nil, plot: nil, checks: nil, error: nil
        )
        app.study.outcome = outcome
        app.saveAttempt(outcome, selfReviewed: true, exercise: exercise, answer: writtenAnswer, hintsUsed: app.study.hintsUsed, mode: "self-review")
    }

    private func updateCoachEditorContext() {
        guard let exercise, isWritten else { app.coachEditorContext = ""; return }
        let checked = selfReviewChecks.sorted().map { exercise.rubric.indices.contains($0) ? exercise.rubric[$0] : "" }.filter { !$0.isEmpty }
        app.coachEditorContext = "Exercise answer draft [\(exercise.id)]:\n\(writtenAnswer)\nSelf-review criteria checked: \(checked.joined(separator: "; "))"
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            app.saveDraft()
        }
    }

    private func flushAndSave() {
        saveTask?.cancel()
        app.saveDraft()
    }

    private func restoreAnswer() {
        guard let exercise else { writtenAnswer = ""; return }
        let draft = app.store.record("drafts", id: exercise.id)
        writtenAnswer = draft?.payload["code"]?.string ?? draft?.payload.text("answer") ?? ""
        selfReviewChecks = Set((draft?.payload["rubricChecked"]?.array ?? []).map { Int($0.number) })
    }
}
