extends RefCounted
class_name RoadSystem

const SeededRngScript = preload("res://game/scripts/core/SeededRng.gd")

var data: DataStore
var rng: SeededRng

func setup(new_data: DataStore, seed: int = 12345) -> void:
	data = new_data
	rng = SeededRngScript.new()
	rng.configure(seed)

func is_connected(location_id: String, route: Dictionary) -> bool:
	return route.get("from", "") == location_id or route.get("to", "") == location_id

func destination_for(location_id: String, route: Dictionary) -> String:
	if route.get("from", "") == location_id:
		return route.get("to", "")
	if route.get("to", "") == location_id:
		return route.get("from", "")
	return ""

func scout_score(company: CompanyState) -> int:
	var score = 0
	for fighter in company.roster:
		if fighter.get("traits", []).has("sharp_eyes"):
			score += 1
		if fighter.get("background", "") in ["ditch poacher", "debt runner"]:
			score += 1
	return score

func build_travel_context(company: CompanyState, route: Dictionary) -> Dictionary:
	var destination = destination_for(company.current_location, route)
	var contract = company.active_contract
	var contract_on_route = false
	if not contract.is_empty():
		contract_on_route = contract.get("target_route", "") == route.get("id", "") or contract.get("target_location", "") == destination
	var danger = int(route.get("danger", 0))
	var low_vigor = company.vigor < 40
	var scouts = scout_score(company)
	var scouts_low = scouts <= 0
	var ambush_roll = rng.range_i(1, 100)
	var ambush_threshold = clamp((danger * 12) - (scouts * 10), 0, 95)
	var ambush_by_roll = ambush_roll <= ambush_threshold
	var escort = not contract.is_empty() and contract.get("type", "") == "escort_caravan" and contract_on_route
	var starts_combat = danger >= 4 or contract_on_route or low_vigor or ambush_by_roll
	var encounter_id = route.get("encounter_table", "road_raiders")
	if not contract.is_empty() and contract.get("encounter_id", "") != "" and contract_on_route:
		encounter_id = contract.get("encounter_id")
	return {
		"route": route.duplicate(true),
		"destination": destination,
		"contract": contract.duplicate(true),
		"contract_on_route": contract_on_route,
		"starts_combat": starts_combat,
		"ambush": danger >= 4 or low_vigor or scouts_low or ambush_by_roll,
		"ambush_roll": ambush_roll,
		"ambush_threshold": ambush_threshold,
		"low_vigor": low_vigor,
		"scouts_low": scouts_low,
		"scout_score": scouts,
		"escort_objective": escort,
		"terrain_tags": route.get("terrain_tags", []),
		"battlefield_tags": route.get("battlefield_tags", []),
		"encounter_id": encounter_id
	}

func apply_road_event(company: CompanyState, route: Dictionary) -> Dictionary:
	if data.road_events.is_empty():
		return {"headline": "The road leg passes without incident.", "effects": {}}
	var event_index = 0
	if int(route.get("danger", 0)) <= 2 and data.road_events.size() > 1:
		event_index = 1
	elif data.road_events.size() > 1:
		event_index = rng.range_i(0, data.road_events.size() - 1)
	var event = data.road_events[event_index]
	var effects = event.get("effects", {})
	if effects.has("morale"):
		company.morale = clamp(company.morale + int(effects["morale"]), 0, 100)
	if effects.has("vigor"):
		company.vigor = clamp(company.vigor + int(effects["vigor"]), 0, 100)
	if effects.has("food"):
		company.food = max(0, company.food + int(effects["food"]))
	return {
		"id": event.get("id", ""),
		"title": event.get("title", "Road Event"),
		"description": event.get("description", ""),
		"effects": effects,
		"headline": "%s: %s" % [event.get("title", "Road Event"), event.get("description", "")]
	}

func travel(company: CompanyState, route: Dictionary) -> Dictionary:
	if not is_connected(company.current_location, route):
		return {"ok": false, "error": "Route is not connected to current location."}
	var destination = destination_for(company.current_location, route)
	var costs = company.apply_route_cost(route)
	var context = build_travel_context(company, route)
	context["travel_summary"] = costs
	return {"ok": true, "destination": destination, "context": context, "travel_summary": costs}
