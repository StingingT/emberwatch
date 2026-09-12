class_name CampaignData
extends RefCounted
## Six authored offline defenses. Each call returns independent, mutable run data.
## Mission 0 delegates directly to GameData so the accepted Briarwood regression
## fixture retains its route, plot IDs, starting balance and six original waves.
## Later missions vary routes and available construction, not the combat rules.
## All route segments advance in Z; walls occupy straight north/south segments.
## Palette keys are optional Battlefield presentation data. Run controllers own
## starting_coins and building_limits; no permanent progression is applied here.

const Data = preload("res://game/game_data.gd")
const BOUNDS := Rect2(-10, -30, 20, 43)
const KEEP := Vector3(0, 0, 9)

static func missions() -> Array[Dictionary]:
	return [
		{"id": "briarwood", "name": "Briarwood Crossing",
			"briefing": "Gather gold, build towers, and hold the crossing against the goblins.",
			"level": Data.level(), "waves": Data.waves()},
		_amberfield(), _stonegate(), _sunscar(), _moonfen(), _emberfall(),
	]

static func _amberfield() -> Dictionary:
	var route: Array[Vector3] = [Vector3(-5, 0, -28), Vector3(-5, 0, -18),
		Vector3(2, 0, -12), Vector3(2, 0, -3), Vector3(0, 0, 3), KEEP]
	var plots: Array[Dictionary] = [
		_plot("orchard", "tower", -1.8, -22),
		_plot("harvest", "tower", -7.9, -14.3),
		_plot("crosswind", "tower", -1.2, -10.4),
		_plot("eastern", "tower", 5.2, -6),
		_plot("hearth", "tower", -3.3, 1),
		_plot("southwatch", "tower", 3.5, 5.3),
		_plot("fieldgate", "wall", 2, -7),
		_plot("granary", "support", -6, -5),
		_plot("workshop", "support", 5.9, 0.8),
	]
	var waves: Array[Dictionary] = [
		_wave("Wolf pelts — dodge their strikes", 10, 2, 0, 1.15, 1.04, 1),
		_wave("Orchard raiders", 12, 5, 1, 0.82, 1.08),
		_wave("Hunters at the bend", 14, 5, 2, 0.70, 1.12, 2),
		_wave("The harvest horde", 16, 9, 4, 0.60, 1.18),
		_wave("Hold the homesteads", 20, 9, 6, 0.50, 1.24, 3),
	]
	return _mission("amberfield", "Amberfield Road",
		"Wolf-pelt hunters pursue you near the road. Dodge their marked strikes and lead them into tower fire.",
		route, plots, Vector3(-1.8, 0, -19.3), waves, 110,
		_palette("a1aa69", "d9bf84", "aeb57b", "c1ccb0"))

static func _stonegate() -> Dictionary:
	var route: Array[Vector3] = [Vector3(5, 0, -28), Vector3(5, 0, -21),
		Vector3(0, 0, -16), Vector3(0, 0, -5), Vector3(-4, 0, 0),
		Vector3(-4, 0, 4), KEEP]
	var plots: Array[Dictionary] = [
		_plot("west_battery", "tower", -3.2, -13),
		_plot("outpost", "tower", 1.7, -24),
		_plot("east_battery", "tower", 3.2, -7),
		_plot("last_battery", "tower", -0.7, 2.7),
		_plot("north_gate", "wall", 5, -24.5),
		_plot("middle_gate", "wall", 0, -10),
		_plot("south_gate", "wall", -4, 2),
		_plot("stoneworks", "support", -6.7, -8),
		_plot("garrison", "support", 4.5, 2.5),
	]
	var waves: Array[Dictionary] = [
		_wave("At the first gate", 10, 3, 1, 0.95, 1.08),
		_wave("Hunters behind the iron", 12, 2, 2, 0.82, 1.12, 2),
		_wave("Hammering the walls", 14, 5, 3, 0.74, 1.16),
		_wave("A breach in the line", 14, 4, 4, 0.66, 1.20, 3),
		_wave("The heavy column", 17, 8, 6, 0.56, 1.25),
		_wave("Three gates stand", 18, 10, 7, 0.50, 1.30),
	]
	return _mission("stonegate", "Stonegate March",
		"Four towers and three gates. Upgrade towers and hold the choke points.",
		route, plots, Vector3(-3.2, 0, -10.4), waves, 120,
		_palette("789783", "c6bea0", "94aa89", "acc6be"))

