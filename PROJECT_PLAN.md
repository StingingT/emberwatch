# Mobile tower-defense game — working plan

Updated: 2026-09-08

## Confirmed by the user

- Build a complete phone game inspired by the gameplay in Kingshot commercials.
- Tower defense is central to the game.
- This task acts as main architect for design, implementation order, and integration.
- Target iPhone first.
- Keep Android as a secondary mobile target using the same source and portrait gameplay; Android validation can happen later or in parallel.
- Use portrait orientation.
- Use simple, colourful 3D with an angled camera.
- The user reports access to a Mac and iPhone models from 12 through 16.
- The likely collaboration workflow is a GitHub repository that another developer can use on their Mac.
- Continue developing and polishing the desktop-playable game now. Native iPhone validation can happen later or in parallel; it does not block further gameplay development.

## Selected technical direction

- Godot **4.7 stable**, standard edition, with typed GDScript. The project and launcher pin this locally verified engine version.
- Mac collaborators should use the same engine and matching export templates.
- Develop and review the shared source project on Windows; import the same source project on Mac and export to Xcode there.
- Use iPhone 12 as the initial performance baseline and test a newer iPhone, including iPhone 16, for layout and rendering differences. These are proposed test targets, not verified compatibility claims.
- Compatibility is the implemented renderer. Keep it provisional until the scene is measured on the target iPhones.
- Keep the game original in its assets, identity, characters, interface, and level designs.

## Planned repository and Mac handoff

1. Version the Godot source project, scenes, scripts, required assets, and non-secret export configuration.
2. Include a README with the exact Godot version, required tools, import/run steps, and iOS/Android export steps. Record the tested macOS, Xcode, Android SDK, device and OS versions when a build is verified.
3. Use project-relative paths and consistent filename case so the project can be imported from another checkout location.
4. Exclude Godot's generated `.godot/` cache and build/export output folders. Use repository-local line-ending rules for text files.
5. Decide whether large binary assets need Git LFS before adding them; document its setup if used.
6. The Mac developer installs the pinned Godot version and matching export templates, imports the project, exports an Xcode project, then configures Apple signing and runs it on a physical iPhone. Record the chosen bundle identifier and signing setup instructions; keep private signing material out of Git.
7. Verify the handoff from a fresh checkout. Record the commit, tool versions, device, iOS or Android version, and results. A Windows desktop run does not establish phone compatibility.

The public repository is https://github.com/StingingT/emberwatch with main as its default branch. The published Android test release is 0.3.0; later local changes are not automatically published. No iPhone build has been tested yet.

## First playable decisions

- The user authorized continuing freely until there is a playable game, with adjustments after playing. The architect adopted the reference's core loop for this first playable.
- Native joystick movement, automatic targeting/fire while moving, nearby build/upgrade buttons, and an active Volley ability. WASD/arrows/E/Space provide desktop controls.
- Enemies attack blocking walls at fixed route positions, then continue toward the Keep after the wall falls.
- Only hero finishing blows grant XP; every kill drops collectible gold. Gold, buildings, hero levels and Smith bonuses reset for each run.
- One scrolling battlefield with six waves, an archer, goblins/scouts/brutes, Archer Towers, Walls, Smith, Mine, three building levels and visible upgrades. Friendly accents are red; enemies are green.
- The exact advertisement has not been supplied; reference fidelity can be refined after the user plays. It does not block the authorized first playable.

## Milestones and evidence boundary

1. **Playable game for feedback — delivered:** the reference's combat/building loop on Windows, with portrait controls, the six-wave defense, progression, support buildings, and win/loss/restart. Current fresh-source checks and rendered output satisfy the initial playable objective; the detailed record is in `docs/first_playable_acceptance.md`.
2. **Gameplay polish:** impact flashes, combined gold-pickup labels, wave completion progress, distinct Smith/Mine upgrades and safe purchase cancellation while moving are implemented and locally validated. Further refinements can follow play feedback; phone validation does not block that work.
3. **Mac/iPhone/Android validation, later or in parallel:** the Android toolchain is configured and the debug APK exports successfully on Windows. Import the shared source on Mac, export through Xcode, install the Android APK on a physical phone, and verify native controls, safe areas, lifecycle behavior and performance. This is required before calling a phone platform tested, and does not block milestones 1–2 or further desktop development.
4. **Complete-game development — active:** the six-mission offline campaign, persistent results/settings, first-run guidance and interrupted-battle recovery are implemented. Recovery keeps one battle, restores it paused without offline time, and preserves actor state and timers through a separate version 1 run journal. Human playtesting of pacing/balance, further presentation/audio polish and release preparation remain. Passing the current automated checks does not complete the full-game goal.

The recovery implementation and its current verification are recorded in `docs/run_recovery_plan.md` and `docs/recovery_validation.md`. Profile version 1 remains unchanged. The iOS and Android handoff presets are 0.3.1/build 4 on Godot 4.7 stable. Historical first-playable (`0a59cd5`) and campaign (`25793af`) checkpoint evidence remains available; current validation follows the recovery source. Final current-source capture/archive verification is tracked in the recovery validation record and must not be inferred from an earlier archive.

The first playable now covers the core and expanded reference loop on Windows. Continue improving that playable game under the user's authorization. Initial-playable acceptance depends on its agreed gameplay and Windows evidence; it does not require campaign or store-release completion. Android debug export is verified locally; signing, real-device touch feel and performance remain pending iPhone/Android verification. See `docs/validation.md` for current evidence, `docs/mac_iphone_handoff.md` for iOS and `docs/mobile_handoff.md` for the shared Android checklist.

## Technical references

- [Godot iOS export requirements and Xcode workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot Android export requirements](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot version control guidance](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
- [Godot renderer selection](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

The technical workflow is proposed and based on documentation. Device performance and build compatibility must be established by testing.
