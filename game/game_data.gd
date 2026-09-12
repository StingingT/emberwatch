class_name GameData
extends RefCounted
## All gameplay balance is configured here, separately from simulation code.

const HERO: Dictionary = {
	"xp_rule": "damage_share", "health": 100.0, "respawn_seconds": 8.0, "protection_seconds": 1.5,
	"speed": 6.0, "damage": 12.0, "attack_interval": 0.65, "range": 8.0,
	"xp_thresholds": [16, 28, 42, 58, 76], "damage_per_tier": 3.0,
	"attack_speed_per_tier": 0.10, "ability_unlock": 2,
	"ability_cooldown": 12.0, "ability_damage": 44.0,
	"ability_targets": 7, "ability_range": 11.0, "coin_radius": 3.3,
}
const ENEMIES: Dictionary = {
	"hunter": {"id": "hunter", "health": 42.0, "speed": 3.6, "damage": 13.0,
		"attack_interval": 1.4, "coins": 14, "xp": 7, "pursuit_range": 7.0, "route_leash": 5.0},
	"goblin": {"id": "goblin", "health": 30.0, "speed": 2.0, "damage": 9.0,
		"attack_interval": 1.2, "coins": 9, "xp": 4},
	"scout": {"id": "scout", "health": 24.0, "speed": 3.1, "damage": 7.0,
		"attack_interval": 0.9, "coins": 10, "xp": 5},
	"brute": {"id": "brute", "health": 110.0, "speed": 1.25, "damage": 20.0,
		"attack_interval": 1.5, "coins": 22, "xp": 10},
}
const HERO_THREAT: Dictionary = {"windup": 0.7, "reach": 2.0, "hit_radius": 1.2}
const BUILDINGS: Dictionary = {
	"tower": {"name": "Archer Tower", "category": "tower", "limit": 99, "max_level": 3,
		"costs": [40, 65, 100], "health": [150.0, 230.0, 350.0],
		"damage": [10.0, 19.0, 32.0], "range": [7.5, 8.5, 10.0],
		"interval": [1.05, 0.85, 0.65], "description": "Arrows cover the trail"},
	"wall": {"name": "Barricade", "category": "wall", "limit": 99, "max_level": 3,
		"costs": [30, 50, 80], "health": [170.0, 330.0, 600.0],
		"description": "Hold the horde in place"},
	"mine": {"name": "Gold Mine", "category": "support", "limit": 1, "max_level": 3,
		"costs": [60, 85, 120], "health": [150.0, 240.0, 350.0],
		"production": [10, 18, 30], "interval": [7.0, 7.0, 7.0],
		"description": "Collect fresh gold every 7s"},
	"smith": {"name": "Smith", "category": "support", "limit": 1, "max_level": 3,
		"costs": [55, 75, 110], "health": [150.0, 240.0, 350.0],
		"description": "Empower your defenses"},
}
const SMITH: Dictionary = {
	"ranged": {"name": "Keen arrows", "description": "Towers +20% damage", "base_cost": 35, "step": 0.20},
	"haste": {"name": "Quick strings", "description": "Towers fire 15% faster", "base_cost": 35, "step": 0.15},
	"fortify": {"name": "Fortify", "description": "Walls & Keep +20% health", "base_cost": 30, "step": 0.20},
}
const SMITH_PRICING: Dictionary = {"repeat_increase": 20, "tier_discount": 5, "minimum": 10}
const STARTING_COINS: int = 100
const KEEP_HEALTH: float = 450.0
const BUILD_RADIUS: float = 3.5
const PREPARATION_TIME: float = 5.0
const BETWEEN_WAVES: float = 5.0
const STAR_HEALTH_THRESHOLDS: Dictionary = {"two": 0.4, "three": 0.8}
const FOOTPRINTS: Dictionary = {"hero_margin": 0.7, "keep_radius_squared": 5.8,
	"building_radius_squared": 2.1, "wall_half_width": 1.85, "wall_half_depth": 0.75}

static func building_footprint_contains(at: Vector3, center: Vector3, kind: String) -> bool:
	var offset: Vector3 = at - center
	if kind == "wall":
		return absf(offset.x) < float(FOOTPRINTS["wall_half_width"]) and absf(offset.z) < float(FOOTPRINTS["wall_half_depth"])
	return offset.length_squared() < float(FOOTPRINTS["building_radius_squared"])

static func level() -> Dictionary:
	var route: Array[Vector3] = [Vector3(0, 0, -28), Vector3(4, 0, -22),
		Vector3(4, 0, -16), Vector3(-3, 0, -11), Vector3(-3, 0, -3),
		Vector3(0, 0, 2), Vector3(0, 0, 9)]
	return {
		"name": "Briarwood Crossing", "bounds": Rect2(-10, -30, 20, 43),
		"route": route, "keep": Vector3(0, 0, 9), "hero": Vector3(-3, 0, -3),
		"plots": [
			{"id": "watch", "category": "tower", "position": Vector3(3.2, 0, 3.6)},
			{"id": "bend", "category": "tower", "position": Vector3(-6.0, 0, -3.8)},
			{"id": "crossing", "category": "tower", "position": Vector3(0, 0, -8.2)},
			{"id": "north", "category": "tower", "position": Vector3(7, 0, -17)},
			{"id": "approach", "category": "tower", "position": Vector3(-0.5, 0, -21)},
			{"id": "gate", "category": "wall", "position": Vector3(0, 0, 4)},
			{"id": "choke", "category": "wall", "position": Vector3(-3, 0, -7)},
			{"id": "forge", "category": "support", "position": Vector3(4.2, 0, -2.2)},
			{"id": "quarry", "category": "support", "position": Vector3(-6, 0, 4.4)},
		],
	}

static func waves() -> Array[Dictionary]:
	return [
		{"name": "Scouts in the pines", "enemies": _pack(8, 0, 0), "interval": 1.1, "health_scale": 1.0},
		{"name": "The green tide", "enemies": _pack(10, 4, 0), "interval": 0.8, "health_scale": 1.0},
		{"name": "Heavy footsteps", "enemies": _pack(10, 4, 2), "interval": 0.75, "health_scale": 1.05},
		{"name": "Break their charge", "enemies": _pack(12, 8, 3), "interval": 0.65, "health_scale": 1.10},
		{"name": "Hold the crossing", "enemies": _pack(15, 10, 5), "interval": 0.6, "health_scale": 1.15},
		{"name": "The last stand", "enemies": _pack(18, 12, 7), "interval": 0.5, "health_scale": 1.2},
	]

static func _pack(goblins: int, scouts: int, brutes: int) -> Array[String]:
	var result: Array[String] = []
	var counts: Array[int] = [goblins, scouts, brutes]
	var names: Array[String] = ["goblin", "scout", "brute"]
	while counts[0] + counts[1] + counts[2] > 0:
		for i: int in range(3):
			if counts[i] > 0:
				result.append(names[i])
				counts[i] -= 1
	return result
