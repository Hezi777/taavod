import SwiftUI
import Charts

struct TodayView: View {
    @Bindable var app: AppModel
    @State private var addingTask = false
    @State private var taskTitle = ""
    @State private var activityPeriod = 90
    @State private var selectedRoleDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var tasks: [WorkspaceRecord] {
        app.store.list("tasks").filter { $0.payload.text("weekOf").isEmpty || $0.payload.text("weekOf") == LearningProgress.week() }
    }
    private var attempts: [WorkspaceRecord] { app.store.list("attempts") }
    private var jobs: [WorkspaceRecord] { app.store.list("jobs") }
    private var passes: Int { attempts.filter { $0.payload.flag("passed") && !$0.payload.flag("selfReported") }.count }
    private var track: SkillTrack? { app.activeTrack ?? app.tracks.first }
    private var completedTasks: Int { tasks.filter { $0.payload.flag("done") }.count }
    private var completedMinutes: Int { tasks.filter { $0.payload.flag("done") }.reduce(0) { $0 + Int($1.payload.number("minutes")) } }
    private var reviews: [Exercise] { LearningProgress.dueReviews(attempts: attempts, tracks: app.tracks) }
    private var progress: Double {
        guard let track, !track.lessons.isEmpty else { return 0 }
        return Double(track.lessons.filter { app.store.record("lessons", id: $0.id)?.payload.flag("completed") == true }.count) / Double(track.lessons.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading
                roleActivityCard
                weeklyPlan
                learningPath
                practiceSummary
            }
            .padding(.horizontal, 30)
            .padding(.top, 24)
            .padding(.bottom, 36)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(TaavodPalette.canvas)
        .alert("Add to this week", isPresented: $addingTask) {
            TextField("One clear next step", text: $taskTitle)
            Button("Cancel", role: .cancel) { taskTitle = "" }
            Button("Add task", action: addTask)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Dashboard")
                .font(.system(size: 28, weight: .medium)).tracking(-0.8)
                .foregroundStyle(TaavodPalette.ink)
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
        }
        .padding(.bottom, 2)
    }

    private var roleActivityCard: some View {
        TaavodCard(padding: 24, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Role activity").font(.system(size: 17, weight: .semibold)).tracking(-0.3)
                    Text("Saved roles over time").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                }
                Spacer(minLength: 12)
                periodSelector
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(jobs.count.formatted())
                    .font(.system(size: 42, weight: .medium, design: .rounded)).tracking(-1.5)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(jobs.count) saved roles")
                Text("saved roles")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(TaavodPalette.muted)
                Spacer()
                Text("\(activityWindowCount) in the last \(activityPeriod) days")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(TaavodPalette.muted)
            }

