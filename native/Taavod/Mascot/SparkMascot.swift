import AppKit
import SceneKit
import SwiftUI

enum SparkMood: Equatable { case idle, thinking, responding, success, error }

/// The existing app integration point, now rendered from the Shih Tzu's real 3D model.
struct SparkMascot: View {
    var size: CGFloat = 64
    var mood: SparkMood = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if size <= 30 {
            MascotArtwork()
                .frame(width: size, height: size)
                .accessibilityLabel("Taavod Shih Tzu assistant")
        } else {
            MascotScene(mood: mood, motionAllowed: !reduceMotion && scenePhase == .active)
                .frame(width: size, height: size)
                .accessibilityLabel("Taavod Shih Tzu assistant")
        }
    }
}

private struct MascotArtwork: View {
    var body: some View {
        if let image = MascotArtworkResource.image {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "pawprint.fill").resizable().scaledToFit().padding(5)
        }
    }

}

@MainActor
private enum MascotArtworkResource {
    static let image: NSImage? = {
        let bundle = Bundle.main
        let candidates = ["Mascot", "Resources/Mascot", nil] as [String?]
        for folder in candidates {
            if let url = bundle.url(forResource: "ShihTzu-Icon", withExtension: "png", subdirectory: folder) {
                return NSImage(contentsOf: url)
            }
        }
        return nil
    }()
}

private struct MascotScene: NSViewRepresentable {
    var mood: SparkMood
    var motionAllowed: Bool

    func makeNSView(context: Context) -> ShihTzuSceneView {
        let view = ShihTzuSceneView(frame: .zero)
        view.mood = mood
        view.motionAllowed = motionAllowed
        view.loadMascot()
        return view
    }

    func updateNSView(_ view: ShihTzuSceneView, context: Context) {
        view.motionAllowed = motionAllowed
        if view.mood != mood { view.setMood(mood) }
    }

    static func dismantleNSView(_ view: ShihTzuSceneView, coordinator: ()) {
        view.stop()
    }
}

@MainActor
private final class ShihTzuSceneView: SCNView {
    var mood: SparkMood = .idle
    var motionAllowed = true {
        didSet { refreshMotion() }
    }
    private var active = true
    private var powerEfficient = !ProcessInfo.processInfo.isLowPowerModeEnabled {
        didSet { refreshMotion() }
    }
    private var pointerMonitor: Any?
    private var powerObserver: NSObjectProtocol?
    private var idleTimer: Timer?
    private var blinkTimer: Timer?
    private var startedAt = ProcessInfo.processInfo.systemUptime
    private weak var head: SCNNode?
    private weak var leftEye: SCNNode?
    private weak var rightEye: SCNNode?
    private weak var leftEar: SCNNode?
    private weak var rightEar: SCNNode?
    private weak var tongue: SCNNode?
    private var targetGaze = CGPoint.zero
    private var cursorIsInsideApp = false
    private var lastPointerUpdate: TimeInterval = 0

