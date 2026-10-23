import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Bindable var app: AppModel
    let onComplete: () -> Void
    @State private var name = ""
    @State private var targetRole = "BI Analyst"
    @State private var weeklyGoal = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sun.max.fill").font(.system(size: 30)).foregroundStyle(.orange)
            Text("A calmer path to your next role").font(.largeTitle.bold())
            Text("Your learning notes, practice, projects and job search stay on this Mac.").foregroundStyle(.secondary)
            Form {
                TextField("What should we call you?", text: $name)
                TextField("Role you’re aiming for", text: $targetRole)
                Stepper("Weekly study goal: \(Int(weeklyGoal)) hours", value: $weeklyGoal, in: 1...20)
            }.formStyle(.grouped)
            Spacer()
            Button("Set up my workspace") {
                app.store.update("profile", id: app.store.profileID, patch: [
                    "name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)),
                    "headline": .string(""), "email": .string(""), "location": .string(""),
                    "targetRoles": .array([.string(targetRole)]), "excludedRoles": .array([]),
                    "targetDate": .string("2027-02-15"), "weeklyHours": .number(weeklyGoal), "preferredIndustry": .string(""),
                    "experience": .string(""), "bio": .string(""), "linkedin": .string(""), "github": .string(""),
                    "portfolio": .string(""), "toolAccess": .array([]), "skillConfidence": .object([:]),
                    "onboardingComplete": .bool(true), "watchlist": .array([]), "notes": .string(""), "sources": .array([]),
                    "createdAt": .string(Date.now.ISO8601Format())
                ])
                if !app.store.profile.isEmpty { onComplete() }
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("You can export or remove your local data in Settings.").font(.caption).foregroundStyle(.tertiary)
        }.padding(28)
    }
}

struct JobsView: View {
    @Bindable var app: AppModel
    @State private var selectedID: String?
    @State private var discoveryOpen = false
    @State private var editor: JobEditor?
    private let stages = ["Discovered", "Saved", "Preparing", "Applied", "Interviewing", "Offer", "Rejected", "Withdrawn", "Archived"]
    private var jobs: [WorkspaceRecord] { app.store.list("jobs").sorted { $0.payload.text("capturedAt") > $1.payload.text("capturedAt") } }
    private var selectedJob: WorkspaceRecord? { jobs.first { $0.id == selectedID } }
    private var activeCount: Int { jobs.filter { !["rejected", "withdrawn", "archived"].contains($0.payload.text("status")) }.count }
    private var followUps: Int { jobs.filter { !$0.payload.text("followUpDate").isEmpty }.count }

