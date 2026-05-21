extends RefCounted
class_name SettlementFactionSystem

const FACTION_TYPES = ["ruling_authority", "merchant_guild", "militia_command", "temple_chapter", "criminal_network", "peasant_commons"]
const TYPE_PRIORITY = {
	"ruling_authority": 0,
	"merchant_guild": 1,
	"militia_command": 2,
	"temple_chapter": 3,
	"criminal_network": 4,
	"peasant_commons": 5
}
const CONTRACT_TYPE_SHIFTS = {
	"escort_caravan": {"merchant_guild": 5, "criminal_network": -2},
	"patrol_route": {"militia_command": 4, "ruling_authority": 2, "criminal_network": -3},
	"hunt_bandits": {"militia_command": 5, "ruling_authority": 3, "criminal_network": -4},
	"recover_wagon": {"merchant_guild": 5},
	"deliver_medicine": {"temple_chapter": 4, "peasant_commons": 2},
	"defend_settlement": {"militia_command": 5, "ruling_authority": 3, "criminal_network": -5},
	"bounty_target": {"ruling_authority": 3, "criminal_network": -3}
}

var factions = []

func configure(new_factions: Array) -> void:
	factions = new_factions

func get_factions_for_settlement(settlement_id: String) -> Array:
	var found = []
	for faction in factions:
		if faction.get("settlement_id", "") == settlement_id:
			found.append(faction)
	return found

func weekly_tick(settlement: Dictionary, current_tick: int = 0, contract_results: Array = []) -> Dictionary:
	var settlement_id = settlement.get("settlement_id", "")
	var local_factions = get_factions_for_settlement(settlement_id)
	var before = _snapshot(local_factions)
	var changes = []
	changes.append_array(_apply_economy_shifts(settlement, local_factions))
	for result in contract_results:
		changes.append_array(apply_contract_result(settlement_id, result.get("contract", {}), result.get("outcome", "success")))
	for faction in local_factions:
		_decay_attitude(faction)
	var dominant = calculate_dominant_faction(local_factions)
	var tension = calculate_faction_tension(local_factions)
	settlement["dominant_internal_faction"] = dominant.get("id", "")
	settlement["faction_tension"] = tension
	settlement["local_policy_tags"] = _policy_tags_for_dominant(dominant)
	settlement["active_internal_conflicts"] = _active_conflicts(local_factions, tension)
	if not settlement.has("last_faction_events"):
		settlement["last_faction_events"] = []
	_apply_dominant_modifiers(settlement, dominant)
	return {
		"settlement_id": settlement_id,
		"before": before,
		"after": _snapshot(local_factions),
		"faction_changes": changes,
		"dominant_internal_faction": settlement.get("dominant_internal_faction", ""),
		"faction_tension": settlement.get("faction_tension", 0),
		"events_triggered": []
	}

func apply_contract_result(settlement_id: String, contract: Dictionary, outcome: String = "success") -> Array:
	var local_factions = get_factions_for_settlement(settlement_id)
	var changes = []
	if local_factions.is_empty():
		return changes
	var patron_id = contract.get("internal_patron_faction", "")
	var patron = _faction_by_id(local_factions, patron_id)
	if patron.is_empty():
		patron = _best_faction_for_contract(local_factions, contract.get("type", ""))
	if patron.is_empty():
		return changes
	if outcome == "success":
		changes.append(_shift(patron, 5, 5, "contract_success_patron"))
		for rival_id in patron.get("rival_faction_ids", []):
			var rival = _faction_by_id(local_factions, rival_id)
			if not rival.is_empty():
				changes.append(_shift(rival, 0, -2, "contract_success_rival"))
		var type_shifts = CONTRACT_TYPE_SHIFTS.get(contract.get("type", ""), {})
		for faction_type in type_shifts.keys():
			for faction in local_factions:
				if faction.get("type", "") == faction_type:
					changes.append(_shift(faction, int(type_shifts[faction_type]), 0, "contract_type_shift"))
	else:
		changes.append(_shift(patron, -5, -5, "contract_failure_patron"))
	return changes