    override init(frame frameRect: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frameRect, options: options)
        backgroundColor = .clear
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        autoenablesDefaultLighting = true
        antialiasingMode = .multisampling4X
        rendersContinuously = false
        isPlaying = false
        powerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.powerEfficient = !ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func loadMascot() {
        let bundle = Bundle.main
        let url = bundle.url(forResource: "ShihTzu", withExtension: "usdz", subdirectory: "Mascot")
            ?? bundle.url(forResource: "ShihTzu", withExtension: "usdz", subdirectory: "Resources/Mascot")
            ?? bundle.url(forResource: "ShihTzu", withExtension: "usdz")
        guard let url, let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) else { return }
        installRuntimeLighting(in: scene)
        self.scene = scene
        pointOfView = scene.rootNode.childNode(withName: "MascotCamera", recursively: true)
        head = scene.rootNode.childNode(withName: "HeadPivot", recursively: true)
        leftEye = scene.rootNode.childNode(withName: "EyeLeft", recursively: true)
        rightEye = scene.rootNode.childNode(withName: "EyeRight", recursively: true)
        leftEar = scene.rootNode.childNode(withName: "EarLeftPivot", recursively: true)
        rightEar = scene.rootNode.childNode(withName: "EarRightPivot", recursively: true)
        tongue = scene.rootNode.childNode(withName: "Tongue", recursively: true)
        setMood(mood, animated: false)
        if window != nil { beginMotion() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removePointerMonitor()
        idleTimer?.invalidate(); idleTimer = nil
        blinkTimer?.invalidate(); blinkTimer = nil
        guard window != nil else { active = false; return }
        active = true
        window?.acceptsMouseMovedEvents = true
        installPointerMonitor()
        beginMotion()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    func setMood(_ newMood: SparkMood, animated: Bool = true) {
        let previous = mood
        mood = newMood
        let animate = animated && motionAllowed && active && powerEfficient
        animateScene(duration: animate ? 0.24 : 0) { [weak self] in
            guard let self else { return }
            self.tongue?.isHidden = newMood != .success && newMood != .responding
            switch newMood {
            case .idle:
                self.head?.eulerAngles.z = -0.06
                self.leftEar?.eulerAngles.z = 0.10; self.rightEar?.eulerAngles.z = -0.10
            case .thinking:
                self.head?.eulerAngles.z = -0.12
                self.leftEar?.eulerAngles.z = 0.14; self.rightEar?.eulerAngles.z = -0.08
            case .responding:
                self.head?.eulerAngles.z = -0.04
                self.leftEar?.eulerAngles.z = 0.04; self.rightEar?.eulerAngles.z = -0.04
            case .success:
                self.head?.eulerAngles.z = -0.02
                self.leftEar?.eulerAngles.z = 0.02; self.rightEar?.eulerAngles.z = -0.02
            case .error:
                self.head?.eulerAngles.z = -0.19
                self.leftEar?.eulerAngles.z = 0.20; self.rightEar?.eulerAngles.z = -0.16
            }
        }
        if newMood != previous && (newMood == .responding || newMood == .success) { blink() }
    }

    private func beginMotion() {
        guard motionAllowed, powerEfficient, active else { return }
        if idleTimer == nil {
            idleTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateIdleGaze() }
            }
        }
        scheduleBlink()
    }

    private func refreshMotion() {
        guard motionAllowed, powerEfficient, active, window != nil else {
            idleTimer?.invalidate(); idleTimer = nil
            blinkTimer?.invalidate(); blinkTimer = nil
            return
        }
        if idleTimer == nil { beginMotion() }
    }

    private func scheduleBlink() {
        blinkTimer?.invalidate()
        guard motionAllowed, powerEfficient, active else { return }
        // Bloub's measured cadence: 1.9–4.6 s between blinks, with an occasional 0.24 s double blink.
        let delay = 1.9 + Double.random(in: 0...2.7)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.motionAllowed, self.active, self.powerEfficient else { return }
                self.blink()
                if Double.random(in: 0...1) < 0.18 {
                    self.blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.24, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated { self?.blink(); self?.scheduleBlink() }
                    }
                } else { self.scheduleBlink() }
            }
        }
    }

    private func blink() {
        guard motionAllowed, powerEfficient, active else { return }
        for eye in [leftEye, rightEye].compactMap({ $0 }) {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.08
            eye.scale.y = 0.06; SCNTransaction.commit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak eye] in
                guard let self, let eye, self.active else { return }
                SCNTransaction.begin(); SCNTransaction.animationDuration = 0.10
                eye.scale.y = 1; SCNTransaction.commit()
            }
        }
        rendersContinuously = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in self?.rendersContinuously = false }
    }

    private func updateIdleGaze() {
        guard !cursorIsInsideApp, mood == .idle || mood == .thinking else { return }
        let time = ProcessInfo.processInfo.systemUptime - startedAt
        let yaw = (loopNoise(time, 11.3, 0.4) * 5.5 + loopNoise(time, 3.7, 2.1) * 1.6) * .pi / 180
        let pitch = (loopNoise(time, 9.1, 1.3) * 4.2 + loopNoise(time, 4.3, 0.7) * 1.3) * .pi / 180
        animateScene(duration: 0.24) { [weak self] in
            self?.head?.eulerAngles.y = CGFloat(yaw)
            self?.head?.eulerAngles.x = CGFloat(-pitch)
        }
    }

    private func updateGaze() {
        guard motionAllowed else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPointerUpdate >= 1.0 / 30.0 else { return }
        lastPointerUpdate = now
        guard let window else { return }
        let location = NSEvent.mouseLocation
        cursorIsInsideApp = NSApp.windows.contains { $0.isVisible && $0.frame.contains(location) }
        guard cursorIsInsideApp else {
            targetGaze = .zero
            return
        }
        let inWindow = window.convertPoint(fromScreen: location)
        let center = CGPoint(x: window.frame.width / 2, y: window.frame.height / 2)
        targetGaze = CGPoint(x: max(-1, min(1, (inWindow.x - center.x) / 420)),
                             y: max(-1, min(1, (inWindow.y - center.y) / 320)))
        let x = targetGaze.x, y = targetGaze.y
        animateScene(duration: motionAllowed && powerEfficient ? 0.24 : 0) { [weak self] in
            guard let self else { return }
            self.head?.eulerAngles.y = CGFloat(x * 0.22)
            self.head?.eulerAngles.x = CGFloat(-y * 0.13)
            for eye in [self.leftEye, self.rightEye].compactMap({ $0 }) {
                let side: CGFloat = eye.name == "EyeLeft" ? -1 : 1
                eye.position.x = side * 0.39 + CGFloat(x) * 0.036
                eye.position.y = 0.15 + CGFloat(y) * 0.025
            }
        }
    }

    private func animateScene(duration: TimeInterval, changes: @escaping () -> Void) {
        guard duration > 0 else {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0; changes(); SCNTransaction.commit()
            needsDisplay = true
            return
        }
        rendersContinuously = true
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.19, 1, 0.22, 1)
        SCNTransaction.completionBlock = { [weak self] in self?.rendersContinuously = false }
        changes()
        SCNTransaction.commit()
    }

    private func installPointerMonitor() {
        pointerMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.window != nil else { return }
                self.cursorIsInsideApp = true
                self.updateGaze()
            }
            return event
        }
    }

    private func removePointerMonitor() {
        if let pointerMonitor { NSEvent.removeMonitor(pointerMonitor) }
        pointerMonitor = nil
    }

    func stop() {
        active = false
        removePointerMonitor()
        idleTimer?.invalidate(); idleTimer = nil
        blinkTimer?.invalidate(); blinkTimer = nil
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        powerObserver = nil
        rendersContinuously = false
    }

    private func installRuntimeLighting(in scene: SCNScene) {
        // USDZ omits the SceneKit-only light nodes from the source scene. Keep the
        // PBR coat and eyes shaded in the live view with a compact local light rig.
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 42; scene.rootNode.addChildNode(ambient)

        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .area
        key.light?.intensity = 200; key.light?.areaType = .rectangle
        key.position = SCNVector3(-3.2, 4.8, 6.0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni
        fill.light?.intensity = 105; fill.position = SCNVector3(4, 1.5, 3.5)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .area
        rim.light?.intensity = 90; rim.position = SCNVector3(2, 4, -3)
        scene.rootNode.addChildNode(rim)
    }

}

private func loopNoise(_ time: Double, _ period: Double, _ seed: Double) -> Double {
    // Bloub face.ts uses this 0.55/0.30/0.15 three-harmonic blend.
    // External gaze uses engine.ts's 0.24-second LOOK_MORPH.
    let phase = time / period * 2 * .pi
    return 0.55 * sin(phase + seed)
        + 0.30 * sin(2 * phase + seed * 1.7 + 1.1)
        + 0.15 * sin(3 * phase + seed * 2.3 + 2.4)
}
