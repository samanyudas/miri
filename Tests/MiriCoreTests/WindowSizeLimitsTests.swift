import CoreGraphics
import Testing

@testable import MiriCore

struct WindowSizeLimitsTests {
    /// The Settings window's minimum: the 880 by 640 design size.
    let minimum = CGSize(width: 880, height: 640)

    @Test func keepsAFrameAtLeastTheMinimum() {
        let frame = CGRect(x: 444, y: 300, width: 900, height: 700)
        #expect(WindowSizeLimits.frame(frame, minimum: minimum) == frame)
        let wide = CGRect(x: 0, y: 46, width: 2048, height: 1286)
        #expect(WindowSizeLimits.frame(wide, minimum: minimum) == wide)
    }

    @Test func growsATooSmallFrameDownFromItsTopEdge() {
        // An Accessibility resize to 700 by 500 keeps the top-left corner, at x 444 and top 1000.
        let small = CGRect(x: 444, y: 500, width: 700, height: 500)
        let limited = WindowSizeLimits.frame(small, minimum: minimum)
        #expect(limited == CGRect(x: 444, y: 360, width: 880, height: 640))
        #expect(limited.maxY == small.maxY)
    }

    @Test func growsEachSideOnItsOwn() {
        let narrow = CGRect(x: 0, y: 0, width: 839, height: 700)
        #expect(WindowSizeLimits.frame(narrow, minimum: minimum).size == CGSize(width: 880, height: 700))
        let short = CGRect(x: 0, y: 0, width: 950, height: 560)
        #expect(WindowSizeLimits.frame(short, minimum: minimum).size == CGSize(width: 950, height: 640))
    }
}