    var body: some View {
        Group {
            if let job = selectedJob {
                VStack(alignment: .leading, spacing: 0) {
                    Button { selectedID = nil; app.selectedRecordID = nil } label: { Label("All roles", systemImage: "chevron.left") }
                        .buttonStyle(.plain).padding(.horizontal, 26).padding(.top, 18)
                    JobDetail(job: job, stages: stages, onChangeStage: { stage in
                        app.store.update("jobs", id: job.id, patch: ["status": .string(stage.lowercased()), "updatedAt": .string(Date.now.ISO8601Format())])
                    }, onEdit: { editor = JobEditor(record: job) }, onDelete: {
                        app.store.remove("jobs", id: job.id); selectedID = nil; app.selectedRecordID = nil
                    })
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Career workspace").font(.title2.weight(.semibold))
                            Text("A clear view of every opportunity").font(.callout).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer(minLength: 4)
                        Menu {
                            Button("Add a role", systemImage: "plus") { editor = JobEditor() }
                            Button("Find or import", systemImage: "magnifyingglass") { discoveryOpen = true }
                        } label: {
                            Label("Add or find a role", systemImage: "plus").labelStyle(.iconOnly)
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                                .frame(width: 36, height: 36).background(TaavodPalette.accent.opacity(0.18), in: Circle())
                        }.menuStyle(.borderlessButton).help("Add or import a role")
                    }
                    HStack(spacing: 8) {
                        JobSummaryChip(value: "\(jobs.count)", label: "tracked", fill: TaavodPalette.surface)
                        JobSummaryChip(value: "\(activeCount)", label: "active", fill: TaavodPalette.surface)
                        JobSummaryChip(value: "\(followUps)", label: "follow-ups", fill: TaavodPalette.surface)
                    }
                    if jobs.isEmpty {
                        ContentUnavailableView {
                            Label("Track your next opportunity", systemImage: "briefcase")
                        } description: {
                            Text("Add a role or import a public listing to keep notes, stages and follow-ups together.")
                        } actions: {
                            Button("Add a role") { editor = JobEditor() }.buttonStyle(TaavodPrimaryButton())
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(selection: $selectedID) {
                            ForEach(stages, id: \.self) { stage in
                                let rows = jobs.filter { $0.payload.text("status") == stage.lowercased() }
                                if !rows.isEmpty {
                                    Section {
                                        ForEach(rows) { job in JobListRow(job: job).tag(job.id) }
                                    } header: {
                                        HStack { Text(stage); Spacer(); Text("\(rows.count)").foregroundStyle(TaavodPalette.muted) }
                                            .font(.caption.weight(.medium))
                                    }
                                }
                            }
                        }.listStyle(.inset).scrollContentBackground(.hidden)
                    }
                }.padding(24).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TaavodPalette.canvas)
        .sheet(item: $editor) { item in JobEditorView(app: app, editor: item) { id in selectedID = id }.frame(width: 560, height: 650) }
        .sheet(isPresented: $discoveryOpen) { JobDiscoverySheet(app: app) { id in selectedID = id; app.selectedRecordID = id }.frame(width: 850, height: 650) }
        .onChange(of: app.route) { _, route in if route == .jobs, let id = app.selectedRecordID { selectedID = id } }
        .onChange(of: app.selectedRecordID) { _, id in if app.route == .jobs, let id { selectedID = id } }
        .onChange(of: selectedID) { _, id in if let id { app.selectedRecordID = id } }
        .onAppear { if app.route == .jobs { selectedID = app.selectedRecordID } }
    }
}

private struct JobSummaryChip: View {
    let value: String
    let label: String
    let fill: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(TaavodPalette.ink)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(TaavodPalette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 11).padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct JobListRow: View {
    let job: WorkspaceRecord
    private var status: String { job.payload.text("status").isEmpty ? "saved" : job.payload.text("status") }
    private var stageFill: Color {
        switch status {
        case "interviewing", "offer": TaavodPalette.mint
        case "applied", "preparing": TaavodPalette.lilac
        case "rejected", "withdrawn", "archived": TaavodPalette.canvas
        default: TaavodPalette.peach
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(job.payload.text("title").isEmpty ? job.title : job.payload.text("title"))
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(TaavodPalette.ink).lineLimit(1)
            Text(job.payload.text("company").isEmpty ? "Company not provided" : job.payload.text("company")).font(.system(size: 12)).foregroundStyle(TaavodPalette.muted).lineLimit(1)
            HStack(spacing: 5) {
                Text(status.capitalized).font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 4).background(stageFill, in: Capsule())
                Spacer()
                if !job.payload.text("followUpDate").isEmpty {
                    Image(systemName: "calendar").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
                }
            }
        }.padding(.vertical, 4).tag(job.id)
    }
}

struct JobEditor: Identifiable {
    let id = UUID()
    var record: WorkspaceRecord?
    init(record: WorkspaceRecord? = nil) { self.record = record }
}

private struct JobEditorView: View {
    @Bindable var app: AppModel
    let editor: JobEditor
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var company = ""
    @State private var title = ""
    @State private var url = ""
    @State private var location = ""
    @State private var description = ""
    @State private var stage = "Saved"
    @State private var notes = ""
    @State private var followUp = Date.now
    @State private var hasFollowUp = false
    @State private var duplicateWarning = false
    private let stages = ["Discovered", "Saved", "Preparing", "Applied", "Interviewing", "Offer", "Rejected", "Withdrawn", "Archived"]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(editor.record == nil ? "Add a role" : "Edit role").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(20)
            Form {
            TextField("Company", text: $company)
                TextField("Role title", text: $title)
                TextField("Job link", text: $url)
                TextField("Location (optional)", text: $location)
                TextField("Job description (optional)", text: $description, axis: .vertical).lineLimit(4...9)
                Picker("Stage", selection: $stage) { ForEach(stages, id: \.self) { Text($0) } }
                Toggle("Set follow-up", isOn: $hasFollowUp)
                if hasFollowUp { DatePicker("Follow-up date", selection: $followUp, displayedComponents: .date) }
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(5...10)
            }.formStyle(.grouped)
            HStack { Spacer(); Button("Save role") { save() }.buttonStyle(.borderedProminent).disabled(company.trimmingCharacters(in: .whitespaces).isEmpty || title.trimmingCharacters(in: .whitespaces).isEmpty) }.padding(20)
        }
        .onAppear {
            guard let p = editor.record?.payload else { return }
            company = p.text("company"); title = p.text("title"); url = p.text("url"); location = p.text("location"); description = p.text("description"); stage = p.text("status").isEmpty ? "saved" : p.text("status").capitalized; notes = p.text("notes")
            if let d = p.text("followUpDate").dayDate { followUp = d; hasFollowUp = true }
        }
        .onChange(of: "\(company)\n\(title)\n\(description)\n\(notes)", initial: true) { _, _ in
            app.coachEditorContext = "Job editor draft:\nCompany: \(company)\nTitle: \(title)\nDescription: \(description)\nNotes: \(notes)"
        }
        .onDisappear { app.coachEditorContext = "" }
        .alert("This role may already be saved", isPresented: $duplicateWarning) {
            Button("Save anyway", role: .destructive) { persist() }
            Button("Review entry", role: .cancel) { }
        } message: { Text("A role with the same company and title is already in your list.") }
    }

    private func save() {
        let company = self.company.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if app.store.list("jobs").contains(where: { $0.id != editor.record?.id && $0.payload.text("company").caseInsensitiveCompare(company) == .orderedSame && $0.payload.text("title").caseInsensitiveCompare(title) == .orderedSame }) {
            duplicateWarning = true
        } else { persist() }
    }

    private func persist() {
        let id = editor.record?.id ?? UUID().uuidString
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var patch: [String: JSONValue] = [
            "company": .string(company.trimmingCharacters(in: .whitespacesAndNewlines)),
            "title": .string(title.trimmingCharacters(in: .whitespacesAndNewlines)), "url": .string(trimmedURL),
            "location": .string(location.trimmingCharacters(in: .whitespacesAndNewlines)),
            "description": .string(description), "canonicalUrl": .string(trimmedURL),
            "status": .string(stage.lowercased()), "notes": .string(notes), "updatedAt": .string(Date.now.ISO8601Format())
        ]
        if editor.record == nil {
            patch.merge([
                "source": .string("Manual"),
                "duplicateUrls": .array([]), "capturedAt": .string(Date.now.ISO8601Format()), "historical": .bool(false),
                "skills": .array([]), "fitScore": .number(0), "fitReasons": .array([]), "gaps": .array([])
            ]) { _, new in new }
        }
        patch["followUpDate"] = hasFollowUp ? .string(followUp.dayString) : .string("")
        app.store.update("jobs", id: id, patch: patch)
        onSave(id); dismiss()
    }
}

