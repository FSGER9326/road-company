extends RefCounted
class_name ContractGenerator

const CONTRACT_TYPES = ["escort_caravan", "patrol_route", "hunt_bandits", "recover_wagon", "deliver_medicine", "defend_settlement", "bounty_target"]

var defaults = []
var defaults_by_type = {}
var generator_seed = 12345

func configure(new_defaults: Array, seed: int = 12345) -> void:
	defaults = new_defaults
	defaults_by_type.clear()
	for item in defaults:
		defaults_by_type[item.get("type", "")] = item
	generator_seed = seed

func generate_contracts(
	current_location: String,
	settlement_economies: Array,
	route_economies: Array,
	route_links: Array,
	faction_reputation: Dictionary,
	existing_contracts: Array,
	locations: Array,
	factions: Array,
	tick: int = 0,
	internal_factions: Array = []
) -> Array:
	var current_settlement = _settlement_by_id(settlement_economies, current_location)
	if current_settlement.is_empty():
		return []
	var connected_routes = _connected_routes(current_location, route_economies, route_links)
	var settlement_candidates = [current_settlement]
	for route in connected_routes:
		var other_id = _other_end(_route_link(route_links, route.get("route_id", "")), current_location)
		var other_settlement = _settlement_by_id(settlement_economies, other_id)
		if not other_settlement.is_empty() and not settlement_candidates.has(other_settlement):
			settlement_candidates.append(other_settlement)

	var candidates = []
	for settlement in settlement_candidates:
		candidates.append_array(_settlement_candidates(current_location, settlement, connected_routes, route_links, locations, faction_reputation, internal_factions))
	for route in connected_routes:
		candidates.append_array(_route_candidates(current_location, route, settlement_economies, route_links, locations, faction_reputation, internal_factions))

	var filtered = []
	for candidate in candidates:
		if float(candidate.get("score", 0.0)) <= 0.0:
			continue
		if _duplicates_existing(candidate, existing_contracts):
			continue
		filtered.append(candidate)
	filtered.sort_custom(Callable(self, "_sort_candidates"))

	var pressure = _pressure_level(current_settlement, connected_routes)
	var limit = 1
	if pressure >= 4:
		limit = 3
	elif pressure >= 2:
		limit = 2
	var result = []
	var used_keys = {}
	for candidate in filtered:
		if result.size() >= limit:
			break
		var key = "%s|%s|%s" % [candidate.get("type", ""), candidate.get("target_location", ""), candidate.get("target_route", "")]
		if used_keys.has(key):
			continue
		used_keys[key] = true
		result.append(_build_contract(candidate, result.size() + 1, tick, locations, factions))
	return result

func _settlement_candidates(current_location: String, settlement: Dictionary, connected_routes: Array, route_links: Array, locations: Array, faction_reputation: Dictionary, internal_factions: Array = []) -> Array:
	var candidates = []
	var population = int(settlement.get("population", 10))
	var weekly_food_need = max(1, int(ceil(float(population) / 250.0)))
	var food_weeks = float(settlement.get("food_stock", 0)) / float(weekly_food_need)
	var medicine_need = max(1.0, float(population) / 400.0)
	var medicine_ratio = float(settlement.get("medicine_stock", 0)) / medicine_need
	var target_id = settlement.get("settlement_id", "")
	var best_route = _best_route_for_settlement(current_location, target_id, connected_routes, route_links)
	if food_weeks < 2.0:
		candidates.append(_candidate("escort_caravan", current_location, target_id, best_route, 30.0 + (2.0 - food_weeks) * 15.0, "%s food stores are below two weeks" % target_id, {"food_weeks": food_weeks, "food_stock": settlement.get("food_stock", 0), "weekly_food_need": weekly_food_need}, faction_reputation, internal_factions))
	if medicine_ratio < 1.0:
		candidates.append(_candidate("deliver_medicine", current_location, target_id, best_route, 30.0 + (1.0 - medicine_ratio) * 25.0, "%s medicine stock is below need" % target_id, {"medicine_ratio": medicine_ratio, "medicine_stock": settlement.get("medicine_stock", 0), "medicine_need": int(ceil(medicine_need))}, faction_reputation, internal_factions))
	if int(settlement.get("trade_access", 0)) < 30:
		candidates.append(_candidate("escort_caravan", current_location, target_id, best_route, 18.0 + float(30 - int(settlement.get("trade_access", 0))), "%s trade access is low" % target_id, {"trade_access": settlement.get("trade_access", 0)}, faction_reputation, internal_factions))
		candidates.append(_candidate("recover_wagon", current_location, target_id, best_route, 15.0 + float(30 - int(settlement.get("trade_access", 0))), "%s trade access points to missing cargo" % target_id, {"trade_access": settlement.get("trade_access", 0)}, faction_reputation, internal_factions))
	if int(settlement.get("security", 0)) < 35:
		candidates.append(_candidate("defend_settlement", current_location, target_id, best_route, 25.0 + float(35 - int(settlement.get("security", 0))), "%s security is low" % target_id, {"security": settlement.get("security", 0)}, faction_reputation, internal_factions))
	if int(settlement.get("unrest", 0)) > 50:
		candidates.append(_candidate("bounty_target", current_location, target_id, best_route, 20.0 + float(int(settlement.get("unrest", 0)) - 50), "%s unrest is high" % target_id, {"unrest": settlement.get("unrest", 0)}, faction_reputation, internal_factions))
	return candidates