static func _sunscar() -> Dictionary:
	var route: Array[Vector3] = [Vector3(-4, 0, -28), Vector3(-4, 0, -21),
		Vector3(5, 0, -14), Vector3(5, 0, -4), Vector3(0, 0, 2), KEEP]
	var plots: Array[Dictionary] = [
		_plot("inner_bend", "tower", 1.8, -7.5),
		_plot("west_sentry", "tower", -7.3, -24),
		_plot("north_sentry", "tower", -0.7, -25),
		_plot("ridge", "tower", -1, -13.8),
		_plot("east_sentry", "tower", 8, -10),
		_plot("south_sentry", "tower", 5.6, 1.8),
		_plot("keep_sentry", "tower", -3.3, 5),
		_plot("sun_gate", "wall", 5, -10.3),
		_plot("home_gate", "wall", 0, 4),
		_plot("lone_workyard", "support", -5, -1),
	]
	var waves: Array[Dictionary] = [
		_wave("Dust on the horizon", 10, 5, 1, 0.90, 1.10),
		_wave("Across the dry fields", 12, 6, 2, 0.80, 1.14),
		_wave("The long crossing", 14, 8, 3, 0.70, 1.18),
		_wave("Scouts at the bend", 16, 8, 4, 0.61, 1.23),
		_wave("No ground to give", 18, 10, 6, 0.53, 1.29),
		_wave("Under the red sun", 18, 12, 8, 0.47, 1.35),
	]
	return _mission("sunscar", "Sunscar Bend",
		"Seven towers, one support plot. Choose a Gold Mine OR a Smith.",
		route, plots, Vector3(1.8, 0, -10.1), waves, 150,
		_palette("a9a273", "d8b784", "b6ae83", "d0c7a6"))

static func _moonfen() -> Dictionary:
	var route: Array[Vector3] = [Vector3(-5, 0, -28), Vector3(-5, 0, -23),
		Vector3(4, 0, -18), Vector3(4, 0, -12), Vector3(-4, 0, -6),
		Vector3(-4, 0, 0), Vector3(0, 0, 5), KEEP]
	var plots: Array[Dictionary] = [
		_plot("long_watch", "tower", -0.3, -14.5),
		_plot("moonrise", "tower", -1.8, -25.6),
		_plot("eastern_reach", "tower", 7.2, -15),
		_plot("reed_watch", "tower", -7.2, -3),
		_plot("southern_reach", "tower", 0.2, -0.5),
		_plot("east_causeway", "wall", 4, -14.7),
		_plot("west_causeway", "wall", -4, -2.7),
		_plot("reed_mine", "support", -7.6, -12.8),
		_plot("moon_workshop", "support", 4, 1.8),
		_plot("south_mine", "support", -4.1, 6.5),
	]
	var waves: Array[Dictionary] = [
		_wave("Rustling reeds", 11, 5, 1, 0.92, 1.12),
		_wave("Across the causeway", 13, 6, 2, 0.80, 1.17),
		_wave("The marsh column", 14, 8, 3, 0.71, 1.22),
		_wave("Gold under pressure", 16, 10, 5, 0.62, 1.28),
		_wave("The moonlit charge", 18, 12, 6, 0.53, 1.34),
		_wave("Last light on the fen", 20, 14, 8, 0.46, 1.40),
	]
	var mission: Dictionary = _mission("moonfen", "Moonfen Causeway",
		"Build up to two Gold Mines and one Smith, then strengthen five towers.",
		route, plots, Vector3(0, 0, -11.8), waves, 160,
		_palette("75958d", "c0c2a0", "8fa89a", "a9c8c5"))
	mission["level"]["building_limits"] = {"mine": 2, "smith": 1}
	return mission