private struct JobDetail: View {
    let job: WorkspaceRecord
    let stages: [String]
    let onChangeStage: @MainActor @Sendable (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var body: some View {
        let p = job.payload
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BentoCard(padding: 24) {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "briefcase.fill").font(.system(size: 16, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                            .frame(width: 42, height: 42).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(p.text("company").isEmpty ? "Company" : p.text("company")).font(.system(size: 23, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                            Text(p.text("title")).font(.system(size: 14)).foregroundStyle(TaavodPalette.ink.opacity(0.72))
                            HStack(spacing: 8) {
                                Picker("Stage", selection: Binding(get: { p.text("status").isEmpty ? "Saved" : p.text("status").capitalized }, set: onChangeStage)) {
                                    ForEach(stages, id: \.self) { Text($0) }
                                }.labelsHidden().fixedSize()
                                if !p.text("followUpDate").isEmpty {
                                    Label("Follow up · \(p.text("followUpDate").formattedDate)", systemImage: "calendar")
                                        .font(.system(size: 11, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(TaavodPalette.surface.opacity(0.82), in: Capsule())
                                }
                            }.padding(.top, 7)
                        }
                        Spacer(minLength: 6)
                        Menu {
                            Button("Edit role", systemImage: "pencil", action: onEdit)
                            Button("Delete role", systemImage: "trash", role: .destructive, action: onDelete)
                        } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .bold)).foregroundStyle(TaavodPalette.ink).frame(width: 34, height: 34).background(TaavodPalette.surface, in: Circle()) }
                            .menuStyle(.borderlessButton).help("More actions")
                    }
                }
                HStack(spacing: 12) {
                    if !p.text("location").isEmpty { JobFact(symbol: "mappin.and.ellipse", title: "Location", value: p.text("location"), fill: TaavodPalette.mint) }
                    if !p.text("source").isEmpty { JobFact(symbol: "sparkle.magnifyingglass", title: "Added from", value: p.text("source"), fill: TaavodPalette.lilac) }
                    if !p.text("capturedAt").isEmpty { JobFact(symbol: "clock", title: "Saved", value: p.text("capturedAt").formattedDate, fill: TaavodPalette.butter) }
                }
                if let link = URL(string: p.text("url")), !p.text("url").isEmpty {
                    BentoCard(padding: 17) {
                        HStack {
                            Image(systemName: "link").foregroundStyle(TaavodPalette.accent)
                            VStack(alignment: .leading, spacing: 3) { Text("Original listing").font(.system(size: 12, weight: .semibold)); Text(p.text("url")).font(.caption).foregroundStyle(TaavodPalette.muted).lineLimit(1) }
                            Spacer()
                            Link(destination: link) { Label("Open", systemImage: "arrow.up.right").font(.system(size: 12, weight: .semibold)) }.buttonStyle(TaavodPrimaryButton())
                        }
                    }
                }
                BentoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your notes").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                        Text(p.text("notes").isEmpty ? "Capture what stood out, who you spoke with, or what you want to ask next." : p.text("notes"))
                            .font(.system(size: 13)).foregroundStyle(p.text("notes").isEmpty ? TaavodPalette.muted : TaavodPalette.ink)
                            .textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
                        if p.text("notes").isEmpty { Button("Add notes", action: onEdit).buttonStyle(.bordered).controlSize(.small) }
                    }
                }
                if !p.text("description").isEmpty {
                    BentoCard {
                        Text("Role description").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                        Text(p.text("description")).font(.system(size: 13)).foregroundStyle(TaavodPalette.ink.opacity(0.88)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text("Updated \(p.text("updatedAt").formattedDate)").font(.caption).foregroundStyle(TaavodPalette.muted).padding(.horizontal, 4)
            }.padding(26).frame(maxWidth: 820, alignment: .leading).frame(maxWidth: .infinity)
        }.background(TaavodPalette.canvas)
    }
}

private struct JobFact: View {
    let symbol: String
    let title: String
    let value: String
    let fill: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                .frame(width: 34, height: 34).background(fill, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(TaavodPalette.muted); Text(value).font(.system(size: 12, weight: .medium)).lineLimit(1) }
            Spacer(minLength: 0)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct PortfolioView: View {
    @Bindable var app: AppModel
    @State private var selectedID: String?
    @State private var adding = false
    @State private var projectTitle = ""
    @State private var evidenceImporter = false
    private var projects: [WorkspaceRecord] { app.store.list("projects").sorted { $0.payload.text("updatedAt") > $1.payload.text("updatedAt") } }
    private var selected: WorkspaceRecord? { projects.first { $0.id == selectedID } }
    private var readyCount: Int { projects.filter { $0.payload.text("status") == "published" }.count }

    var body: some View {
        Group {
            if let project = selected {
                VStack(alignment: .leading, spacing: 0) {
                    Button { selectedID = nil; app.selectedRecordID = nil } label: { Label("All projects", systemImage: "chevron.left") }
                        .buttonStyle(.plain).padding(.horizontal, 26).padding(.top, 18)
                    ProjectDetail(app: app, project: project, evidenceImporter: $evidenceImporter)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Portfolio").font(.title2.weight(.semibold))
                            Text("Projects and proof of your work").font(.callout).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer(minLength: 4)
                        Button { adding = true } label: { Label("Add project", systemImage: "plus") }
                            .buttonStyle(.borderedProminent)
                    }
                    PortfolioProfileCard(profile: app.store.profile)
                    HStack(spacing: 8) {
                        JobSummaryChip(value: "\(projects.count)", label: "projects", fill: TaavodPalette.surface)
                        JobSummaryChip(value: "\(readyCount)", label: "ready to share", fill: TaavodPalette.surface)
                    }
                    if projects.isEmpty {
                        PortfolioLibraryEmpty(app: app)
                    } else {
                        List(selection: $selectedID) {
                            Section("Your projects") {
                                ForEach(projects) { project in PortfolioProjectRow(project: project).tag(project.id) }
                            }
                        }.listStyle(.inset).scrollContentBackground(.hidden)
                    }
                }.padding(24).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TaavodPalette.canvas)
        .alert("New portfolio project", isPresented: $adding) {
            TextField("Project title", text: $projectTitle)
            Button("Cancel", role: .cancel) { projectTitle = "" }
            Button("Add") {
                let name = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        let id = UUID().uuidString
                        let steps = ["Define the question", "Document the method", "Write the result", "Add evidence"].enumerated().map { index, title in JSONValue.object(["id": .string("step-\(index + 1)"), "title": .string(title), "done": .bool(false)]) }
                        app.store.update("projects", id: id, patch: [
                            "name": .string(name), "category": .string("BI"), "status": .string("active"), "summary": .string(""),
                            "description": .string(""), "skills": .array([]), "evidence": .array([]), "evidenceFiles": .array([]),
                            "caveat": .string(""), "nextSteps": .array(steps), "interviewStory": .string(""), "notes": .string(""), "updatedAt": .string(Date.now.ISO8601Format())
                        ])
                        selectedID = id
                    }
                projectTitle = ""
            }
        }
        .onChange(of: app.route) { _, route in if route == .portfolio, let id = app.selectedRecordID { selectedID = id } }
        .onChange(of: app.selectedRecordID) { _, id in if app.route == .portfolio, let id { selectedID = id } }
        .onChange(of: selectedID) { _, id in if let id { app.selectedRecordID = id } }
        .onAppear { if app.route == .portfolio { selectedID = app.selectedRecordID } }
    }
}

