# Emberwatch — architecture and implementation authority

## Active milestone: Gameplay & Progression v2

The user approved the v2 gameplay/progression specification and, on 2026-09-21,
required ranged monsters to share the hero's basic attack range for both hero and
wall targeting. See [progression_v2_workplan.md](progression_v2_workplan.md).
The earlier architecture is preserved verbatim in
[architecture_pre_progression_v2.md](architecture_pre_progression_v2.md).
Its HP-fortress, unspendable-star and melee-hunter rules are historical, not the new
milestone target. Unrelated preservation requirements still apply.

**Implementation status:** only the first targeting and enemy-health-bar slice is
implemented on this branch. The current runtime still uses the old fortress HP and
star gates. Do not call v2 complete or relabel those systems without implementing
the coordinated outcome, persistence and UI changes. Read
[progression_v2_validation.md](progression_v2_validation.md) for actual evidence.

## Preserved structure

Godot and the repository's existing engine pin/Compatibility renderer remain.
The production entry point is `game/main.tscn -> game/army_game.gd`, extending
`game/game.gd`. No new game root, altered launch file, reset profile, changed wave
scheduler, or edit to the separate Three.js project is part of this slice.

| Owner | Responsibility in this slice |
| --- | --- |
| `game/game_data.gd` | Explicit enemy `attack_role`/`locomotion`; no separate ranger range or pursuit radii |
| `game/enemy_combat_rules.gd` | Shared bow range, planar acquisition, route-blocking wall selection, swept segment intersections |
| `entities/enemy.gd` | Ranged-only attacks; wall priority; wind-up; movement between hero shots; always-visible living health bars |
| `entities/enemy_bolt.gd` | Fixed flight and nearest actual wall/hero impact; damage once |
| `tests/check_enemy_range_roles.gd` | Production-scene controlled targeting, collision, bars and actor-restoration tests |
| Existing run/profile/build/UI modules | Retained; later v2 lives/star migration must change them together |

Combat helpers are pure queries. They never grant currency, mutate health, reset a
wave timer, or rebuild UI. Damage occurs in projectile/actor owners. The actor
still awards hero XP only for actual hero damage, capped to remaining health.

## Shared range and targeting

`EnemyCombatRules.ranged_range(game)` reads `hero.attack_range` (eight world units
in the current balance), not `ability_range`. Both hero and wall target checks use
this value and the hero's XZ centre-distance convention. A target must still be
eligible at release; dead/hidden/out-of-range heroes are not shot. Hero death does
not reduce the range against walls. Walls have priority when blocking the route.

Route blocking uses the existing conservative route-wall bounds; projectile
interception uses the wall body. Projectiles compare wall and hero intersection
fractions so a large frame step cannot shoot through a closer wall. Non-wall
buildings are not targets or damage recipients. Wall attacks use travelling bolts,
not instant damage at launch. Non-ranged enemies retain wall attacks but never
hero melee, contact damage, retaliation or pursuit.

The ranged enemy pauses for wind-up and when held by a wall, but moves along its
route during recovery between hero shots. Explicit pause still freezes combat.
No new wave readiness requirement is introduced.

## Health-bar presentation

Small green fills over dark backing appear for full-health as well as wounded
living enemies. Heights derive from mesh bounds; billboard scale preservation and
separate transparent render priorities prevent the fill being hidden by backing.
Bars update on accepted damage/restore and disappear at death. These are source
changes, not evidence that phone-scale visuals have passed review.

## Compatibility and gates

The actor/hostile-projectile snapshot shapes are retained in this slice. Enemy
balance definitions changed, so the existing content fingerprint makes earlier
active battles incompatible; do not remove that check or reinterpret old combat
silently. Campaign results, Supplies, ranks, settings and achievements are not
reset. Finish an old battle on the old version or start a fresh test battle.

CONTINUE: validate this targeting slice, then implement the remaining v2 packages
in dependency order. HOLD merge/release claims until engine and visual checks pass.
Do not use the preserved HP outcomes as proof that lives, finite-star purchases or
Ballista are integrated. Live ads, diamonds, paid speed, gear and hard mode remain
outside the current milestone.
