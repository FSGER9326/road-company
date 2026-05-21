extends RefCounted
class_name AutoplaySmoke

const CompanyStateScript = preload("res://game/scripts/core/CompanyState.gd")
const RoadSystemScript = preload("res://game/scripts/road/RoadSystem.gd")
const ContractSystemScript = preload("res://game/scripts/contracts/ContractSystem.gd")
const CombatSystemScript = preload("res://game/scripts/combat/CombatSystem.gd")
const CampSystemScript = preload("res://game/scripts/camp/CampSystem.gd")

var data: DataStore
var seed := 12345

func setup(new_data: DataStore, new_seed: int = 12345) -> void:
	data = new_data
	seed = new_seed

func run_escort_smoke() -> Dictionary:
	var company = CompanyStateScript.new()
	company.load_from_start(data.company_start)
	var road_system = RoadSystemScript.new()
	road_system.setup(data, seed)
	var contract_system = ContractSystemScript.new()
	var combat_system = CombatSystemScript.new()
	combat_system.setup(data, company, seed)
	var camp_system = CampSystemScript.new()

	var contract = data.by_id(data.contracts, "escort_embermill")
	if contract.is_empty():
		return _fail("escort_embermill contract is missing")
	if not contract_system.accept(company, contract):
		return _fail("could not accept escort contract")
	var route = data.by_id(data.routes, contract.get("target_route", ""))
	if route.is_empty():
		return _fail("escort target route is missing")
	var travel = road_system.travel(company, route)
	if not travel.get("ok", false):
		return _fail(travel.get("error", "travel failed"))
	var context = travel.get("context", {})
	context["starts_combat"] = true
	context["ambush"] = true
	context["escort_objective"] = true
	context["seed"] = seed

	var terrain = combat_system.build_terrain(context.get("terrain_tags", []))
	var units = combat_system.build_units(context)
	var combat_result = _scripted_combat(combat_system, units, terrain)
	company.apply_combat_result(combat_result)
	if combat_result.get("victory", false):
		company.move_to(travel.get("destination", company.current_location))
		if contract_system.active_contract_completed(company, route, travel.get("destination", "")):
			contract_system.complete(company)
	elif combat_result.get("objective_failed", false):
		contract_system.fail(company)
	camp_system.rest(company)
	return {
		"ok": true,
		"scenario": "escort_smoke",
		"victory": combat_result.get("victory", false),
		"rounds": combat_result.get("rounds", 0),
		"location": company.current_location,
		"active_contract": company.has_active_contract(),
		"roster_count": company.roster.size(),
		"graveyard_count": company.graveyard.size()
	}

func _scripted_combat(combat_system: CombatSystem, units: Array, terrain: Dictionary) -> Dictionary:
	var max_rounds = 8
	var rounds = 0
	for round_index in range(max_rounds):
		rounds = round_index + 1
		var order = combat_system.turn_order(units)
		for unit_id in order:
			var actor = _unit_by_id(units, unit_id)
			if actor.is_empty() or not bool(actor.get("alive", true)) or actor.get("morale_state", "steady") == "breaking":
				continue
			actor["ap"] = 9
			if actor.get("side", "") == "player":
				_player_scripted_turn(combat_system, units, actor, terrain)
			elif actor.get("side", "") == "enemy":
				_enemy_scripted_turn(combat_system, units, actor, terrain)
			if _alive_units(units, "enemy").is_empty():
				return _combat_result(units, true, "Autoplay defeated the ambushers.", false, rounds)
			var wagon = _objective_unit(units)
			if not wagon.is_empty() and not bool(wagon.get("alive", true)):
				return _combat_result(units, false, "Autoplay wagon destroyed.", true, rounds)
		var wagon_after_round = _objective_unit(units)
		if not wagon_after_round.is_empty() and round_index >= 4 and bool(wagon_after_round.get("alive", true)):
			return _combat_result(units, true, "Autoplay wagon survived the ambush clock.", false, rounds)
	return _combat_result(units, not _alive_units(units, "player").is_empty(), "Autoplay reached max rounds.", false, rounds)

func _player_scripted_turn(combat_system: CombatSystem, units: Array, actor: Dictionary, terrain: Dictionary) -> void:
	var target = _nearest_alive(units, actor, "enemy", combat_system)
	if target.is_empty():
		return
	_act_toward_and_attack(combat_system, units, actor, target, terrain)

func _enemy_scripted_turn(combat_system: CombatSystem, units: Array, actor: Dictionary, terrain: Dictionary) -> void:
	var target = _objective_unit(units)
	if target.is_empty() or not bool(target.get("alive", true)):
		target = _nearest_alive(units, actor, "player", combat_system)
	if target.is_empty():
		return
	_act_toward_and_attack(combat_system, units, actor, target, terrain)

