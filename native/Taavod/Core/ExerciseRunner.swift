import Foundation
import Observation
import WebKit

@Observable final class ExerciseRunner: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private(set) var status = "Ready"
    private(set) var isRunning = false
    private(set) var outcome: PracticeOutcome?
    private var webView: WKWebView?
    private weak var runtimeHost: NSView?
    private var server: RuntimeAssetServer?
    private var origin: URL?
    private var ready = false
    private var readyContinuation: CheckedContinuation<Void, any Error>?
    private var resultContinuation: CheckedContinuation<PracticeOutcome?, Never>?
    private var requestID: String?
    private var watchdog: Task<Void, Never>?
    private var preparationWatchdog: Task<Void, Never>?
    private let runtimeRoot: URL

    init(runtimeRoot: URL = RuntimePacks.root) {
        self.runtimeRoot = runtimeRoot
        super.init()
    }
    func attachRuntime(to host: NSView) {
        runtimeHost = host
        host.wantsLayer = true
        host.layer?.masksToBounds = true
        guard let webView else { return }
        webView.frame = NSRect(origin: .zero, size: NSSize(width: max(1, host.bounds.width), height: max(1, host.bounds.height)))
        webView.autoresizingMask = [.width, .height]
        if webView.superview !== host { host.addSubview(webView) }
    }

    func run(exercise: Exercise, code: String) async -> PracticeOutcome? {
        await execute(["kind": exercise.kind, "mode": "check", "answer": code, "solution": exercise.solution])
    }
    func explore(code: String) async -> PracticeOutcome? {
        await execute(["kind": "sql", "mode": "explore", "answer": code])
    }
    func cancel() {
        webView?.evaluateJavaScript("window.runtime?.cancel()", completionHandler: nil)
        readyContinuation?.resume(throwing: CancellationError()); readyContinuation = nil
        preparationWatchdog?.cancel(); preparationWatchdog = nil
        finish(nil); status = "Cancelled"
    }
    func suspend() {
        guard !isRunning else { return }
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "runtime")
        webView?.stopLoading(); webView?.removeFromSuperview(); webView = nil; server?.stop(); server = nil; ready = false; origin = nil
    }
    private func execute(_ input: [String: String]) async -> PracticeOutcome? {
        guard !isRunning else { return nil }
        isRunning = true; outcome = nil; status = "Preparing practice…"
        do {
            try await prepare()
            try Task.checkCancellation()
            var request = input; let id = UUID().uuidString; request["id"] = id; requestID = id
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    resultContinuation = continuation
                    armWatchdog(for: id, timeout: .seconds(45))
                    Task { [weak self] in
                        do { _ = try await self?.webView?.callAsyncJavaScript("window.runtime.run(request)", arguments: ["request": request], in: nil, contentWorld: .page) }
                        catch { self?.finish(PracticeOutcome(feedback: error.localizedDescription, error: error.localizedDescription)) }
                    }
                }
            } onCancel: { Task { @MainActor [weak self] in self?.cancel() } }
        } catch is CancellationError {
            finish(nil); return nil
        } catch {
            let result = PracticeOutcome(feedback: error.localizedDescription, error: error.localizedDescription)
            finish(result); return result
        }
    }
    private func prepare() async throws {
        if ready { return }
        if webView == nil {
            let host = try RuntimeAssetServer(resources: AppPaths.resources, runtimes: runtimeRoot)
            server = host; origin = try await host.start()
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
            configuration.userContentController.add(self, name: "runtime")
            let view = WKWebView(frame: .zero, configuration: configuration)
            view.navigationDelegate = self; view.isInspectable = false; webView = view
            if let runtimeHost {
                view.frame = runtimeHost.bounds
                view.autoresizingMask = [.width, .height]
                runtimeHost.addSubview(view)
            }
        }
        try await withCheckedThrowingContinuation { continuation in
            readyContinuation = continuation
            guard let origin else { continuation.resume(throwing: URLError(.cannotConnectToHost)); readyContinuation = nil; return }
            webView?.load(URLRequest(url: origin.appendingPathComponent("engine/index.html")))
            preparationWatchdog = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self, let pending = self.readyContinuation else { return }
                self.readyContinuation = nil
                pending.resume(throwing: URLError(.timedOut))
                self.webView?.stopLoading()
            }
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        if body["ready"] as? Bool == true {
            preparationWatchdog?.cancel(); preparationWatchdog = nil
            ready = true; readyContinuation?.resume(); readyContinuation = nil; return
        }
        guard body["id"] as? String == requestID else { return }
        if let progress = body["status"] as? String {
            status = progress
            let timeout: Duration = progress.localizedCaseInsensitiveContains("loading") ? .seconds(180) : .seconds(45)
            if let requestID { armWatchdog(for: requestID, timeout: timeout) }
        }
        if let raw = body["result"], let data = try? JSONSerialization.data(withJSONObject: raw) {
            do { finish(try JSONDecoder().decode(PracticeOutcome.self, from: data)) }
            catch { finish(PracticeOutcome(feedback: "Could not read the exercise result. Please try again.", error: error.localizedDescription)) }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        readyContinuation?.resume(throwing: error); readyContinuation = nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url?.host == "127.0.0.1" && url?.port == origin?.port ? .allow : .cancel)
    }
    private func finish(_ result: PracticeOutcome?) {
        watchdog?.cancel(); watchdog = nil; requestID = nil; isRunning = false
        outcome = result; status = result?.error == nil ? "Ready" : "Check your code"
        let continuation = resultContinuation; resultContinuation = nil; continuation?.resume(returning: result)
    }
    private func armWatchdog(for id: String, timeout: Duration) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.requestID == id else { return }
            self.webView?.evaluateJavaScript("window.runtime?.cancel()", completionHandler: nil)
            let phase = self.status
            self.finish(PracticeOutcome(feedback: "Execution timed out while \(phase.lowercased()). Simplify the query or stop an infinite loop, then try again.", error: "Execution timed out during \(phase)."))
        }
    }
}
