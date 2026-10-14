import CoreGraphics
import Testing

@testable import MiriCore

struct WindowRecoveryTests {
    /// A 1440 by 875 laptop display below the menu bar, and a 2560 by 1415 external display to its right.
    let laptop = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let external = CGRect(x: 1440, y: 25, width: 2560, height: 1415)

    @Test func leavesReachableWindowsAlone() {
        #expect(WindowRecovery.target(for: CGRect(x: 100, y: 100, width: 800, height: 600), displays: [laptop]) == nil)
        let straddling = CGRect(x: 1000, y: 100, width: 800, height: 600)
        #expect(WindowRecovery.target(for: straddling, displays: [laptop, external]) == nil)
    }

    @Test func returnsAnEngineSliverToItsOwnDisplay() {
        // The engine parks off-screen columns with a few points showing at the display edge.
        let sliver = CGRect(x: 1435, y: 25, width: 900, height: 875)
        let target = WindowRecovery.target(for: sliver, displays: [laptop])
        #expect(target == CGRect(x: 270, y: 69, width: 900, height: 787))
    }

    @Test func keepsAWindowOnTheDisplayThatHoldsMostOfIt() {
        let parked = CGRect(x: 3990, y: 200, width: 1000, height: 700)
        let target = WindowRecovery.target(for: parked, displays: [laptop, external])
        #expect(target == CGRect(x: 2220, y: 383, width: 1000, height: 700))
    }

    @Test func movesAWindowWithNoVisiblePartToTheMainDisplay() {
        let lost = CGRect(x: -5000, y: -5000, width: 600, height: 400)
        #expect(
            WindowRecovery.target(for: lost, displays: [external, laptop])
                == CGRect(x: 2420, y: 533, width: 600, height: 400))
    }

    @Test func shrinksAWindowLargerThanItsDisplay() {
        let wide = CGRect(x: 1400, y: 25, width: 3000, height: 2000)
        let target = WindowRecovery.target(for: wide, displays: [laptop])
        #expect(target == CGRect(x: 72, y: 69, width: 1296, height: 787))
    }

    @Test func ignoresEmptyInput() {
        #expect(WindowRecovery.target(for: CGRect(x: 0, y: 0, width: 100, height: 100), displays: []) == nil)
        #expect(WindowRecovery.target(for: .zero, displays: [laptop]) == nil)
    }
}
