import SwiftUI

struct AppRoot: View {
    @Bindable var app: AppModel
    @AppStorage("appearance") private var appearance = "light"
    @AppStorage("sidebarCollapsed") private var collapsed = false
    @State private var onboarding = false
    @State private var searchOpen = false
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: collapsed ? 76 : 228)
            VStack(spacing: 0) {
                topbar
                ZStack(alignment: .bottomTrailing) {
                    page.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if app.coachOpen {
                        CoachPanel(app: app).padding(18)
                            .transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : 16)))
                    } else if app.route != .practice {
                        Button { toggleCoach() } label: {
                            HStack(spacing: 9) {
                                TaavodPortrait().frame(width: 34, height: 34).clipShape(Circle())
                                Text("Ask Coach").font(.system(size: 12, weight: .semibold))
                                Image(systemName: "sparkle").font(.system(size: 12))
                            }.padding(.vertical, 7).padding(.leading, 7).padding(.trailing, 15)
                                .glassEffect(.regular.interactive(), in: Capsule())
                        }.buttonStyle(.plain).padding(20).help("Ask about your lesson, code, or next step")
                    }
                }
                if let error = app.store.error, !error.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        Text(error).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        Button { app.store.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(12).background(TaavodPalette.butter)
                }
            }
            .background(TaavodPalette.canvas)
        }
        .foregroundStyle(TaavodPalette.ink)
        .tint(TaavodPalette.accent)
        .background(TaavodPalette.surface)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "system" ? nil : .light)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .sheet(isPresented: $onboarding) { OnboardingView(app: app) { onboarding = false }.interactiveDismissDisabled().frame(width: 540, height: 570) }
        .sheet(isPresented: $searchOpen) { SearchView(app: app).frame(width: 720, height: 620) }
        .onAppear { if app.store.profile.isEmpty { onboarding = true } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { app.saveDraft(); app.runner.suspend() } }
        .onChange(of: app.route) { _, _ in app.coachEditorContext = ""; app.saveDraft() }
    }

    @ViewBuilder private var page: some View {
        switch app.route {
        case .today: TodayView(app: app)
        case .learn: LearnView(app: app)
        case .practice: PracticeView(app: app)
        case .jobs: JobsView(app: app)
        case .portfolio: PortfolioView(app: app)
        case .interviews: InterviewsView(app: app)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                TaavodMark().frame(width: 34, height: 34)
                if !collapsed { Text("Taavod").font(.system(size: 22, weight: .medium)).tracking(-0.9) }
            }.padding(.horizontal, collapsed ? 20 : 22).padding(.top, 17).padding(.bottom, 24)

            Button { searchOpen = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14))
                    if !collapsed { Text("Search").font(.system(size: 12)); Spacer(); Text("⌘ K").font(.system(size: 9)) }
                }.foregroundStyle(TaavodPalette.muted).padding(.horizontal, 12).frame(height: 36)
                    .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TaavodPalette.line.opacity(0.4), lineWidth: 0.5))
            }.buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 23).help("Search your workspace")

            if !collapsed { Text("YOUR WORKSPACE").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(TaavodPalette.muted).padding(.horizontal, 24).padding(.bottom, 12) }
            VStack(spacing: 5) {
                ForEach(AppRoute.allCases) { route in
                    if route == .jobs, !collapsed { Text("YOUR NEXT ROLE").font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(TaavodPalette.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.top, 21).padding(.bottom, 7) }
                    Button { app.route = route } label: {
                        HStack(spacing: 12) {
                            Image(systemName: route.symbol).font(.system(size: 16, weight: .regular)).frame(width: 21)
                            if !collapsed {
                                Text(route == .today ? "Dashboard" : route.rawValue).font(.system(size: 13, weight: app.route == route ? .medium : .regular))
                                Spacer()
                                if app.route == route { Circle().fill(.white.opacity(0.8)).frame(width: 4, height: 4) }
                            }
                        }
                        .foregroundStyle(app.route == route ? .white : TaavodPalette.muted)
                        .padding(.horizontal, collapsed ? 13 : 15).frame(height: 39)
                        .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
                        .background(app.route == route ? TaavodPalette.charcoal : .clear, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(app.route == route ? TaavodPalette.line : .clear, lineWidth: 0.75))
                        .contentShape(RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(SidebarButtonStyle()).keyboardShortcut(shortcut(for: route), modifiers: .command)
                        .help(collapsed ? route.rawValue : "")
                }
            }.padding(.horizontal, 14)
            Button { toggleCoach() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.system(size: 15)).frame(width: 21)
                    if !collapsed { Text("Career coach").font(.system(size: 13)); Spacer() }
                }.foregroundStyle(TaavodPalette.muted).padding(.horizontal, collapsed ? 13 : 15).frame(height: 39)
            }.buttonStyle(.plain).padding(.horizontal, 14).padding(.top, 5)
            Spacer(minLength: 20)
            if !collapsed {
                Button { app.route = .learn } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "books.vertical").font(.system(size: 16)).foregroundStyle(TaavodPalette.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your learning paths").font(.system(size: 11, weight: .medium))
                            Text("\(app.tracks.count) paths · \(app.tracks.reduce(0) { $0 + $1.lessons.count }) lessons").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(TaavodPalette.muted)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(TaavodPalette.line.opacity(0.6), lineWidth: 0.75))
                }.buttonStyle(.plain).padding(16)
            }
            Button { openSettings() } label: {
                HStack(spacing: 10) {
                    Text(initials).font(.system(size: 12, weight: .semibold)).frame(width: 33, height: 33)
                        .background(TaavodPalette.peach, in: Circle())
                    if !collapsed {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.store.profile.text("name").isEmpty ? "Your profile" : app.store.profile.text("name")).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                            Text("Personal workspace").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                }.padding(.horizontal, collapsed ? 21 : 22).padding(.vertical, 18)
            }.buttonStyle(.plain).help("Profile and settings")
        }.background(TaavodPalette.sidebar)
    }

    private var topbar: some View {
        HStack(spacing: 17) {
            Button { collapsed.toggle() } label: { Image(systemName: "sidebar.left").font(.system(size: 15)) }
                .buttonStyle(.plain).foregroundStyle(TaavodPalette.muted).help(collapsed ? "Expand sidebar" : "Collapse sidebar")
            HStack(spacing: 10) {
                Image(systemName: "house").font(.system(size: 13)).foregroundStyle(TaavodPalette.muted)
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted.opacity(0.6))
                Text(app.route == .today ? "Dashboard" : app.route.rawValue).font(.system(size: 12)).foregroundStyle(TaavodPalette.muted)
                if app.route == .today { Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(TaavodPalette.muted.opacity(0.6)); Text("Overview").font(.system(size: 11)).padding(.horizontal, 9).padding(.vertical, 5).background(TaavodPalette.surface, in: RoundedRectangle(cornerRadius: 6)) }
            }
            Spacer()
            Button { searchOpen = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                    Text("Search workspace").font(.system(size: 11)).lineLimit(1)
                    Spacer(minLength: 10)
                    Text("⌘ K").font(.system(size: 9, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 3).background(TaavodPalette.canvas, in: RoundedRectangle(cornerRadius: 4))
                }.foregroundStyle(TaavodPalette.muted).padding(.horizontal, 12).frame(width: 190, height: 34)
                    .background(TaavodPalette.surface, in: Capsule())
            }.buttonStyle(.plain).keyboardShortcut("k", modifiers: .command)
            Button { appearance = colorScheme == .dark ? "light" : "dark" } label: {
                Image(systemName: colorScheme == .dark ? "sun.max" : "moon").font(.system(size: 14)).frame(width: 30, height: 34)
            }.buttonStyle(.plain).help(colorScheme == .dark ? "Switch to light mode" : "Switch to dark mode")
                .accessibilityLabel(colorScheme == .dark ? "Switch to light mode" : "Switch to dark mode")
            Button { openSettings() } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 14)).frame(width: 34, height: 34) }.buttonStyle(.plain).help("Settings")
            Button { toggleCoach() } label: { Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 14)).frame(width: 34, height: 34) }
                .buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle()).help("Open coach")
        }.padding(.horizontal, 28).frame(height: 62)
    }

    private var initials: String { String(app.store.profile.text("name").split(separator: " ").prefix(2).compactMap(\.first)) }
    private func shortcut(for route: AppRoute) -> KeyEquivalent {
        switch route {
        case .today: "1"
        case .learn: "2"
        case .practice: "3"
        case .jobs: "4"
        case .portfolio: "5"
        case .interviews: "6"
        }
    }
    private func toggleCoach() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.25)) { app.coachOpen.toggle() }
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}
