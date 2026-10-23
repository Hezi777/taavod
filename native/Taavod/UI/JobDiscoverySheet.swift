import SwiftUI

struct JobDiscoverySheet: View {
    let app: AppModel
    let saved: (String) -> Void
    @State private var discovery = JobDiscovery()
    @State private var query = ""
    @State private var captureURL = ""
    @State private var selectedID: String?
    @State private var showConnections = false
    @Environment(\.dismiss) private var dismiss
    private var index: Int? { discovery.leads.firstIndex { $0.id == selectedID } }
    private var searchQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var alreadySaved: Bool {
        guard let index else { return false }
        let canonical = JobDiscovery.canonicalURL(discovery.leads[index].url)
        guard !canonical.isEmpty else { return false }
        return app.store.list("jobs").contains { JobDiscovery.canonicalURL($0.payload.text("url")) == canonical }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Find your next role").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(20)
            VStack(spacing: 10) {
                HStack {
                    TextField("Role, skills and location", text: $query).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search jobs by role, skills, or location")
                    Button("Search web") { Task { await discovery.search(searchQuery) } }.disabled(searchQuery.isEmpty || discovery.isLoading)
                    Button("Company feeds") { Task { await discovery.companyFeeds(app.store.profile["watchlist"]?.array ?? []) } }.disabled(discovery.isLoading)
                }
                HStack {
                    TextField("Paste a public HTTPS job URL", text: $captureURL).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Public HTTPS job URL")
                    Button("Preview link") { Task { await discovery.capture(captureURL) } }.disabled(captureURL.isEmpty || discovery.isLoading)
                    Button { showConnections = true } label: { Image(systemName: "key") }
                        .help("Search connection settings").accessibilityLabel("Open search connection settings")
                }
            }.padding(.horizontal, 20).padding(.bottom, 14)
            Divider()
            if discovery.isLoading { ProgressView(discovery.status).padding(20) }
            if let error = discovery.error { Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).padding(14) }
            if discovery.leads.isEmpty {
                ContentUnavailableView("Bring a role into your workspace", systemImage: "briefcase", description: Text(discovery.status.isEmpty ? "Search connected job sources or preview a job link. You review the details before saving." : discovery.status))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let index {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Button { selectedID = nil } label: { Label("All results", systemImage: "chevron.left") }.buttonStyle(.plain)
                        Text("Review before saving").font(.headline)
                        TextField("Enter role title", text: Binding(get: { discovery.leads[index].title }, set: { discovery.leads[index].title = $0 }))
                            .textFieldStyle(.roundedBorder).accessibilityLabel("Role title")
                        TextField("Enter company name", text: Binding(get: { discovery.leads[index].company }, set: { discovery.leads[index].company = $0 }))
                            .textFieldStyle(.roundedBorder).accessibilityLabel("Company name")
                        TextField("Add location", text: Binding(get: { discovery.leads[index].location }, set: { discovery.leads[index].location = $0 }))
                            .textFieldStyle(.roundedBorder).accessibilityLabel("Location")
                        if let url = URL(string: discovery.leads[index].url) { Link("Open original listing", destination: url).font(.callout) }
                        TextEditor(text: Binding(get: { discovery.leads[index].description }, set: { discovery.leads[index].description = $0 }))
                            .font(.callout).padding(6).frame(minHeight: 180)
                            .background(.background, in: RoundedRectangle(cornerRadius: 10)).accessibilityLabel("Job description")
                        Text("A capture or search result does not confirm the vacancy is still open.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack { Spacer(); Button(alreadySaved ? "Already saved" : "Save role") { save(discovery.leads[index]) }
                            .buttonStyle(.borderedProminent)
                            .disabled(alreadySaved || discovery.leads[index].company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || discovery.leads[index].title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    }.padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review listings before saving").font(.headline)
                    Text("Select a result to check its details and availability.").font(.callout).foregroundStyle(.secondary)
                    List(discovery.leads, selection: $selectedID) { lead in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lead.title).fontWeight(.medium).lineLimit(3)
                            Text(lead.company.isEmpty ? lead.source : lead.company).font(.caption).foregroundStyle(.secondary)
                        }.tag(lead.id)
                    }.listStyle(.inset).scrollContentBackground(.hidden)
                }.padding(24).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if !discovery.status.isEmpty { Text(discovery.status).font(.caption).foregroundStyle(.secondary).padding(12) }
        }
        .onAppear { query = (app.store.profile.strings("targetRoles").first ?? "BI Developer") + " " + app.store.profile.text("location") }
        .onChange(of: discovery.leads.map(\.id)) { _, _ in selectedID = nil }
        .sheet(isPresented: $showConnections) { CoachSettingsView().frame(width: 580, height: 580) }
    }
    private func save(_ lead: JobLead) {
        let id = UUID().uuidString
        app.store.update("jobs", id: id, patch: [
            "title": .string(lead.title), "company": .string(lead.company), "location": .string(lead.location),
            "url": .string(lead.url), "canonicalUrl": .string(JobDiscovery.canonicalURL(lead.url)), "description": .string(lead.description),
            "source": .string(lead.source), "duplicateUrls": .array([]), "capturedAt": .string(Date.now.ISO8601Format()),
            "postedAt": .string(lead.postedAt), "historical": .bool(false), "skills": .array([]), "status": .string("saved"),
            "fitScore": .number(0), "fitReasons": .array([]), "gaps": .array([]), "notes": .string("Captured for review; vacancy availability is unverified.")
        ])
        guard app.store.record("jobs", id: id) != nil else { return }
        saved(id); dismiss()
    }
}