func _route_candidates(current_location: String, route: Dictionary, settlement_economies: Array, route_links: Array, locations: Array, faction_reputation: Dictionary, internal_factions: Array = []) -> Array:
	var candidates = []
	var route_id = route.get("route_id", "")
	var link = _route_link(route_links, route_id)
	var target_id = _other_end(link, current_location)
	var danger = int(route.get("danger", 0))
	var bandits = int(route.get("bandit_pressure", 0))
	if danger > 40:
		candidates.append(_candidate("patrol_route", current_location, target_id, route, 25.0 + float(danger - 40), "%s danger is high" % route_id, {"route.danger": danger}, faction_reputation, internal_factions))
		candidates.append(_candidate("escort_caravan", current_location, target_id, route, 15.0 + float(danger - 40) * 0.5, "%s needs guarded caravans" % route_id, {"route.danger": danger}, faction_reputation, internal_factions))
	if bool(route.get("blocked", false)):
		candidates.append(_candidate("patrol_route", current_location, target_id, route, 45.0, "%s is blocked" % route_id, {"route.blocked": true}, faction_reputation, internal_factions))
	if bandits > 40:
		candidates.append(_candidate("patrol_route", current_location, target_id, route, 25.0 + float(bandits - 40), "%s bandit pressure is high" % route_id, {"route.bandit_pressure": bandits}, faction_reputation, internal_factions))
	if bandits > 55:
		candidates.append(_candidate("hunt_bandits", current_location, target_id, route, 35.0 + float(bandits - 55), "%s bandits are organized" % route_id, {"route.bandit_pressure": bandits}, faction_reputation, internal_factions))
	else:
		candidates.append(_candidate("hunt_bandits", current_location, target_id, route, max(0.0, float(bandits - 40)), "%s bandits are active" % route_id, {"route.bandit_pressure": bandits}, faction_reputation, internal_factions))
	if int(route.get("traffic", 0)) > 30 and danger > 50:
		candidates.append(_candidate("recover_wagon", current_location, target_id, route, 20.0 + float(danger - 50), "%s has traffic and frequent losses" % route_id, {"route.traffic": route.get("traffic", 0), "route.danger": danger}, faction_reputation, internal_factions))
	if int(route.get("monster_pressure", 0)) > 30:
		candidates.append(_candidate("defend_settlement", current_location, target_id, route, 20.0 + float(int(route.get("monster_pressure", 0)) - 30), "%s has monster pressure near settlements" % route_id, {"route.monster_pressure": route.get("monster_pressure", 0)}, faction_reputation, internal_factions))
	return candidates

