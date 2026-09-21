# Emberwatch agent instructions

Read `docs/architecture.md`, `docs/progression_v2_workplan.md` and
`docs/progression_v2_validation.md` first. The user approved Gameplay & Progression
Spec v2 and added shared hero/ranged-enemy/wall attack range on 2026-09-21.
This supersedes conflicting older rules, not unfinished runtime acceptance.

This branch implements the first targeting/HP-bar slice ONLY. Fortress lives,
spendable stars, navigation graphs, Ballista and quarry art are still outstanding.
Do not infer completion from a document or test file being present.

Preserve `game/main.tscn -> game/army_game.gd -> game/game.gd`, existing wave pacing,
current tower art, profile data, trained stats and proportional hero damage XP.
Do not add a parallel game controller. Do not modify the separate web prototype.

Only ranged enemies may damage the hero. Use the hero's actual basic attack range
for BOTH hero and wall targets; never introduce another ranger range constant.
Keep wall priority, shot obstruction and projectile ordering in the shared combat
rules. Non-ranged hunters now remain fast route runners, not hero pursuers.

Keep player faction red, enemies green, simple natural-material buildings, and
cosmetics separate from stat progression. No diamonds, live ad SDK, paid speed,
gear, store or new campaign regions. Do not merge or claim human acceptance.

Run the new production-scene tests and existing regression suites, report real
commands/result markers, and inspect rendered bars and attacks on a phone before
merging. Static checks alone are not runtime or visual validation.