private struct PortfolioProfileCard: View {
    let profile: [String: JSONValue]
    private var displayName: String { profile.text("name").isEmpty ? "Your profile" : profile.text("name") }
    private var headline: String {
        if !profile.text("headline").isEmpty { return profile.text("headline") }
        return profile.strings("targetRoles").joined(separator: " · ")
    }
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 30)).foregroundStyle(TaavodPalette.ink)
                .frame(width: 46, height: 46).background(TaavodPalette.butter, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName).font(.system(size: 13, weight: .semibold)).foregroundStyle(TaavodPalette.ink).lineLimit(1)
                Text(headline.isEmpty ? "Add your target role in Settings" : headline).font(.system(size: 11)).foregroundStyle(TaavodPalette.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PortfolioProjectRow: View {
    let project: WorkspaceRecord
    private var status: String { project.payload.text("status") }
    private var title: String { project.payload.text("title").isEmpty ? project.payload.text("name") : project.payload.text("title") }
    private var statusLabel: String {
        switch status {
        case "published": "Ready to share"
        case "beta": "In review"
        case "archived": "Archived"
        default: "In progress"
        }
    }
    private var tint: Color {
        switch status {
        case "published": TaavodPalette.mint
        case "beta": TaavodPalette.lilac
        case "archived": TaavodPalette.canvas
        default: TaavodPalette.peach
        }
    }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line").font(.system(size: 13, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                .frame(width: 34, height: 34).background(tint, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "Untitled project" : title).font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Text(statusLabel).font(.system(size: 10, weight: .medium)).foregroundStyle(TaavodPalette.muted)
                    if !project.payload.strings("evidence").isEmpty || !project.payload.strings("evidenceFiles").isEmpty {
                        Text("·").foregroundStyle(TaavodPalette.muted)
                        Text("\(project.payload.strings("evidence").count + project.payload.strings("evidenceFiles").count) evidence")
                            .font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 4)
    }
}

private struct ProjectDetail: View {
    @Bindable var app: AppModel
    let project: WorkspaceRecord
    @Binding var evidenceImporter: Bool
    @State private var description = ""
    @State private var title = ""
    @State private var status = "In progress"
    @State private var evidence: [String] = []
    private var steps: [ProjectStep] {
        if let rawSteps = project.payload["nextSteps"], case .array(let values) = rawSteps {
            let parsed = values.compactMap { value -> ProjectStep? in
                guard case .object(let fields) = value else { return nil }
                let title = fields.text("title")
                guard !title.isEmpty else { return nil }
                return ProjectStep(id: fields.text("id").isEmpty ? title : fields.text("id"), title: title, done: fields.flag("done"))
            }
            if !parsed.isEmpty { return parsed }
        }
        let completed = Set(project.payload.strings("completed"))
        return project.payload.strings("checklist").map { ProjectStep(id: $0, title: $0, done: completed.contains($0)) }
    }
    private var evidenceNotes: [String] { project.payload.strings("evidence") }
    private var evidenceURLs: [URL] { project.payload.strings("evidenceFiles").map { URL(fileURLWithPath: $0) } }
    private var statusLabel: String {
        switch project.payload.text("status") {
        case "beta": "In review"
        case "published": "Ready to share"
        case "archived": "Archived"
        case "secondary": "Secondary"
        default: "In progress"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BentoCard(padding: 24) {
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 18, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                            .frame(width: 44, height: 44).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 7) {
                            TextField("Project title", text: $title).font(.system(size: 22, weight: .semibold)).textFieldStyle(.plain).foregroundStyle(TaavodPalette.ink)
                            Text(project.payload.text("category").isEmpty ? "Portfolio project" : project.payload.text("category"))
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(TaavodPalette.ink.opacity(0.68))
                            Picker("Status", selection: Binding(get: { statusLabel }, set: { label in
                                let value = label == "Ready to share" ? "published" : label == "In review" ? "beta" : label == "Archived" ? "archived" : label == "Secondary" ? "secondary" : "active"
                                app.store.update("projects", id: project.id, patch: ["status": .string(value), "updatedAt": .string(Date.now.ISO8601Format())])
                            })) {
                                ForEach(["In progress", "In review", "Ready to share", "Secondary", "Archived"], id: \.self) { Text($0) }
                            }.labelsHidden().fixedSize().padding(.top, 5)
                        }
                        Spacer(minLength: 4)
                        Menu {
                            Button("Delete project", systemImage: "trash", role: .destructive) { app.store.remove("projects", id: project.id) }
                        } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .bold)).foregroundStyle(TaavodPalette.ink).frame(width: 34, height: 34).background(TaavodPalette.surface, in: Circle()) }
                            .menuStyle(.borderlessButton).help("More actions")
                    }
                }
                BentoCard {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Project story").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                            Text("Describe the question, approach and result.").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer()
                        Button("Save details") { app.store.update("projects", id: project.id, patch: ["name": .string(title), "title": .string(title), "description": .string(description), "updatedAt": .string(Date.now.ISO8601Format())]) }
                            .buttonStyle(TaavodPrimaryButton())
                    }
                    TextField("What question does this project answer?", text: $description, axis: .vertical)
                        .lineLimit(4...9).textFieldStyle(.plain).padding(13)
                        .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 13))
                }
                BentoCard {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Project checklist").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                            Text("A few details make the work easy to explain.").font(.system(size: 12)).foregroundStyle(TaavodPalette.ink.opacity(0.64))
                        }
                        Spacer()
                        Text("\(steps.filter(\.done).count) of \(steps.count)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(TaavodPalette.ink)
                    }
                    ForEach(steps) { step in
                        Toggle(step.title, isOn: Binding(get: { step.done }, set: { checked in
                            let updated = steps.map { value in JSONValue.object(["id": .string(value.id), "title": .string(value.title), "done": .bool(value.id == step.id ? checked : value.done)]) }
                            app.store.update("projects", id: project.id, patch: ["nextSteps": .array(updated), "updatedAt": .string(Date.now.ISO8601Format())])
                        })).tint(TaavodPalette.accent)
                    }
                }
                BentoCard {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Evidence").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                            Text("Notes and files that support this project.").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer()
                        Button { evidenceImporter = true } label: { Label("Add file", systemImage: "paperclip") }.buttonStyle(.bordered).controlSize(.small)
                    }
                    if evidenceNotes.isEmpty && evidenceURLs.isEmpty {
                        Label("Attach a chart, report or sample file. Files are copied into Taavod’s local support folder.", systemImage: "tray")
                            .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted).frame(maxWidth: .infinity, alignment: .leading).padding(13)
                            .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 13))
                    }
                    ForEach(Array(evidenceNotes.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            Image(systemName: "text.alignleft").foregroundStyle(TaavodPalette.ink).frame(width: 31, height: 31).background(TaavodPalette.mint, in: RoundedRectangle(cornerRadius: 11))
                            Text(item).font(.system(size: 12)).foregroundStyle(TaavodPalette.ink).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(9).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 13))
                    }
                    ForEach(evidenceURLs, id: \.path) { url in
                        HStack(spacing: 10) {
                            Image(systemName: "doc").foregroundStyle(TaavodPalette.ink).frame(width: 31, height: 31).background(TaavodPalette.peach, in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) { Text(url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1); Text("Local file").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted) }
                            Spacer()
                            Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain).help("Show file")
                            Button { removeEvidence(url) } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Remove evidence")
                        }.padding(9).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                WorkspaceFilesSection(app: app)
            }.padding(25).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(TaavodPalette.canvas)
        .fileImporter(isPresented: $evidenceImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in importEvidence(result) }
        .onAppear(perform: loadProject)
        .onChange(of: project.id) { _, _ in loadProject() }
    }

    private func loadProject() {
        title = project.payload.text("title").isEmpty ? project.payload.text("name") : project.payload.text("title")
        description = project.payload.text("description")
    }

    private func importEvidence(_ result: Result<[URL], Error>) {
        do {
            let incoming = try result.get()
            let folder = AppPaths.support.appendingPathComponent("evidence", isDirectory: true).appendingPathComponent(project.id, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var paths = project.payload.strings("evidenceFiles")
            for source in incoming {
                let access = source.startAccessingSecurityScopedResource()
                defer { if access { source.stopAccessingSecurityScopedResource() } }
                var destination = folder.appendingPathComponent(source.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) { destination = folder.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent) }
                try FileManager.default.copyItem(at: source, to: destination)
                paths.append(destination.path)
            }
            app.store.update("projects", id: project.id, patch: ["evidenceFiles": .array(paths.map(JSONValue.string)), "updatedAt": .string(Date.now.ISO8601Format())])
        } catch { app.store.error = "Could not add evidence: \(error.localizedDescription)" }
    }

    private func removeEvidence(_ url: URL) {
        let paths = project.payload.strings("evidenceFiles").filter { $0 != url.path }
        app.store.update("projects", id: project.id, patch: ["evidenceFiles": .array(paths.map(JSONValue.string)), "updatedAt": .string(Date.now.ISO8601Format())])
    }
}