func _candidate(contract_type: String, origin: String, target: String, route: Dictionary, score: float, reason: String, trigger_fields: Dictionary, faction_reputation: Dictionary, internal_factions: Array = []) -> Dictionary:
	var preference = _internal_faction_preference(target if not target.is_empty() else origin, contract_type, internal_factions)
	return {
		"type": contract_type,
		"origin_location": origin,
		"target_location": target if not target.is_empty() else origin,
		"target_route": route.get("route_id", ""),
		"route": route,
		"score": score * float(preference.get("score_multiplier", 1.0)) + float(_deterministic_jitter(contract_type, origin, target, route.get("route_id", ""))) / 100.0,
		"reason": reason,
		"trigger_fields": trigger_fields,
		"internal_patron_faction": preference.get("internal_patron_faction", ""),
		"internal_reward_multiplier": preference.get("reward_multiplier", 1.0)
	}

func _build_contract(candidate: Dictionary, index: int, tick: int, locations: Array, factions: Array) -> Dictionary:
	var contract_type = candidate.get("type", "")
	var defaults_for_type = defaults_by_type.get(contract_type, {})
	var origin_id = candidate.get("origin_location", "")
	var target_id = candidate.get("target_location", origin_id)
	var route = candidate.get("route", {})
	var target_location = _location_by_id(locations, target_id)
	var origin_location = _location_by_id(locations, origin_id)
	var route_days = max(1, int(route.get("days", 2)))
	var urgency = _calculate_urgency(float(candidate.get("score", 0.0)))
	var danger = _calculate_danger(_settlement_stub(target_id), route)
	var prosperity = int(target_location.get("prosperity", 50))
	var reward_crowns = _clamp_int(int(round(float(_calculate_reward(int(defaults_for_type.get("base_crowns", 250)), danger, urgency, route_days, prosperity)) * float(candidate.get("internal_reward_multiplier", 1.0)))), 50, 5000)
	var reward_renown = _clamp_int(int(round(float(defaults_for_type.get("base_renown", 8)) * (0.8 + float(urgency) * 0.05) * (0.8 + float(route_days) * 0.05))), 2, 50)
	var patron_faction = _pick_patron_faction(target_location, origin_location)
	var route_success = defaults_for_type.get("route_effects_success", {}).duplicate(true)
	var route_failure = defaults_for_type.get("route_effects_failure", {}).duplicate(true)
	var settlement_success = {}
	var settlement_failure = {}
	settlement_success[target_id] = defaults_for_type.get("settlement_effects_success", {}).duplicate(true)
	settlement_failure[target_id] = defaults_for_type.get("settlement_effects_failure", {}).duplicate(true)
	var target_name = target_location.get("name", target_id)
	var route_name = route.get("route_id", "local roads").replace("_", " ")
	var vars = {"target_name": target_name, "route_name": route_name}
	return {
		"id": "%s_%s_%s_%03d" % [contract_type, origin_id, target_id, index],
		"title": str(defaults_for_type.get("title_template", contract_type)).format(vars),
		"type": contract_type,
		"patron_faction": patron_faction,
		"internal_patron_faction": candidate.get("internal_patron_faction", ""),
		"origin_location": origin_id,
		"target_location": target_id,
		"target_route": route.get("route_id", ""),
		"urgency": urgency,
		"danger": danger,
		"reward_crowns": reward_crowns,
		"reward_renown": reward_renown,
		"description": str(defaults_for_type.get("description_template", "")).format(vars),
		"success_text": str(defaults_for_type.get("success_template", "")).format(vars),
		"failure_text": str(defaults_for_type.get("failure_template", "")).format(vars),
		"encounter_id": defaults_for_type.get("encounter_id", "road_raiders"),
		"encounter_tags": [contract_type],
		"required_cargo_or_objective": defaults_for_type.get("required_objective", ""),
		"faction_effects": {patron_faction: max(2, int(defaults_for_type.get("base_renown", 8) / 2))},
		"failure_faction_effects": {patron_faction: -max(2, int(defaults_for_type.get("base_renown", 8) / 2))},
		"route_effects_on_success": route_success,
		"route_effects_on_failure": route_failure,
		"settlement_effects_on_success": settlement_success,
		"settlement_effects_on_failure": settlement_failure,
		"success_effects": {"route": route_success, "settlement": settlement_success},
		"failure_effects": {"route": route_failure, "settlement": settlement_failure},
		"route_effects": {"success": route_success, "failure": route_failure},
		"settlement_effects": {"success": settlement_success, "failure": settlement_failure},
		"generated_from": {
			"world_state_reason": candidate.get("reason", ""),
			"trigger_fields": candidate.get("trigger_fields", {}),
			"internal_faction_preference": candidate.get("internal_patron_faction", ""),
			"seed_offset": _deterministic_jitter(contract_type, origin_id, target_id, route.get("route_id", ""))
		},
		"expires_after_days": _expires_after(urgency, danger),
		"expires_after_ticks": _expires_after(urgency, danger),
		"seed": generator_seed
	}

