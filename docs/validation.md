# Current validation: recovery checkpoint

## Hero danger integration

The first Combat & Visual Identity integration adds 100 hero health, nearby enemy strikes with a 0.7-second marked wind-up, eight-second respawn and 1.5-second protection. Timings and reach are balance data. Headless hero-danger checks cover hit/dodge, pause, death without mission termination, blocked downed actions, restoration and protection. Actual rendering of `hero_attack_warning.png` and `hero_down.png` was reviewed. Existing economy/combat/UI/feedback/profile/run-store checks passed; actor snapshot tests were extended for the added combat fields and passed, as did recovery/continuation and Android routing. All six campaign missions remain legally winnable. The playthrough movement check excludes only a verified dead-to-alive transition at the authored respawn position, not arbitrary teleports.

New enemy roles and abilities remain unimplemented, and no human combat-feel or phone validation is claimed. This source integration is newer than the 0.3.1 downloads. Existing older active battle snapshots have a different combat fingerprint and cannot be continued under the new rules; campaign results/settings retain their existing format.

## Tower coverage before construction

Empty tower plots show the configured level-one range while selected. Constructed towers continue to show their current-tier range; support and wall plots do not show tower ranges. Resuming restores a range ring hidden by the paused selection update even if the selected plot has not changed. Economy checks passed 77 assertions, recovery checks passed 165, and the Compatibility-rendered `tower_plot_preview.png` was visually reviewed. This source follow-up is not part of the existing 0.3.1 APK/ZIP.

## Live upgrade previews, after 0.3.1

The nearby upgrade panel now previews next-tier tower arrow damage/range (including current Smith damage bonuses), mine gold per interval, wall health after full repair (including fortification), and the Smith's maximum per-purchase discount. Costs and purchase rules remain unchanged. The full headless regression wrapper passed with exit 0. The expanded economy suite then passed 74 checks, including real tower/mine offers, Smith discounts, damaged fortified walls, tower damage bonuses and capped buildings. Portrait captures for tower, wall, mine and Smith offers were visually reviewed (`upgrade_bend.png`, `upgrade_choke.png`, `upgrade_quarry.png`, `smith.png`). These source changes are newer than the packaged 0.3.1 APK and ZIP.

## Local test delivery 0.3.1, 2026-09-12

The complete headless validation wrapper passed after integrating audio muting, mission-result statistics and campaign best-time labels (including 137 UI checks and six sound checks). Android version 0.3.1/code 4 exported successfully and passed APK v2/v3 signature verification. Its package metadata was read back. See `mobile_handoff.md` for the artifact and hash. Physical-device testing and human playtest feedback remain required; this is a local test build, not full-game acceptance or a newly published release.

## Campaign records, 2026-09-12

Mission cards now display the profile's best completion time for completed, unlocked missions. Unbeaten missions show no time record. The controller supplies the existing profile field without changing persistence or unlock rules. The Compatibility-rendered UI suite passed 137 checks, including displayed time and absent-record behavior; `artifacts/ui_campaign.png` was visually reviewed. Campaign lifecycle checks passed 71 assertions. Human pacing/balance feedback and physical-device validation remain outstanding.

## Mission result feedback, 2026-09-12

Victory and defeat summaries now receive the actual elapsed battle time and Keep health from the run controller. The results show minutes/seconds and the remaining health percentage alongside waves, kills and collected gold. The existing portrait card accommodates all five rows without moving its actions. The UI suite passed 135 checks in the Compatibility renderer, including a 127.9-second/315-of-450-health fixture displayed as 2:07 and 70%; `artifacts/ui_mission_result.png` was visually reviewed. Campaign lifecycle checks also passed all 71 assertions. These results do not establish human balance or phone performance.

## Audio follow-up, 2026-09-12

Disabling sound now stops all active effect players immediately. Re-enabling sound starts no old effects and allows a fresh event immediately; ordinary duplicate-event throttling remains active. `tests/check_sound.gd` exercises six playback-state checks using actual AudioStreamPlayers with the Dummy audio driver. It allows the audio mixer to retire stopped playbacks before shutdown. This verifies playback control, not perceived audio quality on speakers or phones.

The complete headless `tools/validate.ps1` run passed with exit 0 after this change, including the new sound suite, all existing gameplay/UI/storage/recovery suites, the active win/unattended loss scenarios and all six campaign playthroughs. No new renderer or physical-device validation is claimed for this audio-only change. Full-game completion remains open.

Date: 2026-09-09. Engine: **Godot 4.7.stable.official.5b4e0cb0f**, Windows. The six-mission campaign and interrupted-battle recovery are implemented. The complete working-source `tools/validate.ps1 -Capture` run and a fresh-source headless run passed with exit 0. The Android debug APK export also passed and its v2/v3 signature verified. Compatibility rendering was reviewed on an NVIDIA RTX 3060. This establishes Windows/source behavior, not a signed iPhone build or physical-device performance.

