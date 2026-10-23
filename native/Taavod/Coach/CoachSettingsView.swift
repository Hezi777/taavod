import SwiftUI

struct CoachSettingsView: View {
    @State private var credentials: CoachCredentials
    @State private var providerKey = ""
    @State private var tavilyKey = ""
    @State private var confirmingProviderRemoval = false
    @State private var confirmingTavilyRemoval = false
    @FocusState private var providerKeyFocused: Bool

    init(credentials: CoachCredentials = .shared) { _credentials = State(initialValue: credentials) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach settings").font(.system(size: 22, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                    Text("Connect a model provider and manage your local keys.")
                        .font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                }
                .padding(.horizontal, 2)

                providerCard
                jobSearchCard
                privacyCard

                if !credentials.status.isEmpty {
                    Label {
                        Text(credentials.status).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(statusIsError ? TaavodPalette.peach : TaavodPalette.accent)
                    }
                    .font(.system(size: 11)).foregroundStyle(TaavodPalette.ink)
                    .padding(.horizontal, 3)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(TaavodPalette.canvas)
        .frame(minWidth: 420, minHeight: 460)
        .onChange(of: credentials.provider) { _, _ in
            providerKey = ""
            credentials.status = ""
        }
        .confirmationDialog("Remove the saved \(credentials.provider.title) key?", isPresented: $confirmingProviderRemoval, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) { credentials.remove(); providerKey = "" }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The Coach will need a new key before it can send messages.")
        }
        .confirmationDialog("Remove the saved job search key?", isPresented: $confirmingTavilyRemoval, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) { credentials.remove(account: "tavily"); tavilyKey = "" }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Public job search will be unavailable until a key is added again.")
        }
        .task { if !credentials.keyPresent { providerKeyFocused = true } }
    }

    private var providerCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeading("Coach provider", symbol: "sparkles", tint: TaavodPalette.lilac)

                Picker("Provider", selection: Binding(get: { credentials.provider }, set: credentials.select)) {
                    ForEach(CoachProvider.allCases) { provider in Text(provider.title).tag(provider) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 9) {
                    Text("1 · Add a provider key").font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                    HStack {
                        Label(credentials.keyPresent ? "Key saved in Keychain" : "No key saved", systemImage: credentials.keyPresent ? "checkmark.circle.fill" : "key")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(credentials.keyPresent ? TaavodPalette.accent : TaavodPalette.muted)
                        Spacer()
                        if credentials.keyPresent {
                            Button("Remove", role: .destructive) { confirmingProviderRemoval = true }
                                .font(.system(size: 11, weight: .medium)).buttonStyle(TaavodPressButtonStyle())
                        }
                    }
                    SecureField("\(credentials.provider.title) API key", text: $providerKey)
                        .focused($providerKeyFocused)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 11).padding(.vertical, 10)
                        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 1))
                    HStack {
                        Text("Stored securely on this Mac.").font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                        Spacer()
                        Button("Save to Keychain") {
                            credentials.save(providerKey.trimmingCharacters(in: .whitespacesAndNewlines))
                            providerKey = ""
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(TaavodPalette.accent, in: Capsule())
                        .buttonStyle(TaavodPressButtonStyle())
                        .disabled(providerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(providerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                }

                Rectangle().fill(TaavodPalette.line).frame(height: 1)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("2 · Choose a model").font(.system(size: 12, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                        Spacer()
                        Button {
                            Task { await credentials.loadModels() }
                        } label: {
                            HStack(spacing: 6) {
                                if credentials.loadingModels { ProgressView().controlSize(.small) }
                                else { Image(systemName: "arrow.clockwise") }
                                Text(credentials.loadingModels ? "Loading" : "Fetch models")
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TaavodPalette.accent)
                        .buttonStyle(TaavodPressButtonStyle())
                        .disabled(credentials.loadingModels || !credentials.keyPresent)
                    }
                    Text("Fetch the models available to this key, then select one.")
                        .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
                    Picker("Model", selection: Binding(get: { credentials.model }, set: credentials.selectModel)) {
                        if credentials.models.isEmpty {
                            Text(credentials.model.isEmpty ? "Fetch models first" : credentials.model).tag(credentials.model)
                        }
                        ForEach(credentials.models, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 1))
                }
            }
        }
    }

    private var jobSearchCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeading("Optional job search", symbol: "magnifyingglass", tint: TaavodPalette.mint)
                Text("Tavily powers public job search. Its key stays in Keychain and is only used by the job search service.")
                    .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Label(credentials.tavilyPresent ? "Key saved in Keychain" : "No key saved", systemImage: credentials.tavilyPresent ? "checkmark.circle.fill" : "key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(credentials.tavilyPresent ? TaavodPalette.accent : TaavodPalette.muted)
                    Spacer()
                    if credentials.tavilyPresent {
                        Button("Remove", role: .destructive) { confirmingTavilyRemoval = true }
                            .font(.system(size: 11, weight: .medium)).buttonStyle(TaavodPressButtonStyle())
                    }
                }
                SecureField("Tavily API key", text: $tavilyKey)
                    .font(.system(size: 12)).textFieldStyle(.plain)
                    .padding(.horizontal, 11).padding(.vertical, 10)
                    .background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 1))
                HStack {
                    Spacer()
                    Button("Save to Keychain") {
                        credentials.save(tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines), account: "tavily")
                        tavilyKey = ""
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TaavodPalette.accent)
                    .buttonStyle(TaavodPressButtonStyle())
                    .disabled(tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundStyle(TaavodPalette.accent).padding(.top, 1)
            Text("The selected provider receives each message with this screen, your current lesson or exercise, draft, profile and progress. The selected workspace record is included when present; Coach can retrieve other saved records when needed. API keys stay in Keychain. Taavod does not inspect screenshots or other apps.")
                .font(.system(size: 11)).foregroundStyle(TaavodPalette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TaavodPalette.line, lineWidth: 1))
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(15)
            .background(TaavodPalette.surface.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.7))
    }

    private func cardHeading(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
                .frame(width: 26, height: 26).background(tint.opacity(0.46), in: Circle())
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(TaavodPalette.ink)
            Spacer()
        }
    }

    private var statusIsError: Bool {
        let status = credentials.status
        return status != "Saved securely in Keychain."
            && status != "Removed from Keychain."
            && !status.hasPrefix("Loaded ")
    }
}