func _act_toward_and_attack(combat_system: CombatSystem, units: Array, actor: Dictionary, target: Dictionary, terrain: Dictionary) -> void:
	var weapon = data.get_weapon(actor.get("weapon_id", ""))
	var range_limit = int(weapon.get("range", 1))
	while int(actor.get("ap", 0)) >= 3 and combat_system.hex_distance(actor.get("q", 0), actor.get("r", 0), target.get("q", 0), target.get("r", 0)) > range_limit:
		var step = _best_step(combat_system, units, actor, target, terrain.get("blocked", {}))
		if step.is_empty():
			break
		if not combat_system.move_unit(actor, step.get("q", actor.get("q", 0)), step.get("r", actor.get("r", 0)), terrain.get("slow", {})):
			break
	if bool(target.get("alive", true)) and combat_system.hex_distance(actor.get("q", 0), actor.get("r", 0), target.get("q", 0), target.get("r", 0)) <= range_limit:
		combat_system.attack(actor, target, weapon)

func _best_step(combat_system: CombatSystem, units: Array, actor: Dictionary, target: Dictionary, blocked: Dictionary) -> Dictionary:
	var candidates = [
		Vector2i(actor.get("q", 0) + 1, actor.get("r", 0)),
		Vector2i(actor.get("q", 0) - 1, actor.get("r", 0)),
		Vector2i(actor.get("q", 0), actor.get("r", 0) + 1),
		Vector2i(actor.get("q", 0), actor.get("r", 0) - 1),
		Vector2i(actor.get("q", 0) + 1, actor.get("r", 0) - 1),
		Vector2i(actor.get("q", 0) - 1, actor.get("r", 0) + 1)
	]
	var best = {}
	var best_dist = combat_system.hex_distance(actor.get("q", 0), actor.get("r", 0), target.get("q", 0), target.get("r", 0))
	for candidate in candidates:
		var key = "%s,%s" % [candidate.x, candidate.y]
		if blocked.has(key) or not _unit_at(units, candidate.x, candidate.y).is_empty():
			continue
		if candidate.x < 0 or candidate.x > 8 or candidate.y < 0 or candidate.y > 6:
			continue
		var dist = combat_system.hex_distance(candidate.x, candidate.y, target.get("q", 0), target.get("r", 0))
		if dist < best_dist:
			best_dist = dist
			best = {"q": candidate.x, "r": candidate.y}
	return best

func _combat_result(units: Array, victory: bool, headline: String, objective_failed: bool, rounds: int) -> Dictionary:
	var updates = {}
	var dead_ids = []
	var casualties = []
	var injuries = []
	for unit in units:
		if unit.get("side", "") == "player":
			updates[unit.get("id", "")] = {
				"hp": int(unit.get("hp", 0)),
				"armor_body": int(unit.get("armor_body", 0)),
				"armor_head": int(unit.get("armor_head", 0)),
				"fatigue": int(unit.get("fatigue", 0)),
				"morale_state": unit.get("morale_state", "steady"),
				"injuries": unit.get("injuries", [])
			}
			if not bool(unit.get("alive", true)):
				dead_ids.append(unit.get("id", ""))
				casualties.append(unit.get("name", "Unknown"))
			elif unit.get("injuries", []).size() > 0:
				injuries.append("%s: %s" % [unit.get("name", "Unknown"), ", ".join(unit.get("injuries", []))])
	return {
		"victory": victory,
		"headline": headline,
		"objective_failed": objective_failed,
		"rounds": rounds,
		"roster_updates": updates,
		"dead_ids": dead_ids,
		"casualties": casualties,
		"injuries": injuries,
		"crowns_delta": 95 if victory else 0,
		"food_delta": 0,
		"tools_delta": 1 if victory else 0,
		"medicine_delta": 0,
		"ammo_delta": -1,
		"morale_delta": 5 if victory else -10,
		"vigor_delta": -8,
		"loot": {"crowns": 95 if victory else 0, "tools": 1 if victory else 0}
	}

func _nearest_alive(units: Array, actor: Dictionary, side: String, combat_system: CombatSystem) -> Dictionary:
	var best = {}
	var best_dist = 999
	for unit in units:
		if unit.get("side", "") == side and bool(unit.get("alive", true)):
			var dist = combat_system.hex_distance(actor.get("q", 0), actor.get("r", 0), unit.get("q", 0), unit.get("r", 0))
			if dist < best_dist:
				best_dist = dist
				best = unit
	return best

func _alive_units(units: Array, side: String) -> Array:
	var found = []
	for unit in units:
		if unit.get("side", "") == side and bool(unit.get("alive", true)):
			found.append(unit)
	return found

func _objective_unit(units: Array) -> Dictionary:
	for unit in units:
		if unit.get("side", "") == "objective":
			return unit
	return {}

func _unit_by_id(units: Array, unit_id: String) -> Dictionary:
	for unit in units:
		if unit.get("id", "") == unit_id:
			return unit
	return {}

func _unit_at(units: Array, q: int, r: int) -> Dictionary:
	for unit in units:
		if bool(unit.get("alive", true)) and int(unit.get("q", -1)) == q and int(unit.get("r", -1)) == r:
			return unit
	return {}

func _fail(reason: String) -> Dictionary:
	return {"ok": false, "scenario": "escort_smoke", "error": reason}