func _sort_candidates(a: Dictionary, b: Dictionary) -> bool:
	if float(a.get("score", 0.0)) == float(b.get("score", 0.0)):
		return str(a.get("type", "")) < str(b.get("type", ""))
	return float(a.get("score", 0.0)) > float(b.get("score", 0.0))

func _pressure_level(settlement: Dictionary, connected_routes: Array) -> int:
	var pressure = 0
	var population = int(settlement.get("population", 10))
	var weekly_food_need = max(1, int(ceil(float(population) / 250.0)))
	if int(settlement.get("food_stock", 0)) < weekly_food_need * 2:
		pressure += 1
	if float(settlement.get("medicine_stock", 0)) < max(1.0, float(population) / 400.0):
		pressure += 1
	if int(settlement.get("security", 0)) < 35 or int(settlement.get("unrest", 0)) > 50:
		pressure += 1
	for route in connected_routes:
		if int(route.get("danger", 0)) > 40 or int(route.get("bandit_pressure", 0)) > 40 or bool(route.get("blocked", false)):
			pressure += 1
	return pressure

func _calculate_urgency(score: float) -> int:
	return _clamp_int(int(ceil(score / 20.0)), 1, 5)

func _calculate_danger(settlement: Dictionary, route: Dictionary) -> int:
	if not route.is_empty():
		return _clamp_int(int(round(float(route.get("danger", 0)) * 0.08 + float(route.get("bandit_pressure", 0)) * 0.04)), 1, 10)
	return _clamp_int(int(round((100.0 - float(settlement.get("security", 50)) + float(settlement.get("unrest", 0))) / 20.0)), 1, 10)

func _calculate_reward(base: int, danger: int, urgency: int, route_days: int, prosperity: int) -> int:
	var danger_mult = 0.8 + float(danger) * 0.05
	var urgency_mult = 0.8 + float(urgency) * 0.05
	var distance_mult = 0.8 + float(route_days) * 0.05
	var wealth_mult = 0.9 + float(prosperity) / 500.0
	return _clamp_int(int(round(float(base) * danger_mult * urgency_mult * distance_mult * wealth_mult)), 50, 5000)

func _expires_after(urgency: int, danger: int) -> int:
	return _clamp_int(max(3, int(round(float(urgency) * 2.0 - float(danger) * 0.5))), 0, 52)

func _pick_patron_faction(target_location: Dictionary, origin_location: Dictionary) -> String:
	var influence = target_location.get("faction_influence", {})
	if influence.is_empty():
		influence = origin_location.get("faction_influence", {})
	var best = ""
	var best_value = -999
	for faction_id in influence.keys():
		if int(influence[faction_id]) > best_value:
			best = faction_id
			best_value = int(influence[faction_id])
	return best if not best.is_empty() else "ashen_crown"

func _duplicates_existing(candidate: Dictionary, existing_contracts: Array) -> bool:
	for contract in existing_contracts:
		if contract.get("type", "") == candidate.get("type", "") and contract.get("target_route", "") == candidate.get("target_route", "") and contract.get("target_location", "") == candidate.get("target_location", ""):
			return true
	return false

