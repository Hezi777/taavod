import SwiftUI
import AppKit

@MainActor private final class CodeTextView: NSTextView {
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let layout = layoutManager, let container = textContainer else { return }
        let visible = visibleRect
        let gutter = NSRect(x: visible.minX, y: visible.minY, width: 46, height: visible.height)
        NSColor.controlBackgroundColor.setFill()
        gutter.fill()

        let source = string as NSString
        guard source.length > 0 else { return }
        let glyphRange = layout.glyphRange(forBoundingRect: visible, in: container)
        let characterRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        var lineNumber = 1
        var lineStart = 0
        while lineStart < characterRange.location {
            lineStart = NSMaxRange(source.lineRange(for: NSRange(location: lineStart, length: 0)))
            lineNumber += 1
        }

        var location = lineStart
        while location <= NSMaxRange(characterRange) && location <= source.length {
            let glyph = layout.glyphIndexForCharacter(at: min(location, source.length))
            var lineRect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            lineRect.origin.y += textContainerInset.height
            let label = NSAttributedString(
                string: "\(lineNumber)",
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]
            )
            label.draw(at: NSPoint(x: 5, y: lineRect.minY + 1))
            let next = NSMaxRange(source.lineRange(for: NSRange(location: location, length: 0)))
            if next <= location { break }
            location = next
            lineNumber += 1
            if location >= source.length { break }
        }

        NSColor.separatorColor.setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 45.5, y: gutter.minY))
        divider.line(to: NSPoint(x: 45.5, y: gutter.maxY))
        divider.stroke()
    }
}

struct NativeCodeEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String
    @Binding var findText: String
    let language: PackKind

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 640
        let height = proposal.height.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 400
        return CGSize(width: width, height: height)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.textBackgroundColor

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = CodeTextView(frame: NSRect(origin: .zero, size: scroll.contentSize), textContainer: textContainer)
        textView.isRichText = false
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.textContainerInset = NSSize(width: 62, height: 14)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = scroll.contentSize
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.string = text
        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.applySyntaxHighlighting()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
            if let container = textView.textContainer { textView.layoutManager?.ensureLayout(for: container) }
            context.coordinator.applySyntaxHighlighting()
        }
        context.coordinator.updateDocumentFrame(in: scroll)
        if context.coordinator.lastFindText != findText {
            context.coordinator.lastFindText = findText
            if !findText.isEmpty { context.coordinator.findNext(findText) }
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeCodeEditor
        weak var textView: NSTextView?
        var lastFindText = ""

        init(_ parent: NativeCodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            applySyntaxHighlighting()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            let range = textView.selectedRange()
            guard range.location != NSNotFound, range.length > 0, range.location + range.length <= (textView.string as NSString).length else {
                parent.selectedText = ""
                return
            }
            parent.selectedText = (textView.string as NSString).substring(with: range)
        }

        func findNext(_ query: String) {
            guard let textView, !query.isEmpty else { return }
            let source = textView.string as NSString
            let current = textView.selectedRange()
            let options: NSString.CompareOptions = [.caseInsensitive]
            var found = source.range(of: query, options: options, range: NSRange(location: min(current.location + current.length, source.length), length: max(0, source.length - min(current.location + current.length, source.length))))
            if found.location == NSNotFound { found = source.range(of: query, options: options) }
            if found.location != NSNotFound {
                textView.setSelectedRange(found)
                textView.scrollRangeToVisible(found)
            }
        }

        func updateDocumentFrame(in scroll: NSScrollView) {
            guard let textView, let container = textView.textContainer, let layout = textView.layoutManager else { return }
            let contentSize = scroll.contentSize
            guard contentSize.width > 0, contentSize.height > 0 else { return }
            textView.setFrameSize(NSSize(width: contentSize.width, height: max(contentSize.height, textView.frame.height)))
            container.containerSize = NSSize(width: contentSize.width - textView.textContainerInset.width * 2, height: CGFloat.greatestFiniteMagnitude)
            layout.ensureLayout(for: container)
            let used = layout.usedRect(for: container)
            let height = max(contentSize.height, used.maxY + textView.textContainerInset.height * 2)
            if abs(textView.frame.height - height) > 1 { textView.setFrameSize(NSSize(width: contentSize.width, height: height)) }
        }

        func applySyntaxHighlighting() {
            guard let textView, let storage = textView.textStorage else { return }
            let source = textView.string
            let selected = textView.selectedRange()
            let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let full = NSRange(location: 0, length: (source as NSString).length)
            storage.beginEditing()
            storage.setAttributes([.font: baseFont, .foregroundColor: NSColor.labelColor], range: full)
            let keywordPattern = parent.language == .sql
                ? #"\b(SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|ON|GROUP BY|ORDER BY|HAVING|AS|AND|OR|NOT|NULL|IS|IN|LIMIT|OFFSET|COUNT|DISTINCT|INSERT|UPDATE|DELETE|CREATE|WITH|CASE|WHEN|THEN|ELSE|END|ASC|DESC|UNION|OVER|PARTITION BY)\b"#
                : #"\b(def|return|for|in|if|else|elif|while|import|from|as|class|with|try|except|True|False|None|and|or|not|lambda|yield|print|len|range)\b"#
            apply(pattern: keywordPattern, to: storage, source: source, color: .systemBlue, options: [.caseInsensitive])
            apply(pattern: #"'([^'\\]|\\.)*'|\"([^\"\\]|\\.)*\""#, to: storage, source: source, color: .systemRed)
            apply(pattern: #"--[^\n]*|#[^\n]*"#, to: storage, source: source, color: .systemGreen)
            apply(pattern: #"\b[0-9]+(\.[0-9]+)?\b"#, to: storage, source: source, color: .systemOrange)
            storage.endEditing()
            if selected.location <= (source as NSString).length {
                textView.setSelectedRange(NSRange(location: selected.location, length: min(selected.length, (source as NSString).length - selected.location)))
            }
        }

        private func apply(pattern: String, to storage: NSTextStorage, source: String, color: NSColor, options: NSRegularExpression.Options = []) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            regex.enumerateMatches(in: source, range: NSRange(location: 0, length: (source as NSString).length)) { match, _, _ in
                if let range = match?.range { storage.addAttribute(.foregroundColor, value: color, range: range) }
            }
        }
    }
}
