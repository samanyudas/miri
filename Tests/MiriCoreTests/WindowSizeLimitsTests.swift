import CoreGraphics
import Testing

@testable import MiriCore

struct WindowSizeLimitsTests {
    /// The Settings window's limits: the 880 by 640 design size, up to 1100 points wide and any height.
    let minimum = CGSize(width: 880, height: 640)
    let maximum = CGSize(width: 1100, height: CGFloat.greatestFiniteMagnitude)

    @Test func keepsAFrameWithinTheLimits() {
        let frame = CGRect(x: 444, y: 300, width: 900, height: 700)
        #expect(WindowSizeLimits.frame(frame, minimum: minimum, maximum: maximum) == frame)
    }

    @Test func growsATooSmallFrameDownFromItsTopEdge() {
        // An Accessibility resize to 700 by 500 keeps the top-left corner, at x 444 and top 1000.
        let small = CGRect(x: 444, y: 500, width: 700, height: 500)
        let limited = WindowSizeLimits.frame(small, minimum: minimum, maximum: maximum)
        #expect(limited == CGRect(x: 444, y: 360, width: 880, height: 640))
        #expect(limited.maxY == small.maxY)
    }

    @Test func limitsEachSideOnItsOwn() {
        let narrow = CGRect(x: 0, y: 0, width: 839, height: 700)
        #expect(
            WindowSizeLimits.frame(narrow, minimum: minimum, maximum: maximum).size == CGSize(width: 880, height: 700))
        let wide = CGRect(x: 0, y: 0, width: 1400, height: 800)
        #expect(
            WindowSizeLimits.frame(wide, minimum: minimum, maximum: maximum).size == CGSize(width: 1100, height: 800))
    }
}
