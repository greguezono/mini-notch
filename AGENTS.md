# MiniNotch

macOS notch quick-actions app: toggle hidden files, keep awake, empty Trash. SwiftPM package, AppKit + SwiftUI, no dependencies. Requires macOS 26 and Xcode command-line tools.

## Layout

```text
src/                      executable target MinimalNotch (product MiniNotch)
  MinimalNotchApp.swift   AppDelegate, NotchPanel, hover/hide logic
  ControlsView.swift      SwiftUI buttons row + inline error area
  PanelState.swift        panel open/hold state
  GlassSettings.swift     Liquid Glass tint + Always Show Actions settings
  SystemActions.swift     SystemActions actor + NativeFinder (CGEvent/AppleScript)
test/BehaviorTests.swift  XCTest, injected closures (no real Finder/IOKit)
assets/                   Info.plist, entitlements, icon (.icns/.png + generation prompt)
scripts/build-app.sh      release build + codesign -> build/MiniNotch.app
scripts/check-signing.py  signing regression; run after touching build-app.sh or assets
```

## Build, test, install

```sh
swift test
bash scripts/build-app.sh                      # file is not executable; use bash
python3 scripts/check-signing.py               # only after signing/packaging changes
```

Greg runs the installed copy at `/Applications/MiniNotch.app`. A rebuild does nothing until reinstalled and relaunched:

```sh
osascript -e 'quit app "MiniNotch"'
bash scripts/build-app.sh
rm -rf /Applications/MiniNotch.app && cp -R build/MiniNotch.app /Applications/MiniNotch.app
codesign --verify --strict /Applications/MiniNotch.app
open /Applications/MiniNotch.app
```

Confirm the PID changed (`pgrep -l MiniNotch`) before testing behavior.

## Signing

`build-app.sh` pins the `MiniNotch Local Signing` certificate by fingerprint and never falls back to ad-hoc. Keep the certificate, bundle identifier `local.greguezono.MinimalNotch`, and install path unchanged; changing any of them invalidates saved Accessibility/Automation permissions. The designated requirement is identifier + certificate leaf, so updates signed with the same identity retain TCC grants.

If Accessibility shows enabled but access is denied, check `tccd` logs for "Failed to match existing code requirement", then quit the app and run `tccutil reset Accessibility local.greguezono.MinimalNotch`. The reset clears only this app's stale grant; the user must approve again.

## Behavior invariants

- Hidden files: posts Command-Shift-Period to Finder's PID after an event-posting access preflight. Denied access never posts; it shows an inline error with Open Settings. A new Accessibility grant requires quitting and reopening the app. The On/Off indicator tracks this session's successful dispatches only.
- Keep awake: IOPMAssertion preventing idle system sleep only. Released on quit. Real-assertion test is opt-in via `MINIMAL_NOTCH_TEST_SLEEP=1`.
- Empty Trash: no-op when Trash is empty; otherwise Finder `empty trash` via NSAppleScript. Cancellation (-128) is silent; permission denial and timeout surface inline. Destructive confirmations were removed with user sign-off; confirm before changing that again.
- Errors render inline in the panel (expanded frame), never as alerts. A failure clears only when its own action later succeeds.
- Panel calls `makeKeyAndOrderFront` on show so `.glassEffect` renders clear, not frosted; it is a `.nonactivatingPanel` so the app is not activated.
- Tests never post keyboard events or empty the real Trash.

## History

Earlier designs (Finder preference write + restart, Trash confirmation dialogs, ad-hoc signing) were replaced and their verification logs removed. See git history before the layout flatten commit if you need them.
