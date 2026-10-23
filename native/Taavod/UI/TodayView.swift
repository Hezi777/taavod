import SwiftUI
import Charts

struct TodayView: View {
    @Bindable var app: AppModel
    @State private var revealed = false
    @State private var chartRevealed = false
    @State private var addingTask = false
    @State private var taskTitle = ""
    @State private var selectedDay: Date?
    @State private var activityPeriod = 7
    @State private var selectedJobStage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var tasks: [WorkspaceRecord] { app.store.list("tasks").filter { $0.payload.text("weekOf").isEmpty || $0.payload.text("weekOf") == LearningProgress.week() } }
    private var attempts: [WorkspaceRecord] { app.store.list("attempts") }
    private var jobs: [WorkspaceRecord] { app.store.list("jobs") }
    private var passes: [WorkspaceRecord] { attempts.filter { $0.payload.flag("passed") && !$0.payload.flag("selfReported") } }
    private var track: SkillTrack? { app.activeTrack ?? app.tracks.first }
    private var targetRole: String { app.store.profile.strings("targetRoles").first ?? "Your next role" }
    private var completedTasks: Int { tasks.filter { $0.payload.flag("done") }.count }
    private var completedMinutes: Int { tasks.filter { $0.payload.flag("done") }.reduce(0) { $0 + Int($1.payload.number("minutes")) } }
    private var reviews: [Exercise] { LearningProgress.dueReviews(attempts: attempts, tracks: app.tracks) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heading
                    HStack(spacing: 14) {
                        hero.frame(maxWidth: .infinity)
                        targetCard.frame(width: geometry.size.width > 1000 ? 265 : 235)
                    }.frame(height: 132).modifier(DashboardArrival(revealed: revealed, order: 0, reduceMotion: reduceMotion))
                    statsRow.modifier(DashboardArrival(revealed: revealed, order: 1, reduceMotion: reduceMotion))
                    if attempts.isEmpty {
                        HStack(alignment: .top, spacing: 14) {
                            jobPipelineCard.frame(maxWidth: .infinity)
                            weeklyPlan.frame(width: geometry.size.width > 1000 ? 330 : 290)
                        }.frame(height: 354).modifier(DashboardArrival(revealed: revealed, order: 2, reduceMotion: reduceMotion))
                        HStack(alignment: .top, spacing: 14) {
                            practiceEmptyCard.frame(maxWidth: .infinity)
                            learningCard.frame(maxWidth: .infinity)
                            attentionCard.frame(width: geometry.size.width > 1000 ? 290 : 260)
                        }.frame(height: 215).modifier(DashboardArrival(revealed: revealed, order: 4, reduceMotion: reduceMotion))
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            activityCard.frame(maxWidth: .infinity)
                            weeklyPlan.frame(width: geometry.size.width > 1000 ? 330 : 290)
                        }.frame(height: 354).modifier(DashboardArrival(revealed: revealed, order: 2, reduceMotion: reduceMotion))
                        jobPipelineCard.frame(height: 230).modifier(DashboardArrival(revealed: revealed, order: 3, reduceMotion: reduceMotion))
                        HStack(alignment: .top, spacing: 14) {
                            learningCard.frame(maxWidth: .infinity)
                            attentionCard.frame(width: geometry.size.width > 1000 ? 330 : 290)
                        }.frame(height: 215).modifier(DashboardArrival(revealed: revealed, order: 4, reduceMotion: reduceMotion))
                    }
                    footer
                }.padding(.horizontal, 26).padding(.top, 8).padding(.bottom, 85)
                    .frame(maxWidth: 1260).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .background(TaavodPalette.canvas)
        .task {
            if app.dashboardHasAppeared { revealed = true; chartRevealed = true; return }
            app.dashboardHasAppeared = true
            revealed = true
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 140)) } catch { return }
            withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: reduceMotion ? 0.15 : 0.28)) { chartRevealed = true }
        }
        .alert("Add to this week", isPresented: $addingTask) {
            TextField("One clear next step", text: $taskTitle)
            Button("Cancel", role: .cancel) { taskTitle = "" }
            Button("Add task") { addTask() }
        }
    }

    private var heading: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                Text("Your next move, \(firstName).").font(.system(size: 28, weight: .medium)).tracking(-0.8)
            }
            Spacer()
            Label("All changes saved on this Mac", systemImage: "checkmark.circle")
                .font(.system(size: 10)).foregroundStyle(TaavodPalette.muted).padding(.bottom, 5)
        }.padding(.bottom, 4)
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color(hex: 0x252A26), Color(hex: 0x33332D)], startPoint: .leading, endPoint: .trailing)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                TaavodPortrait().frame(width: 220, height: 132).clipped()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.27), .init(color: .black, location: 1)], startPoint: .leading, endPoint: .trailing))
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) { Circle().fill(Color(hex: 0xC8E8B8)).frame(width: 5, height: 5); Text("ONE STEP AT A TIME").tracking(1.6) }.font(.system(size: 9, weight: .medium)).foregroundStyle(Color.white.opacity(0.72))
                Text("Make today count.").font(.system(size: 23, weight: .semibold)).tracking(-0.7)
                    .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                Text("Learn a skill. Put it into practice. Build proof for your next role.")
                    .font(.system(size: 10)).lineLimit(1).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                Button { app.route = .learn } label: { HStack(spacing: 16) { Text("Continue learning"); Image(systemName: "arrow.right") } }
                    .buttonStyle(TaavodPrimaryButton(light: true)).padding(.top, 3)
            }.padding(.horizontal, 21).padding(.vertical, 10)
        }.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var targetCard: some View {
        TaavodCard(fill: TaavodPalette.lilac, padding: 14, spacing: 7) {
            HStack { Text("WORKING TOWARD").font(.system(size: 9, weight: .semibold)).tracking(1.3); Spacer(); Image(systemName: "scope").font(.system(size: 18, weight: .light)) }
            Text(targetRole).font(.system(size: 16, weight: .semibold)).tracking(-0.35).lineLimit(1)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(targetDays.map(String.init) ?? "—").font(.system(size: 29, weight: .medium, design: .rounded)).tracking(-1)
                    .contentTransition(.numericText())
                Text("days to prepare").font(.system(size: 10)).foregroundStyle(TaavodPalette.ink.opacity(0.6))
            }
            HStack {
                Label(targetDate?.formatted(date: .abbreviated, time: .omitted) ?? "Set a target in your profile", systemImage: "calendar")
                Spacer()
            }.font(.system(size: 9)).foregroundStyle(TaavodPalette.ink.opacity(0.7))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            metric("Practice checks", value: "\(attempts.count)", note: "\(passes.count) verified passes", symbol: "checkmark.seal", fill: TaavodPalette.surface)
            metric("Weekly plan", value: "\(completedTasks)/\(tasks.count)", note: "tasks completed", symbol: "checklist", fill: TaavodPalette.mint)
            metric("Roles tracked", value: "\(jobs.count)", note: "in your career workspace", symbol: "briefcase", fill: TaavodPalette.surface)
            metric("Portfolio", value: "\(app.store.list("projects").count)", note: "projects to build on", symbol: "square.stack.3d.up", fill: TaavodPalette.peach)
        }.frame(height: 82)
    }

    private func metric(_ title: String, value: String, note: String, symbol: String, fill: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(TaavodPalette.muted).frame(width: 28, height: 28)
                .background(TaavodPalette.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 10)).foregroundStyle(TaavodPalette.muted).lineLimit(1)
                Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(-0.6).contentTransition(.numericText())
                Text(note).font(.system(size: 9)).foregroundStyle(TaavodPalette.muted).lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 13).padding(.vertical, 9).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.65))
    }

    private var practiceEmptyCard: some View {
        TaavodCard(padding: 18, spacing: 9) {
            HStack {
                TaavodCardTitle(title: "Practice rhythm", subtitle: "No checks saved yet", symbol: "chart.bar.xaxis")
                Spacer()
            }
            Text("Your attempts and verified passes will build this chart.")
                .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { app.route = .practice } label: {
                HStack(spacing: 8) { Text("Start practice"); Image(systemName: "arrow.right") }
            }.buttonStyle(TaavodPrimaryButton())
        }
    }

    private var activityCard: some View {
        TaavodCard(padding: 20, spacing: 12) {
            HStack(alignment: .center) {
                TaavodCardTitle(title: "Practice rhythm", subtitle: "Submitted checks and verified passes", symbol: "chart.bar.xaxis")
                Spacer(minLength: 10)
                HStack(spacing: 2) {
                    ForEach([7, 30, 90], id: \.self) { days in
                        Button { withAnimation(.easeInOut(duration: 0.18)) { activityPeriod = days; selectedDay = nil } } label: {
                            Text("\(days) days").font(.system(size: 10, weight: activityPeriod == days ? .semibold : .medium))
                                .foregroundStyle(activityPeriod == days ? TaavodPalette.ink : TaavodPalette.muted)
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background { if activityPeriod == days { RoundedRectangle(cornerRadius: 7).fill(TaavodPalette.line.opacity(0.75)) } }
                        }.buttonStyle(.plain).help("Show the last \(days) days")
                    }
                }.padding(3).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 10))
            }
            if periodAttempts == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 20)).foregroundStyle(TaavodPalette.muted.opacity(0.65))
                    Text(attempts.isEmpty ? "Your first practice check will appear here." : "No practice checks in this period.").font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(periodAttempts)").font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.9).contentTransition(.numericText())
                    Text("checks in \(activityPeriod) days").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
                    Spacer()
                    Text("\(periodPasses) verified passes").font(.system(size: 10, weight: .medium)).foregroundStyle(TaavodPalette.accent)
                }
                Chart {
                    ForEach(activity) { day in
                        BarMark(x: .value("Date", day.date, unit: activityPeriod == 90 ? .weekOfYear : .day), y: .value("Submitted checks", day.attempts), width: .ratio(activityPeriod == 90 ? 0.55 : 0.48))
                            .foregroundStyle(selectedActivity?.id == day.id ? TaavodPalette.accent.gradient : TaavodPalette.line.gradient)
                            .cornerRadius(4)
                            .accessibilityLabel(day.date.formatted(.dateTime.month(.abbreviated).day()))
                            .accessibilityValue("\(day.attempts) checks, \(day.passes) verified passes")
                        if day.passes > 0 {
                            BarMark(x: .value("Date", day.date, unit: activityPeriod == 90 ? .weekOfYear : .day), y: .value("Verified passes", day.passes), width: .ratio(activityPeriod == 90 ? 0.24 : 0.2))
                                .foregroundStyle(TaavodPalette.accent.gradient.opacity(0.85)).cornerRadius(3)
                        }
                        if selectedActivity?.id == day.id {
                            RuleMark(x: .value("Selected date", day.date, unit: activityPeriod == 90 ? .weekOfYear : .day))
                                .foregroundStyle(TaavodPalette.muted.opacity(0.35))
                                .annotation(position: .top, spacing: 5) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(day.date.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 9, weight: .semibold))
                                        Text("\(day.attempts) checks · \(day.passes) passes").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted)
                                    }.padding(.horizontal, 9).padding(.vertical, 6).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(TaavodPalette.line, lineWidth: 0.7))
                                }
                        }
                    }
                }
                .chartYScale(domain: 0...max(3, (activity.map(\.attempts).max() ?? 0) + 1))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: activityPeriod == 7 ? 7 : activityPeriod == 30 ? 6 : 7)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(activityPeriod == 7 ? date.formatted(.dateTime.weekday(.abbreviated)) : date.formatted(.dateTime.month(.abbreviated).day()))
                            }
                        }.foregroundStyle(TaavodPalette.muted)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(TaavodPalette.line)
                    AxisValueLabel().foregroundStyle(TaavodPalette.muted)
                } }
                .chartXSelection(value: $selectedDay)
                .chartPlotStyle { plot in plot.padding(.horizontal, 6) }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let plot = proxy.plotFrame else { return }
                                    let frame = geometry[plot]
                                    let x = location.x - frame.origin.x
                                    selectedDay = proxy.value(atX: x, as: Date.self)
                                case .ended: selectedDay = nil
                                }
                            }
                    }
                }
                .frame(height: 206)
                .mask(alignment: .leading) { Rectangle().scaleEffect(x: chartRevealed ? 1 : 0.02, anchor: .leading) }
                HStack(spacing: 16) {
                    chartKey("Submitted checks", color: TaavodPalette.line)
                    chartKey("Verified passes", color: TaavodPalette.accent)
                    Spacer()
                    Text(activityPeriod == 90 ? "weekly totals" : "daily totals").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted)
                }
            }
        }
    }

    private var jobPipelineCard: some View {
        TaavodCard(padding: 20, spacing: 12) {
            HStack {
                TaavodCardTitle(title: "Role pipeline", subtitle: "Saved roles by current stage", symbol: "arrow.trianglehead.branch")
                Spacer()
                Text("\(jobs.count) tracked roles").font(.system(size: 10, weight: .medium)).foregroundStyle(TaavodPalette.muted)
            }
            if jobs.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "briefcase").font(.system(size: 19)).foregroundStyle(TaavodPalette.muted.opacity(0.7))
                    Text("Saved roles will appear here as your search takes shape.").font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(jobStages) { stage in
                        BarMark(x: .value("Saved roles", stage.count), y: .value("Stage", stage.name), height: .ratio(0.5))
                            .foregroundStyle((selectedJobStage ?? mostCommonJobStage) == stage.name ? TaavodPalette.accent.gradient : TaavodPalette.line.gradient)
                            .cornerRadius(4)
                            .accessibilityLabel(stage.name)
                            .accessibilityValue("\(stage.count) saved roles")
                            .annotation(position: .trailing, alignment: .center, spacing: 6) {
                                Text("\(stage.count)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(TaavodPalette.muted)
                            }
                        if (selectedJobStage ?? mostCommonJobStage) == stage.name {
                            RuleMark(x: .value("Selected stage", stage.count))
                                .foregroundStyle(TaavodPalette.accent.opacity(0.24))
                                .annotation(position: .top, alignment: .trailing, spacing: 3) {
                                    Text(stage.detail).font(.system(size: 9)).foregroundStyle(TaavodPalette.muted)
                                        .padding(.horizontal, 7).padding(.vertical, 4).background(TaavodPalette.surface, in: Capsule())
                                }
                        }
                    }
                }
                .chartXScale(domain: 0...max(1, jobStages.map(\.count).max() ?? 1))
                .chartYScale(domain: jobStages.map(\.name).reversed())
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(TaavodPalette.line)
                    AxisValueLabel().foregroundStyle(TaavodPalette.muted)
                } }
                .chartYAxis { AxisMarks(position: .leading) { value in
                    AxisValueLabel().foregroundStyle(TaavodPalette.ink)
                } }
                .chartYSelection(value: $selectedJobStage)
                .chartPlotStyle { plot in plot.padding(.trailing, 24) }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let plot = proxy.plotFrame else { return }
                                    let frame = geometry[plot]
                                    selectedJobStage = proxy.value(atY: location.y - frame.origin.y, as: String.self)
                                case .ended: selectedJobStage = nil
                                }
                            }
                    }
                }
                .frame(height: max(attempts.isEmpty ? 180 : 110, CGFloat(jobStages.count) * (attempts.isEmpty ? 36 : 21)))
                .accessibilityLabel("Saved roles grouped by their current job-search stage")
                .id(colorScheme)
            }
        }
    }

    private var weeklyPlan: some View {
        TaavodCard(padding: 20, spacing: 12) {
            HStack {
                TaavodCardTitle(title: "This week", subtitle: "Small steps, clear direction", symbol: "calendar")
                Spacer()
                Button { addingTask = true } label: { Image(systemName: "plus").font(.system(size: 13)).frame(width: 24, height: 24) }.buttonStyle(.plain).help("Add a weekly task")
            }
            VStack(spacing: 0) {
                if tasks.isEmpty {
                    Text("Make room for one useful step.").font(.system(size: 13, weight: .medium)).padding(.vertical, 24)
                    Button("Suggest my weekly plan") { LearningProgress.suggestPlan(app: app) }.buttonStyle(TaavodPrimaryButton())
                } else {
                    ForEach(tasks.prefix(4)) { task in
                        HStack(spacing: 10) {
                            Button { toggleTask(task) } label: {
                                Image(systemName: task.payload.flag("done") ? "checkmark.circle.fill" : "circle").font(.system(size: 17)).foregroundStyle(task.payload.flag("done") ? TaavodPalette.accent : TaavodPalette.muted.opacity(0.65))
                            }.buttonStyle(.plain).help(task.payload.flag("done") ? "Mark unfinished" : "Complete task")
                            Button { openTask(task) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.payload.text("title")).font(.system(size: 11, weight: .medium)).lineLimit(1).strikethrough(task.payload.flag("done"))
                                    Text("\(Int(task.payload.number("minutes"))) min · \(task.payload.text("type").capitalized)").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 6)
                        if task.id != tasks.prefix(4).last?.id { Divider().overlay(TaavodPalette.line) }
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text("\(completedTasks) of \(tasks.count) complete").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
                Spacer()
                Button("Refresh plan") { LearningProgress.suggestPlan(app: app) }.buttonStyle(.plain).font(.system(size: 10, weight: .semibold))
            }
        }
    }

    private var learningCard: some View {
        TaavodCard {
            HStack { TaavodCardTitle(title: "Your learning path", subtitle: "Continue where you left off", symbol: "book.closed"); Spacer(); Button { app.route = .learn } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain) }
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().stroke(TaavodPalette.line, lineWidth: 7)
                    Circle().trim(from: 0, to: progress).stroke(TaavodPalette.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%").font(.system(size: 22, weight: .semibold, design: .rounded))
                }.frame(width: 86, height: 86).accessibilityLabel("\(Int(progress * 100)) percent of lessons complete")
                VStack(alignment: .leading, spacing: 7) {
                    Text(track?.title ?? "Choose a learning path").font(.system(size: 18, weight: .semibold)).tracking(-0.4).lineLimit(1)
                    Text(track?.lessons.first(where: { $0.id == app.study.lessonID })?.title ?? track?.lessons.first?.title ?? "Explore the lesson library")
                        .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted).lineLimit(2)
                    Button { app.route = .learn } label: { HStack(spacing: 10) { Text("Continue lesson"); Image(systemName: "arrow.right") }.font(.system(size: 11, weight: .semibold)) }.buttonStyle(.plain).padding(.top, 4)
                }
                Spacer(minLength: 0)
            }.padding(.top, 6)
        }
    }

    private var attentionCard: some View {
        TaavodCard(fill: TaavodPalette.butter) {
            HStack { Image(systemName: "sparkle").font(.system(size: 20, weight: .light)); Spacer(); Text("YOUR NEXT STEP").font(.system(size: 8, weight: .semibold)).tracking(1.2) }
            if let review = reviews.first {
                Text("Keep it fresh.").font(.system(size: 22, weight: .semibold)).tracking(-0.6)
                Text("\(review.title) is ready for a recall check.").font(.system(size: 11)).foregroundStyle(TaavodPalette.ink.opacity(0.65)).lineLimit(2)
                Spacer(minLength: 0)
                Button { app.openExercise(review) } label: { Label("Review exercise", systemImage: "arrow.right") }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
            } else {
                Text("Turn learning\ninto proof.").font(.system(size: 22, weight: .semibold)).tracking(-0.6)
                Text("Put one skill into a project you can talk about.").font(.system(size: 11)).foregroundStyle(TaavodPalette.ink.opacity(0.65)).lineLimit(2)
                Spacer(minLength: 0)
                Button { app.route = .portfolio } label: { HStack { Text("Open your portfolio"); Image(systemName: "arrow.right") }.font(.system(size: 11, weight: .semibold)) }.buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("A little progress adds up.").font(.system(size: 11, weight: .medium))
            Spacer()
            Text("\(completedMinutes) planned minutes completed this week").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
        }.padding(.horizontal, 4).padding(.top, 3)
    }

    private func chartKey(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: 6, height: 6); Text(label).font(.system(size: 9)).foregroundStyle(TaavodPalette.muted) }
    }
    private var firstName: String { app.store.profile.text("name").split(separator: " ").first.map(String.init) ?? "you" }
    private var targetDate: Date? { try? Date(app.store.profile.text("targetDate"), strategy: .iso8601.year().month().day()) }
    private var targetDays: Int? { targetDate.map { max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: $0).day ?? 0) } }
    private var progress: Double {
        guard let track, !track.lessons.isEmpty else { return 0 }
        return Double(track.lessons.filter { app.store.record("lessons", id: $0.id)?.payload.flag("completed") == true }.count) / Double(track.lessons.count)
    }
    private var jobStages: [JobStage] {
        let order = ["discovered", "saved", "preparing", "applied", "interviewing", "offer", "rejected", "withdrawn", "archived"]
        let grouped = Dictionary(grouping: jobs) { job in
            let status = job.payload.text("status").lowercased()
            return status.isEmpty ? "saved" : status
        }
        let ordered = grouped.keys.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs) ?? order.count
            let right = order.firstIndex(of: rhs) ?? order.count
            return left == right ? lhs < rhs : left < right
        }
        let visible = Array(ordered.prefix(5))
        var stages = visible.map { status in
            JobStage(name: status.capitalized, count: grouped[status, default: []].count, detail: "\(grouped[status, default: []].count) roles at \(status.capitalized)")
        }
        let remaining = ordered.dropFirst(visible.count)
        if !remaining.isEmpty {
            let count = remaining.reduce(0) { $0 + grouped[$1, default: []].count }
            let summary = remaining.map { "\($0.capitalized): \(grouped[$0, default: []].count)" }.joined(separator: " · ")
            stages.append(JobStage(name: "Other stages", count: count, detail: summary))
        }
        return stages
    }
    private var mostCommonJobStage: String? { jobStages.max { $0.count < $1.count }?.name }
    private var periodAttempts: Int { activity.reduce(0) { $0 + $1.attempts } }
    private var periodPasses: Int { activity.reduce(0) { $0 + $1.passes } }
    private var activity: [ActivityDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(activityPeriod - 1), to: today) ?? today
        let records = attempts.compactMap { record -> (Date, WorkspaceRecord)? in
            guard let date = LearningProgress.date(record.payload.text("createdAt")), date >= start, date < (calendar.date(byAdding: .day, value: 1, to: today) ?? today) else { return nil }
            return (date, record)
        }
        let grouped = Dictionary(grouping: records) { item -> Date in
            let day = calendar.startOfDay(for: item.0)
            if activityPeriod == 90 { return calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day }
            return day
        }
        let step = activityPeriod == 90 ? 7 : 1
        return Swift.stride(from: 0, to: activityPeriod, by: step).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = activityPeriod == 90 ? (calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date) : date
            let bucket = grouped[key] ?? []
            return ActivityDay(date: key, attempts: bucket.count, passes: bucket.filter { $0.1.payload.flag("passed") && !$0.1.payload.flag("selfReported") }.count)
        }
    }
    private var selectedActivity: ActivityDay? {
        guard let selectedDay else { return activity.last(where: { $0.attempts > 0 }) }
        return activity.first { Calendar.current.isDate($0.date, equalTo: selectedDay, toGranularity: activityPeriod == 90 ? .weekOfYear : .day) }
    }
    private func toggleTask(_ task: WorkspaceRecord) {
        let done = !task.payload.flag("done")
        app.store.update("tasks", id: task.id, patch: ["done": .bool(done), "completedAt": .string(done ? Date.now.ISO8601Format() : "")])
    }
    private func openTask(_ task: WorkspaceRecord) {
        if let exercise = app.tracks.flatMap(\.exercises).first(where: { $0.id == task.payload.text("exerciseId") }) { app.openExercise(exercise) }
        else { app.route = task.payload.text("type") == "project" ? .portfolio : task.payload.text("type") == "interview" ? .interviews : .practice }
    }
    private func addTask() {
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { app.store.update("tasks", id: UUID().uuidString, patch: ["title": .string(title), "minutes": .number(30), "done": .bool(false), "type": .string("career"), "weekOf": .string(LearningProgress.week()), "createdAt": .string(Date.now.ISO8601Format())]) }
        taskTitle = ""
    }
}

private struct JobStage: Identifiable {
    let name: String
    let count: Int
    let detail: String
    var id: String { name }
}

private struct ActivityDay: Identifiable {
    let date: Date
    let attempts: Int
    let passes: Int
    var id: Date { date }
}

private struct DashboardArrival: ViewModifier {
    let revealed: Bool
    let order: Int
    let reduceMotion: Bool
    func body(content: Content) -> some View {
        content.opacity(revealed ? 1 : 0).offset(y: revealed || reduceMotion ? 0 : 8)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.28).delay(Double(order) * 0.05), value: revealed)
    }
}
