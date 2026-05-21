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

func complete(company, route_economy: Dictionary = {}, current_tick: int = 0) -> Dictionary:
	var contract = company.active_contract.duplicate(true)
	var result = company.apply_contract_success()
	if not contract.is_empty() and not route_economy.is_empty():
		result["route_dynamics"] = route_dynamics.apply_contract_success(contract, route_economy, current_tick)
	return result

func fail(company, route_economy: Dictionary = {}, current_tick: int = 0) -> Dictionary:
	var contract = company.active_contract.duplicate(true)
	var result = company.apply_contract_failure()
	if not contract.is_empty() and not route_economy.is_empty():
		result["route_dynamics"] = route_dynamics.apply_contract_failure(contract, route_economy, current_tick)
	return result