private struct ProjectStep: Identifiable {
    let id: String
    let title: String
    let done: Bool
}

private struct PortfolioLibraryEmpty: View {
    @Bindable var app: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BentoCard(fill: TaavodPalette.peach, padding: 26) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 20, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                        .frame(width: 49, height: 49).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 16))
                    Text("Show what you can do").font(.system(size: 23, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                    Text("Add a project, describe your approach and collect evidence you can share with employers.")
                        .font(.system(size: 13)).foregroundStyle(TaavodPalette.ink.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
                }
                WorkspaceFilesSection(app: app)
            }.padding(25).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(TaavodPalette.canvas)
    }
}

private struct WorkspaceFilesSection: View {
    @Bindable var app: AppModel
    private var files: [WorkspaceRecord] { app.store.list("files").sorted { $0.payload.text("createdAt") > $1.payload.text("createdAt") } }
    var body: some View {
        BentoCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace files").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                    Text("CVs, assignments and project material saved locally.").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                }
                Spacer()
                Text("\(files.count)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(TaavodPalette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(TaavodPalette.butter, in: Capsule())
            }
            if files.isEmpty {
                Text("Imported CVs, assignments and project files appear here.").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
            } else {
                ForEach(files) { file in
                    let path = file.payload.text("path")
                    let url = URL(fileURLWithPath: path)
                    let available = FileManager.default.fileExists(atPath: path)
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: file.payload.text("kind") == "cv" ? "person.text.rectangle" : "doc")
                            .foregroundStyle(TaavodPalette.ink).frame(width: 34, height: 34)
                            .background(file.payload.text("kind") == "cv" ? TaavodPalette.lilac : TaavodPalette.mint, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.payload.text("name").isEmpty ? url.lastPathComponent : file.payload.text("name")).font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.ink).lineLimit(1)
                            Text("\(file.payload.text("kind").capitalized) · \(file.payload.text("createdAt").formattedDate)").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
                            if !file.payload.text("notes").isEmpty { Text(file.payload.text("notes")).font(.system(size: 11)).foregroundStyle(TaavodPalette.muted).lineLimit(2) }
                            if !available { Text("File content is unavailable in the local workspace.").font(.system(size: 10)).foregroundStyle(.orange) }
                        }
                        Spacer()
                        if available {
                            Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain).help("Reveal file")
                            Button("Save a copy…") { saveCopy(from: url, named: file.payload.text("name")) }.buttonStyle(.borderless)
                        }
                    }.padding(10).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func saveCopy(from source: URL, named name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name.isEmpty ? source.lastPathComponent : name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try FileManager.default.copyItem(at: source, to: destination) }
        catch { app.store.error = "Could not save file copy: \(error.localizedDescription)" }
    }
}

struct InterviewsView: View {
    @Bindable var app: AppModel
    @State private var selectedID: String?
    @State private var prompt = "Tell me about a dashboard or analysis you built."
    @State private var answer = ""
    @State private var duration = 3.0
    @State private var deadline: Date?
    @State private var savedMessage = false
    @State private var reflection = ""
    @State private var creating = false
    private var sessions: [WorkspaceRecord] { app.store.list("interviews").sorted { $0.payload.text("createdAt") > $1.payload.text("createdAt") } }
    private var current: WorkspaceRecord? { sessions.first { $0.id == selectedID } }

