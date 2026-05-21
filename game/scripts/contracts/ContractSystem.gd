extends RefCounted
class_name ContractSystem

const RouteDynamicsSystemScript = preload("res://game/scripts/world/RouteDynamicsSystem.gd")

var route_dynamics = RouteDynamicsSystemScript.new()

func configure_route_dynamics(system) -> void:
	route_dynamics = system

func can_accept(company, contract: Dictionary) -> bool:
	return not company.has_active_contract() and not contract.is_empty()

func accept(company, contract: Dictionary) -> bool:
	if not can_accept(company, contract):
		return false
	company.accept_contract(contract)
	return true

func active_contract_completed(company, route: Dictionary, destination: String) -> bool:
	if not company.has_active_contract():
		return false
	var contract = company.active_contract
	return contract.get("target_route", "") == route.get("id", "") or contract.get("target_location", "") == destination

func complete(company, route_economy: Dictionary = {}, current_tick: int = 0, settlement_economies: Array = []) -> Dictionary:
	var contract = company.active_contract.duplicate(true)
	var result = company.apply_contract_success()
	if not contract.is_empty() and not route_economy.is_empty():
		result["route_dynamics"] = route_dynamics.apply_contract_success(contract, route_economy, current_tick)
	if not contract.is_empty() and not settlement_economies.is_empty():
		result["settlement_effects"] = _apply_settlement_effects(contract.get("settlement_effects_on_success", {}), settlement_economies)
	return result

func fail(company, route_economy: Dictionary = {}, current_tick: int = 0, settlement_economies: Array = []) -> Dictionary:
	var contract = company.active_contract.duplicate(true)
	var result = company.apply_contract_failure()
	if not contract.is_empty() and not route_economy.is_empty():
		result["route_dynamics"] = route_dynamics.apply_contract_failure(contract, route_economy, current_tick)
	if not contract.is_empty() and not settlement_economies.is_empty():
		result["settlement_effects"] = _apply_settlement_effects(contract.get("settlement_effects_on_failure", {}), settlement_economies)
	return result

func _apply_settlement_effects(effects_by_settlement: Dictionary, settlement_economies: Array) -> Array:
	var summaries = []
	for settlement_id in effects_by_settlement.keys():
		var settlement = _settlement_by_id(settlement_economies, settlement_id)
		if settlement.is_empty():
			continue
		var before = settlement.duplicate(true)
		var effects = effects_by_settlement.get(settlement_id, {})
		for key in effects.keys():
			var value = effects[key]
			if key in ["food_stock", "medicine_stock", "tools_stock", "arms_stock"]:
				settlement[key] = max(0, int(settlement.get(key, 0)) + int(value))
			elif key in ["prosperity", "security", "unrest", "trade_access", "recruitment_pool_quality"]:
				settlement[key] = _clamp_int(int(settlement.get(key, 0)) + int(value), 0, 100)
			elif key == "add_status_effect":
				_add_status_effect(settlement, str(value))
			elif key == "remove_status_effect":
				_remove_status_effect(settlement, str(value))
		summaries.append({
			"settlement_id": settlement_id,
			"before": before,
			"after": settlement.duplicate(true),
			"effects_applied": effects.duplicate(true)
		})
	return summaries

func _settlement_by_id(settlement_economies: Array, settlement_id: String) -> Dictionary:
	for settlement in settlement_economies:
		if settlement.get("settlement_id", "") == settlement_id:
			return settlement
	return {}

func _add_status_effect(settlement: Dictionary, status_id: String) -> void:
	if status_id.is_empty():
		return
	var statuses = settlement.get("status_effects", [])
	if typeof(statuses) != TYPE_ARRAY:
		statuses = []
	if not statuses.has(status_id):
		statuses.append(status_id)
	settlement["status_effects"] = statuses

func _remove_status_effect(settlement: Dictionary, status_id: String) -> void:
	var statuses = settlement.get("status_effects", [])
	if typeof(statuses) != TYPE_ARRAY:
		statuses = []
	statuses.erase(status_id)
	settlement["status_effects"] = statuses

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return min(max_value, max(min_value, value))
