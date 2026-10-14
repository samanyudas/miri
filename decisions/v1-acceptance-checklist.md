# V1 acceptance checklist

Status: accepted on 14 October 2026.

This checklist has two levels.
The quick check runs during everyday development, so builds and iteration stay fast.
The release check is the v1 multi-monitor release blocker.
It runs as v1 approaches, and whenever Sam asks for it.

## Quick check

Run on whichever setup is available, with at least 5 windows per strip.

1. Scroll each strip in a horizontal and then a vertical arrangement.
   No off-screen window moves to another display.
2. Scroll one strip.
   No other strip changes its scroll position or focus.
3. Move focus and a window to the other display in both directions.
4. Unplug and replug the external display 3 times.
   No window is lost, and strips return when macOS returns their Space.
5. Close and open the lid once with an external display connected.
6. Sleep and wake 3 times.
7. Force-quit the engine once.
   Miri restarts it and restores the layout.

Any failure blocks merging the change that caused it.

## Release check

The sections below define the release check.

### Pass rules

Each scenario runs on the university setup and the home setup.
Mixed arrangements run last, on a friend's MacBook Pro with three displays.
Each display has at least 2 native Spaces, and each strip holds at least 10 windows.
Use apps with different window behaviors, including a browser, a terminal, an Electron app, and a document app.

A single failure fails the blocker.
A failure includes a lost window, a window on the wrong display, a window that macOS relocates off-screen, or an engine that does not recover.
After any fix, the full checklist runs again from the start.
The release candidate build must pass 3 consecutive full runs.

### Arrangements and scrolling

1. Arrange displays horizontally, with the external display on the left and then on the right.
2. Arrange displays vertically, with the external display above and then below.
3. Repeat each arrangement with the laptop as the main display and then with the external display as the main display.
4. Scroll every strip to both ends with the keyboard and the trackpad.
   No off-screen window moves to another display.
   Repeat trackpad scrolling with each trackpad scrolling setting, and confirm that the correct strip moves.
5. Scroll one strip.
   No other strip changes its scroll position or focus.
6. Repeat scrolling on displays with different resolutions and scaling, including the 32-inch TV.

### Monitor navigation

1. Move focus to the display in each direction where one exists.
2. Move a window to the display in each direction where one exists.
   The window keeps its column and its width relative to the display.
3. Issue a monitor command toward a side with no display.
   Nothing moves.

### Display changes

1. Unplug and replug the external display 50 times.
   Include unplugging during a scroll animation and during a window move.
2. Close and open the lid 20 times with two external displays connected.
3. Sleep and wake 50 times, including at least one overnight sleep.
4. Rearrange displays in **System Settings > Displays** while Miri runs.
5. Change the main display while Miri runs.
6. Change the resolution and scaling of a connected display.
7. Unplug a display that shows a native fullscreen window.

After each change, every window remains reachable.
Strips return to their display when macOS returns their Space.

### Engine recovery

1. Force-quit the engine 10 times during a multi-monitor session.
   Miri restarts it, and startup session restore returns the layout.
2. Force-quit the engine 3 times within 5 minutes.
   Miri stops restarting it and shows the failure, logs, and a manual restart control.

### Endurance

1. Run an 8-hour working session with two displays and no restarts.
   Engine memory use stays stable.
2. Complete the 2-week daily-use period from the release scope.
