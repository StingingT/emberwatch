# Emberwatch — architecture and implementation authority

Updated 2026-09-14. This document replaces the older active-scope summary, not the
implementation evidence recorded in the historical milestone documents.

## Current authority

The user has authorized permanent army progression, achievements, simplified
menus, stronger building evolution, free pacing controls, and an optional
post-battle ad reward of **50% additional Supplies**. See
[army_progression.md](army_progression.md) for rules, ownership and acceptance.

This explicitly supersedes the HOLD on **meta progression and its necessary
persistence/UI integration** in `combat_visual_identity_plan.md`. Existing combat,
hero danger, touch/readability, and device acceptance checks remain outstanding;
they have not become accepted merely because this milestone started. A real ad
SDK, purchases, diamonds, gear, loot boxes and new campaign missions remain on HOLD.

The implementation is a **draft, not a validated release**. Read
[army_validation.md](army_validation.md) before asserting test coverage.

## Non-negotiable game rules

- Godot remains the engine; keep the repository's engine pin and Compatibility
  renderer. Portrait canvas is 720 by 1280 with an angled orthographic camera.
- Friendly faction is red; initial enemies are green. Use friendly, original,
  simple shapes. No realistic textures, giant decorative banners or crowded menus.
- Control an archer through native touch movement or WASD. Aim/fire is automatic;
  Volley uses touch or Space. Movement remains available during ordinary attacks.
- Hero damage grants proportional run XP, capped to actual damage. Tower finishing
  blows do not erase hero contribution. Hero death permits timed respawn; the Keep
  determines mission defeat. Preserve the updated hunters, ranged threats and
  Multishot/Volley/Piercing run-local choices.
- Gold is physical, collected in-world, and spent during live combat. Gold and
  Smith upgrades reset with a new battle. No offline battle simulation.
- Build on authored plots only. Keep per-level building caps configurable. Do not
  replace the current six missions, their plot restrictions or wave rosters with
  new content as part of this patch.
- Buildings evolve visibly during a battle: substantially larger silhouettes,
  greater structural sophistication and appropriate materials. Archer Towers have
  one, two and three visible red archers. Do not force all building families through
  the same wood/stone/metal sequence. Existing three-tier access is not removed.
- Permanent training does not change hero/monster cosmetics. Cosmetic acquisition
  is a separate future achievement/store/loot feature, never a level-up side effect.

## Entry point and ownership

`game/main.tscn` now instantiates `game/army_game.gd`, which extends the existing
`game/game.gd`. This is a narrow integration adapter, not a second combat engine.

| Owner | Responsibility |
| --- | --- |
| `game/game.gd` | Existing battle composition, waves, targeting, coin economy, plots, Smith, campaign and recovery coordination |
| `game/army_game.gd` | Training at run start, Supplies settlement, recovery adapter, menu routing, pacing and optional ad-provider boundary |
| `game/army_data.gd` | Training definitions/costs/star gates, achievements, Supplies formulas, training balance version |
| `game/army_progression.gd` | Validated additive army ledger; purchases, first-clear records and idempotent grants |
| `game/player_profile.gd` | Existing mission best results and settings, unchanged schema |
| `game/atomic_json_store.gd` | Existing atomic publication and backup protection, unchanged |
| `game/run_store.gd`, `game/run_snapshot.gd` | Existing battle journal and baseline snapshot validation, unchanged |
| `entities/` | Hero/enemy combat, death, projectiles and physical pickups |
| `game/building.gd` | Construction, tier stats, tower salvos, wall health and mine production |
| `common/army_building_visuals.gd` | Staffed Archer Tower models and actual arrow origins; delegates other building families |
| `common/visuals.gd`, `common/visual_mesh_kit.gd`, `levels/` | Existing original geometry and authored battlefield |
| `ui/hud.gd`, `ui/touch_*.gd` | Existing combat HUD, safe areas and native touch ownership |
| `ui/army_menu.gd` | Flat home/training/achievements/campaign/result/pause pages using the existing HUD helpers |

Do not add new metagame logic to `hud.gd`, mutate `GameData` constants at runtime,
or copy the full base run controller into the new adapter. Actor methods and
signals remain unchanged except the optional `mine_yield(base)` hook.

