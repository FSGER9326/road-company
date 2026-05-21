extends RefCounted
class_name RouteDynamicsSystem

const STATUS_NORMAL = "normal"
const STATUS_STABILIZING = "stabilizing"
const STATUS_SECURE = "secure"
const HISTORY_MAX = 20
const STABILIZING_SUCCESSES = 3
const SECURE_SUCCESSES = 6
const SECURE_DANGER_MAX = 30
const SECURE_PATROL_FLOOR = 30
const ROUTE_SECURE_EFFECT = "route_secure"
const EFFECT_FIELDS = ["bandit_pressure", "danger", "monster_pressure", "patrol_presence", "traffic", "trade_flow"]

func apply_contract_success(contract: Dictionary, route_data: Dictionary, current_tick: int = 0) -> Dictionary:
	return _apply_contract_effects(contract, route_data, "success", current_tick)

func apply_contract_failure(contract: Dictionary, route_data: Dictionary, current_tick: int = 0) -> Dictionary:
	return _apply_contract_effects(contract, route_data, "failure", current_tick)

func recalculate_status(route_data: Dictionary) -> String:
	var successes = 0
	for entry in route_data.get("route_history", []):
		if entry.get("outcome", "") == "success":
			successes += 1
	if successes >= SECURE_SUCCESSES and int(route_data.get("danger", 0)) <= SECURE_DANGER_MAX:
		route_data["status"] = STATUS_SECURE
	elif successes >= STABILIZING_SUCCESSES:
		route_data["status"] = STATUS_STABILIZING
	else:
		route_data["status"] = STATUS_NORMAL
	return route_data["status"]

func get_settlement_effect_ids(route_data: Dictionary) -> Array:
	if route_data.get("status", STATUS_NORMAL) == STATUS_SECURE:
		return [ROUTE_SECURE_EFFECT]
	return []

func clear_expired_blocks(route_data: Dictionary, current_tick: int) -> void:
	var blocked_until = route_data.get("blocked_until_tick", null)
	if blocked_until != null and current_tick >= int(blocked_until):
		route_data["blocked"] = false
		route_data["blocked_until_tick"] = null

func status_bandit_growth_multiplier(route_data: Dictionary) -> float:
	match route_data.get("status", STATUS_NORMAL):
		STATUS_SECURE:
			return 0.25
		STATUS_STABILIZING:
			return 0.5
		_:
			return 1.0

func apply_status_floors(route_data: Dictionary) -> void:
	if route_data.get("status", STATUS_NORMAL) == STATUS_SECURE:
		route_data["patrol_presence"] = max(SECURE_PATROL_FLOOR, int(route_data.get("patrol_presence", 0)))

func _apply_contract_effects(contract: Dictionary, route_data: Dictionary, outcome: String, current_tick: int) -> Dictionary:
	var before = route_data.duplicate(true)
	var field = "route_effects_on_success" if outcome == "success" else "route_effects_on_failure"
	var effects = contract.get(field, {})
	var applied = {}
	for key in EFFECT_FIELDS:
		if effects.has(key):
			var delta = int(effects[key])
			route_data[key] = _clamp_int(int(route_data.get(key, 0)) + delta, 0, 100)
			applied[key] = delta
	var blocked_for = null
	if outcome == "failure" and effects.has("block_duration_ticks"):
		blocked_for = max(1, int(effects.get("block_duration_ticks", 1)))
		route_data["blocked"] = true
		route_data["blocked_until_tick"] = current_tick + blocked_for
		applied["block_duration_ticks"] = blocked_for
	_append_history(route_data, current_tick, contract.get("id", ""), outcome, applied)
	recalculate_status(route_data)
	apply_status_floors(route_data)
	return {
		"route_id": route_data.get("route_id", ""),
		"before": before,
		"after": route_data.duplicate(true),
		"effects_applied": applied,
		"blocked_for": blocked_for
	}

func _append_history(route_data: Dictionary, current_tick: int, contract_id: String, outcome: String, effects: Dictionary) -> void:
	var history = route_data.get("route_history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	history.append({
		"tick": current_tick,
		"contract": contract_id,
		"outcome": outcome,
		"effects": effects.duplicate(true)
	})
	while history.size() > HISTORY_MAX:
		history.pop_front()
	route_data["route_history"] = history

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return min(max_value, max(min_value, value))
