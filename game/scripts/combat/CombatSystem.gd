extends RefCounted
class_name CombatSystem

const SeededRngScript = preload("res://game/scripts/core/SeededRng.gd")

var data: DataStore
var company: CompanyState
var rng: SeededRng

func setup(new_data: DataStore, new_company: CompanyState, seed: int = 12345) -> void:
	data = new_data
	company = new_company
	rng = SeededRngScript.new()
	rng.configure(seed)

func build_cells(width: int = 9, height: int = 7) -> Array:
	var cells = []
	for r in range(height):
		for q in range(width):
			cells.append({"q": q, "r": r})
	return cells

func build_terrain(terrain_tags: Array) -> Dictionary:
	var blocked = {}
	var slow = {}
	if terrain_tags.has("forest"):
		for key in ["4,1", "4,5", "5,2"]:
			blocked[key] = true
		for key in ["3,2", "3,3", "4,3", "5,4"]:
			slow[key] = true
	if terrain_tags.has("mud") or terrain_tags.has("marsh"):
		for key in ["3,4", "4,4", "5,3", "5,5", "6,3"]:
			slow[key] = true
	return {"blocked": blocked, "slow": slow}

func build_units(context: Dictionary) -> Array:
	var units = []
	var starts = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 2), Vector2i(2, 4)]
	var i = 0
	for fighter in company.roster:
		if i >= starts.size():
			break
		var p = starts[i]
		var unit = fighter.duplicate(true)
		unit["side"] = "player"
		unit["q"] = p.x
		unit["r"] = p.y
		unit["alive"] = int(unit.get("hp", 1)) > 0
		unit["ap"] = 9
		if context.get("low_vigor", false):
			unit["fatigue"] = int(unit.get("fatigue", 0)) + 12
		unit["abbr"] = unit.get("name", "?").left(2)
		units.append(unit)
		i += 1
	if context.get("escort_objective", false):
		units.append(build_wagon())
	var encounter = data.get_encounter(context.get("encounter_id", "road_raiders"))
	var enemy_ids = encounter.get("enemies", ["raider_cutthroat", "raider_thug", "raider_archer", "raider_cutthroat", "raider_thug"])
	var enemy_starts = [Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(8, 2), Vector2i(8, 4), Vector2i(8, 3)]
	for enemy_index in range(min(enemy_ids.size(), enemy_starts.size())):
		var enemy_data = data.get_enemy(enemy_ids[enemy_index]).duplicate(true)
		var ep = enemy_starts[enemy_index]
		enemy_data["id"] = "%s_%s" % [enemy_data.get("id", "enemy"), enemy_index]
		enemy_data["side"] = "enemy"
		enemy_data["q"] = ep.x
		enemy_data["r"] = ep.y
		enemy_data["alive"] = true
		enemy_data["ap"] = 9
		enemy_data["abbr"] = enemy_data.get("name", "EN").left(2)
		units.append(enemy_data)
	return units

func build_wagon() -> Dictionary:
	return {
		"id": "escort_wagon",
		"name": "Cargo Wagon",
		"abbr": "WG",
		"side": "objective",
		"q": 2,
		"r": 3,
		"hp": 90,
		"max_hp": 90,
		"armor_body": 25,
		"armor_head": 0,
		"fatigue": 0,
		"max_fatigue": 999,
		"morale_state": "steady",
		"action_points": 0,
		"ap": 0,
		"melee_skill": 0,
		"melee_defense": 5,
		"ranged_defense": 0,
		"resolve": 80,
		"initiative": 0,
		"weapon_id": "wagon_axle",
		"alive": true
	}

func turn_order(units: Array) -> Array:
	var ids = []
	for unit in units:
		if bool(unit.get("alive", true)) and unit.get("side", "") != "objective" and unit.get("morale_state", "steady") != "breaking":
			ids.append(unit.get("id", ""))
	ids.sort_custom(func(a, b): return int(_unit_by_id(units, a).get("initiative", 0)) > int(_unit_by_id(units, b).get("initiative", 0)))
	return ids

