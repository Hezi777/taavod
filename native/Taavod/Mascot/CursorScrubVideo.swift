import AVFoundation
import AppKit
import SwiftUI

enum CursorScrubAxis: Equatable {
    case horizontal
    case vertical
}

enum CursorScrubContentMode {
    case fit
    case fill
}

enum CursorScrubTrackingArea {
    case component
    case window
}

/// Scrubs a muted, local video as the pointer moves inside this app window.
///
/// Keep source clips intra-frame for responsive seeking. One suitable transcode is:
/// `ffmpeg -i in.mp4 -c:v libx264 -preset slow -crf 18 -g 1 -keyint_min 1 -x264-params scenecut=0 -pix_fmt yuv420p -movflags +faststart -an out.mp4`
struct CursorScrubVideo: View {
    let fileURL: URL
    var axis: CursorScrubAxis = .horizontal
    var trackingArea: CursorScrubTrackingArea = .component
    var reversed = false
    var contentMode: CursorScrubContentMode = .fit
    var cornerRadius: CGFloat = 0
    var poster: NSImage?
    var accessibilityLabel = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        CursorScrubVideoHost(
            fileURL: fileURL,
            axis: axis,
            trackingArea: trackingArea,
            reversed: reversed,
            contentMode: contentMode,
            cornerRadius: cornerRadius,
            poster: poster,
            motionAllowed: !reduceMotion && scenePhase == .active,
            accessibilityLabel: accessibilityLabel
        )
    }
}

private struct CursorScrubVideoHost: NSViewRepresentable {
    let fileURL: URL
    let axis: CursorScrubAxis
    let trackingArea: CursorScrubTrackingArea
    let reversed: Bool
    let contentMode: CursorScrubContentMode
    let cornerRadius: CGFloat
    let poster: NSImage?
    let motionAllowed: Bool
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> CursorScrubNSView {
        let view = CursorScrubNSView()
        context.coordinator.attach(view)
        context.coordinator.update(self)
        return view
    }

    func updateNSView(_ view: CursorScrubNSView, context: Context) {
        context.coordinator.attach(view)
        context.coordinator.update(self)
    }

