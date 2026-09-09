# Interrupted battle recovery

**Status: implemented contract, locally validated on Windows.** This feature extends the campaign checkpoint, preserves profile version 1 and retains existing combat balance. The separate battle journal uses version 1. Current tests, renderer evidence and archive verification are recorded in [recovery_validation.md](recovery_validation.md). Native Mac/iPhone verification remains parallel or later work; the full-game goal remains active.

## Player behavior

- Keep one resumable battle. After reopening, **Continue defense** restores it paused; the player explicitly resumes. Nothing advances while the app is closed.
- Pause, application suspension, returning from a battle to the title, and normal desktop window close preserve it. Restarting or selecting another mission explicitly replaces that battle.
- Also checkpoint every five seconds of active play after a complete simulation step. Suspension triggers an immediate paused checkpoint. Termination without a suspension callback recovers the last successful checkpoint, so subsequent unsaved actions cannot be promised.
- Finished or abandoned battles must not reappear through backup recovery. Save failures remain visible and do not prevent session play.
- “Lossless” means preserving the saved gameplay state: rewards, gold, health, wave progress, living actors, targeting, positions and timers. Transient sound, held inputs, toasts, death effects and construction tweens may end at interruption.

## Ownership and interfaces

| Owner | Implemented responsibility |
| --- | --- |
| game/player_profile.gd | Continue owning only campaign results and preferences, with the existing API and unchanged JSON schema. |
| game/atomic_json_store.gd | Shared temporary-write, flush, validation, backup, rename, rollback and future-version protection. Accepts a validator and byte limit; owns no gameplay fields. Both stores use it; the original 57 profile checks pass. |
| game/run_store.gd | Owns user://emberwatch_run.json and its independent version 1 envelope/backup. APIs: load_run() -> Dictionary, store_run(snapshot, run_id = "") -> bool, finish_run(outcome, run_id = "") -> bool, last_error. Empty save_path is memory-only. Load reports missing, active, terminal, recovered, incompatible, future or failed status. |
| game/game.gd / game/run_snapshot.gd | capture_run_snapshot() -> Dictionary, validate_run_snapshot(snapshot) -> Dictionary, restore_run_snapshot(snapshot) -> bool, save_interrupted_run() -> bool, continue_defense() -> bool. Root owns lifecycle. Full validation precedes current-world mutation; direct restoration performs no save and ends paused. |
| Actor scripts | capture_state() -> Dictionary and restore_state(saved) -> void after normal setup. Restore assigns fields without spending, XP/reward callbacks, attacks, timer advancement or construction effects. Coin snapshot_available() and projectile snapshot_target() filter consumed actors/targets. Building setup(..., animate = true) supports silent restoration. |
| ui/hud.gd | continue_requested and set_continue_summary(summary) show mission, wave and elapsed time. Persistence status is visible; HUD owns neither unlock rules nor saves. |

A validated existing battle may resume its known mission even if an older recovered profile lacks that mission's unlock. Ordinary new-mission selection retains existing unlock rules.

## Envelope and compatibility

Only JSON primitives are stored; vectors become three numeric components. The exact envelope fields are version = 1, state = active or terminal, run_id, sequence, snapshot and outcome. The content_fingerprint belongs inside the active snapshot. A terminal record has an empty snapshot and an outcome identifying victory, loss or explicit abandonment/replacement; victory carries mission_id, stars and seconds.

The fingerprint covers the selected mission's gameplay level data, ordered waves, collision footprints and relevant GameData balance constants. Cosmetic palettes, names and descriptions are excluded. Changed routes, plots, rosters or combat balance cannot silently reinterpret old state. Incompatible files are preserved and Continue is unavailable; starting a new defense with a genuinely new identity explicitly replaces them. Unknown future envelope versions remain protected from overwrite.

Enforced budgets: 2 MiB; at most 512 living enemies, 2,048 projectiles, 2,048 coin piles and the authored number of buildings. Validation rejects invalid types, nonfinite numbers, unsupported kinds, duplicate/dangling IDs, invalid tiers/health/XP, impossible wave cursors and invalid positions. It checks spawned = kills + living enemies and current-wave health scaling. Hero positions inside the Keep or an occupied building are rejected before world replacement. Actual float32 movement-edge coordinates receive the same tolerance as runtime collision checks; arrow flight and mine drop offsets are allowed.

## Required runtime fields

| Component | Save exactly | Derive or reset |
| --- | --- | --- |
| Run | Mission ID; coins, coins_collected, kills, keep_health; all three smith_levels; elapsed; _used_volley; _last_keep_warning; _run_start. | Resolve mission index by ID. Derive keep_max from mission base health and saved fortification; validate health against it. Settings remain in the profile. |
| Waves | wave_index including preparation -1; wave_cursor; wave_active; exact signed wave_timer. | Restore the fingerprint-matched ordered roster/route. Never infer spawning progress from surviving enemy count. wave_timer can legitimately be negative while awaiting the final enemy. |
| Hero | Position, tier, xp, ability_cooldown, shot_remaining, model facing. | Derive next_xp, damage, attack interval, speed/ranges from matched balance and tier without add_xp() side effects. Clear move_input. |
| Living enemy | Snapshot-local ID, kind, position, health, max_health, route_index, attack_remaining, model facing; preserve enemy array order. | Derive kind-specific speed/damage/attack interval/gold/XP from matched balance. Preserve wave-scaled maximum health. Exclude dead and queued actors whose rewards already occurred. |
| Live arrow | Position, target enemy ID, _damage, _source, _speed, _lifetime; preserve order. | Resolve target after enemies exist; rebuild orientation. Exclude impacted/queued arrows. Arrows whose target already died have no remaining effect; do not resurrect or retarget them. |
| Uncollected coin pile | Position, value, magnetized, magnet_speed, age, phase; preserve distinct piles and child order. | Exclude collected/queued piles. Instantiate directly: drop_coin() can merge piles and alter magnet timing. Never credit uncollected value to the wallet. |
| Living building | Plot ID, kind, tier, health, exact signed cooldown; preserve insertion order. | Resolve plot position, derive max health with modifiers, rebuild model/bar and hide occupied plot. Do not purchase/upgrade. Idle tower cooldowns can legitimately be negative. |
| View and transient effects | camera_focus is saved; actor facing and coin phase are included above. | Recompute selection, range rings, bars, HUD and tutorials. Reset hero/enemy walk, recoil, flash and swing phases; clear transient feedback, held inputs and toasts. Construction tweens are cancelled and final-tier models rebuilt immediately. |

