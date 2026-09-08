# Campaign checkpoint validation

Date: 2026-09-08. Engine: **Godot 4.7.stable.official.5b4e0cb0f**, Windows. The current campaign checkpoint passes **354 checks** and legal winning playthroughs of all six missions. Visual captures use the Compatibility renderer on an NVIDIA RTX 3060. This establishes local playability, not iPhone performance or a signed iOS build. Full-game work remains active; interrupted-run recovery is next.

The earlier **182-check first-playable acceptance at `0a59cd5` is historical**. Its scope and archive evidence remain in [first_playable_acceptance.md](first_playable_acceptance.md). The current campaign, profile and UI evidence is detailed in [campaign_validation.md](campaign_validation.md).

## Reproducible checks

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate.ps1 -Capture` from the project. The wrapper requires successful markers and rejects script errors, failed checks and reported ObjectDB leaks. Logs and PNGs are generated in `artifacts/` and excluded from the source repository.

| Check | Current result and scope |
| --- | --- |
| Godot import | Passed; all gameplay scripts loaded |
| Economy / flow | 68 checks passed: spending, plot categories/proximity, caps, all four building types through tier 3, configurable tier limits, timed physical mine production, mine/Smith construction, global modifiers, wall rebuilding, pause, waves, victory, defeat, restart and construction directly under the hero |
| Combat | 44 checks passed: movement/collision, actual hero/tower arrows, kill attribution, physical/merged coin collection, Volley unlock/cooldown/impacts, route movement, wall attacks and Keep damage |
| Native touch UI | 101 checks passed: prior touch/pause/purchase regressions plus mission cards and locking, Next/replay/ending, settings, help, hints, larger controls, save notices and wrapped mission briefings |
| World feedback / wave integration | 13 checks passed: real hits and physical pickups drive feedback, no duplicate rewards, combined pickup values, pause/resume/expiration, concurrent effect caps, restart/title cleanup and remaining counts including pending spawns |
| Local profile | 57 checks passed: completed-mission/settings roundtrips, best-record preservation, validated writes, valid-backup recovery, future-schema protection, write failures and retry; isolated test profiles |
| Campaign integration | 71 checks passed: mission locks/unlocks, route/plot/wave replacement, run resets, ratings, replay records, settings/tutorial application, save-failure presentation and final-campaign completion |
| Total integration checks | **354 passed**: 68 economy + 44 combat + 101 UI + 13 feedback + 57 profile + 71 campaign |
| Original six-wave playthrough | Passed with normal starting gold/stats and actual movement, projectiles, pickups, purchases and cooldowns; no teleports, currency grants or forced kills |
| Full six-mission campaign | Passed continuously through real victories and unlocks, using each mission's normal starting resources and legal movement, combat and purchases |
| Unattended defense | Lost on wave 4; the Keep can actually be overrun |
| Actual renderer in working source | Existing gameplay/Smith/pause/progression captures, all six staged mission views and eight campaign/settings/help/result UI captures. Campaign briefings and help text were checked after fixing wrapping |
| Portable campaign source | Fresh Windows extraction passed import, all **354 checks**, original active/unattended scenarios and the full legal campaign. This fresh extraction ran headless checks/playthroughs; the rendered evidence above was reviewed separately in the working source |

Original Briarwood regression playthrough: 128 kills, 20 purchases, 7 Volleys, 1,559 collected gold, hero level 5, Keep 450/450, victory in 124.77 simulated seconds. The six-mission results are recorded in [campaign_validation.md](campaign_validation.md). The automated player uses complete game state to choose routes; this proves legal winning paths, not human difficulty or mobile performance. Simulation timestamps are not wall-clock benchmarks.

## Reference coverage retained by the campaign

The polish passes add brief hit/defeat flashes and floating collected-gold totals. Nearby simultaneous pickups share one value label. A wave completion bar counts unspawned and surviving enemies, and shows a countdown between waves. Campaign missions preserve that combat/building loop while adding authored routes, tactical plot variations, saved results, settings and guidance. The current suite contains 354 integration checks plus the original regression scenarios and legal campaign playthrough. Pending device tests are a later or parallel workstream and do not block compatible desktop development.

The design audit also found and fixed held-purchase retargeting: moving to a different plot while holding a purchase could spend gold on the new plot. Stable plot identities now cancel only purchase touches on a selection change, preserving movement. Regression tests cover different building kinds, same-kind plots, upgrades, Smith options and hidden/reappearing selections. Building tier caps and Smith price scaling now live in balance data.

Smith and Mine upgrades grow into substantially different structures. The complete tier gallery and runtime purchase capture remain covered by current working-source renderer checks. The requirement-by-requirement initial acceptance record is historical and remains in [first_playable_acceptance.md](first_playable_acceptance.md).

Two playability regressions were reproduced before their fixes: standing on a plot during construction trapped the hero (all four building types), and interrupting a held title/pause/result button left it assigned to a missing finger. Construction now places an overlapping hero at the nearest clear edge; lifecycle resets clear every live touch button. Both regression groups pass, as do the normal six-wave playthrough and prior checks.

| Requirement | Evidence |
| --- | --- |
| Portrait, angled simple 3D | `project.godot`, camera in `game/game.gd`, renderer captures |
| Larger scrolling levels | `CampaignData.missions()` supplies authored bounds/routes/plots; camera follows hero; movement and campaign-transition checks |
| Archer movement and bow | Combat checks use actual HeroActor and projectiles |
| Enemies, routes, waves, health/death | Combat/economy checks plus full six-wave run |
| Physical coins and live purchasing | No immediate gold credit on kill; actual magnet collection and spend/cap checks |
| Tower, Wall, Mine, Smith, Keep | Runtime actors, configured plots, visual models and gameplay checks |
| Three-tier buildings | Data/upgrade checks and visibly different models authored in `common/visuals.gd` |
| Hero-only kill XP and active ability | Hero/tower attribution tests and Volley checks; normal playthrough uses ability |
| Three nearby Smith choices | Native-touch UI checks and reviewed Smith capture; effect/cost text is visible |
| Red friendlies, green goblins, large readable objects | Original meshes and reviewed runtime captures |
| Victory / defeat / retry | Economy checks and full active/unattended sessions |
| Six missions, ratings and campaign ending | Campaign integration checks, native UI checks, six legal wins/unlocks and reviewed mission/result screens |
| Saved progress/settings and guidance | Isolated profile roundtrips/recovery tests, real root preference application, tutorial conditions and visible save-failure notices |
| Cross-platform source | Relative paths, pinned engine, source package, Windows/Mac launchers and handoff guide |

## Still requiring user/device feedback

- Mac import and signed iPhone export/install.
- Physical iPhone 12–16 multi-touch feel, safe areas, interruptions and sustained performance/heat.
- Human playtesting of clarity, pacing, economy and enjoyment, plus comparison to the user's exact reference commercial.
- Interrupted-run recovery is the next active implementation step. The current profile saves completed missions and settings; terminating the process during a battle does not yet restore that battle.
- Further presentation/audio polish and release preparation remain in the active full-game plan.

The source iOS preset deliberately contains placeholder signing identity values. No GitHub remote has been published and no iOS device test is claimed.
