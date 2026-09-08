# Campaign checkpoint: scope and evidence

Recorded 2026-09-08 on Windows with Godot **4.7.stable.official.5b4e0cb0f**. This checkpoint delivers a playable six-mission offline campaign, persistent completed-mission results and settings, onboarding, and a campaign ending. Full-game development remains active beyond this checkpoint; interrupted-run recovery is next.

The original first-playable acceptance at `0a59cd5` covered 182 checks and one six-wave defense. That historical record is [first_playable_acceptance.md](first_playable_acceptance.md). This document records the expanded campaign evidence.

## Implemented scope

- Six authored missions: Briarwood Crossing, Amberfield Road, Stonegate March, Sunscar Bend, Moonfen Causeway and Emberfall Watch. They vary routes, wave rosters, starting resources, construction opportunities and building limits. Briarwood retains the original regression baseline.
- Real victory unlocks the next mission. Unlocked missions remain replayable. The profile retains best stars and best completion time independently, so a weaker replay cannot lower either record. The final ending requires a victory for every authored mission.
- Gold, structures, hero XP, active enemies and Smith bonuses start fresh for each battle. Completed missions and preferences persist between sessions.
- A versioned local profile at `user://emberwatch_profile.json` validates data, stages writes, retains a previous-valid `.bak`, recovers a corrupt primary from a valid backup, and preserves unsupported future-version files. Failed writes retain this session's progress and show a visible status.
- Sound, reduced motion, larger controls and tutorial hints are available from title/pause settings. Contextual first-run guidance remains noninteractive. Campaign cards show actual tactical briefings; Sunscar explicitly presents the Gold Mine **OR** Smith choice.

## Verified checks

`tools/validate.ps1 -Capture` completed successfully in the working source. The wrapper checks process exits and required success markers and rejects script errors, explicit failures and reported ObjectDB leaks. Generated logs/PNGs remain under `artifacts/` and are excluded from source control.

| Suite | Passed | Evidence |
| --- | ---: | --- |
| Economy and battle flow | 68 | `artifacts/economy.log` |
| Combat and physical rewards | 44 | `artifacts/combat.log` |
| Native-input HUD, campaign and settings | 101 | `artifacts/ui.log`; renderer rerun in `artifacts/ui_capture.log` |
| World feedback and wave totals | 13 | `artifacts/feedback.log` |
| Persistent profile and failure/recovery cases | 57 | `artifacts/profile.log` |
| Campaign integration and lifecycle | 71 | `artifacts/campaign.log` |
| **Total** | **354** | Successful suite markers in all six logs |

Profile filesystem tests use isolated temporary saves. Campaign integration, full playthroughs and visual fixtures use memory-only profiles, preserving the player's actual progress. Deterministic integration fixtures exercise individual branches; the separate legal playthrough below supplies complete-run evidence.

UI coverage retains simultaneous joystick/purchase/Volley input, cancellation, interrupted overlay recovery and selected-plot purchase cancellation. New checks cover locked mission rejection, exact mission IDs, Next/replay/ending, silent preference loading, single setting-change events, settings navigation, hint/toast priority, reduced fading, larger controls with Smith separation, persistent save notices and briefing bounds.

## Legal campaign playthrough

`tests/check_campaign_playthrough.gd` advances one continuous campaign through actual victories and unlocks. It uses authored starting resources, normal hero movement, real projectiles, collectible coins, purchases and cooldowns. It does not grant currency, teleport the hero, force kills or pre-unlock missions. `artifacts/campaign_playthrough.log` ends with `CAMPAIGN_PLAYTHROUGH_PASS: all six missions won and unlocked through normal gameplay`.

| Mission | Waves | Kills | Purchases | Volleys | Simulated seconds | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Briarwood Crossing | 6 | 128 | 20 | 7 | 124.77 | Won |
| Amberfield Road | 5 | 121 | 23 | 6 | 119.02 | Won |
| Stonegate March | 6 | 145 | 19 | 9 | 152.05 | Won |
| Sunscar Bend | 6 | 161 | 24 | 10 | 147.50 | Won |
| Moonfen Causeway | 6 | 172 | 21 | 9 | 153.88 | Won |
| Emberfall Watch | 7 | 227 | 28 | 13 | 183.37 | Won |

All six automated wins retained Keep health 450/450. The original unattended regression still lost on wave 4 (`artifacts/playthrough.log`). The driver can inspect complete world state and choose routes continuously. These results establish legal winning paths and a functioning loss state; they do not establish human difficulty, pacing, completion time or enjoyment. Simulated time is not a frame-rate benchmark.

## Rendered and portable evidence

Actual Compatibility rendering on the NVIDIA RTX 3060 produced six staged mission views (`artifacts/mission_<id>.png`) and reported `CAMPAIGN_CAPTURE_PASS` in `artifacts/campaign_capture.log`. These show the authored terrain, routes and plot layouts; staged render fixtures are not substitutes for the legal playthrough.

Eight UI captures cover title, mission selection, mission result, final ending, settings, help, larger controls and save-failure presentation: `ui_campaign_title.png`, `ui_campaign.png`, `ui_mission_result.png`, `ui_campaign_ending.png`, `ui_settings.png`, `ui_how_to_play.png`, `ui_large_controls.png` and `ui_save_notice.png`. Campaign/help wrapping was fixed and visually reviewed after the first capture exposed overflow; six briefing-bound regressions now protect the real mission descriptions. Existing gameplay, Smith purchase and 12-model building-progression captures also passed in the working source.

A fresh campaign source archive was extracted to a separate Windows directory without the source checkout's `.godot` cache. Import, all **354 checks**, the original active/unattended scenarios and the complete legal campaign passed there with exit 0. The extraction path is recorded in `artifacts/fresh_source_path.txt` (this run: `C:\Users\guyro\AppData\Local\Temp\emberwatch-campaign-5c10a7cba24d4f88bf33db1feb90359e`). Its own `artifacts/` directory contains the successful suite/playthrough markers. Fresh-extraction verification was headless; rendered captures were reviewed separately in the working source. Only documentation changed after that runtime package was prepared.

## Scope limits and next work

- **Interrupted-run recovery is next.** The current profile preserves completed missions and settings, not a partly completed battle after process termination. Pausing while the process remains alive is covered separately.
- Human playtesting, further presentation/audio polish and release preparation remain active work. Passing this checkpoint does not finish the full-game goal.
- Mac import, iOS signing/install, physical-device multitouch, safe areas, interruptions and sustained performance/heat remain later or parallel verification. They do not block compatible desktop gameplay development.
- The exact reference advertisement has not been supplied. No claim of verified advertisement fidelity, store release, GitHub publication or tested native iPhone compatibility is made.

See [campaign_plan.md](campaign_plan.md) for scope and [mac_iphone_handoff.md](mac_iphone_handoff.md) for device validation.
