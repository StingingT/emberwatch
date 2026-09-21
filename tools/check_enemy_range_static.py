"""Source-contract smoke checks. NOT a GDScript parser, runtime test, or render test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
files = {name: (root / name).read_text(encoding="utf-8") for name in (
    "game/enemy_combat_rules.gd", "game/game_data.gd", "entities/enemy.gd",
    "entities/enemy_bolt.gd", "tests/check_enemy_range_roles.gd",
)}
rules, data, actor, bolt, tests = (files[key] for key in files)
checks: list[tuple[str, bool]] = [
    ("basic bow range is read from the hero", 'hero.get("attack_range")' in rules),
    ("no independent ranged enemy range", '\"range\":' not in data.split('const ENEMIES: Dictionary = {')[1].split('const HERO_THREAT:')[0]),
    ("ranger declares ranged attack role", bool(re.search(r'"ranger":\s*\{[^\n]*"attack_role": "ranged"', data))),
    ("other current kinds declare route-only role", all(re.search(rf'"{kind}":\s*\{{[^\n]*"attack_role": "route_only"', data) for kind in ("hunter", "scout", "goblin", "brute"))),
    ("both target types use the same range value", 'CombatRules.in_range(global_position, wall.global_position, radius)' in actor and 'CombatRules.in_range(global_position, hero.global_position, radius)' in actor),
    ("old chase removed", '_hunt_hero' not in actor and 'pursuit_range' not in actor),
    ("no direct melee damage to hero in actor", 'target.take_damage' not in actor and 'hero.take_damage' not in actor),
    ("role gate precedes ranged selection", actor.index('if _attack_role != "ranged":') < actor.index('var target: Node3D = _ranged_target()')),
    ("walls are checked before hero projectile impact", bolt.index('if not wall_hit.is_empty()') < bolt.index('if hero_time >= 0.0:')),
    ("damage waits for real projectile impact", 'wall.call("take_damage"' not in actor.split('func _attack_ranged')[1].split('func setup')[0]),
    ("bars visible at full health", '_health_root.visible = not dead and health > 0.0' in actor),
    ("billboards preserve the changing fill scale", 'material.billboard_keep_scale = true' in actor),
    ("bar ordering is explicit", 'Vector2(1.12, 0.17), 10' in actor and 'Vector2(1.00, 0.095), 11' in actor),
    ("bar height uses model geometry", 'bounds.get_endpoint(corner)' in actor),
    ("new suite loads actual entry point", 'preload("res://game/main.tscn")' in tests),
    ("new suite isolates saves", 'game.persistent_profile = false' in tests),
]
for name, ok in checks:
    if not ok:
        raise SystemExit(f"ENEMY_RANGE_STATIC_FAILED: {name}")
print(f"ENEMY_RANGE_STATIC_OK: {len(checks)} source checks; Godot runtime/rendering NOT tested")
