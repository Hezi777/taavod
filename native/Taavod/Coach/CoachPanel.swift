import SwiftUI

struct CoachPanel: View {
    let app: AppModel
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool
    private var model: CoachModel { app.coach }

    var body: some View {
        GeometryReader { geometry in
            let width = min(app.coachExpanded ? 620.0 : 380.0, max(0, geometry.size.width - 36))
            let height = min(app.coachExpanded ? 560.0 : 450.0, max(0, geometry.size.height - 36))
            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 0) {
                    header
                    contextBadge
                    Rectangle().fill(TaavodPalette.line.opacity(0.75)).frame(height: 1)
                    if !app.coachExpanded { compactConversation }
                    else { conversation }
                    if let error = model.error { errorBanner(error) }
                    composer
                }
                .frame(width: width, height: height)
                .foregroundStyle(TaavodPalette.ink)
                .glassEffect(.regular.tint(TaavodPalette.surface.opacity(0.92)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.9), lineWidth: 1))
                .shadow(color: TaavodPalette.ink.opacity(0.14), radius: 28, y: 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .sheet(isPresented: $showSettings) { CoachSettingsView().frame(minWidth: 420, minHeight: 460) }
    }

    private var header: some View {
        HStack(spacing: 11) {
            SparkMascot(size: 28, mood: model.isSending ? .thinking : (model.error == nil ? .idle : .error))
                .frame(width: 42, height: 42)
                .background(TaavodPalette.mint.opacity(0.42), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Taavod Coach").font(.system(size: 15, weight: .semibold))
                Text(providerStatus).font(.system(size: 11, weight: .medium)).foregroundStyle(TaavodPalette.muted).lineLimit(1)
            }
            Spacer(minLength: 5)
            Menu {
                Button("New conversation", systemImage: "plus") { model.newConversation() }.disabled(model.isSending)
                if !model.conversations.isEmpty {
                    Divider()
                    ForEach(model.conversations) { conversation in
                        Button {
                            model.selectConversation(conversation.id)
                        } label: {
                            if conversation.id == model.conversationID { Label(conversation.title.isEmpty ? "Conversation" : conversation.title, systemImage: "checkmark") }
                            else { Text(conversation.title.isEmpty ? "Conversation" : conversation.title) }
                        }
                        .disabled(model.isSending)
                    }
                }
            } label: {
                headerButton("bubble.left.and.bubble.right", help: "Choose or start a conversation")
            }
            Button { showSettings = true } label: { headerButton("slider.horizontal.3", help: "Coach settings") }
            Button { app.coachExpanded.toggle() } label: {
                headerButton(app.coachExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", help: app.coachExpanded ? "Make coach compact" : "Expand coach")
            }
            Button { app.coachOpen = false } label: { headerButton("xmark", help: "Close coach") }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 17).padding(.top, 15).padding(.bottom, 12)
    }

    private func headerButton(_ symbol: String, help: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TaavodPalette.ink)
            .frame(width: 30, height: 30)
            .background(TaavodPalette.surface.opacity(0.88), in: Circle())
            .overlay(Circle().strokeBorder(TaavodPalette.line, lineWidth: 1))
            .contentShape(Circle())
            .help(help)
    }

    private var providerStatus: String {
        let usage = model.lastInputTokens + model.lastOutputTokens > 0 ? " · \(model.lastInputTokens) in / \(model.lastOutputTokens) out" : ""
        return "\(model.credentials.provider.title) · \(model.credentials.model.isEmpty ? "Choose model" : model.credentials.model)\(usage)"
    }

    private var contextBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield.fill").foregroundStyle(TaavodPalette.accent)
            Text(contextDescription)
                .lineLimit(1).minimumScaleFactor(0.84)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(TaavodPalette.muted)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(TaavodPalette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(TaavodPalette.line, lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 11)
    }

