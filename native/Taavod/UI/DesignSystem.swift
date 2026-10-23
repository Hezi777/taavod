import SwiftUI
import AppKit

enum TaavodPalette {
    static let canvas = adaptive(0xF5F5F5, 0x000000)
    static let surface = adaptive(0xFFFFFF, 0x111113)
    static let sidebar = adaptive(0xFFFFFF, 0x000000)
    static let ink = adaptive(0x17191B, 0xF6F5F1)
    static let muted = adaptive(0x6E7074, 0xB4B5BA)
    static let line = adaptive(0xE7E7E3, 0x2D2E34)
    static let lilac = surface
    static let mint = surface
    static let peach = surface
    static let butter = surface
    static let blue = surface
    static let accent = adaptive(0x7051D4, 0x9469FF)
    static let charcoal = Color(hex: 0x1C1D20)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct TaavodCard<Content: View>: View {
    var fill: Color = TaavodPalette.surface
    var padding: CGFloat = 22
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.025), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(TaavodPalette.line.opacity(0.65), lineWidth: 0.65))
    }
}

struct TaavodPrimaryButton: ButtonStyle {
    var light = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 17).padding(.vertical, 11)
            .foregroundStyle(light ? TaavodPalette.charcoal : TaavodPalette.surface)
            .background(light ? Color.white : TaavodPalette.ink, in: Capsule())
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TaavodPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TaavodInteractiveCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                shape.strokeBorder(
                    TaavodPalette.accent.opacity(isHovered && isEnabled ? 0.58 : 0),
                    lineWidth: isHovered && isEnabled ? 1 : 0
                )
                .allowsHitTesting(false)
            }
            .background {
                shape.fill(TaavodPalette.ink.opacity(isHovered && isEnabled ? 0.025 : 0))
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
            .focusEffectDisabled(false)
            .onHover { hovering in
                let activeHover = hovering && isEnabled
                guard isHovered != activeHover else { return }
                isHovered = activeHover
                if activeHover { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled && isHovered { NSCursor.pop(); isHovered = false }
            }
            .onDisappear {
                if isHovered { NSCursor.pop(); isHovered = false }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
    }
}

extension View {
    func taavodInteractiveCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(TaavodInteractiveCardModifier(cornerRadius: cornerRadius))
    }
}

struct TaavodPortrait: View {
    private static let image = NSImage(contentsOf: AppPaths.resources.appendingPathComponent("Mascot/FlowPortrait.png"))
    private static let videoURL = AppPaths.resources.appendingPathComponent("Mascot/FlowHeadScrub.mp4")
    var body: some View {
        GeometryReader { geometry in
            if FileManager.default.fileExists(atPath: Self.videoURL.path) {
                CursorScrubVideo(
                    fileURL: Self.videoURL,
                    trackingArea: .window,
                    contentMode: .fill,
                    poster: Self.image,
                    accessibilityLabel: "Shih Tzu portrait"
                )
            } else if let image = Self.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                Image(systemName: "pawprint.fill").resizable().aspectRatio(contentMode: .fit).foregroundStyle(TaavodPalette.muted)
            }
        }
    }
}

struct TaavodMark: View {
    private static let image = NSImage(contentsOf: AppPaths.resources.appendingPathComponent("Mascot/ShihTzu-Icon.png"))
    var body: some View {
        Group {
            if let image = Self.image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(3) }
            else { Image(systemName: "pawprint.fill").padding(7) }
        }.background(TaavodPalette.charcoal, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct TaavodCardTitle: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 14, weight: .regular))
                .foregroundStyle(TaavodPalette.ink)
                .frame(width: 34, height: 34)
                .background(TaavodPalette.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TaavodPalette.line, lineWidth: 0.6))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(TaavodPalette.muted)
            }
        }
    }
}