static func _emberfall() -> Dictionary:
	var route: Array[Vector3] = [Vector3(0, 0, -28), Vector3(6, 0, -23),
		Vector3(6, 0, -17), Vector3(-5, 0, -11), Vector3(-5, 0, -4),
		Vector3(3, 0, 1), Vector3(3, 0, 6), KEEP]
	var plots: Array[Dictionary] = [
		_plot("northwatch", "tower", 0, -22.5),
		_plot("redoubt", "tower", 8.8, -19),
		_plot("crossfire", "tower", -0.4, -16.7),
		_plot("westwatch", "tower", -8.1, -8.5),
		_plot("forgeguard", "tower", -1.4, -5.3),
		_plot("lastcross", "tower", 6.3, 0),
		_plot("keepwatch", "tower", -0.4, 3.4),
		_plot("red_gate", "wall", 6, -20),
		_plot("black_gate", "wall", -5, -7),
		_plot("last_gate", "wall", 3, 3.5),
		_plot("heartforge", "support", 5.9, -8),
		_plot("goldstore", "support", -5.8, 4.5),
	]
	var waves: Array[Dictionary] = [
		_wave("The final march", 12, 6, 1, 0.92, 1.16),
		_wave("Over the eastern road", 14, 7, 2, 0.81, 1.21),
		_wave("Banners in the smoke", 15, 8, 3, 0.72, 1.26),
		_wave("Hold the western line", 17, 10, 4, 0.63, 1.31),
		_wave("The iron tide", 18, 12, 6, 0.55, 1.36),
		_wave("Before the last dawn", 20, 14, 8, 0.48, 1.42),
		_wave("The light endures", 24, 16, 10, 0.42, 1.48),
	]
	return _mission("emberfall", "Emberfall Watch",
		"Seven waves and three gates. Defend both bends through the final assault.",
		route, plots, Vector3(0, 0, -19.8), waves, 180,
		_palette("95886e", "d0b38b", "a69b7b", "c8bca7"))

static func _mission(id: String, name: String, briefing: String, route: Array[Vector3],
		plots: Array[Dictionary], hero: Vector3, waves: Array[Dictionary], starting_coins: int,
		palette: Dictionary) -> Dictionary:
	return {"id": id, "name": name, "briefing": briefing,
		"level": {"name": name, "bounds": BOUNDS, "route": route, "keep": KEEP,
			"hero": hero, "plots": plots, "starting_coins": starting_coins,
			"palette": palette}, "waves": waves}

static func _plot(id: String, category: String, x: float, z: float) -> Dictionary:
	return {"id": id, "category": category, "position": Vector3(x, 0, z)}

static func _palette(grass: String, trail: String, shoulder: String, sky: String) -> Dictionary:
	return {"grass": Color(grass), "trail": Color(trail), "shoulder": Color(shoulder),
		"sky": Color(sky)}

static func _wave(name: String, goblins: int, scouts: int, brutes: int,
		interval: float, health_scale: float, hunters: int = 0) -> Dictionary:
	var enemies: Array[String] = []
	var counts: Array[int] = [goblins, scouts, brutes, hunters]
	var kinds: Array[String] = ["goblin", "scout", "brute", "hunter"]
	while counts[0] + counts[1] + counts[2] + counts[3] > 0:
		for index: int in range(kinds.size()):
			if counts[index] > 0:
				enemies.append(kinds[index])
				counts[index] -= 1
	return {"name": name, "enemies": enemies, "interval": interval,
		"health_scale": health_scale}
