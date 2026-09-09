# Mac / iPhone handoff

The current Windows checkpoint contains six playable campaign missions, saved results/unlocks, settings, tutorial guidance, an ending and interrupted-battle recovery. Working-source rendering and fresh-source headless validation passed; see [recovery_validation.md](recovery_validation.md). Assertion totals include repeated simulation comparisons and do not represent independent play scenarios. Native Mac/iPhone and Android validation remains a later or parallel workstream and does not block desktop development. See [mobile_handoff.md](mobile_handoff.md) for the Android toolchain and checklist.

## Toolchain

- Godot **4.7 stable**, standard (GDScript) edition, with matching **4.7 stable export templates** installed through Editor > Manage Export Templates. [Pinned engine download](https://godotengine.org/download/archive/4.7-stable/).
- macOS with Xcode, the iPhone SDK and signing access for the intended developer team. Record actual tested versions below instead of assuming every combination works.
- Start with an iPhone 12, then check a newer device through iPhone 16. This is a proposed device matrix; compatibility is not yet verified.

## Fresh checkout to device

1. Clone the repository or unpack the source archive. The complete project uses relative paths. No Git LFS is needed for the current small text-only source assets.
2. Import `project.godot` in Godot. Allow imports to finish, then press F5 to verify local gameplay.
3. Run all README headless commands, including profile, run-store, actor-snapshot, recovery, recovery-edge, continuation and Android Back-routing checks, plus both playthrough scripts. The current baseline/recovery suites report 725 assertions; continuation reports 1,242 assertions including 1,200 paired simulation comparisons. Require the printed success markers and no script errors. These tests use isolated or memory-only profile/run stores.
4. Open Project > Export > iOS. Replace `com.example.emberwatch` with your own unique bundle identifier and set your App Store Team ID. Select your signing configuration. The checked-in 0.3.0/build 3 preset is a handoff template, not a ready signed export.
5. Export the project to a new directory such as `builds/ios/Emberwatch.xcodeproj`. Keep exported Xcode files separate from the source project and avoid spaces in the exported project name.
6. Open the exported project in Xcode. Select your development team and physical device; resolve provisioning/signing, then build and run.
7. Re-export after source changes. Do not treat a previously exported Xcode project as the current Godot source.

The default renderer is Compatibility. The iOS simulator is useful for some checks but cannot replace physical-device validation. [Official Godot iOS export workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

## Device acceptance to record

- Native joystick movement while a second finger builds, upgrades or uses Volley; released/cancelled touches never leave movement stuck.
- Portrait HUD stays clear of the notch, Dynamic Island and home indicator. All six campaign cards, tactical briefings, stars, settings, hints and Smith effects remain readable without tooltips. Check normal and Larger Controls layouts, including Smith options above the build card.
- Pause/resume, leaving the app and returning, screen locking and interruptions do not advance the battle while paused.
- Interrupt a busy battle with enemies, arrows, upgraded structures, a damaged wall, attracted coin piles and active Volley cooldown. Relaunch and select **Continue defense**. Confirm it restores paused with matching gold, health, progression and timers, and resumes only on explicit input. No offline time should be applied. Test actual backgrounding, screen lock and process termination; a forced termination may roll back to the last successful checkpoint.
- Return to title and Continue; then test restart, a new mission, victory and defeat. Replaced/finished battles must not return through Continue. Check visible save/recovery failures using isolated fixtures, including larger controls and held-button interruption.
- Play all six missions, each containing five to seven waves: Briarwood Crossing, Amberfield Road, Stonegate March, Sunscar Bend, Moonfen Causeway and Emberfall Watch. Verify coin collection, live construction, three-tier upgrades, victory/defeat/retry, sequential unlocks, Next Mission and the campaign ending. Check Sunscar's single support-plot choice and Moonfen's higher mine limit.
- Complete a mission, change Sound, Reduced Motion, Larger Controls and Tutorial Hints, then close and relaunch the app. Confirm preferences, unlocked missions and best star/time records survive. A loss must not unlock a mission, and a weaker replay must not lower the saved records.
- Confirm first-run hints follow actual actions, can be disabled and do not consume touches. Hold title, pause and result buttons across interruptions; a new finger must still work after returning.
- Measure busy-wave frame time, memory and device temperature during an extended session. Initial target: 60 fps on iPhone 12; report actual measurements and adjust rendering/content if needed. This target has not been proven.

The unchanged version 1 profile is `user://emberwatch_profile.json`; the separate version 1 battle journal is `user://emberwatch_run.json`. Both use `.bak` recovery copies in the app's Godot user-data location. Successful terminal publication updates both run copies to prevent an old active battle returning. Corruption/future-version/write-failure checks belong in isolated test paths; preserve actual player saves. Verify visible recovery/save-failure notices and real device lifecycle delivery. Recovery passes Windows integration and continuation tests; its native iPhone behavior remains unverified.

| Evidence | Result |
| --- | --- |
| Source commit / archive | Pending |
| macOS and Xcode | Pending |
| Godot/export-template version | Required 4.7 stable; device export pending |
| Device model / iOS version | Pending |
| Fresh clone import and desktop play | Pending on Mac |
| Signed export / install / launch | Pending |
| Multi-touch and safe areas | Pending |
| Six mission wins / unlocks / ending | Passed on Windows; pending native device |
| Completed progress/settings across relaunch | Profile checks passed on Windows; pending native device |
| Full run / pause / resume / interrupted button input | Pending native device |
| Partly completed battle after process termination | Recovery implemented and Windows-tested; pending native interruption/relaunch verification |
| Busy-wave frame time, memory, heat | Pending |

## Repository policy

Commit source files, `.gd.uid` files, project metadata and non-secret export settings. Exclude `.godot/`, builds, capture logs, private keys, certificates and provisioning profiles. Credentials stay with the signing developer. Store publication and TestFlight distribution are later steps and are not required to validate the first local device build.
