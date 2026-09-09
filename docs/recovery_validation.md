# Recovery checkpoint: scope and evidence

Recorded 2026-09-09 on Windows with **Godot 4.7.stable.official.5b4e0cb0f**. Interrupted-battle recovery is implemented and locally validated. The complete working-source `tools/validate.ps1 -Capture` run and a separate fresh-source headless run both passed with exit 0. Compatibility renderer captures were reviewed on an NVIDIA RTX 3060. The iOS and Android export presets are **0.3.0 / build 3**; this is source metadata, not a signed or tested phone release.

The first-playable checkpoint `0a59cd5` and campaign checkpoint `25793af` are historical. Their records remain in [first_playable_acceptance.md](first_playable_acceptance.md) and [campaign_validation.md](campaign_validation.md). This document describes current recovery evidence. The full-game goal remains active.

## Implemented behavior

- One interrupted battle is available through **Continue defense**, with mission, wave and elapsed-time summary. Continue reconstructs it **paused** and clears held input. No offline time advances.
- Checkpoints occur every five seconds of active simulation through a deferred callback after the current step, plus pause, return to title, app-suspension notification and normal desktop close. Abrupt termination can recover only the last successful checkpoint, not unsaved actions since it.
- Run gold, collected gold, kills, Keep health, Smith modifiers, hero tier/XP, wave progress, ordered enemies, buildings, flying arrows and distinct physical coin piles retain their saved positions and timers. Restoration neither spends money nor repeats XP, rewards, impacts, mining or construction effects. Signed idle tower and wave timers are preserved.
- The existing profile remains **version 1**. `game/atomic_json_store.gd` supplies shared validated atomic publication and backup mechanics; the separate `user://emberwatch_run.json` journal has its own **version 1** envelope. Profile and run owners retain separate data responsibilities.
- Content fingerprints cover mission gameplay, ordered waves, balance and collision footprints while excluding cosmetic names/descriptions/palettes. Incompatible state cannot silently resume; future-version files remain protected. Validation finishes before replacing the world.
- Victory/loss/replacement terminal records reach both run copies on successful publication, so backup recovery cannot resurrect a retired battle. Pending victory outcomes reconcile through the existing best-result profile API, making retries idempotent.
- An older pending victory is reconciled before a newer battle replaces its journal. A new battle that finishes before its first checkpoint can still publish its own terminal identity; this includes a zero-health loss. Failures stay visible, and the session remains playable without claiming durable success.
- Malformed hero positions inside the Keep or an occupied structure are rejected. Valid float32 coordinates at runtime collision edges remain accepted. Full schema checks also cover finite values, limits, IDs/targets, wave counts and scaled health.

The exact APIs, schemas and restoration order are in [run_recovery_plan.md](run_recovery_plan.md).

## Automated evidence

The wrapper requires each success marker and checks error output as well as process status. It rejects script errors, reported failures and ObjectDB leaks. These are **assertion counts**, not counts of independent play scenarios.

| Suite | Passing assertions | Working-source log |
| --- | ---: | --- |
| Economy and battle flow | 68 | `artifacts/economy.log` |
| Combat and physical rewards | 44 | `artifacts/combat.log` |
| Native-input HUD, campaign, settings and Continue | 134 | `artifacts/ui.log` |
| Feedback and wave totals | 13 | `artifacts/feedback.log` |
| Existing profile compatibility and failure/recovery | 57 | `artifacts/profile.log` |
| Campaign integration and lifecycle | 71 | `artifacts/campaign.log` |
| Actor JSON snapshots and silent restoration | 71 | `artifacts/actor_snapshot.log` |
| Run journal, atomic storage and retirement | 68 | `artifacts/run_store.log` |
| Root recovery, lifecycle and validation | 165 | `artifacts/recovery.log` |
| Terminal identities and collision-edge validation | 25 | `artifacts/recovery_edges.log` |
| Android Back routing | 9 | `artifacts/android.log` |
| Continuation proof | 1,242, including 1,200 per-step comparisons | `artifacts/recovery_continuation.log` |

