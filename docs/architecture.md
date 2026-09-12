# Emberwatch — implementation contract

Working title only. User authorized implementation on 2026-09-08. Godot 4.7 stable, GDScript, Compatibility renderer as the initial portable baseline. iPhone renderer/performance acceptance remains pending device tests.

## Active scope and decisions

**Current authority:** the user has promoted [Combat & Visual Identity Pass](combat_visual_identity_plan.md). Its combat, enemy, ability and visual requirements supersede the earlier no-hero-death restriction and campaign-expansion direction below. Additional missions, save/recovery features, settings, monetization, equipment and meta progression are on HOLD. The following actor interfaces describe the current implementation baseline and will be extended for this milestone, not treated as a reason to defer it.

The first playable has passed acceptance. The current user goal is to continue finishing the game. `docs/campaign_plan.md` promotes a six-mission campaign, versioned local profile, onboarding and settings into active scope and defines their integration interfaces. Earlier initial-slice restrictions below describe the accepted baseline; this promotion supersedes their hold on campaign work.

CONTINUE: implement the reference's full first playable loop, then validate it before campaign expansion. Portrait 720 x 1280 design canvas, angled orthographic camera, original simplified 3D. Joystick or WASD movement, auto-target/fire while moving, nearby construction, Space/touch Volley. Purchases happen in live combat. Fixed enemy route; walls at designated route checkpoints are attacked until destroyed. Only hero finishing blows grant XP. Physical coins collect within a magnet radius. No paid assets or online services.

The user's current direction is to continue desktop gameplay development and polish now. Native iPhone testing is a later or parallel workstream, required before calling the phone version tested. Scheduling the Mac handoff, configuring signing or awaiting physical-device evidence does not block further gameplay development.

The current polish pass adds impact flashes, combined gold-pickup labels and wave completion progress. Windows integration checks and rendered captures validate this pass. `game/world_feedback.gd` draws short-lived effects below the HUD, caps concurrent effects, freezes them during pause and clears them at run boundaries. Feedback does not own rewards or damage.

Construction remains valid while standing on a plot. Before spending gold, the run controller finds a nearby clear edge if the new footprint overlaps the hero. All native touch buttons, including temporary menu buttons, release their finger ownership on lifecycle resets.

Building `max_level` and Smith repeat-cost growth, tier discount and minimum price are configurable in `GameData`. The building actor, purchase controller and upgrade view share the same configured tier limit. Initial content still has three building tiers.

`game/game.gd` is the composition root and owns run state, economy, wave timing, plot state and cross-system coordination. No autoloads initially. Balance and level layout live in `game/game_data.gd`. No agent may edit another agent's assigned files without coordination.

## Root owns

