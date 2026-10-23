import AppKit
import SwiftUI

struct RuntimeWebViewHost: NSViewRepresentable {
    let runner: ExerciseRunner

    func makeNSView(context: Context) -> NSView {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        runner.attachRuntime(to: host)
        return host
    }

    func updateNSView(_ host: NSView, context: Context) {
        runner.attachRuntime(to: host)
    }
}
