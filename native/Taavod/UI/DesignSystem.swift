import SwiftUI
import AppKit

enum TaavodPalette {
    static let canvas = adaptive(0xF3F3F1, 0x08090B)
    static let surface = adaptive(0xFFFFFF, 0x151619)
    static let sidebar = adaptive(0xFFFFFF, 0x050607)
    static let ink = adaptive(0x17191B, 0xF6F5F1)
    static let muted = adaptive(0x797B7E, 0xB4B5BA)
    static let line = adaptive(0xE7E7E3, 0x2D2E34)
    static let lilac = adaptive(0xE8DDF9, 0x252034)
    static let mint = adaptive(0xD9EEDD, 0x192824)
    static let peach = adaptive(0xF8DFCC, 0x2D231F)
    static let butter = adaptive(0xF6EDC5, 0x292719)
    static let blue = adaptive(0xDFECF4, 0x172431)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 17).padding(.vertical, 11)
            .foregroundStyle(light ? TaavodPalette.charcoal : TaavodPalette.surface)
            .background(light ? Color.white : TaavodPalette.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TaavodPortrait: View {
    private static let image = NSImage(contentsOf: AppPaths.resources.appendingPathComponent("Mascot/FlowPortrait.png"))
    private static let videoURL = AppPaths.resources.appendingPathComponent("Mascot/FlowHeadScrub.mp4")
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 100, FileManager.default.fileExists(atPath: Self.videoURL.path) {
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
