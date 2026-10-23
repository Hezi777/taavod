import SwiftUI
import AppKit

@main
struct TaavodApp: App {
    @State private var app: AppModel?
    @State private var startupError: String?

    init() {
        do {
            let store = try WorkspaceStore()
            _app = State(initialValue: AppModel(store: store))
        } catch {
            _app = State(initialValue: nil)
            _startupError = State(initialValue: "Taavod could not open its local workspace. Your data has not been changed.\n\n\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        Window("Taavod", id: "main") {
            Group {
                if let app {
                    AppRoot(app: app)
                } else {
                    ContentUnavailableView("Workspace unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text(startupError ?? "Taavod could not open its local workspace."))
                        .frame(minWidth: 960, minHeight: 680)
                }
            }
            .frame(minWidth: 960, minHeight: 680)
        }
        .defaultSize(width: 1180, height: 800)
        Settings {
            if let app { SettingsView(app: app).frame(width: 640, height: 650) }
        }
    }
}
