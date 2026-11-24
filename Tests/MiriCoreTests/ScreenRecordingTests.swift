import Testing

@testable import MiriCore

private final class FakeScreenRecording: ScreenRecordingAccess {
    var isGranted: Bool
    let grantsOnRequest: Bool
    private(set) var prompts = 0

    init(granted: Bool, grantsOnRequest: Bool = false) {
        isGranted = granted
        self.grantsOnRequest = grantsOnRequest
    }

    func request() -> Bool {
        if !isGranted {
            prompts += 1
            isGranted = grantsOnRequest
        }
        return isGranted
    }
}

struct ScreenRecordingTests {
    @Test func turningOnWithoutPermissionPromptsAndStaysOff() {
        let access = FakeScreenRecording(granted: false)
        #expect(access.switchValue(wanting: true) == false)
        #expect(access.prompts == 1)
    }

    @Test func turningOnSavesOnWhenThePromptGrantsPermission() {
        let access = FakeScreenRecording(granted: false, grantsOnRequest: true)
        #expect(access.switchValue(wanting: true))
        #expect(access.prompts == 1)
    }

    @Test func turningOnWithPermissionSavesOnWithoutAPrompt() {
        let access = FakeScreenRecording(granted: true)
        #expect(access.switchValue(wanting: true))
        #expect(access.prompts == 0)
    }

    @Test func turningOffNeverPrompts() {
        let access = FakeScreenRecording(granted: false)
        #expect(access.switchValue(wanting: false) == false)
        #expect(access.prompts == 0)
    }

    @Test func aRevokedGrantTurnsASavedSwitchOffWithoutAPrompt() {
        let access = FakeScreenRecording(granted: true)
        #expect(access.revokes(true) == false)
        access.isGranted = false
        #expect(access.revokes(true))
        #expect(access.revokes(false) == false)
        #expect(access.prompts == 0)
    }
}