    static func dismantleNSView(_ view: CursorScrubNSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var view: CursorScrubNSView?
        private weak var trackedWindow: NSWindow?
        private var fileURL: URL?
        private var axis: CursorScrubAxis = .horizontal
        private var trackingArea: CursorScrubTrackingArea = .component
        private var reversed = false
        private var duration: CMTime = .zero
        private var player: AVPlayer?
        private var itemObservation: NSKeyValueObservation?
        private var displayObservation: NSKeyValueObservation?
        private var loadTask: Task<Void, Never>?
        private var activityObservers: [NSObjectProtocol] = []
        private var localMonitor: Any?
        private var previousMouseMoveSetting: Bool?
        private var scrubTimer: Timer?
        private var lastTick = 0.0
        private var targetPosition = 0.0
        private var smoothedPosition = 0.0
        private var seekInFlight = false
        private var pendingSeek: CMTime?
        private var lastSeekTarget: CMTime?
        private var motionAllowed = true
        private var isReady = false
        private var displayReady = false

        func attach(_ view: CursorScrubNSView) {
            guard self.view !== view else { return }
            detach()
            self.view = view
            view.scrubHandler = { [weak self] point in self?.updatePointer(point) }
            view.onWindowChange = { [weak self] in self?.refreshDisplayState() }
            view.onPowerStateChange = { [weak self] in self?.refreshDisplayState() }
            installActivityObservers()
            refreshTracking()
        }

        func update(_ configuration: CursorScrubVideoHost) {
            guard let view else { return }
            view.setAccessibilityLabel(configuration.accessibilityLabel)
            view.cornerRadius = max(0, configuration.cornerRadius)
            view.contentMode = configuration.contentMode
            view.poster = configuration.poster
            axis = configuration.axis
            trackingArea = configuration.trackingArea
            reversed = configuration.reversed
            motionAllowed = configuration.motionAllowed
            refreshDisplayState()

            guard fileURL != configuration.fileURL else { return }
            fileURL = configuration.fileURL
            loadVideo(at: configuration.fileURL)
        }

        func detach() {
            stopScrubbing()
            removeLocalMonitor()
            restoreWindowMouseMoveSetting()
            activityObservers.forEach(NotificationCenter.default.removeObserver)
            activityObservers.removeAll()
            loadTask?.cancel()
            loadTask = nil
            itemObservation = nil
            displayObservation = nil
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
            view?.scrubHandler = nil
            view?.onWindowChange = nil
            view?.onPowerStateChange = nil
            view?.stop()
            view?.playerLayer.player = nil
            view?.playerLayer.isHidden = true
            view = nil
            isReady = false
            displayReady = false
            seekInFlight = false
            duration = .zero
        }

        private func loadVideo(at url: URL) {
            loadTask?.cancel()
            itemObservation = nil
            displayObservation = nil
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
            view?.playerLayer.player = nil
            view?.playerLayer.isHidden = true
            view?.posterLayer.isHidden = false
            isReady = false
            displayReady = false
            seekInFlight = false
            duration = .zero
            lastSeekTarget = nil
            pendingSeek = nil
            targetPosition = 0
            smoothedPosition = 0
            stopScrubbing()
            refreshDisplayState()

            let asset = AVURLAsset(url: url)
            loadTask = Task { [weak self] in
                do {
                    async let playable = asset.load(.isPlayable)
                    async let loadedDuration = asset.load(.duration)
                    let (canPlay, duration) = try await (playable, loadedDuration)
                    guard !Task.isCancelled, let self, self.fileURL == url, canPlay,
                          duration.isNumeric, CMTimeGetSeconds(duration) > 0 else { return }
                    self.configurePlayer(asset: asset, duration: duration)
                } catch is CancellationError {
                    return
                } catch {
                    if self?.fileURL == url { self?.view?.playerLayer.isHidden = true }
                }
            }
        }

        private func configurePlayer(asset: AVURLAsset, duration: CMTime) {
            guard let view else { return }
            self.duration = duration
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.volume = 0
            player.actionAtItemEnd = .pause
            self.player = player
            view.playerLayer.player = player
            view.playerLayer.isHidden = false
            view.posterLayer.isHidden = false

            itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status == .readyToPlay else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.player?.currentItem === item else { return }
                    self.showFirstFrame()
                }
            }
            displayObservation = view.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                guard layer.isReadyForDisplay else { return }
                Task { @MainActor [weak self] in self?.revealVideoFrame() }
            }
        }

        private func showFirstFrame() {
            guard let player, !isReady else { return }
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                Task { @MainActor [weak self] in
                    guard let self, self.player === player, completed else { return }
                    self.isReady = true
                    self.refreshDisplayState()
                }
            }
        }

        private func revealVideoFrame() {
            displayReady = true
            refreshDisplayState()
        }

        private func refreshDisplayState() {
            guard let view else { return }
            let canShowVideo = isReady && displayReady && motionAllowed && !ProcessInfo.processInfo.isLowPowerModeEnabled && appWindowIsActive
            let canDecodeVideo = player != nil && motionAllowed && !ProcessInfo.processInfo.isLowPowerModeEnabled && appWindowIsActive
            view.playerLayer.isHidden = !canDecodeVideo
            view.posterLayer.isHidden = canShowVideo
            if !canDecodeVideo {
                player?.pause(); stopScrubbing(); removeLocalMonitor(); restoreWindowMouseMoveSetting()
            }
            else { refreshTracking() }
        }

        private var appWindowIsActive: Bool {
            guard let window = view?.window else { return false }
            return NSApp.isActive && window.isKeyWindow && window.isVisible && !window.isMiniaturized
        }

        private func refreshTracking() {
            guard let view, let window = view.window,
                  motionAllowed, !ProcessInfo.processInfo.isLowPowerModeEnabled,
                  appWindowIsActive, isReady else {
                removeLocalMonitor()
                restoreWindowMouseMoveSetting()
                stopScrubbing()
                return
            }
            if trackedWindow !== window {
                removeLocalMonitor()
                restoreWindowMouseMoveSetting()
                trackedWindow = window
                previousMouseMoveSetting = window.acceptsMouseMovedEvents
                window.acceptsMouseMovedEvents = true
            }
            guard localMonitor == nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .rightMouseDown, .rightMouseDragged]) { [weak self, weak view] event in
                guard let self, let view, event.window === view.window else { return event }
                self.updatePointer(event.locationInWindow)
                return event
            }
        }

        private func updatePointer(_ point: NSPoint) {
            guard motionAllowed, isReady, appWindowIsActive, let view else { return }
            let normalized: CGFloat
            switch trackingArea {
            case .component:
                let localPoint = view.convert(point, from: nil)
                guard view.bounds.contains(localPoint), view.bounds.width > 0, view.bounds.height > 0 else { return }
                normalized = axis == .horizontal
                    ? localPoint.x / view.bounds.width
                    : localPoint.y / view.bounds.height
            case .window:
                guard let contentView = view.window?.contentView,
                      contentView.bounds.width > 0, contentView.bounds.height > 0 else { return }
                let localPoint = contentView.convert(point, from: nil)
                let horizontal = (localPoint.x - contentView.bounds.minX) / contentView.bounds.width
                let vertical = contentView.isFlipped
                    ? (localPoint.y - contentView.bounds.minY) / contentView.bounds.height
                    : (contentView.bounds.maxY - localPoint.y) / contentView.bounds.height
                normalized = axis == .horizontal ? horizontal : vertical
            }
            let next = min(1, max(0, Double(reversed ? 1 - normalized : normalized)))
            guard abs(next - targetPosition) > 0.0005 else { return }
            targetPosition = next
            startScrubbing()
        }

        private func startScrubbing() {
            guard scrubTimer == nil, motionAllowed, isReady else { return }
            lastTick = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advanceScrub() }
            }
            RunLoop.main.add(timer, forMode: .common)
            scrubTimer = timer
        }

        private func advanceScrub() {
            guard motionAllowed, appWindowIsActive, duration.isNumeric else { stopScrubbing(); return }
            let now = ProcessInfo.processInfo.systemUptime
            let delta = min(0.1, max(0, now - lastTick))
            lastTick = now
            let difference = targetPosition - smoothedPosition
            smoothedPosition += difference * (1 - exp(-delta / 0.22))
            if abs(targetPosition - smoothedPosition) < 0.001 { smoothedPosition = targetPosition }

            let safeEnd = max(0, CMTimeGetSeconds(duration) - (1.0 / 30.0))
            let targetSeconds = min(safeEnd, max(0, smoothedPosition * safeEnd))
            let target = CMTime(seconds: targetSeconds, preferredTimescale: 6000)
            if seekInFlight {
                pendingSeek = target
            } else if shouldSeek(to: target) {
                requestSeek(to: target)
            }

            if abs(targetPosition - smoothedPosition) < 0.001, !seekInFlight, pendingSeek == nil {
                stopScrubbing()
            }
        }

        private func shouldSeek(to target: CMTime) -> Bool {
            guard let lastSeekTarget else { return true }
            return abs(CMTimeGetSeconds(target - lastSeekTarget)) >= 0.008
        }

        private func requestSeek(to target: CMTime) {
            guard let player, !seekInFlight else { pendingSeek = target; return }
            seekInFlight = true
            lastSeekTarget = target
            player.seek(to: target,
                        toleranceBefore: CMTime(seconds: 0.008, preferredTimescale: 6000),
                        toleranceAfter: CMTime(seconds: 0.008, preferredTimescale: 6000)) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.player === player else { return }
                    self.seekInFlight = false
                    if let pending = self.pendingSeek, self.shouldSeek(to: pending) {
                        self.pendingSeek = nil
                        self.startScrubbing()
                    } else {
                        self.pendingSeek = nil
                        if abs(self.targetPosition - self.smoothedPosition) < 0.001 { self.stopScrubbing() }
                    }
                }
            }
        }

        private func stopScrubbing() {
            scrubTimer?.invalidate()
            scrubTimer = nil
        }

        private func removeLocalMonitor() {
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            localMonitor = nil
        }

        private func restoreWindowMouseMoveSetting() {
            guard let previousMouseMoveSetting else { return }
            trackedWindow?.acceptsMouseMovedEvents = previousMouseMoveSetting
            trackedWindow = nil
            self.previousMouseMoveSetting = nil
        }

        private func installActivityObservers() {
            let center = NotificationCenter.default
            for name in [NSApplication.didResignActiveNotification, NSApplication.didBecomeActiveNotification,
                         NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
                activityObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshDisplayState() }
                })
            }
        }
    }
}