## Run-start training and restoration

Training consists of five bounded ranks each in hero damage, hero health, tower
damage, tower attack rate, fortifications and mine output. Purchases use Supplies;
star requirements are gates, not costs. Runtime stats use a copy of the selected
ranks taken at battle start. Upgrades purchased while a battle is saved apply to
its successor, not retrospectively to the saved battle.

The snapshot adapter adds `army: {version, ranks}`. A legacy snapshot without this
field means zero training. It checks this data, converts trained hero/Keep/wall
health to baseline units for the existing strict validator, then returns the
original, unmodified snapshot. This preserves every existing actor/lifecycle check
while supporting higher legitimate health. It must reject invalid values, not
clamp them into apparently valid health. Increment the army balance version if
training interpretation changes. Restore at 1x speed, paused.

## Rewards and persistent data

The new `user://emberwatch_army.json` is additive. Existing campaign, settings and
battle files are not renamed, replaced or reset. The ledger contains Supplies,
training ranks, achievement claims, first clears and per-run reward receipts.

Completed waves bank Supplies, including on later defeat. Each receipt stores the
largest rewarded completed-wave count, so loading an older checkpoint does not
pay those same waves twice. Victory adds a completion/star bonus and at most one
first-clear bonus per mission. A terminal receipt and its wallet change are one
atomic document. The adapter reconciles a matching terminal receipt against the
battle journal after restart, closing the receipt-before-journal crash window.
Historical campaign progress seeds first-clear records and earns applicable
one-time achievement grants; stars are neither spent nor repeatedly accumulated.

Storage failures must remain visible. Like the existing profile, failed writes
retain session progress; they do not establish durable persistence. Unknown/newer
or unreadable army profiles are preserved with purchases/rewards disabled. Do not
prune old run IDs casually: that would break replay protection. The initial ledger
has a 20,000-run limit and reports exhaustion without silently deleting receipts.

## Presentation and input boundaries

Use flat cream panels, dark readable text and restrained red actions. A training
page shows one category, never every system simultaneously. Achievements paginate.
Result pages show outcome, best-performance context, normal Supplies, optional
bonus and clear navigation. Normal rewards are already banked; declining an ad
never withholds them. No diamonds, decorative plus-currency buttons or fake prices.

All new buttons reuse native touch buttons and existing safe-area overlay scaling.
Close overlays/reset held input before gameplay. Escape/Android Back returns from
army pages. Settings/help keep their original handlers. Pacing uses a Start Now
button in the existing wave-panel footprint and a free 1x/2x choice in pause.

At 2x, all simulation clocks advance together and the physics tick rate scales
accordingly. Menus/paused simulation return to normal time. Reset globals on exit.
Completion records continue using simulation seconds, not accelerated wall time.

## Optional rewarded-ad boundary

No production provider is wired in this change. The game works offline; the UI
shows ads unavailable rather than simulating a video or minting Supplies on click.

A future injected provider must expose `is_available() -> bool`,
`request(run_id) -> bool`, `reward_completed(run_id)` and `reward_failed(run_id)`.
Completion means the real provider verified the reward event, not merely that a
window closed. The integration accepts only its matching outstanding request.
Grant `floor(normal_mission_supplies / 2)` once per terminal run. Achievement grants
are separate and never boosted. Cancellation/no-fill/errors leave base rewards and
normal navigation intact. SDK/privacy/store work needs its own reviewed task.

## Continue / Hold gates

CONTINUE: inspect and validate this additive implementation; fix integration and
layout defects; render the real menus and tower tiers; tune the first three missions
with zero/early training and no ads; finish the existing combat-feel checks.

HOLD: merging or calling this release-ready before Godot import, new and existing
regression checks, renderer captures, save/reload and normal-speed playtests pass.
Also HOLD diamonds, store payments, equipment, cosmetic loot, paid speed, new maps,
and unrelated recovery-framework redesign.

Agents report exact files changed, tests actually executed, result markers,
remaining uncertainty and screenshots from the real renderer. Do not cite a mockup,
static check, or inherited old test result as evidence this new layer runs.