func calculate_dominant_faction(local_factions: Array) -> Dictionary:
	var dominant = {}
	for faction in local_factions:
		if dominant.is_empty():
			dominant = faction
			continue
		var influence = int(faction.get("influence", 0))
		var dominant_influence = int(dominant.get("influence", 0))
		if influence > dominant_influence:
			dominant = faction
		elif influence == dominant_influence:
			if int(TYPE_PRIORITY.get(faction.get("type", ""), 99)) < int(TYPE_PRIORITY.get(dominant.get("type", ""), 99)):
				dominant = faction
	return dominant

func calculate_faction_tension(local_factions: Array) -> int:
	var by_id = {}
	for faction in local_factions:
		by_id[faction.get("id", "")] = faction
	var seen = {}
	var tension = 0.0
	for faction in local_factions:
		for rival_id in faction.get("rival_faction_ids", []):
			var pair = [faction.get("id", ""), rival_id]
			pair.sort()
			var key = "%s|%s" % [pair[0], pair[1]]
			if seen.has(key) or not by_id.has(rival_id):
				continue
			seen[key] = true
			var rival = by_id[rival_id]
			if int(faction.get("influence", 0)) > 30 and int(rival.get("influence", 0)) > 30:
				tension += float(min(int(faction.get("influence", 0)), int(rival.get("influence", 0)))) * 0.3
	var dominant = calculate_dominant_faction(local_factions)
	if int(dominant.get("influence", 0)) > 70:
		tension -= 5.0
	return _clamp_int(int(round(tension)), 0, 100)

func preference_for_contract(settlement_id: String, contract_type: String) -> Dictionary:
	var local_factions = get_factions_for_settlement(settlement_id)
	var dominant = calculate_dominant_faction(local_factions)
	if dominant.is_empty():
		return {"score_multiplier": 1.0, "reward_multiplier": 1.0, "internal_patron_faction": ""}
	var score_multiplier = 1.0
	if dominant.get("supported_contract_types", []).has(contract_type):
		score_multiplier = 1.3
	elif dominant.get("opposed_contract_types", []).has(contract_type):
		score_multiplier = 0.7
	var reward_multiplier = _clamp_float(1.0 + float(dominant.get("attitude_to_company", 0)) / 200.0, 0.5, 1.5)
	return {
		"score_multiplier": score_multiplier,
		"reward_multiplier": reward_multiplier,
		"internal_patron_faction": dominant.get("id", "")
	}

func _apply_economy_shifts(settlement: Dictionary, local_factions: Array) -> Array:
	var changes = []
	if int(settlement.get("security", 0)) < 35:
		changes.append_array(_shift_type(local_factions, "militia_command", 3, 0, "low_security"))
		changes.append_array(_shift_type(local_factions, "criminal_network", 1, 0, "low_security"))
	if _has_food_shortage(settlement):
		changes.append_array(_shift_type(local_factions, "peasant_commons", 3, 0, "food_shortage"))
	if int(settlement.get("prosperity", 0)) > 65:
		changes.append_array(_shift_type(local_factions, "merchant_guild", 2, 0, "high_prosperity"))
	if int(settlement.get("trade_access", 0)) < 30:
		changes.append_array(_shift_type(local_factions, "merchant_guild", -2, 0, "low_trade_access"))
	if int(settlement.get("unrest", 0)) > 50:
		changes.append_array(_shift_type(local_factions, "criminal_network", 2, 0, "high_unrest"))
		changes.append_array(_shift_type(local_factions, "ruling_authority", -2, 0, "high_unrest"))
	if int(settlement.get("corruption", 0)) > 50:
		changes.append_array(_shift_type(local_factions, "criminal_network", 3, 0, "high_corruption"))
		changes.append_array(_shift_type(local_factions, "temple_chapter", -2, 0, "high_corruption"))
	return changes