func move_unit(unit: Dictionary, q: int, r: int, slow_cells: Dictionary = {}) -> bool:
	var cost = 3
	if slow_cells.has("%s,%s" % [q, r]):
		cost += 1
	if int(unit.get("ap", 0)) < cost:
		return false
	unit["q"] = q
	unit["r"] = r
	unit["ap"] = int(unit.get("ap", 0)) - cost
	unit["fatigue"] = int(unit.get("fatigue", 0)) + cost
	return true

func attack(attacker: Dictionary, defender: Dictionary, weapon: Dictionary) -> Dictionary:
	var ap_cost = int(weapon.get("ap_cost", 4))
	if int(attacker.get("ap", 0)) < ap_cost:
		return {"ok": false, "reason": "not_enough_ap"}
	attacker["ap"] = int(attacker.get("ap", 0)) - ap_cost
	attacker["fatigue"] = int(attacker.get("fatigue", 0)) + int(weapon.get("fatigue_cost", 6))
	var attack_skill = int(attacker.get("melee_skill", 50))
	var defense = int(defender.get("melee_defense", 0))
	if int(weapon.get("range", 1)) > 1:
		attack_skill = int(attacker.get("ranged_skill", attack_skill))
		defense = int(defender.get("ranged_defense", defense))
	var chance = clamp(55 + attack_skill - defense + int(weapon.get("hit_bonus", 0)), 15, 95)
	var roll = rng.range_i(1, 100)
	if roll > chance:
		return {"ok": true, "hit": false, "roll": roll, "chance": chance}
	var damage = rng.range_i(int(weapon.get("damage_min", 12)), int(weapon.get("damage_max", 20)))
	var damage_result = apply_damage(defender, damage, weapon)
	return {"ok": true, "hit": true, "roll": roll, "chance": chance, "damage": damage, "damage_result": damage_result}

func apply_damage(defender: Dictionary, damage: int, weapon: Dictionary, force_body: bool = true) -> Dictionary:
	var armor_key = "armor_body"
	if not force_body and rng.chance(20) and int(defender.get("armor_head", 0)) > 0:
		armor_key = "armor_head"
	var armor_before = int(defender.get(armor_key, 0))
	var armor_damage = min(armor_before, int(float(damage) * float(weapon.get("armor_damage", 1.0))))
	defender[armor_key] = max(0, armor_before - armor_damage)
	var hp_damage = max(0, damage - armor_before)
	if armor_before <= 0:
		hp_damage = damage
	defender["hp"] = max(0, int(defender.get("hp", 1)) - hp_damage)
	if hp_damage >= 14 and defender.get("side", "") != "objective":
		morale_check(defender, 18)
	if int(defender.get("hp", 0)) <= 0:
		defender["alive"] = false
	return {"armor_key": armor_key, "armor_damage": armor_damage, "hp_damage": hp_damage, "dead": not bool(defender.get("alive", true))}

func morale_check(unit: Dictionary, penalty: int) -> bool:
	var company_morale = 50
	if company != null:
		company_morale = company.morale
	var target = clamp(int(unit.get("resolve", 40)) + int(company_morale * 0.25) - penalty, 10, 95)
	if rng.range_i(1, 100) <= target:
		return true
	var state = unit.get("morale_state", "steady")
	if state == "steady":
		unit["morale_state"] = "wavering"
	elif state == "wavering":
		unit["morale_state"] = "breaking"
	return false

func ally_death_morale(units: Array, side: String) -> void:
	for unit in units:
		if unit.get("side", "") == side and bool(unit.get("alive", true)):
			morale_check(unit, 24)

func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 = -q1 - r1
	var s2 = -q2 - r2
	return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2)

func _unit_by_id(units: Array, unit_id: String) -> Dictionary:
	for unit in units:
		if unit.get("id", "") == unit_id:
			return unit
	return {}