    var body: some View {
        Group {
            if let current {
                VStack(alignment: .leading, spacing: 0) {
                    Button { selectedID = nil; app.selectedRecordID = nil } label: { Label("All practice", systemImage: "chevron.left") }
                        .buttonStyle(.plain).padding(.horizontal, 26).padding(.top, 18)
                    savedSession(current)
                }
            } else if creating {
                VStack(alignment: .leading, spacing: 0) {
                    Button { creating = false; deadline = nil } label: { Label("All practice", systemImage: "chevron.left") }
                        .buttonStyle(.plain).padding(.horizontal, 26).padding(.top, 18)
                    drillEditor
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interview practice").font(.title2.weight(.semibold))
                            Text("Build confidence one answer at a time").font(.callout).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer()
                        Button { newSession() } label: { Label("Start a drill", systemImage: "plus") }.buttonStyle(.borderedProminent)
                    }
                    HStack(spacing: 8) {
                        JobSummaryChip(value: "\(sessions.count)", label: "saved drills", fill: TaavodPalette.surface)
                        JobSummaryChip(value: "\(sessions.reduce(0) { $0 + (Int($1.payload.text("durationMinutes")) ?? 0) })", label: "minutes practiced", fill: TaavodPalette.surface)
                    }
                    if sessions.isEmpty {
                        ContentUnavailableView {
                            Label("Practice your first answer", systemImage: "quote.bubble")
                        } description: {
                            Text("Choose a question, time a short answer, and save it to review later.")
                        } actions: {
                            Button("Start a drill") { newSession() }.buttonStyle(TaavodPrimaryButton())
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(selection: $selectedID) {
                            Section("Saved sessions") {
                                ForEach(sessions) { session in InterviewSessionRow(session: session).tag(session.id) }
                            }
                        }.listStyle(.inset).scrollContentBackground(.hidden)
                    }
                }.padding(24).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TaavodPalette.canvas)
        .alert("Saved", isPresented: $savedMessage) { Button("OK", role: .cancel) { } } message: { Text("Your interview notes were saved in this Mac’s local workspace.") }
        .onChange(of: selectedID) { _, id in reflection = sessions.first { $0.id == id }?.payload.text("reflection") ?? "" }
        .onChange(of: "\(prompt)\n\(answer)\n\(reflection)", initial: true) { _, _ in
            app.coachEditorContext = "Interview practice draft:\nQuestion: \(prompt)\nAnswer: \(answer)\nReflection: \(reflection)"
        }
        .onDisappear { app.coachEditorContext = "" }
        .onChange(of: app.route) { _, route in if route == .interviews, let id = app.selectedRecordID { selectedID = id } }
        .onChange(of: app.selectedRecordID) { _, id in if app.route == .interviews, let id { selectedID = id } }
        .onChange(of: selectedID) { _, id in if let id { app.selectedRecordID = id } }
        .onAppear { if app.route == .interviews, let id = app.selectedRecordID { selectedID = id } }
    }

    private var drillEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A focused practice round").font(.system(size: 22, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                        Text("Shape a clear answer, then save it with your reflection.").font(.system(size: 13)).foregroundStyle(TaavodPalette.muted)
                    }
                    Spacer()
                    if current != nil { Button("New drill") { newSession() }.buttonStyle(.bordered).controlSize(.small) }
                }
                BentoCard(padding: 21) {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening").foregroundStyle(TaavodPalette.ink)
                        Text("PRACTICE QUESTION").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(0.8).foregroundStyle(TaavodPalette.ink.opacity(0.72))
                    }
                    TextField("Write or choose a question", text: $prompt, axis: .vertical)
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(TaavodPalette.ink).textFieldStyle(.plain).lineLimit(2...4)
                }
                BentoCard(padding: 17) {
                    HStack(spacing: 15) {
                        Image(systemName: "timer").font(.system(size: 17, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                            .frame(width: 42, height: 42).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Timebox").font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                            Picker("Time", selection: $duration) { Text("2 minutes").tag(2.0); Text("3 minutes").tag(3.0); Text("5 minutes").tag(5.0) }
                                .labelsHidden().fixedSize().disabled(deadline != nil)
                        }
                        Spacer()
                        if let deadline {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                let remaining = max(0, Int(deadline.timeIntervalSince(timeline.date)))
                                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(remaining == 0 ? Color.orange : TaavodPalette.ink)
                                    .padding(.horizontal, 13).padding(.vertical, 7).background(TaavodPalette.surface, in: Capsule())
                            }
                            Button("Stop") { self.deadline = nil }.buttonStyle(.bordered).controlSize(.small)
                        } else {
                            Button("Start timer") { deadline = Date.now.addingTimeInterval(duration * 60) }.buttonStyle(TaavodPrimaryButton())
                        }
                    }
                }
                BentoCard {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your answer").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                            Text("Use a real example and focus on your contribution.").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer()
                        Button("Save practice") { saveSession() }.buttonStyle(TaavodPrimaryButton()).disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    TextEditor(text: $answer).font(.system(size: 14)).scrollContentBackground(.hidden)
                        .padding(12).frame(minHeight: 180).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 13))
                    HStack(spacing: 8) {
                        AnswerCue(title: "Context", fill: TaavodPalette.lilac)
                        AnswerCue(title: "Your action", fill: TaavodPalette.mint)
                        AnswerCue(title: "Result", fill: TaavodPalette.peach)
                    }
                }
            }.padding(24).frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func savedSession(_ session: WorkspaceRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved practice").font(.system(size: 22, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                        Text("\(session.payload.text("durationMinutes")) minutes · \(session.payload.text("createdAt").formattedDate)").font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                    }
                    Spacer()
                    Button("New drill") { newSession() }.buttonStyle(.bordered).controlSize(.small)
                }
                BentoCard {
                    Text("PRACTICE QUESTION").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(0.8).foregroundStyle(TaavodPalette.ink.opacity(0.7))
                    Text(session.payload.text("prompt")).font(.system(size: 17, weight: .semibold)).foregroundStyle(TaavodPalette.ink).textSelection(.enabled)
                }
                BentoCard {
                    Text("Your answer").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                    Text(session.payload.text("answer").isEmpty ? "No response was saved for this practice round." : session.payload.text("answer"))
                        .font(.system(size: 14)).foregroundStyle(session.payload.text("answer").isEmpty ? TaavodPalette.muted : TaavodPalette.ink)
                        .textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                }
                BentoCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reflection").font(.system(size: 16, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                        Text("What worked, and what would you make clearer next time?").font(.system(size: 12)).foregroundStyle(TaavodPalette.ink.opacity(0.67))
                    }
                    TextEditor(text: $reflection).font(.system(size: 13)).scrollContentBackground(.hidden)
                        .frame(minHeight: 100).padding(10).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                            Button("Practice this question") { prompt = session.payload.text("prompt"); answer = ""; selectedID = nil; creating = true; deadline = nil }.buttonStyle(.bordered).controlSize(.small)
                        Spacer()
                        Button("Save reflection") { app.store.update("interviews", id: session.id, patch: ["reflection": .string(reflection)]) }.buttonStyle(TaavodPrimaryButton())
                    }
                }
            }.padding(24).frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private func newSession() { selectedID = nil; app.selectedRecordID = nil; creating = true; answer = ""; reflection = ""; prompt = "Tell me about a dashboard or analysis you built."; deadline = nil }
    private func saveSession() {
        let id = UUID().uuidString
        app.store.update("interviews", id: id, patch: ["prompt": .string(prompt), "answer": .string(answer), "reflection": .string(""), "durationMinutes": .string(String(Int(duration))), "createdAt": .string(Date.now.ISO8601Format())])
        selectedID = id; creating = false; reflection = ""; deadline = nil; savedMessage = true
    }
}