func _connected_routes(location_id: String, route_economies: Array, route_links: Array) -> Array:
	var route_ids = []
	for route in route_links:
		if route.get("from", "") == location_id or route.get("to", "") == location_id:
			route_ids.append(route.get("id", ""))
	var found = []
	for route_economy in route_economies:
		if route_ids.has(route_economy.get("route_id", "")):
			found.append(route_economy)
	return found

func _best_route_for_settlement(current_location: String, settlement_id: String, connected_routes: Array, route_links: Array) -> Dictionary:
	var best = {}
	var best_score = -999
	for route in connected_routes:
		var link = _route_link(route_links, route.get("route_id", ""))
		if settlement_id != current_location and _other_end(link, current_location) != settlement_id:
			continue
		var score = int(route.get("danger", 0)) + int(route.get("bandit_pressure", 0)) - int(route.get("traffic", 0))
		if score > best_score:
			best = route
			best_score = score
	return best

func _settlement_by_id(settlements: Array, settlement_id: String) -> Dictionary:
	for settlement in settlements:
		if settlement.get("settlement_id", "") == settlement_id:
			return settlement
	return {}

func _location_by_id(locations: Array, location_id: String) -> Dictionary:
	for location in locations:
		if location.get("id", "") == location_id:
			return location
	return {"id": location_id, "name": location_id, "faction_influence": {"ashen_crown": 1}}

func _route_link(route_links: Array, route_id: String) -> Dictionary:
	for route in route_links:
		if route.get("id", "") == route_id:
			return route
	return {}

func _other_end(route: Dictionary, location_id: String) -> String:
	if route.get("from", "") == location_id:
		return route.get("to", "")
	if route.get("to", "") == location_id:
		return route.get("from", "")
	return location_id

func _route_days(route_id: String) -> int:
	return 2

func _settlement_stub(settlement_id: String) -> Dictionary:
	return {"settlement_id": settlement_id, "security": 50, "unrest": 0}

func _internal_faction_preference(settlement_id: String, contract_type: String, internal_factions: Array) -> Dictionary:
	var dominant = _dominant_internal_faction(settlement_id, internal_factions)
	if dominant.is_empty():
		return {"score_multiplier": 1.0, "reward_multiplier": 1.0, "internal_patron_faction": ""}
	var score_multiplier = 1.0
	if dominant.get("supported_contract_types", []).has(contract_type):
		score_multiplier = 1.3
	elif dominant.get("opposed_contract_types", []).has(contract_type):
		score_multiplier = 0.7
	return {
		"score_multiplier": score_multiplier,
		"reward_multiplier": _clamp_float(1.0 + float(dominant.get("attitude_to_company", 0)) / 200.0, 0.5, 1.5),
		"internal_patron_faction": dominant.get("id", "")
	}

func _dominant_internal_faction(settlement_id: String, internal_factions: Array) -> Dictionary:
	var type_priority = {"ruling_authority": 0, "merchant_guild": 1, "militia_command": 2, "temple_chapter": 3, "criminal_network": 4, "peasant_commons": 5}
	var dominant = {}
	for faction in internal_factions:
		if faction.get("settlement_id", "") != settlement_id:
			continue
		if dominant.is_empty():
			dominant = faction
			continue
		if int(faction.get("influence", 0)) > int(dominant.get("influence", 0)):
			dominant = faction
		elif int(faction.get("influence", 0)) == int(dominant.get("influence", 0)):
			if int(type_priority.get(faction.get("type", ""), 99)) < int(type_priority.get(dominant.get("type", ""), 99)):
				dominant = faction
	return dominant

func _deterministic_jitter(contract_type: String, origin: String, target: String, route_id: String) -> int:
	var text = "%s|%s|%s|%s|%s" % [generator_seed, contract_type, origin, target, route_id]
	var value = 0
	for i in range(text.length()):
		value = (value + text.unicode_at(i) * (i + 17)) % 97
	return value

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return min(max_value, max(min_value, value))

func _clamp_float(value: float, min_value: float, max_value: float) -> float:
	return min(max_value, max(min_value, value))