The first eleven suites contain **725 assertions**, including 9 Android Back-routing checks. The continuation suite separately exercises one 20-second paired simulation, not 1,242 independent scenarios. Tests use unique isolated filesystem paths or memory-only stores. They do not overwrite player profile/run files.

The continuation harness starts a busy wave with a tiered tower, wounded fortified wall, due mine, Smith effects, injured enemies, hero/tower/Volley arrows, attracted gold and nonzero timers. After a JSON round trip into a fresh root, both worlds receive identical movement, ability inputs and cosmetic random streams. Every step compares all ordered snapshot fields with absolute numeric tolerance 0.0002. Fixture grants end before comparison; subsequent damage, kills, XP, mining and pickups come from real gameplay.

At **0.150 simulated seconds**, kills and a pickup had occurred and the wall had been destroyed: kills 4, collected gold 13, wall absent. The test restored this consumed-effect boundary again into another fresh root and continued without duplication. At 10 seconds both runs had cleared wave 1 with 8 kills. At 20 seconds both were in wave 2 with 13 kills, 1,622 gold and 5 living enemies. The final paused checkpoint also validated and reconstructed identically.

## Gameplay and rendered evidence

The original legal Briarwood playthrough and all six legal campaign wins passed again with the recovery code. They use normal starting resources, real movement, purchases, projectile combat, coin collection and cooldowns, without currency grants, hero teleports, forced kills or pre-unlocks. The unattended defense still lost on wave 4. Logs: `artifacts/playthrough.log` and `artifacts/campaign_playthrough.log`.

Campaign results remain Briarwood 128 kills / 124.77 simulated seconds, Amberfield 121 / 119.02, Stonegate 145 / 152.05, Sunscar 161 / 147.50, Moonfen 172 / 153.88 and Emberfall 227 / 183.37. All automated wins retained Keep health 450/450. These runs prove legal winning routes and working loss conditions, not human difficulty, enjoyment or device performance. Simulation time is not a frame-rate measurement.

The complete actual-renderer pass covered gameplay, Smith, pause, the 12-model tier gallery, all six staged mission maps, and campaign/settings/help/result/Continue UI. Three additional **staged real-root** recovery captures at 720×1280 were reviewed:

- `artifacts/recovery_title.png`: Continue summary on the title screen.
- `artifacts/recovery_paused.png`: restored battle awaiting explicit Resume.
- `artifacts/recovery_resumed.png`: resumed battle with live HUD.

`artifacts/recovery_capture.log` ends with `RECOVERY_CAPTURE_PASS`; both player stores are memory-only for this fixture. The expanded UI suite passed its 134 assertions both headlessly and in the capture run. Staged captures establish presentation and state visibility, not legal completion or balance.

## Portable-source evidence

A newly packaged recovery source archive was extracted without the checkout's `.godot` cache to the unique path recorded in `artifacts/fresh_source_path.txt`.

That extraction passed Godot import, all eleven baseline/recovery suites (725 assertions, including Android Back routing), the 1,242-assertion continuation suite, the original active win/unattended loss, and all six normal campaign victories/unlocks, with exit 0. Fresh-extraction evidence is headless; rendered captures were reviewed separately in the working source. The archive and executable-content comparison are refreshed with this checkpoint.

## Remaining work

Human playtesting of clarity, campaign pacing, economy, difficulty and enjoyment; further presentation/audio polish; and release preparation remain active. These automated checks do not complete the full-game goal.

Mac import, iOS signing/install, Android APK signing/install, physical-device multi-touch, safe areas, actual operating-system interruption/relaunch behavior, and sustained frame time/memory/temperature still need native validation. Desktop notification tests do not prove iPhone or Android lifecycle delivery. Native checks can happen later or in parallel and do not block compatible desktop development. GitHub publication, TestFlight/Play Store/App Store release and exact-commercial fidelity are not claimed.
