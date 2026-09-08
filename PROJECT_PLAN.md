# Mobile tower-defense game — working plan

Updated: 2026-09-08

## Confirmed by the user

- Build a complete phone game inspired by the gameplay in Kingshot commercials.
- Tower defense is central to the game.
- This task acts as main architect for design, implementation order, and integration.
- Target iPhone first.
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
2. Include a README with the exact Godot version, required tools, import/run steps, and iOS export steps. Record the tested macOS, Xcode, and iOS versions when a build is verified.
3. Use project-relative paths and consistent filename case so the project can be imported from another checkout location.
4. Exclude Godot's generated `.godot/` cache and build/export output folders. Use repository-local line-ending rules for text files.
5. Decide whether large binary assets need Git LFS before adding them; document its setup if used.
6. The Mac developer installs the pinned Godot version and matching export templates, imports the project, exports an Xcode project, then configures Apple signing and runs it on a physical iPhone. Record the chosen bundle identifier and signing setup instructions; keep private signing material out of Git.
7. Verify the handoff from a fresh checkout. Record the commit, tool versions, device, iOS version, and results. A Windows desktop run does not establish iPhone compatibility.

GitHub publication is a later step. Source is prepared locally; no remote repository has been created or pushed. No iPhone build has been tested yet.

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
3. **Mac/iPhone validation, later or in parallel:** import the shared source on Mac, export through Xcode, and verify native controls, safe areas, lifecycle behavior and performance on physical iPhones. This is required before calling the phone version tested, and does not block milestones 1–2 or further desktop development.
4. **Later complete-game scope:** use play feedback to agree campaign and progression scope, then develop saves, onboarding, audio, settings, accessibility and release preparation. These later milestones are separate from delivering the initial playable game.

The first playable now covers the core and expanded reference loop on Windows. Continue improving that playable game under the user's authorization. Initial-playable acceptance depends on its agreed gameplay and Windows evidence; it does not require campaign or store-release completion. Phone export, signing, real-device touch feel and performance remain pending Mac/iPhone verification. See `docs/validation.md` for current evidence, and `docs/mac_iphone_handoff.md` for the device checklist.

## Technical references

- [Godot iOS export requirements and Xcode workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot version control guidance](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
- [Godot renderer selection](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

The technical workflow is proposed and based on documentation. Device performance and build compatibility must be established by testing.