            if jobs.isEmpty {
                emptyRoleActivity("No saved roles yet.", detail: "Add a role to start your activity timeline.", action: "Browse roles")
            } else if activityWindowCount == 0 {
                let detail = undatedRoleCount > 0
                    ? "\(undatedRoleCount.formatted()) saved roles have no capture date. All roles remain in the full list."
                    : "Your \(jobs.count.formatted()) saved roles are still available in the full list."
                emptyRoleActivity("No roles saved in this period.", detail: detail, action: "View all roles")
            } else {
                Chart {
                    ForEach(roleActivity) { bucket in
                        BarMark(
                            x: .value("Date", bucket.date, unit: activityPeriod == 90 ? .weekOfYear : .day),
                            y: .value("Roles saved", bucket.count),
                            width: .ratio(activityPeriod == 90 ? 0.56 : activityPeriod == 30 ? 0.58 : 0.5)
                        )
                        .foregroundStyle(isSelected(bucket) ? TaavodPalette.accent : TaavodPalette.line)
                        .cornerRadius(4)
                        .accessibilityLabel(bucket.date.formatted(.dateTime.month(.wide).day()))
                        .accessibilityValue("\(bucket.count) roles saved")

                        if isSelected(bucket) {
                            RuleMark(x: .value("Selected date", bucket.date, unit: activityPeriod == 90 ? .weekOfYear : .day))
                                .foregroundStyle(TaavodPalette.muted.opacity(0.32))
                                .annotation(position: .top, spacing: 5) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if activityPeriod == 90 {
                                            Text("Week of \(bucket.date.formatted(.dateTime.month(.abbreviated).day()))")
                                                .font(.system(size: 11, weight: .semibold))
                                        } else {
                                            Text(bucket.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        Text("\(bucket.count) \(bucket.count == 1 ? "role" : "roles") saved")
                                            .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 0.8))
                                }
                        }
                    }
                }
                .chartYScale(domain: 0...max(3, (roleActivity.map(\.count).max() ?? 0) + 1))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: activityPeriod == 7 ? 7 : 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(activityPeriod == 7
                                     ? date.formatted(.dateTime.weekday(.abbreviated))
                                     : date.formatted(.dateTime.month(.abbreviated).day()))
                            }
                        }
                        .foregroundStyle(TaavodPalette.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(TaavodPalette.line)
                        AxisValueLabel().foregroundStyle(TaavodPalette.muted)
                    }
                }
                .chartXSelection(value: $selectedRoleDate)
                .chartPlotStyle { plot in plot.padding(.horizontal, 8) }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let plot = proxy.plotFrame else { return }
                                    let frame = geometry[plot]
                                    selectedRoleDate = proxy.value(atX: location.x - frame.origin.x, as: Date.self)
                                case .ended:
                                    selectedRoleDate = nil
                                }
                            }
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("Roles saved by day over the last \(activityPeriod) days")

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(TaavodPalette.accent).frame(width: 11, height: 8)
                    Text("Selected day or week").font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                    Spacer()
                    if undatedRoleCount > 0 {
                        Text("\(undatedRoleCount) roles without a saved date are not charted")
                            .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .id(colorScheme)
    }

    private var periodSelector: some View {
        HStack(spacing: 2) {
            ForEach([7, 30, 90], id: \.self) { days in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                        activityPeriod = days
                        selectedRoleDate = nil
                    }
                } label: {
                    Text("\(days)d")
                        .font(.system(size: 12, weight: activityPeriod == days ? .semibold : .medium))
                        .foregroundStyle(activityPeriod == days ? TaavodPalette.ink : TaavodPalette.muted)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background {
                            if activityPeriod == days {
                                RoundedRectangle(cornerRadius: 7).fill(TaavodPalette.line)
                            }
                        }
                }
                .buttonStyle(TaavodPressButtonStyle())
                .accessibilityLabel("Show roles saved in the last \(days) days")
                .accessibilityAddTraits(activityPeriod == days ? .isSelected : [])
            }
        }
        .padding(3)
        .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func emptyRoleActivity(_ title: String, detail: String, action: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(TaavodPalette.ink)
            Text(detail).font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
            Button(action) { app.route = .jobs }
                .font(.system(size: 12, weight: .medium)).buttonStyle(.bordered).controlSize(.regular).padding(.top, 3)
        }
                .frame(maxWidth: .infinity, minHeight: 160)
        .multilineTextAlignment(.center)
    }

    private var weeklyPlan: some View {
        TaavodCard(padding: 20, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week").font(.system(size: 17, weight: .semibold)).tracking(-0.3)
                    Text("\(completedTasks) of \(tasks.count) tasks complete · \(completedMinutes) min completed")
                        .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                }
                Spacer()
                Button { LearningProgress.suggestPlan(app: app) } label: { Label("Refresh plan", systemImage: "arrow.clockwise") }
                    .font(.system(size: 11, weight: .medium)).buttonStyle(TaavodPressButtonStyle())
                Button { addingTask = true } label: { Label("Add task", systemImage: "plus") }
                    .font(.system(size: 11, weight: .medium)).buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.bottom, 14)

            if tasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Make room for one useful step.").font(.system(size: 13)).foregroundStyle(TaavodPalette.muted)
                    Button("Suggest my weekly plan") { LearningProgress.suggestPlan(app: app) }
                        .buttonStyle(.bordered).controlSize(.regular)
                }
                .padding(.vertical, 14)
            } else {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(task)
                    if index < tasks.count - 1 {
                        Rectangle().fill(TaavodPalette.line).frame(height: 0.7).padding(.leading, 42)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func taskRow(_ task: WorkspaceRecord) -> some View {
        HStack(spacing: 10) {
            Button { toggleTask(task) } label: {
                Image(systemName: task.payload.flag("done") ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17)).foregroundStyle(task.payload.flag("done") ? TaavodPalette.accent : TaavodPalette.muted)
                    .frame(width: 32, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TaavodPressButtonStyle())
            .accessibilityLabel(task.payload.flag("done") ? "Mark \(task.payload.text("title")) unfinished" : "Complete \(task.payload.text("title"))")

            Button { openTask(task) } label: {
                Text(task.payload.text("title"))
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(task.payload.flag("done"))
                    .foregroundStyle(TaavodPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TaavodPressButtonStyle())

            Text("\(Int(task.payload.number("minutes"))) min · \(task.payload.text("type").capitalized)")
                .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 2)
    }

    private var learningPath: some View {
        TaavodCard(padding: 20, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learning path").font(.system(size: 17, weight: .semibold)).tracking(-0.3)
                    Text(track?.title ?? "Choose a path to begin")
                        .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                }
                Spacer()
                Text("\(Int(progress * 100))% complete")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(TaavodPalette.muted)
            }
            ProgressView(value: progress).tint(TaavodPalette.accent)
            HStack {
                Text(track?.lessons.first(where: { $0.id == app.study.lessonID })?.title ?? track?.lessons.first?.title ?? "Explore the lesson library")
                    .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                Spacer()
                Button {
                    if let track, let lesson = app.activeLesson ?? track.lessons.first { app.openLesson(lesson, in: track) }
                    else { app.route = .learn }
                } label: { Label("Continue learning", systemImage: "arrow.right") }
                    .font(.system(size: 12, weight: .medium)).buttonStyle(TaavodPressButtonStyle())
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var practiceSummary: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.seal").font(.system(size: 15)).foregroundStyle(TaavodPalette.muted)
            Text("Practice").font(.system(size: 13, weight: .semibold))
            Text("\(attempts.count) checks · \(passes) verified passes")
                .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
            if let review = reviews.first {
                Text("· Due: \(review.title)").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted).lineLimit(1)
            }
            Spacer()
            if let review = reviews.first {
                Button { app.openExercise(review) } label: { Label("Review exercise", systemImage: "arrow.right") }
                    .font(.system(size: 12, weight: .medium)).buttonStyle(TaavodPressButtonStyle())
            } else {
                Button { app.route = .practice } label: { Label("Start practice", systemImage: "arrow.right") }
                    .font(.system(size: 12, weight: .medium)).buttonStyle(TaavodPressButtonStyle())
            }
        }
        .padding(.horizontal, 4).padding(.vertical, 8)
    }

    private var undatedRoleCount: Int { jobs.count - jobs.filter { LearningProgress.date($0.payload.text("capturedAt")) != nil }.count }
    private var activityWindowCount: Int { roleActivity.reduce(0) { $0 + $1.count } }
    private var selectedRoleActivity: RoleActivityDay? {
        guard let selectedRoleDate else { return roleActivity.last(where: { $0.count > 0 }) }
        let granularity: Calendar.Component = activityPeriod == 90 ? .weekOfYear : .day
        return roleActivity.first { Calendar.current.isDate($0.date, equalTo: selectedRoleDate, toGranularity: granularity) }
    }
    private func isSelected(_ bucket: RoleActivityDay) -> Bool { selectedRoleActivity?.id == bucket.id }

    private var roleActivity: [RoleActivityDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(activityPeriod - 1), to: today) else { return [] }
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let datedJobs = jobs.compactMap { job -> (Date, WorkspaceRecord)? in
            guard let date = LearningProgress.date(job.payload.text("capturedAt")), date >= start, date < end else { return nil }
            return (date, job)
        }
        let grouped = Dictionary(grouping: datedJobs) { item -> Date in
            let day = calendar.startOfDay(for: item.0)
            return activityPeriod == 90 ? (calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day) : day
        }

        let offsets = Swift.stride(from: 0, to: activityPeriod, by: activityPeriod == 90 ? 7 : 1)
        var keys: [Date] = []
        for offset in offsets {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let key = activityPeriod == 90 ? (calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date) : date
            if keys.last != key { keys.append(key) }
        }
        return keys.map { date in RoleActivityDay(date: date, count: grouped[date, default: []].count) }
    }

    private func toggleTask(_ task: WorkspaceRecord) {
        let done = !task.payload.flag("done")
        app.store.update("tasks", id: task.id, patch: ["done": .bool(done), "completedAt": .string(done ? Date.now.ISO8601Format() : "")])
    }

    private func openTask(_ task: WorkspaceRecord) {
        if let exercise = app.tracks.flatMap(\.exercises).first(where: { $0.id == task.payload.text("exerciseId") }) {
            app.openExercise(exercise)
        } else {
            app.route = task.payload.text("type") == "project" ? .portfolio : task.payload.text("type") == "interview" ? .interviews : .practice
        }
    }

    private func addTask() {
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            app.store.update("tasks", id: UUID().uuidString, patch: ["title": .string(title), "minutes": .number(30), "done": .bool(false), "type": .string("career"), "weekOf": .string(LearningProgress.week()), "createdAt": .string(Date.now.ISO8601Format())])
        }
        taskTitle = ""
    }
}

private struct RoleActivityDay: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}