project.godot, game/*, tests/*, tools/*, README.md, export configuration, docs, root metadata. Root builds nodes in `_ready`, injects dependencies through setup methods, and calls UI with view-state dictionaries. Root owns the Keep health state.

## Visual agent — CONTINUE

Own only `common/visuals.gd` (`class_name GameVisuals extends RefCounted`) and `levels/battlefield.gd` (`class_name Battlefield extends Node3D`). Optional own visual helper scripts under common/visual_*.

GameVisuals static methods return unattached Node3D model roots, positioned with feet at y=0:

- `hero() -> Node3D` — red archer, bow, cape, shadow.
- `enemy(kind: String) -> Node3D` — green goblin, variants scout/brute; faces local -Z.
- `building(kind: String, tier: int) -> Node3D` — tower, wall, mine, smith, keep. Distinct silhouettes at tiers 1–3. Tower occupies radius 1.05; support 1.1; wall width 3.0 in X/depth .8 in Z; keep radius 2.
- `plot(category: String) -> Node3D` — ring/platform, category marker; tower/wall/support.
- `coin() -> Node3D`, `arrow() -> Node3D` — arrow along -Z.
- `ring(radius: float, color: Color) -> Node3D` — range/selection floor ring.

Battlefield: `setup(level: Dictionary) -> void`. Creates terrain, fixed trail and decorative original scenery, daylight lighting/environment. No gameplay actors/camera/UI/Keep/plots. `level` keys: `bounds: Rect2` (x,z); `route: Array[Vector3]`; `keep: Vector3`; `plots: Array[Dictionary]` with `id:String, category:String, position:Vector3`. Terrain is flat y=0; no cliffs. Decorative scenery outside walking bounds; no untracked blockers. Root provides bounds Rect2(-10,-30,20,43), hero around (0,0,4), keep (0,0,9), winding route from (0,0,-28) to keep. Landscape must read attractively at portrait camera (size ~24, KEEP_HEIGHT) with grass, broad warm path, edge trees/rocks, low noise. Avoid text-heavy 3D labels. Meshes/materials shared where practical.

## Combat agent — CONTINUE

Own only `entities/hero.gd`, `entities/enemy.gd`, `entities/projectile.gd`, `entities/coin.gd`. Use GameVisuals preloaded from common/visuals.gd when it exists; agreed contract allows work in parallel.

`HeroActor extends Node3D`: properties `game:Node`, `move_input:Vector2`, `tier:int=1`, `xp:int=0`, `next_xp:int`, `ability_cooldown:float=0`; `setup(owner_game:Node, stats:Dictionary)`, `add_xp(amount:int)`, `use_ability() -> bool`. Reads data keys speed, damage, attack_interval, range, xp_thresholds:Array, ability_unlock, ability_cooldown, ability_damage, ability_targets, coin_radius. Update movement in physics, clamp via game.constrain_hero_motion(from:Vector3,to:Vector3)->Vector3. x input maps world X, y input maps world Z. Root sets move_input each physics frame. Auto-fire nearest enemy, projectiles carry source "hero". XP gives visible level-up and damage/attack upgrades per data. Volley hits multiple enemies using visible arrows; unlocked at tier 2. No hero death in this milestone.

`EnemyActor extends Node3D`: properties `game:Node`, `health:float`, `max_health:float`, `dead:bool=false`, `kind:String`, `route_index:int=0`; `setup(owner_game:Node, stats:Dictionary, route:Array[Vector3])`; `take_damage(amount:float, source:String)`. Stats keys id, health, speed, damage, attack_interval, coins, xp. Follow route on XZ, stop at returned wall and attack it, attack Keep upon reaching last waypoint. Root `on_enemy_killed(enemy:Node3D, source:String, coins:int, xp:int)` called exactly once; then queue_free. Small health display when damaged; hit/death feedback. Entities must check game.is_playing() before updates.

`ArrowProjectile extends Node3D`: `setup(owner_game:Node, start:Vector3, target:Node3D, damage:float, source:String, speed:float=24.0)`. On impact call take_damage once if target alive; expired or invalid-target arrows free safely. Never retain dead references. Visual uses GameVisuals.arrow.

`CoinPickup extends Node3D`: properties value:int; `setup(owner_game:Node, at:Vector3, amount:int)`. Visible bounce/spin; magnet within hero's data coin_radius; collect once through game.collect_coin(amount:int, at:Vector3), queue_free. No auto-credit on drop, no finite expiration. Root may merge rewards at same location during crowded waves.

Root game methods usable by combat:

- `is_playing() -> bool`
- `nearest_enemy(at:Vector3, max_range:float) -> Node3D`
- `enemies_in_range(at:Vector3, max_range:float) -> Array[Node3D]`
- `spawn_arrow(at:Vector3, target:Node3D, damage:float, source:String) -> void`
- `get_blocking_wall(at:Vector3, next:Vector3) -> Node3D` (wall has take_damage(amount, source))
- `damage_keep(amount:float) -> void`
- `on_enemy_killed(enemy:Node3D, source:String, coins:int, xp:int) -> void`
- `collect_coin(amount:int, at:Vector3) -> void`
- `constrain_hero_motion(from:Vector3, to:Vector3) -> Vector3`
- `notify(message:String, tone:String="info") -> void`
- `play_sound(kind:String) -> void`
- `show_hit(at:Vector3, lethal:bool) -> void` — presentation only, called after accepted enemy damage.
- `get_hero() -> Node3D`

## UI agent — CONTINUE

Own only `ui/hud.gd` (`class_name GameHUD extends CanvasLayer`), `ui/touch_stick.gd` (Control), optional UI helpers/assets authored under ui/. Programmatic responsive UI, touch-first, elegant deep evergreen/cream/gold panels, red accents; avoid tiny text. Portrait design 720x1280, auto-resize safe areas for iOS and Android. Mouse/WASD are desktop alternatives, not substitute touch events. Read mobile skill's safe-area script before implementing its pattern.

GameHUD signals: `play_requested`, `restart_requested`, `menu_requested`, `pause_requested`, `resume_requested`, `build_requested(kind:String)`, `upgrade_requested`, `smith_requested(id:String)`, `ability_requested`, `sound_toggled(enabled:bool)`.

GameHUD public API:

- `movement_vector() -> Vector2` returns joystick vector (keyboard root handles).
- `show_title()`, `show_game()`, `show_pause()`, `show_result(won:bool, summary:Dictionary)` (summary kills, coins, wave, total_waves).
- `update_state(state:Dictionary)` with coins:int, keep_health:float, keep_max:float, wave:int, total_waves:int, wave_text:String, wave_active:bool, wave_remaining:int, wave_total:int, kills:int, hero_level:int, xp:int, next_xp:int, ability_unlocked:bool, ability_cooldown:float, ability_total:float, threat_text:String. Remaining enemies includes both pending spawns and surviving actors; the completion bar advances on kills.
- `show_context(context:Dictionary)`; empty hides. Context keys selection_id:String (stable plot ID), title:String, subtitle:String, options:Array[Dictionary], upgrade_cost:int (-1 no upgrade), tier:int, can_upgrade:bool. Changing selection_id cancels held purchase touches without releasing the movement stick; an unchanged identity preserves touches across ordinary refreshes. Option keys id:String, label:String, cost:int, enabled:bool, description:String. IDs tower/wall/mine/smith trigger build_requested. Built smith options IDs ranged/haste/fortify trigger smith_requested. Context includes `screen_position:Vector2` (smith world position projected); place its three purchase bulbs around/above smith, clamped away from top HUD and lower controls, avoiding overlap.
- `toast(message:String, tone:String="info")`.
- `reset_input()` clears active stick/touches on pause/background/title.

Title: EMBERWATCH / Defend the last light, large Play button, compact movement/build teaching and iPhone portrait framing. Main HUD: keep health, coins, wave banner, hero XP, nearby build card, joystick bottom left, Volley bottom right, pause button. Avoid obstructing center combat. Three Smith options directly accessible; no fullscreen Smith screen. Root updates state/context 10x per second. UI toast must not consume combat touch input. Use readable plain words and confirm unavailable costs by disabled buttons. Includes result/retry/home and pause/resume/restart/sound controls. Title/result/pause overlay must consume taps so joystick cannot start behind it.

## Integration evidence

Root runs Godot headless import, scripted gameplay checks, and real renderer captures. Tests must exercise actual hero/tower damage, kill attribution, collection and spending, caps/upgrades, Smith effects, walls, waves, and win/loss/restart. Record new polish evidence after implementing and checking each change.

Initial-playable acceptance is based on the agreed playable loop and its Windows validation. A green desktop test does not establish phone performance, touch feel or iOS export/signing; those claims require Mac and physical-iPhone evidence later or in parallel. Campaign, store release and other later complete-game milestones are separate from the initial playable objective and do not block continued desktop development.
