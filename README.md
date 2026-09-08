# Emberwatch

An original portrait action tower-defense game inspired by the fast combat/building loop described in the supplied Kingshot-commercial design. Working title; one playable defense level for feedback.

## Play on Windows

Use **Godot 4.7 stable, standard edition**. Double-click **play_windows.cmd**, or import **project.godot** into Godot and press **F6** with the main scene open / **F5** to run the project. The launcher accepts a custom executable through `GODOT_BIN` or `tools/run_windows.ps1 -GodotPath <path>`.

1. Select **Defend the Keep**.
2. Move with **WASD / arrow keys** or drag the on-screen stick. Your archer aims and fires automatically.
3. Walk near an empty plot and click its build button. **E** builds/upgrades the nearest plot on desktop (support plots default to Mine; use buttons to choose Smith).
4. Walk near dropped coins to collect them. Building and upgrading spend the same gold during combat.
5. Hero kills earn XP. At level 2, **Space / Volley** fires a stronger multi-target attack.
6. Protect the Keep through six waves. **Escape / II** pauses; retry and title controls are on pause/results screens.

Suggested first move: build the nearby Archer Tower for 40 gold, then head north toward incoming enemies. Walls buy time; Mine coins must be collected; the Smith strengthens towers and fortifications. Smith upgrades apply for the current run. Restart resets the run.

## Play on Mac and test iPhone

Clone/copy the entire source project, install the same **Godot 4.7 stable**, import `project.godot`, and press F5. Alternatively run `bash tools/run_macos.sh`. No Windows-only plugins or external art packages are required.

For an actual iPhone build, follow [docs/mac_iphone_handoff.md](docs/mac_iphone_handoff.md). An iOS export preset is included, with placeholder identity values that the Mac developer must replace. The first playable is locally validated on Windows; a Mac/iPhone build and device performance have not yet been verified.

To make a portable source archive, run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/package_source.ps1`. It creates `builds/emberwatch-source.zip` without generated caches, logs or private signing files. The recipient still needs Godot; this archive is source, not an installed iPhone app.

## What is implemented

- A large scrolling 3D battlefield, controllable red archer, green goblins/scouts/brutes, six waves and a vulnerable Keep.
- Auto bow combat, real flying arrows, physical gold, hero XP, level-ups and active Volley.
- Impact flashes, floating collected-gold totals, and wave progress counting both incoming and surviving enemies.
- Fixed plots; Archer Tower, Wall, Mine and Smith; three visible tiers per building; configurable caps/costs.
- Three nearby Smith purchases: tower damage, tower attack rate, wall/Keep health.
- Portrait native multi-touch, safe-area layout, pause/restart/win/loss, original procedural art and synthesized effects.

## Project structure

| Location | Responsibility |
| --- | --- |
| `game/game.gd` | Run state, waves, economy and integration |
| `game/game_data.gd` | Hero/enemy/building balance and level layout |
| `game/building.gd` | Tower fire, wall health, mine production, upgrades |
| `game/world_feedback.gd` | Bounded impact flashes and combined gold pickup labels |
| `entities/` | Hero, enemies, arrows and coins |
| `common/visuals.gd`, `levels/` | Original meshes and battlefield |
| `ui/` | Touch controls, HUD and menus |
| `tests/` | Integration checks against real gameplay code |

## Validation

On Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate.ps1 -Capture`.

On Mac, run the same Godot checks directly:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --script tests/check_economy.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_combat.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_ui.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_feedback.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_playthrough.gd --fixed-fps 60 --quit-after 120000
```

Check success markers and error output as well as exit codes: Godot may return exit 0 after a script error. Capture scenes are staged visual QA; they do not prove balance or a completed normal run.

The supplied reference is preserved in `docs/kingshot_design_reference.md`. Current decisions and boundaries are in `docs/architecture.md`; the larger roadmap remains in `PROJECT_PLAN.md`.

Building tier caps and Smith price scaling live in `game/game_data.gd`, alongside the other balance values. Routine balance changes do not require editing purchase logic.

Godot is used under its [MIT licence](https://godotengine.org/license/). All current game visuals and sound effects are authored in this source project. No commercial assets are bundled.
