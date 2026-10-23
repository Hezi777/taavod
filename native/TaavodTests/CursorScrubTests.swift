import Foundation
import Testing
@testable import Taavod

@Test @MainActor func cursorMappingUsesTheWholeTrackingBoundsAndClampsOutside() {
    let bounds = CGRect(x: 10, y: 20, width: 1000, height: 600)
    #expect(CursorScrubMath.position(CGPoint(x: 10, y: 20), in: bounds, axis: .horizontal, flipped: true, reversed: false) == 0)
    #expect(CursorScrubMath.position(CGPoint(x: 510, y: 20), in: bounds, axis: .horizontal, flipped: true, reversed: false) == 0.5)
    #expect(CursorScrubMath.position(CGPoint(x: 1200, y: 20), in: bounds, axis: .horizontal, flipped: true, reversed: false) == 1)
    #expect(CursorScrubMath.position(CGPoint(x: -100, y: 20), in: bounds, axis: .horizontal, flipped: true, reversed: true) == 1)
}

@Test @MainActor func verticalScrubbingAlwaysStartsAtTheTopInEitherCoordinateSystem() {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    #expect(CursorScrubMath.position(CGPoint(x: 400, y: 0), in: bounds, axis: .vertical, flipped: true, reversed: false) == 0)
    #expect(CursorScrubMath.position(CGPoint(x: 400, y: 600), in: bounds, axis: .vertical, flipped: false, reversed: false) == 0)
    #expect(CursorScrubMath.position(CGPoint(x: 400, y: 0), in: bounds, axis: .vertical, flipped: false, reversed: false) == 1)
}

@Test @MainActor func pointerResponseCatchesUpWithoutThePreviousLongLag() {
    let response = CursorScrubMath.advance(from: 0, toward: 1, elapsed: 0.15)
    #expect(response > 0.89)
    #expect(response < 1)
    #expect(CursorScrubMath.advance(from: 0.9, toward: 0, elapsed: 1.0 / 60) < 0.75)
}

@Test @MainActor func lowPowerFrameRateRetainsTheSameResponseTime() {
    var sixtyHz = 0.0
    var thirtyHz = 0.0
    for _ in 0..<6 { sixtyHz = CursorScrubMath.advance(from: sixtyHz, toward: 1, elapsed: 1.0 / 60) }
    for _ in 0..<3 { thirtyHz = CursorScrubMath.advance(from: thirtyHz, toward: 1, elapsed: 1.0 / 30) }
    #expect(abs(sixtyHz - thirtyHz) < 0.000001)
}
