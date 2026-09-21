# Progression v2 — first targeting slice validation

Base: main `758b20b2d38a002779ed3f7995ce20c430940fe8`.
Scope: shared ranged range, ranged-only hero attacks, ranged wall attacks and
interception, and living enemy health bars. This is NOT the full v2 implementation.

## Executed locally

- Reconstructed the inspected base `game/game_data.gd` and `entities/enemy.gd` from
  the previously supplied source archive, then verified their Git blob hashes match
  GitHub (`ea5d695...` and `6002696...`) before editing.
- `python tools/check_enemy_range_static.py` -> `ENEMY_RANGE_STATIC_OK: 16 source
  checks; Godot runtime/rendering NOT tested`.
- Reviewed diff scope and preserved unrelated base actor damage XP/drop/route code.
- Updated `check_hero_danger.gd` to test route-only runners and dodgeable ranged
  projectiles instead of the removed melee-hunter rule, retaining death/respawn,
  input restrictions and snapshot checks. This updated suite has NOT been run.

The static checker is not a GDScript parser. No import, engine execution, visual
capture, phone performance check or human playtest has run for this patch. The
local environment has no Godot binary; network/tool download attempts did not
provide one. No old milestone pass count is evidence for the new code.

## Required engine commands before merge

Set GODOT to the repository-pinned standard executable and run from the repo root:

```sh
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --script tests/check_enemy_range_roles.gd --fixed-fps 60 --quit-after 6000
"$GODOT" --headless --path . --script tests/check_hero_danger.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_ranged_enemy.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_combat.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_actor_snapshot.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_army_progression.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_wave_pacing.gd --fixed-fps 60 --quit-after 60000
```

Require `ENEMY_RANGE_ROLES_OK` and each suite's expected success marker with no
parser/script errors, not just exit zero. The new suite instantiates main.tscn,
uses isolated in-memory progress and drives real actors with controlled positions
and steps. It does not test normal campaign balance or legal full playthroughs.

It covers inside/outside shared ranges, range recheck at release, role isolation,
wall priority and movement, non-wall target exclusion, nearest wall/hero projectile
intersections, pause, duplicate impacts, full/wounded/dead health bars and actor
wind-up restoration. Extend with recovery of a wall-targeted bolt, a destroyed wall
mid-flight, full mission playthroughs and real render/device inspection.

Old active battles become incompatible through the existing enemy-data fingerprint.
Verify the game shows its compatibility notice while historic campaign/settings/
Supplies remain intact. No life/star migration is included yet.

Visual acceptance: inspect bars at normal portrait camera distance with goblins,
scouts, brutes, hunters and ranged enemies; check fill shrinkage, facing, backing
occlusion, model clipping and crowd readability. Check that attacks have readable
wind-up, heroes can evade, walls shield, and rangers do not stall route progress
between hero shots. No screenshot or balance claim should be inferred from tests.
