import CoreGraphics
import Testing

@testable import MiriCore

struct WindowPlacementTests {
    /// A 2560 by 1440 main display with a 30-point menu bar, in AppKit coordinates.
    let mainVisible = CGRect(x: 0, y: 0, width: 2560, height: 1410)

    @Test func keepsAWindowThatAlreadyFits() {
        let frame = CGRect(x: 840, y: 415, width: 880, height: 640)
        #expect(WindowPlacement.fitted(frame, in: mainVisible) == frame)
    }

    @Test func bringsAPartlyOffscreenRightWindowOntoTheSameDisplay() {
        // Reproduces #526: an 880-wide window with only 40 points visible on the right edge.
        let clipped = CGRect(x: 2520, y: 500, width: 880, height: 640)
        let fitted = WindowPlacement.fitted(clipped, in: mainVisible)
        #expect(fitted == CGRect(x: 1680, y: 500, width: 880, height: 640))
        #expect(mainVisible.contains(fitted))
    }

    @Test func clampsEveryEdgeIntoTheVisibleArea() {
        let offLeft = CGRect(x: -500, y: 400, width: 880, height: 640)
        #expect(WindowPlacement.fitted(offLeft, in: mainVisible) == CGRect(x: 0, y: 400, width: 880, height: 640))

        let offBottom = CGRect(x: 500, y: -200, width: 880, height: 640)
        #expect(WindowPlacement.fitted(offBottom, in: mainVisible) == CGRect(x: 500, y: 0, width: 880, height: 640))

        let offTop = CGRect(x: 500, y: 900, width: 880, height: 640)
        #expect(WindowPlacement.fitted(offTop, in: mainVisible) == CGRect(x: 500, y: 770, width: 880, height: 640))
    }

    @Test func clampsOnASecondaryDisplayWithNegativeCoordinates() {
        let leftDisplay = CGRect(x: -2048, y: 0, width: 2048, height: 1287)
        let clippedLeft = CGRect(x: -2200, y: 300, width: 880, height: 640)
        #expect(
            WindowPlacement.fitted(clippedLeft, in: leftDisplay)
                == CGRect(x: -2048, y: 300, width: 880, height: 640))

        let clippedRight = CGRect(x: -200, y: 300, width: 880, height: 640)
        #expect(
            WindowPlacement.fitted(clippedRight, in: leftDisplay)
                == CGRect(x: -880, y: 300, width: 880, height: 640))
    }

    @Test func shrinksAWindowLargerThanTheVisibleArea() {
        let smallDisplay = CGRect(x: 0, y: 0, width: 1280, height: 800)
        let oversized = CGRect(x: 100, y: -50, width: 1600, height: 1000)
        #expect(WindowPlacement.fitted(oversized, in: smallDisplay) == smallDisplay)
    }
}