Assign enemy IDs from the ordered live list during capture and consistently reference them from arrows. Never serialize Godot instance IDs, WeakRefs, Objects or scene paths. Preserve existing container, array and building insertion orders: target ties and wall/attack processing can affect gameplay.

No gameplay RNG state is currently required. Wave composition, damage and rewards are deterministic. Global randomness in actors only supplies cosmetic coin phase; landscape decoration uses fixed local generators. Save existing coin phases only for visual continuity. Future gameplay randomness needs an owned generator with saved state.

## Capture and restore

1. Capture on the main thread at a stable boundary. Pause/suspension first pauses root and clears input. Periodic capture is deferred until the current simulation step ends, avoiding snapshots halfway through death, XP and gold creation.
2. Filter consumed actors, build the ID map, copy primitives and validate the whole candidate before disk writes.
3. Flush a validated temporary file, back up only a valid prior primary, then publish by same-directory rename. Failure preserves the previous checkpoint and current session battle.
4. Validate envelope, fingerprint, fields and references before replacing the world. Recover malformed primary from a compatible valid backup and display recovery status.
5. Restore under state resetting. Reuse normal mission world construction without new-run save hooks, purchase actions or simulation ticks.
6. Apply root counters/modifiers; rebuild buildings, hero, ordered enemies, distinct coins and targeted arrows. Refresh derived stats and health bars after applying fields.
7. Set state paused, clear held inputs, reconstruct HUD/camera/context and await explicit Resume. Do not advance wall-clock time.

## Terminal records and profile coordination

The terminal envelope is a small completion journal, not another campaign-results owner.

- On victory, freeze and persist a terminal outcome before relying on profile storage. Publish it into both run primary and backup with the validated replacement mechanics, so successful retirement cannot recover the previous active battle from backup.
- Then call the existing profile.record_victory(). Best-stars/best-time aggregation makes replaying a pending result idempotent. Startup reconciles a terminal victory not yet represented in the profile and shows no Continue action.
- Loss and explicit abandonment/replacement also publish terminal records to both copies, without victory data. Never clear only the primary: its backup could resurrect an abandoned battle.
- A new defense uses a new run ID and replaces the terminal envelope with its first checkpoint.
- Before overwriting an earlier terminal victory, root retries its profile reconciliation. If storage still fails, the old completion journal remains intact and current session results stay visibly unsaved. If the new battle finishes before its first checkpoint can be published, finish_run(outcome, current_run_id) may create a terminal record under that genuinely new identity, including a zero-health loss. The default identity path still rejects mission mismatch. This exception prevents an old pending victory from making a later battle finish under the wrong identity.
- Failed terminal or profile publication remains a visible failure while session play/results remain usable; do not claim successful durable retirement if the relevant writes failed.

## Acceptance coverage

The following coverage is implemented and passes in the working source. The final source-archive status is recorded separately in [recovery_validation.md](recovery_validation.md); native device behavior remains to be tested.

1. Existing profile, campaign, economy, combat, feedback and touch suites pass. Profile v1 files and APIs remain compatible after shared-storage extraction.
2. Real roots with isolated disk storage roundtrip preparation, a partially spawned wave and an inter-wave interval into a fresh paused root. Saved counters, positions, health, modifiers and timers match.
3. Compare uninterrupted and restored continuations under identical inputs. Include wall/Keep attacks, a damaged upgraded wall, mine production, injured enemies, hero/tower/Volley arrows in flight, partly magnetized gold and nonzero attack/Volley cooldowns. Compare rewards, XP, health, waves and actor counts; forced victories are not this evidence.
4. Capture immediately after kills, impacts, pickups and wall destruction without duplicating rewards/damage/actors. Nearby saved coin piles remain distinct.
5. Pause, return to title, suspension, reopen and Continue preserve state; nothing advances while closed/paused and held controls clear.
6. Victory, defeat, restart and mission replacement retire old state. Corrupting a terminal primary cannot offer the prior battle from backup. Pending terminal victories reconcile failed profile writes idempotently.
7. Corruption, invalid types/ranges, duplicate/dangling IDs, changed content and future versions fail before mutating the world. Future files remain untouched. Write failures retain current play and show status.
8. Fixtures use unique paths or memory-only stores, never user profile/run files. A fresh-directory source package validates both stores.
9. Render and exercise Continue/paused recovery in portrait and with larger controls, including actual button/interruption events. Native iPhone lifecycle verification follows without blocking implementation.
