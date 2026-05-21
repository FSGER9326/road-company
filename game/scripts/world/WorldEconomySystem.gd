extends RefCounted
class_name WorldEconomySystem

const MIN_POPULATION = 10
const MAX_POPULATION = 50000

func weekly_tick(settlements: Array, routes: Array, route_links: Array = []) -> Dictionary:
	var settlement_updates = []
	var route_updates = []
	for route in routes:
		route_updates.append(_tick_route(route))
	for settlement in settlements:
		var connected = _connected_route_economies(settlement.get("settlement_id", ""), routes, route_links)
		settlement_updates.append(_tick_settlement(settlement, connected))
	return {
		"settlements": settlement_updates,
		"routes": route_updates
	}

func _tick_route(route: Dictionary) -> Dictionary:
	var before = route.duplicate(true)
	if bool(route.get("blocked", false)):
		route["traffic"] = 0
		route["trade_flow"] = 0
		route["danger"] = _clamp_int(int(route.get("danger", 0)) + 2, 0, 100)
	else:
		var pressure = int(route.get("bandit_pressure", 0)) + int(route.get("monster_pressure", 0))
		var safety = int(route.get("patrol_presence", 0)) + int(route.get("road_quality", 0))
		var traffic_delta = int(round((safety - pressure - int(route.get("danger", 0))) / 25.0))
		route["traffic"] = _clamp_int(int(route.get("traffic", 0)) + traffic_delta, 0, 100)
		var danger_delta = int(round((pressure - safety) / 35.0))
		route["danger"] = _clamp_int(int(route.get("danger", 0)) + danger_delta, 0, 100)
		route["trade_flow"] = _clamp_int(int(round((int(route.get("traffic", 0)) + int(route.get("road_quality", 0)) + int(route.get("patrol_presence", 0)) - int(route.get("danger", 0))) / 3.0)), 0, 100)
	return {
		"route_id": route.get("route_id", ""),
		"before": before,
		"after": route.duplicate(true)
	}

func _tick_settlement(settlement: Dictionary, connected_routes: Array) -> Dictionary:
	var before = settlement.duplicate(true)
	var population = _clamp_int(int(settlement.get("population", MIN_POPULATION)), MIN_POPULATION, MAX_POPULATION)
	var weekly_food_need = max(1, int(ceil(float(population) / 250.0)))
	var food_before = max(0, int(settlement.get("food_stock", 0)))
	var food_after = max(0, food_before - weekly_food_need)
	var shortage = food_before < weekly_food_need * 2
	settlement["food_stock"] = food_after

	var route_trade_delta = _route_trade_delta(connected_routes)
	settlement["trade_access"] = _clamp_int(int(settlement.get("trade_access", 0)) + route_trade_delta, 0, 100)

	var unrest_delta = -1
	if shortage:
		unrest_delta += 8
	if int(settlement.get("security", 0)) < 30:
		unrest_delta += 3
	settlement["unrest"] = _clamp_int(int(settlement.get("unrest", 0)) + unrest_delta, 0, 100)

	var prosperity_delta = 0
	if shortage:
		prosperity_delta -= 5
	if int(settlement.get("trade_access", 0)) >= 60:
		prosperity_delta += 2
	elif int(settlement.get("trade_access", 0)) < 35:
		prosperity_delta -= 2
	if int(settlement.get("security", 0)) >= 55:
		prosperity_delta += 1
	elif int(settlement.get("security", 0)) < 30:
		prosperity_delta -= 2
	if int(settlement.get("unrest", 0)) > 60:
		prosperity_delta -= 3
	settlement["prosperity"] = _clamp_int(int(settlement.get("prosperity", 0)) + prosperity_delta, 0, 100)

	var population_delta = 0
	if int(settlement.get("prosperity", 0)) >= 70 and int(settlement.get("security", 0)) >= 45 and int(settlement.get("unrest", 0)) <= 35 and not shortage:
		population_delta = max(1, int(round(float(population) * 0.002)))
	elif shortage or int(settlement.get("prosperity", 0)) < 20 or int(settlement.get("unrest", 0)) > 80:
		population_delta = -max(1, int(round(float(population) * 0.003)))
	settlement["population"] = _clamp_int(population + population_delta, MIN_POPULATION, MAX_POPULATION)

	settlement["market_tier"] = _market_tier(int(settlement.get("population", MIN_POPULATION)), int(settlement.get("prosperity", 0)))
	settlement["recruitment_pool_quality"] = _clamp_int(int(round((int(settlement.get("prosperity", 0)) + int(settlement.get("security", 0)) - int(settlement.get("unrest", 0)) * 0.5) / 2.0)), 0, 100)
	_clamp_stock_fields(settlement)

	return {
		"settlement_id": settlement.get("settlement_id", ""),
		"before": before,
		"after": settlement.duplicate(true),
		"food_consumed": weekly_food_need,
		"shortage": shortage,
		"trade_delta": route_trade_delta,
		"prosperity_delta": int(settlement.get("prosperity", 0)) - int(before.get("prosperity", 0)),
		"unrest_delta": int(settlement.get("unrest", 0)) - int(before.get("unrest", 0)),
		"population_delta": int(settlement.get("population", 0)) - int(before.get("population", 0))
	}

func _route_trade_delta(connected_routes: Array) -> int:
	if connected_routes.is_empty():
		return -2
	var total = 0
	for route in connected_routes:
		total += int(route.get("trade_flow", 0))
	var average = float(total) / float(connected_routes.size())
	return _clamp_int(int(round((average - 50.0) / 15.0)), -4, 4)

func _connected_route_economies(settlement_id: String, route_economies: Array, route_links: Array) -> Array:
	var route_ids = []
	for route in route_links:
		if route.get("from", "") == settlement_id or route.get("to", "") == settlement_id:
			route_ids.append(route.get("id", ""))
	var found = []
	for route_economy in route_economies:
		if route_ids.has(route_economy.get("route_id", "")):
			found.append(route_economy)
	return found

func _market_tier(population: int, prosperity: int) -> int:
	var base = 1
	if population >= 3000:
		base = 4
	elif population >= 1200:
		base = 3
	elif population >= 300:
		base = 2
	if prosperity >= 75 and base < 5:
		base += 1
	if prosperity < 25 and base > 1:
		base -= 1
	return _clamp_int(base, 1, 5)

func _clamp_stock_fields(settlement: Dictionary) -> void:
	for field in ["food_stock", "medicine_stock", "tools_stock", "arms_stock"]:
		settlement[field] = max(0, int(settlement.get(field, 0)))

func _clamp_int(value: int, min_value: int, max_value: int) -> int:
	return min(max_value, max(min_value, value))