    private var compactConversation: some View {
        VStack(spacing: 9) {
            if model.messages.isEmpty {
                Spacer(minLength: 10)
                emptyState
                Spacer(minLength: 10)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 11) {
                            ForEach(model.messages.suffix(3)) { message in messageBubble(message).id(message.id) }
                        }.padding(.vertical, 14)
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        if let last = model.messages.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right").foregroundStyle(TaavodPalette.lilac)
                Text("\(model.messages.count) messages").foregroundStyle(TaavodPalette.muted)
                Spacer()
                Button("Open full chat", systemImage: "arrow.up.left.and.arrow.down.right") { app.coachExpanded = true }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(TaavodPalette.accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.bottom, 11)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("What are you working through?")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
            Text(emptyDescription)
                .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 290)
            VStack(spacing: 7) {
                ForEach(Array(starterOptions.enumerated()), id: \.offset) { _, item in
                    starterButton(item.0, prompt: item.1, color: item.2)
                }
            }
            .frame(maxWidth: 290)
            .padding(.top, 2)
        }
        .padding(.horizontal, 22)
    }

    private func starterButton(_ title: String, prompt: String, color: Color) -> some View {
        Button { sendStarter(prompt) } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkle").font(.system(size: 11, weight: .semibold)).foregroundStyle(TaavodPalette.accent)
                    .frame(width: 24, height: 24).background(color.opacity(0.55), in: Circle())
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(TaavodPalette.ink)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .medium)).foregroundStyle(TaavodPalette.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.isSending)
    }

    private func sendStarter(_ prompt: String) {
        model.input = prompt
        model.send()
    }

    private var contextDescription: String {
        switch app.route {
        case .practice, .learn: "Exercise, draft & selection shared · records on request"
        case .jobs: "Selected role and editor draft shared · records on request"
        case .portfolio: "Current project shared · other records on request"
        case .interviews: "Question and answer draft shared · records on request"
        case .today: "Progress and current screen shared · records on request"
        }
    }

    private var emptyDescription: String {
        switch app.route {
        case .practice, .learn: "Your current exercise and draft are ready when you need a hand."
        case .jobs: "Ask about a role, your application notes, or a follow-up."
        case .portfolio: "Work through a project story, evidence, or next step."
        case .interviews: "Practice an answer or reflect on a recent interview."
        case .today: "Choose a next step for learning, your portfolio, or job search."
        }
    }

    private var starterOptions: [(String, String, Color)] {
        switch app.route {
        case .practice, .learn:
            [
                ("Give me a hint", "Give me one small hint for my current exercise. Ask me a question to help me reason it through.", TaavodPalette.mint),
                ("Review my draft", "Review my current draft. Ask me a focused question about the next improvement before giving a full solution.", TaavodPalette.lilac),
                ("Explain my last result", "Help me understand my most recent exercise result and what I should check next.", TaavodPalette.butter)
            ]
        case .jobs:
            [
                ("Review this role", "Help me identify the most important requirements in the selected role.", TaavodPalette.mint),
                ("Improve my notes", "Review my current job editor draft and ask what evidence I can add.", TaavodPalette.lilac),
                ("Plan a follow-up", "Help me choose a thoughtful next step for this job application.", TaavodPalette.butter)
            ]
        case .portfolio:
            [
                ("Strengthen this story", "Help me make the current project story clearer and more specific.", TaavodPalette.mint),
                ("Review the evidence", "Ask me a question to check whether the current project evidence supports its claim.", TaavodPalette.lilac),
                ("Choose a next step", "Help me choose one concrete next step for this portfolio project.", TaavodPalette.butter)
            ]
        case .interviews:
            [
                ("Practice this answer", "Ask me a focused question about the interview answer I am drafting.", TaavodPalette.mint),
                ("Make it clearer", "Help me improve the clarity of my current interview answer without rewriting it for me.", TaavodPalette.lilac),
                ("Find stronger evidence", "Ask what concrete evidence could make my interview answer more convincing.", TaavodPalette.butter)
            ]
        case .today:
            [
                ("Plan a study session", "Help me choose a small useful learning step for today.", TaavodPalette.mint),
                ("Prepare for a role", "Help me choose one practical job-search task to do next.", TaavodPalette.lilac),
                ("Review my progress", "Help me reflect on my recent progress and choose a next step.", TaavodPalette.butter)
            ]
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.messages.isEmpty { emptyState.padding(.top, 42).padding(.bottom, 20) }
                    ForEach(model.messages) { message in messageBubble(message).id(message.id) }
                    if model.isSending && model.messages.last?.content.isEmpty == true {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(TaavodPalette.accent)
                            Text("Thinking through it…").font(.system(size: 11, weight: .medium)).foregroundStyle(TaavodPalette.muted)
                        }.padding(.horizontal, 16).padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: 570, alignment: .leading).frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .onChange(of: model.messages.last?.content) { _, _ in
                if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder private func messageBubble(_ message: CoachMessage) -> some View {
        let user = message.role == "user"
        HStack(alignment: .top, spacing: 8) {
            if user { Spacer(minLength: 46) }
            if !user {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TaavodPalette.accent)
                    .frame(width: 24, height: 24)
                    .background(TaavodPalette.mint.opacity(0.42), in: Circle())
                    .padding(.top, 2)
            }
            Group {
                if message.content.isEmpty { Text(" ").frame(minHeight: 14) }
                else { Text(LocalizedStringKey(message.content)).textSelection(.enabled) }
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(user ? TaavodPalette.accent.opacity(0.35) : TaavodPalette.line, lineWidth: 1))
            .foregroundStyle(TaavodPalette.ink)
            if !user { Spacer(minLength: 24) }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(TaavodPalette.peach)
            Text(message).font(.system(size: 11)).foregroundStyle(TaavodPalette.ink).lineLimit(3)
            Spacer(minLength: 2)
            Button("Retry") { model.retry() }
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(TaavodPalette.accent)
                .buttonStyle(.plain).disabled(!model.canRetry)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(TaavodPalette.peach.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(TaavodPalette.peach.opacity(0.55), lineWidth: 1))
        .padding(.horizontal, 14).padding(.bottom, 7)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Ask a question or request a hint…", text: Binding(get: { model.input }, set: { model.input = $0 }), axis: .vertical)
                .lineLimit(1...4).textFieldStyle(.plain).focused($inputFocused)
                .onSubmit { model.send() }
                .font(.system(size: 12.5))
                .foregroundStyle(TaavodPalette.ink)
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 1))
            Button {
                if model.isSending { model.cancel() } else { model.send() }
            } label: {
                Image(systemName: model.isSending ? "stop.fill" : "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(model.isSending ? TaavodPalette.ink : TaavodPalette.accent, in: Circle())
            }
            .buttonStyle(.plain).disabled(!model.isSending && model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(model.isSending ? "Stop response" : "Send message")
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 13)
        .background(TaavodPalette.canvas.opacity(0.42))
    }
}
