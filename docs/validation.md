# First playable validation

Date: 2026-09-08. Engine: **Godot 4.7.stable.official.5b4e0cb0f**, Windows. Visual captures use the Compatibility renderer on an NVIDIA RTX 3060. This establishes local playability, not iPhone performance or a signed iOS build.

## Reproducible checks

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate.ps1 -Capture` from the project. The wrapper requires successful markers and rejects script errors, failed checks and reported ObjectDB leaks. Logs and PNGs are generated in `artifacts/` and excluded from the source repository.

| Check | Current result and scope |
| --- | --- |
| Godot import | Passed; all gameplay scripts loaded |
| Economy / flow | 68 checks passed: spending, plot categories/proximity, caps, all four building types through tier 3, configurable tier limits, timed physical mine production, mine/Smith construction, global modifiers, wall rebuilding, pause, waves, victory, defeat, restart and construction directly under the hero |
| Combat | 44 checks passed: movement/collision, actual hero/tower arrows, kill attribution, physical/merged coin collection, Volley unlock/cooldown/impacts, route movement, wall attacks and Keep damage |
| Native touch UI | 57 checks passed: title/start, joystick drag, simultaneous movement with build/Volley, cancellation, repeated context refresh, pause/resume, visible Smith effects, three aspect ratios, max XP, retry, interrupted overlay touches, wave progress/countdown updates and cancellation of held purchases when the selected plot changes |
| World feedback / wave integration | 13 checks passed: real hits and physical pickups drive feedback, no duplicate rewards, combined pickup values, pause/resume/expiration, concurrent effect caps, restart/title cleanup and remaining counts including pending spawns |
| Full six-wave playthrough | Passed with normal starting gold/stats and actual movement, projectiles, pickups, purchases and cooldowns; no teleports, currency grants or forced kills |
| Unattended defense | Lost on wave 4; the Keep can actually be overrun |
| Actual renderer | Title, gameplay, world feedback, Smith, Smith purchase and pause captures; a separate 12-model building-progression gallery. Feedback, HUD, purchase confirmation and tier silhouettes visually reviewed |
| Portable source archive | Current executable source freshly extracted to another Windows directory without `.godot`; import, all 182 checks, full playthrough, runtime captures and progression gallery passed. Final documentation updates do not change the tested executable source |

Latest active playthrough: 128 kills, 20 purchases, 7 Volleys, 1,559 collected gold, hero level 5, Keep 450/450, victory in about 125 simulated seconds. The automated player uses complete game state to choose routes; this proves a legal winning path, not human difficulty or mobile performance. Simulation timestamps are not wall-clock benchmarks.

## Reference coverage for this playable

The polish passes add brief hit/defeat flashes and floating collected-gold totals. Nearby simultaneous pickups share one value label. A wave completion bar counts unspawned and surviving enemies, and shows a countdown between waves. The current suite contains 182 integration checks plus the normal six-wave playthrough. Continued gameplay development is authorized; pending device tests are a separate validation workstream.

The design audit also found and fixed held-purchase retargeting: moving to a different plot while holding a purchase could spend gold on the new plot. Stable plot identities now cancel only purchase touches on a selection change, preserving movement. Regression tests cover different building kinds, same-kind plots, upgrades, Smith options and hidden/reappearing selections. Building tier caps and Smith price scaling now live in balance data.

Smith and Mine upgrades now grow into substantially different structures. The complete tier gallery and runtime purchase capture were reviewed after fresh-source validation. See `docs/first_playable_acceptance.md` for the requirement-by-requirement acceptance record.

Two playability regressions were reproduced before their fixes: standing on a plot during construction trapped the hero (all four building types), and interrupting a held title/pause/result button left it assigned to a missing finger. Construction now places an overlapping hero at the nearest clear edge; lifecycle resets clear every live touch button. Both regression groups pass, as do the normal six-wave playthrough and prior checks.

| Requirement | Evidence |
| --- | --- |
| Portrait, angled simple 3D | `project.godot`, camera in `game/game.gd`, renderer captures |
| Larger scrolling level | `GameData.level()` bounds/route; camera follows hero; movement checks |
| Archer movement and bow | Combat checks use actual HeroActor and projectiles |
| Enemies, routes, waves, health/death | Combat/economy checks plus full six-wave run |
| Physical coins and live purchasing | No immediate gold credit on kill; actual magnet collection and spend/cap checks |
| Tower, Wall, Mine, Smith, Keep | Runtime actors, configured plots, visual models and gameplay checks |
| Three-tier buildings | Data/upgrade checks and visibly different models authored in `common/visuals.gd` |
| Hero-only kill XP and active ability | Hero/tower attribution tests and Volley checks; normal playthrough uses ability |
| Three nearby Smith choices | Native-touch UI checks and reviewed Smith capture; effect/cost text is visible |
| Red friendlies, green goblins, large readable objects | Original meshes and reviewed runtime captures |
| Victory / defeat / retry | Economy checks and full active/unattended sessions |
| Cross-platform source | Relative paths, pinned engine, source package, Windows/Mac launchers and handoff guide |

## Still requiring user/device feedback

- Mac import and signed iPhone export/install.
- Physical iPhone 12–16 multi-touch feel, safe areas, interruptions and sustained performance/heat.
- Human playtesting of clarity, pacing, economy and enjoyment, plus comparison to the user's exact reference commercial.
- Campaign, saved progression and store-release work are later roadmap milestones. They are not represented as complete.

The source iOS preset deliberately contains placeholder signing identity values. No GitHub remote has been published and no iOS device test is claimed.
