# Mac / iPhone handoff

## Toolchain

- Godot **4.7 stable**, standard (GDScript) edition, with matching **4.7 stable export templates** installed through Editor > Manage Export Templates. [Pinned engine download](https://godotengine.org/download/archive/4.7-stable/).
- macOS with Xcode, the iPhone SDK and signing access for the intended developer team. Record actual tested versions below instead of assuming every combination works.
- Start with an iPhone 12, then check a newer device through iPhone 16. This is a proposed device matrix; compatibility is not yet verified.

## Fresh checkout to device

1. Clone the repository or unpack the source archive. The complete project uses relative paths. No Git LFS is needed for the current small text-only source assets.
2. Import `project.godot` in Godot. Allow imports to finish, then press F5 to verify local gameplay.
3. Run the README's headless checks. Require the printed success markers and no script errors.
4. Open Project > Export > iOS. Replace `com.example.emberwatch` with your own unique bundle identifier and set your App Store Team ID. Select your signing configuration. The checked-in values are a prototype template, not a ready signed export.
5. Export the project to a new directory such as `builds/ios/Emberwatch.xcodeproj`. Keep exported Xcode files separate from the source project and avoid spaces in the exported project name.
6. Open the exported project in Xcode. Select your development team and physical device; resolve provisioning/signing, then build and run.
7. Re-export after source changes. Do not treat a previously exported Xcode project as the current Godot source.

The default renderer is Compatibility. The iOS simulator is useful for some checks but cannot replace physical-device validation. [Official Godot iOS export workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

## Device acceptance to record

- Native joystick movement while a second finger builds, upgrades or uses Volley; released/cancelled touches never leave movement stuck.
- Portrait HUD stays clear of the notch, Dynamic Island and home indicator. Text and Smith effects are readable without tooltips.
- Pause/resume, leaving the app and returning, screen locking and interruptions do not advance the battle while paused.
- Play a full six-wave defense, including coin collection, three-tier upgrades and victory/defeat/retry.
- Measure busy-wave frame time, memory and device temperature during an extended session. Initial target: 60 fps on iPhone 12; report actual measurements and adjust rendering/content if needed. This target has not been proven.

| Evidence | Result |
| --- | --- |
| Source commit / archive | Pending |
| macOS and Xcode | Pending |
| Godot/export-template version | Required 4.7 stable; device export pending |
| Device model / iOS version | Pending |
| Fresh clone import and desktop play | Pending on Mac |
| Signed export / install / launch | Pending |
| Multi-touch and safe areas | Pending |
| Full run / pause / resume | Pending |
| Busy-wave frame time, memory, heat | Pending |

## Repository policy

Commit source files, `.gd.uid` files, project metadata and non-secret export settings. Exclude `.godot/`, builds, capture logs, private keys, certificates and provisioning profiles. Credentials stay with the signing developer. Store publication and TestFlight distribution are later steps and are not required to validate the first local device build.