The current detailed evidence is [recovery_validation.md](recovery_validation.md). The earlier first-playable checkpoint **`0a59cd5`** and campaign checkpoint **`25793af`** are historical; their evidence remains in [first_playable_acceptance.md](first_playable_acceptance.md) and [campaign_validation.md](campaign_validation.md). Full-game development remains active.

## Reproduce

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate.ps1 -Capture` from the project. The wrapper checks success markers and error output as well as exit status, rejecting script errors, explicit failures and reported ObjectDB leaks. README lists the equivalent direct Godot commands for Mac. Logs and captures are generated under `artifacts/`, outside source control.

| Suite | Passing assertions |
| --- | ---: |
| Economy and battle flow | 68 |
| Combat and physical rewards | 44 |
| Native-input UI, campaign, settings and Continue | 134 |
| Feedback and wave totals | 13 |
| Profile compatibility and storage recovery | 57 |
| Campaign lifecycle | 71 |
| Actor snapshots and silent restoration | 71 |
| Run journal and shared atomic storage | 68 |
| Root recovery/lifecycle/validation | 165 |
| Terminal identities and collision edges | 25 |
| Android Back routing | 9 |
| Paired continuation over 20 seconds | 1,242, including 1,200 per-step comparisons |

The first eleven suites total 725 assertions, including 9 Android Back-routing checks. These counts include repeated state assertions; they are not counts of independent gameplay scenarios. Tests use isolated paths or memory-only profile/run stores and preserve player files.

## Outcomes and evidence boundaries

- **Recovery:** one resumable battle, five-second deferred checkpoints plus pause/title/suspension/desktop-close handling; Continue restores paused with no offline time. Ordered actors, current rewards, modifiers, health and exact timers survive. Validation, backups, terminal retirement and idempotent profile reconciliation are covered.
- **Continuation:** a fresh JSON restoration matched uninterrupted real-root simulation at every step for 20 seconds. A second restoration after kills, collection and wall destruction also matched, without duplicated effects. Both runs reached the next authored wave; the progressed checkpoint restored identically.
- **Legal play:** the original Briarwood win and every campaign mission passed again under normal resources, movement, purchases and combat. The unattended defense still lost on wave 4. Complete-state automated play proves legal winning paths, not human pacing or difficulty.
- **Presentation:** actual rendering covered gameplay, Smith, pause, three-tier tower/wall/mine/Smith progression, six mission maps, campaign/settings/help/results and recovery title/paused/resumed views. Staged captures are visual evidence, not balance evidence.
- **Portable source:** the current recovery source passed import, every headless suite, original active/unattended scenarios and all six legal wins after extraction into a fresh Windows directory. The path and packaging evidence are recorded in [recovery_validation.md](recovery_validation.md). Rendering was checked separately in the working source.

## Reference loop retained

Portrait angled 3D, scrolling routes, move-and-auto-fire combat, real arrows, collectible gold, hero damage XP, active Volley, nearby live purchases, blocking/destructible walls, mines, Smith modifiers, three visible structure tiers and a vulnerable Keep remain covered. Campaign missions add route and plot strategies while preserving that loop. Previous construction-under-hero and held-purchase/input-interruption regressions remain covered by the expanded suites.

The implemented recovery contract is [run_recovery_plan.md](run_recovery_plan.md). The active roadmap is [campaign_plan.md](campaign_plan.md) and `PROJECT_PLAN.md`.

## Still pending

Human feedback on clarity, campaign pacing, economy, difficulty and enjoyment; further presentation/audio polish and release preparation remain. Passing this checkpoint does not finish the full-game goal.

Mac import, signed iOS export/install, Android physical-device install, Android release signing, real iPhone 12-16 and Android multi-touch/safe areas, operating-system interruption/relaunch behavior, sustained frame time, memory and heat require native testing. These later or parallel checks do not block compatible desktop development. The iOS and Android presets are **0.3.0/build 3**, with placeholder signing identities. No native-phone validation, GitHub publication, TestFlight/Play Store/App Store release or exact-commercial fidelity is claimed.

Current combat integration: hunters are introduced in Amberfield and Stonegate. Hero/Volley damage now grants proportional fractional XP immediately, capped at health removed; tower damage and killing blows add no bonus. The complete validation wrapper passed, including all six legal campaign wins. Targeted fractional-XP actor and interrupted-run round trips also passed. The hunter model was inspected in a rendered portrait encounter; human playtest acceptance is still pending. Existing 0.3.1 APKs do not contain these changes.

Ranged enemy integration: full validation wrapper passed with crossbow goblins in Amberfield and Stonegate, including six legal campaign wins. RANGED_ENEMY_PASS covers wind-up, release-time aim, dodge, shooter death, hostile projectile round trip, pause and single swept impact. An actual portrait capture passed and was inspected. The UI suite passed again after correcting remaining kill-XP hints.
