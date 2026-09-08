# Baro

A macOS menu bar app that watches your posture with the webcam and dims the screen when you've been slouching for too long.

Anything you can click away, you eventually click away without reading. So Baro puts itself in the way instead. The screen clears on its own once you sit up, and there's a snooze button for when the timing is bad. Everything runs on device.

The interface is Korean only for now.

## Requirements

- macOS 14 or later
- A built-in or external camera
- Xcode command line tools (Swift 5.10+) to build

## Install

There are no prebuilt binaries yet, so you'll need to build it.

```sh
git clone https://github.com/mjjoo24/Baro.git
cd Baro
swift Scripts/generate_icon.swift
./Scripts/build_app.sh release
```

This produces `build/Baro.app`. You can move it to Applications, but macOS treats the moved copy as a different app, so it'll ask for camera access again.

The app isn't signed with a Developer ID, so Gatekeeper blocks the first launch. Right click the app and choose Open, or allow it under System Settings > Privacy & Security.

## Usage

Click the menu bar icon to get started. On first launch it explains why it needs the camera before asking, so the system prompt doesn't show up out of nowhere.

Once the camera is on, wait for the preview to say it found your face, sit up straight, and start the calibration. Hold still for about five seconds and that posture becomes your baseline. Moving during the measurement cancels it and you start over. That's deliberate: a baseline averaged from two different postures is worse than no baseline.

### How the score works

Baro compares where you are now against the baseline and scores four things, 0 to 100 each. Those scores are added together and capped at 100.

| Metric | What it measures |
| --- | --- |
| Forward shift | How much closer your face is to the camera |
| Head drop | How far your eye line has fallen |
| Head tilt | How far you've tilted your head sideways |
| Head turn | How far you've turned your head to the side |

When the total stays above the threshold (45 by default) for 3 seconds, the menu bar icon switches to a warning. Five seconds after that, the screen dims. All three numbers are adjustable. The live score shows up in the settings window and on the dimmed screen too, so you can see which of the four set it off.

The baseline is relative to whatever the camera happened to see during calibration, so the camera doesn't have to sit directly in front of you. The flip side is that calibrating while already slouched makes slouching the correct posture. That one moment is worth getting right.

### What happens when you slouch

Pick one under Settings > General:

- Menu bar icon only
- Dim the screen (default)
- Blur the screen
- Turn the display off

### Presets and postures

With more than one monitor there isn't a single correct posture. A preset holds up to five of them, and scoring uses whichever one fits best at the moment. Calibrate once per screen and looking at the second monitor stops setting off false warnings.

Presets are for splitting things up by environment, like home and office. Each one can remember the display setup it was calibrated with, so docking or undocking switches presets on its own.

## FAQ

**I get warned every time I look at my second monitor.**
Add that posture to the preset under Settings > Presets > Add posture. And if your head is turned far enough that none of the registered postures explain it, Baro stops scoring altogether, so stepping away or turning to talk to someone won't dim your screen.

**Does it dim the screen during video calls?**
No. When another app is using the camera, detection and screen interventions are suspended.

**Doesn't registering more postures make detection worse?**
It does. Every posture you add widens the range that counts as acceptable. That's why presets cap at five, and why Baro asks for confirmation when a new posture looks noticeably worse than the ones already there. Register a slouch and it stays acceptable from then on.

**How much battery does it use?**
Capture is throttled to 1.5 frames per second. Posture doesn't change fast enough to need more.

## Data and privacy

Each frame is turned into a handful of face landmarks in memory and then thrown away. No code in this repo writes an image to disk or opens a network connection. What does get stored is the calibration result, which is a few face coordinates, plus your settings.

```
~/Library/Application Support/Baro/presets.json   presets and registered postures
~/Library/Preferences/com.baro.app.plist          settings
```

Face detection uses Apple's Vision framework. No external services, no model downloads.

## Uninstall

```sh
rm -rf /Applications/Baro.app
rm -rf ~/Library/Application\ Support/Baro
defaults delete com.baro.app
```

If you turned on launch at login, switch it off in settings before deleting the app.

## Development

```
Sources/BaroCore/   scoring, state machine, preset storage. No AppKit or Vision
Sources/Baro/       camera capture, Vision landmarks, SwiftUI views
Tests/              unit tests for BaroCore
```

The core logic lives in its own target so `swift test` can cover it without a real device. Anything that needs a camera or a window stays in the app target.

```sh
swift build
swift test
./Scripts/build_app.sh          # debug build, produces the .app
```

`swift run` won't get you a working app. macOS grants camera permission per `.app` bundle, not per executable, so you have to go through `build_app.sh`. It's also why the bundle always lands at the same path, since moving it would cost you the permission.

The build script touches every source file before compiling. SwiftPM was sometimes skipping changed files and linking stale objects, so edits silently didn't make it into the app. If you find a better fix, please send it.

## Contributing

Issues and pull requests are welcome. A few things to keep in mind.

- No comments in the code. Make it readable through names and structure, and put the reasoning in the pull request description.
- Touching the detection logic means adding tests in `BaroCore`. They have to run without a camera.
- For UI changes, stick to standard macOS controls and conventions.

Detection accuracy is the weakest part. Baro only looks at face landmarks, so it can't tell turning your chair apart from twisting your neck. Tracking shoulders alongside the face would fix that, and it's the contribution I'd most like to see.

## License

MIT. See `LICENSE`.
