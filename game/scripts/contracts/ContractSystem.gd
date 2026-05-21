extends RefCounted
class_name ContractSystem

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

func complete(company) -> Dictionary:
	return company.apply_contract_success()

func fail(company) -> Dictionary:
	return company.apply_contract_failure()
