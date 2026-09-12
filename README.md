# Emberwatch

An original portrait action tower-defense game inspired by the fast combat/building loop described in the supplied Kingshot-commercial design. Six missions form an offline campaign with saved unlocks and results. Working title; full-game development continues.

## Play on Windows

For the current feedback build, use [the 0.3.1 playtest guide](docs/playtest_031.md) to record gameplay and device observations.

Use **Godot 4.7 stable, standard edition**. Double-click **play_windows.cmd**, or import **project.godot** into Godot and press **F6** with the main scene open / **F5** to run the project. The launcher accepts a custom executable through `GODOT_BIN` or `tools/run_windows.ps1 -GodotPath <path>`.

1. Select **Defend the Keep** to start the next unbeaten mission, or **Campaign** to select an unlocked mission.
2. Move with **WASD / arrow keys** or drag the on-screen stick. Your archer aims and fires automatically.
3. Walk near an empty plot and click its build button. **E** builds/upgrades the nearest plot on desktop (support plots default to Mine; use buttons to choose Smith).
4. Walk near dropped coins to collect them. Building and upgrading spend the same gold during combat.
5. Hero damage earns proportional XP, even when towers land the final hit. At level 2, **Space / Volley** fires a stronger multi-target attack.
6. Protect the Keep through each mission's five to seven waves. Win to unlock the next mission; use **Next mission** or replay for a better rating. **Escape / II** pauses.

Suggested first move: build the nearby Archer Tower for 40 gold, then head north toward incoming enemies. Walls buy time; Mine coins must be collected; the Smith strengthens towers and fortifications. Smith upgrades apply for the current run. Restart resets the run.

Selected empty tower plots preview firing range before construction. Nearby upgrade panels explain the next tier's benefits before you spend gold.

Mission cards explain the strategic variation. Sunscar has one support plot, so choose a Mine or Smith. Moonfen allows two Mines. Win with at least 40%/80% Keep health for two/three stars; any victory earns one. Replaying cannot reduce your best rating or time.

After each battle, the results show battle time and remaining Keep health alongside waves, kills and collected gold.
Completed mission cards show your best completion time beside the saved star rating.

**Settings** on the title and pause screens control sound, reduced motion, larger controls and tutorial hints. Completed missions and preferences save locally with a recovery backup.

Turning sound off immediately stops active effects. Turning it back on permits new effects without replaying old ones.

**Continue defense** restores one interrupted battle **paused**, including gold, health, hero XP, buildings, enemies, flying arrows, coin piles and timers. Resume when ready; no offline time advances. Checkpoints save every five seconds of active play and on pause, title return, app suspension and normal desktop close. An abrupt termination recovers the last successful checkpoint. Restarting or choosing a new mission replaces the saved battle. Save failures appear in the UI while session play remains available.

## Play on Mac, test iPhone, and test Android

Clone/copy the entire source project, install the same **Godot 4.7 stable**, import `project.godot`, and press F5. Alternatively run `bash tools/run_macos.sh`. No Windows-only plugins or external art packages are required.

For an actual iPhone build, follow [docs/mac_iphone_handoff.md](docs/mac_iphone_handoff.md). For Android setup and the device checklist, see [docs/mobile_handoff.md](docs/mobile_handoff.md). The Android debug APK export is verified locally; iOS export, release signing and physical iPhone/Android device performance have not yet been verified.

To make a portable source archive, run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/package_source.ps1`. It creates `builds/emberwatch-source.zip` without generated caches, logs or private signing files. The recipient still needs Godot; this archive is source, not an installed iPhone app.

## What is implemented

- Six scrolling 3D battlefields with different routes, palettes and plot strategies; a controllable red archer, green goblins/scouts/brutes and a vulnerable Keep.
- Auto bow combat, real flying arrows, physical gold, hero XP, level-ups and active Volley.
- Impact flashes, floating collected-gold totals, and wave progress counting both incoming and surviving enemies.
- Fixed plots; Archer Tower, Wall, Mine and Smith; three visible tiers per building; configurable caps/costs.
- Three nearby Smith purchases: tower damage, tower attack rate, wall/Keep health.
- Portrait native multi-touch, safe-area layout, pause/restart/win/loss, original procedural art and synthesized effects.
- Campaign unlocks, best star/time records, a final ending, recoverable local profile, contextual first-run guidance and persistent accessibility/settings choices.
- Interrupted-battle recovery, compatible-content checks, validated atomic writes and terminal records that prevent finished battles returning through a backup.

## Project structure

| Location | Responsibility |
| --- | --- |
| `game/game.gd` | Run state, waves, economy and integration |
| `game/game_data.gd` | Hero/enemy/building balance and level layout |
| `game/campaign_data.gd` | Six mission layouts, wave rosters and strategic variations |
| `game/player_profile.gd` | Versioned local progress/settings and recovery |
| `game/atomic_json_store.gd` | Shared validated atomic JSON publication and backup protection |
| `game/run_store.gd`, `game/run_snapshot.gd` | Separate battle journal, compatibility and actor-state validation |
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
"$GODOT" --headless --audio-driver Dummy --path . --script tests/check_sound.gd --quit-after 4000
"$GODOT" --headless --path . --script tests/check_economy.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_combat.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_ui.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_feedback.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_profile.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_run_store.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_actor_snapshot.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_campaign.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_recovery.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_recovery_edges.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_recovery_continuation.gd --fixed-fps 60 --quit-after 8000
"$GODOT" --headless --path . --script tests/check_playthrough.gd --fixed-fps 60 --quit-after 120000
"$GODOT" --headless --path . --script tests/check_campaign_playthrough.gd --fixed-fps 60 --quit-after 150000
```

Check success markers and error output as well as exit codes: Godot may return exit 0 after a script error. Capture scenes are staged visual QA; they do not prove balance or a completed normal run.

The supplied reference is preserved in `docs/kingshot_design_reference.md`. Current decisions and boundaries are in `docs/architecture.md`; the larger roadmap remains in `PROJECT_PLAN.md`.

Current evidence is in [docs/validation.md](docs/validation.md) and [docs/recovery_validation.md](docs/recovery_validation.md). The recovery contract is in [docs/run_recovery_plan.md](docs/run_recovery_plan.md); campaign scope and remaining full-game work are in [docs/campaign_plan.md](docs/campaign_plan.md). Tests and rendered fixtures use memory-only or isolated profile/run stores and never overwrite player progress. The iOS and Android handoff presets are version **0.3.1**, build **4**; Android debug export is verified locally, while release signing and physical-device validation remain pending. See [docs/mobile_handoff.md](docs/mobile_handoff.md) for Android setup.

Building tier caps and Smith price scaling live in `game/game_data.gd`, alongside the other balance values. Routine balance changes do not require editing purchase logic.

Godot is used under its [MIT licence](https://godotengine.org/license/). All current game visuals and sound effects are authored in this source project. No commercial assets are bundled.