func _shift_type(local_factions: Array, faction_type: String, influence_delta: int, attitude_delta: int, reason: String) -> Array:
	var changes = []
	for faction in local_factions:
		if faction.get("type", "") == faction_type:
			changes.append(_shift(faction, influence_delta, attitude_delta, reason))
	return changes

func _shift(faction: Dictionary, influence_delta: int, attitude_delta: int, reason: String) -> Dictionary:
	var before_influence = int(faction.get("influence", 0))
	var before_attitude = int(faction.get("attitude_to_company", 0))
	faction["influence"] = _clamp_int(before_influence + influence_delta, 0, 100)
	faction["attitude_to_company"] = _clamp_int(before_attitude + attitude_delta, -100, 100)
	return {
		"faction_id": faction.get("id", ""),
		"reason": reason,
		"influence_delta": int(faction.get("influence", 0)) - before_influence,
		"attitude_delta": int(faction.get("attitude_to_company", 0)) - before_attitude
	}

func _decay_attitude(faction: Dictionary) -> void:
	var attitude = int(faction.get("attitude_to_company", 0))
	if attitude > 0:
		attitude = max(0, attitude - 2)
	elif attitude < 0:
		attitude = min(0, attitude + 2)
	faction["attitude_to_company"] = attitude

func _apply_dominant_modifiers(settlement: Dictionary, dominant: Dictionary) -> void:
	for key in dominant.get("economy_modifiers", {}).keys():
		if key in ["prosperity", "security", "unrest", "trade_access", "corruption"]:
			settlement[key] = _clamp_int(int(settlement.get(key, 0)) + int(dominant.get("economy_modifiers", {})[key]), 0, 100)

func _policy_tags_for_dominant(dominant: Dictionary) -> Array:
	match dominant.get("type", ""):
		"ruling_authority":
			return ["curfew_ready"]
		"merchant_guild":
			return ["market_open"]
		"militia_command":
			return ["raised_patrols"]
		"temple_chapter":
			return ["sanctuary_watch"]
		"criminal_network":
			return ["shadow_tolls"]
		"peasant_commons":
			return ["bread_claims"]
	return []

func _active_conflicts(local_factions: Array, tension: int) -> Array:
	if tension < 30:
		return []
	var dominant = calculate_dominant_faction(local_factions)
	var conflicts = []
	for rival_id in dominant.get("rival_faction_ids", []):
		var rival = _faction_by_id(local_factions, rival_id)
		if not rival.is_empty() and int(rival.get("influence", 0)) > 30:
			conflicts.append("%s_vs_%s" % [dominant.get("id", ""), rival_id])
	return conflicts

func _best_faction_for_contract(local_factions: Array, contract_type: String) -> Dictionary:
	var best = {}
	var best_score = -999
	for faction in local_factions:
		var score = int(faction.get("influence", 0))
		if faction.get("supported_contract_types", []).has(contract_type):
			score += 20
		if faction.get("opposed_contract_types", []).has(contract_type):
			score -= 20
		if score > best_score:
			best = faction
			best_score = score
	return best

func _faction_by_id(local_factions: Array, faction_id: String) -> Dictionary:
	for faction in local_factions:
		if faction.get("id", "") == faction_id:
			return faction
	return {}

func _has_food_shortage(settlement: Dictionary) -> bool:
	var population = int(settlement.get("population", 10))
	var weekly_need = max(1, int(ceil(float(population) / 250.0)))
	return int(settlement.get("food_stock", 0)) < weekly_need * 2

func _snapshot(local_factions: Array) -> Array:
	var result = []
	for faction in local_factions:
		result.append(faction.duplicate(true))
	return result

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return min(max_value, max(min_value, value))

func _clamp_float(value: float, min_value: float, max_value: float) -> float:
	return min(max_value, max(min_value, value))