@MainActor
private final class CursorScrubNSView: NSView {
    let playerLayer = AVPlayerLayer()
    let posterLayer = CALayer()
    var poster: NSImage? { didSet { updatePoster() } }
    var contentMode: CursorScrubContentMode = .fit { didSet { updateGravity() } }
    var cornerRadius: CGFloat = 0 { didSet { updateCornerRadius() } }
    var scrubHandler: ((NSPoint) -> Void)?
    var onWindowChange: (() -> Void)?
    var onPowerStateChange: (() -> Void)?
    private var powerObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        layer?.addSublayer(playerLayer)
        layer?.addSublayer(posterLayer)
        playerLayer.isHidden = true
        posterLayer.isHidden = false
        updateGravity()
        powerObserver = NotificationCenter.default.addObserver(forName: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onPowerStateChange?() }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
        posterLayer.frame = bounds
        updateCornerRadius()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        scrubHandler?(event.locationInWindow)
    }

    override func mouseDragged(with event: NSEvent) {
        scrubHandler?(event.locationInWindow)
    }

    override func mouseDown(with event: NSEvent) {
        scrubHandler?(event.locationInWindow)
    }

    override func rightMouseDown(with event: NSEvent) {
        scrubHandler?(event.locationInWindow)
    }

    override func mouseEntered(with event: NSEvent) {
        scrubHandler?(event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) { }

    func stop() {
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        powerObserver = nil
        playerLayer.player?.pause()
        playerLayer.player = nil
        playerLayer.removeFromSuperlayer()
    }

    private func updatePoster() {
        posterLayer.contents = poster?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        posterLayer.contentsGravity = contentMode == .fit ? .resizeAspect : .resizeAspectFill
    }

    private func updateGravity() {
        playerLayer.videoGravity = contentMode == .fit ? .resizeAspect : .resizeAspectFill
        updatePoster()
    }

    private func updateCornerRadius() {
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = cornerRadius > 0
        playerLayer.cornerRadius = cornerRadius
        playerLayer.masksToBounds = cornerRadius > 0
    }
}
