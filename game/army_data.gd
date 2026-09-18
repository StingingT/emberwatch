class_name ArmyData
extends RefCounted
## Permanent training is independent of run gold, Smith ranks and cosmetics.
const BALANCE_VERSION: int = 1
const MAX_RANK: int = 5
const COSTS: Array[int] = [80, 140, 240, 400, 650]
const STAR_GATES: Array[int] = [0, 3, 6, 9, 12]
const UPGRADES: Dictionary = {
	"hero_damage": {"label": "Bow training", "group": "hero", "step": 0.06, "effect": "Hero damage"},
	"hero_health": {"label": "Endurance", "group": "hero", "step": 0.10, "effect": "Hero health"},
	"tower_damage": {"label": "Archer drills", "group": "army", "step": 0.06, "effect": "Tower damage"},
	"tower_haste": {"label": "Ready strings", "group": "army", "step": 0.04, "effect": "Tower fire rate"},
	"fortifications": {"label": "Masonry", "group": "army", "step": 0.10, "effect": "Wall and Keep health"},
	"mine_output": {"label": "Mining tools", "group": "army", "step": 0.10, "effect": "Mine gold output"},
}
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_defense", "name": "First defense", "metric": "missions", "target": 1, "reward": 25},
	{"id": "three_fronts", "name": "Three fronts", "metric": "missions", "target": 3, "reward": 50},
	{"id": "last_light", "name": "Keep the last light", "metric": "missions", "target": 6, "reward": 100},
	{"id": "three_stars", "name": "A promising start", "metric": "stars", "target": 3, "reward": 25},
	{"id": "six_stars", "name": "Holding the line", "metric": "stars", "target": 6, "reward": 50},
	{"id": "nine_stars", "name": "Veteran defender", "metric": "stars", "target": 9, "reward": 75},
	{"id": "twelve_stars", "name": "Master defender", "metric": "stars", "target": 12, "reward": 100},
	{"id": "eighteen_stars", "name": "An unbroken realm", "metric": "stars", "target": 18, "reward": 150},
]

static func rank_of(ranks: Dictionary, id: String) -> int:
	return clampi(int(ranks.get(id, 0)), 0, MAX_RANK)

static func multiplier(ranks: Dictionary, id: String) -> float:
	return 1.0 + rank_of(ranks, id) * float(UPGRADES[id]["step"])

static func valid_ranks(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for id: Variant in value:
		if not id is String or not UPGRADES.has(id) or not whole(value[id], MAX_RANK):
			return false
	return true

static func whole(value: Variant, limit: int = 1000000000) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) >= 0 and float(value) <= limit and floorf(float(value)) == float(value)

static func stars(results: Dictionary) -> int:
	var total: int = 0
	for record: Dictionary in results.values():
		total += clampi(int(record.get("stars", 0)), 0, 3)
	return total

static func wave_supplies(mission_index: int, cleared: int) -> int:
	return maxi(0, cleared) * (12 + 4 * maxi(0, mission_index))

static func victory_supplies(mission_index: int, earned_stars: int, first_clear: bool) -> int:
	return 40 + 12 * maxi(0, mission_index) + 8 * clampi(earned_stars, 1, 3) + (40 if first_clear else 0)

static func ad_bonus(normal_supplies: int) -> int:
	# 50% of the entire normal mission reward; never achievement grants.
	return floori(maxi(0, normal_supplies) * 0.5)

static func hero_stats(base: Dictionary, ranks: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result["health"] = float(base["health"]) * multiplier(ranks, "hero_health")
	for key: String in ["damage", "damage_per_tier", "ability_damage"]:
		result[key] = float(base[key]) * multiplier(ranks, "hero_damage")
	return result