private struct InterviewSessionRow: View {
    let session: WorkspaceRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.payload.text("prompt").isEmpty ? "Untitled practice" : session.payload.text("prompt"))
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.ink).lineLimit(2)
            HStack(spacing: 6) {
                Text(session.payload.text("createdAt").formattedDate)
                if !session.payload.text("durationMinutes").isEmpty { Text("·"); Text("\(session.payload.text("durationMinutes")) min") }
            }.font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
        }.padding(.vertical, 4)
    }
}

private struct AnswerCue: View {
    let title: String
    let fill: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle").font(.system(size: 10, weight: .medium))
            Text(title).font(.system(size: 10, weight: .medium))
        }.foregroundStyle(TaavodPalette.ink.opacity(0.78)).padding(.horizontal, 9).padding(.vertical, 6).background(fill, in: Capsule())
    }
}

struct SearchView: View {
    @Bindable var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var searchText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matches: [WorkspaceRecord] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText
        return app.store.records.filter { record in
            record.payload.values.contains { value in
                switch value {
                case .string(let value): value.localizedCaseInsensitiveContains(q)
                case .array(let values): values.contains { $0.string.localizedCaseInsensitiveContains(q) }
                default: false
                }
            }
        }.prefix(40).map { $0 }
    }
    private var lessonMatches: [(track: SkillTrack, lesson: Lesson)] {
        guard !searchText.isEmpty else { return [] }
        return app.tracks.flatMap { track in
            track.lessons.compactMap { lesson in
                let content = [track.title, lesson.title, lesson.takeaway, lesson.source.title, lesson.example] + lesson.paragraphs
                return content.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ? (track, lesson) : nil
            }
        }.prefix(20).map { $0 }
    }
    private var exerciseMatches: [(track: SkillTrack, exercise: Exercise)] {
        guard !searchText.isEmpty else { return [] }
        return app.tracks.flatMap { track in
            track.exercises.compactMap { exercise in
                let content = [track.title, exercise.title, exercise.prompt, exercise.kind, exercise.difficulty] + exercise.hints + exercise.rubric
                return content.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ? (track, exercise) : nil
            }
        }.prefix(20).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search jobs, lessons, exercises and notes", text: $query).textFieldStyle(.plain).font(.title3).keyboardShortcut(.return, modifiers: []) }
                .padding(18)
            Divider()
            if searchText.isEmpty { ContentUnavailableView("Search your workspace", systemImage: "magnifyingglass", description: Text("Find saved records, lessons and exercises.")) }
            else if matches.isEmpty && lessonMatches.isEmpty && exerciseMatches.isEmpty { ContentUnavailableView.search(text: query) }
            else {
                List {
                    if !lessonMatches.isEmpty {
                        Section("Lessons") {
                            ForEach(lessonMatches, id: \.lesson.id) { result in
                                Button {
                                    app.openLesson(result.lesson, in: result.track)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.lesson.title).fontWeight(.medium)
                                        Text("\(result.track.title) · Lesson · \(result.lesson.minutes) min").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !exerciseMatches.isEmpty {
                        Section("Exercises") {
                            ForEach(exerciseMatches, id: \.exercise.id) { result in
                                Button {
                                    if let lessonIndex = result.track.lessons.indices.first(where: { LearnView.exercises(for: result.track, lessonIndex: $0).contains(where: { $0.id == result.exercise.id }) }) {
                                        app.study.trackID = result.track.id
                                        app.study.lessonID = result.track.lessons[lessonIndex].id
                                    } else {
                                        app.study.trackID = result.track.id
                                        app.study.lessonID = ""
                                    }
                                    app.openExercise(result.exercise)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.exercise.title).fontWeight(.medium)
                                        Text("\(result.track.title) · Exercise · \(result.exercise.difficulty) · \(result.exercise.minutes) min").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !matches.isEmpty {
                        Section("Saved workspace") {
                            ForEach(matches) { record in
                                Button {
                                    switch record.kind {
                                    case "jobs": app.route = .jobs
                                    case "projects": app.route = .portfolio
                                    case "interviews": app.route = .interviews
                                    case "attempts", "drafts":
                                        let exerciseID = record.payload.text("exerciseId").isEmpty ? record.id : record.payload.text("exerciseId")
                                        if let exercise = app.tracks.flatMap(\.exercises).first(where: { $0.id == exerciseID }) { app.openExercise(exercise) }
                                        else { app.route = .practice }
                                    case "lessons":
                                        if let track = app.tracks.first(where: { $0.lessons.contains(where: { $0.id == record.id }) }),
                                           let lesson = track.lessons.first(where: { $0.id == record.id }) {
                                            app.openLesson(lesson, in: track)
                                        } else { app.route = .learn }
                                    default: app.route = .today
                                    }
                                    if ["jobs", "projects", "interviews"].contains(record.kind) { app.selectedRecordID = record.id }
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) { Text(record.title.isEmpty ? record.kind.capitalized : record.title).fontWeight(.medium); Text("\(record.kind.capitalized) · \(record.payload.values.compactMap { if case .string(let s) = $0 { s } else { nil } }.first(where: { $0.localizedCaseInsensitiveContains(searchText) }) ?? "Saved locally")").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.listStyle(.plain)
            }
        }
        .onChange(of: query) { _, value in app.search = value }
        .onAppear { query = app.search }
    }
}

struct SettingsView: View {
    @Bindable var app: AppModel
    @AppStorage("appearance") private var appearance = "light"
    @State private var importing = false
    @State private var exportDocument: WorkspaceDocument?
    @State private var exporting = false
    @State private var showCoachSettings = false
    @State private var name = ""
    @State private var targetRoles = ""
    private var savedName: String { app.store.profile.text("name") }
    private var savedRoles: String { app.store.profile.strings("targetRoles").joined(separator: ", ") }
    private var hasProfileChanges: Bool { name != savedName || targetRoles != savedRoles }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings").font(.system(size: 26, weight: .semibold))
                    Text("Personalize your workspace and manage local learning tools and data.")
                        .font(.callout).foregroundStyle(TaavodPalette.muted)
                }

                BentoCard {
                    settingsHeading("Profile", detail: "Used to tailor your workspace and career guidance.", symbol: "person.crop.circle")
                    LabeledContent("Name") { TextField("Your name", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 330) }
                    LabeledContent("Target roles") { TextField("BI Analyst, Data Analyst…", text: $targetRoles).textFieldStyle(.roundedBorder).frame(maxWidth: 330) }
                    HStack {
                        if hasProfileChanges { Button("Discard changes") { loadProfile() }.buttonStyle(.bordered) }
                        Spacer()
                        Button("Save profile") { saveProfile() }.buttonStyle(TaavodPrimaryButton()).disabled(!hasProfileChanges)
                    }
                }

                BentoCard {
                    settingsHeading("Appearance", detail: "Choose how Taavod looks on this Mac.", symbol: "circle.lefthalf.filled")
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }.pickerStyle(.segmented).frame(maxWidth: 360)
                }

                BentoCard {
                    settingsHeading("Career coach", detail: "Connect optional services and control coaching preferences.", symbol: "sparkles")
                    Button("Open coach settings…") { showCoachSettings = true }.buttonStyle(.bordered)
                }

                BentoCard {
                    settingsHeading("Offline practice", detail: "Download local runtimes to practice without an internet connection.", symbol: "shippingbox")
                    ForEach(PackKind.allCases) { kind in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(kind == .sql ? "SQL & PostgreSQL" : "Python, pandas & charts").font(.system(size: 13, weight: .medium))
                                Text(app.packs.isInstalled(kind) ? "Installed · available offline" : app.packs.sizeLabel(kind) + " · downloads when installed")
                                    .font(.caption).foregroundStyle(TaavodPalette.muted)
                            }
                            Spacer()
                            if app.packs.installing == kind {
                                ProgressView(value: app.packs.progress).frame(width: 70)
                                Button("Cancel download") { app.packs.cancel() }
                            } else if app.packs.isInstalled(kind) {
                                Button("Remove download") { do { app.runner.suspend(); try app.packs.remove(kind) } catch { app.store.error = error.localizedDescription } }
                                    .disabled(app.runner.isRunning)
                            } else {
                                Button("Install") { Task { do { try await app.packs.install(kind) } catch is CancellationError {} catch { app.store.error = error.localizedDescription } } }
                                    .buttonStyle(.bordered).disabled(app.packs.installing != nil)
                            }
                        }.padding(.vertical, 7)
                    }
                }

                BentoCard {
                    settingsHeading("Workspace data", detail: "Your records stay on this Mac unless you export them.", symbol: "externaldrive")
                    HStack(spacing: 10) {
                        Button("Export workspace…") { makeExport() }.buttonStyle(.borderedProminent)
                        Button("Import workspace…") { importing = true }.buttonStyle(.bordered)
                        Button("Show data folder") { NSWorkspace.shared.open(AppPaths.support) }.buttonStyle(.bordered)
                    }
                    Text("Exports include saved workspace records. API credentials remain in Keychain and are not included.")
                        .font(.caption).foregroundStyle(TaavodPalette.muted)
                }
            }.padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(TaavodPalette.canvas)
        .foregroundStyle(TaavodPalette.ink)
        .tint(TaavodPalette.accent)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "system" ? nil : .light)
        .onAppear(perform: loadProfile)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in importData(result) }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "taavod-workspace") { result in
            if case .failure(let error) = result { app.store.error = "Could not export workspace: \(error.localizedDescription)" }
        }
        .sheet(isPresented: $showCoachSettings) { CoachSettingsView().frame(width: 580, height: 580) }
    }

    private func settingsHeading(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(width: 34, height: 34)
                .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
            }
            Spacer(minLength: 0)
        }
    }

    private func loadProfile() {
        name = savedName
        targetRoles = savedRoles
    }

    private func saveProfile() {
        let roles = targetRoles.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        app.store.update("profile", id: app.store.profileID, patch: [
            "name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)),
            "targetRoles": .array(roles.map(JSONValue.string))
        ])
        loadProfile()
    }

    private func makeExport() {
        do { exportDocument = WorkspaceDocument(data: try app.store.exportData()); exporting = true }
        catch { app.store.error = "Could not export workspace: \(error.localizedDescription)" }
    }

    private func importData(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            struct LegacyExport: Decodable { var records: [WorkspaceRecord] }
            let records: [WorkspaceRecord]
            if let legacy = try? JSONDecoder().decode(LegacyExport.self, from: data) { records = legacy.records }
            else { records = try JSONDecoder().decode([WorkspaceRecord].self, from: data) }
            let count = try app.store.importRecords(records)
            app.store.error = "Imported \(count) new records. Existing records with the same IDs were kept."
        } catch { app.store.error = "Could not import workspace: \(error.localizedDescription)" }
    }
}

struct WorkspaceDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct BentoCard<Content: View>: View {
    var fill: Color = TaavodPalette.surface
    var padding: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14, content: { content })
            .padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.7))
    }
}
