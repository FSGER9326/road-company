extends RefCounted
class_name DataStore

var locations = []
var routes = []
var contracts = []
var factions = []
var weapons = []
var armor = []
var enemies = []
var encounters = []
var road_events = []
var trade_goods = []
var settlement_economy = []
var route_economy = []
var settlement_status_effects = []
var company_start = {}

func load_all() -> void:
	locations = _load_array("res://data/world/locations.json")
	routes = _load_array("res://data/world/routes.json")
	contracts = _load_array("res://data/contracts/contracts.json")
	factions = _load_array("res://data/factions/factions.json")
	weapons = _load_array("res://data/combat/weapons.json")
	armor = _load_array("res://data/combat/armor.json")
	enemies = _load_array("res://data/combat/enemies.json")
	encounters = _load_array("res://data/combat/encounters.json")
	road_events = _load_array("res://data/events/road_events.json")
	trade_goods = _load_array("res://data/world/trade_goods.json")
	settlement_economy = _load_array("res://data/world/settlement_economy.json")
	route_economy = _load_array("res://data/world/route_economy.json")
	settlement_status_effects = _load_array("res://data/world/settlement_status_effects.json")
	company_start = _load_dict("res://data/company/company_start.json")

func by_id(collection: Array, item_id: String) -> Dictionary:
	for item in collection:
		if item.get("id", "") == item_id:
			return item
	return {}

func connected_routes(location_id: String) -> Array:
	var found = []
	for route in routes:
		if route.get("from") == location_id or route.get("to") == location_id:
			found.append(route)
	return found

func other_end(route: Dictionary, location_id: String) -> String:
	if route.get("from") == location_id:
		return route.get("to", "")
	return route.get("from", "")

func contracts_for_location(location_id: String) -> Array:
	var location = by_id(locations, location_id)
	var allowed = location.get("available_contracts", [])
	var found = []
	for contract in contracts:
		if contract.get("origin_location") == location_id or allowed.has(contract.get("id")):
			found.append(contract)
	return found

func get_weapon(weapon_id: String) -> Dictionary:
	return by_id(weapons, weapon_id)

func get_armor(armor_id: String) -> Dictionary:
	return by_id(armor, armor_id)

func get_encounter(encounter_id: String) -> Dictionary:
	return by_id(encounters, encounter_id)

func get_enemy(enemy_id: String) -> Dictionary:
	return by_id(enemies, enemy_id)

func get_settlement_economy(settlement_id: String) -> Dictionary:
	for item in settlement_economy:
		if item.get("settlement_id", "") == settlement_id:
			return item
	return {}

func _load_array(path: String) -> Array:
	var value = _load_json(path)
	if typeof(value) == TYPE_ARRAY:
		return value
	push_error("Expected JSON array at %s" % path)
	return []

func _load_dict(path: String) -> Dictionary:
	var value = _load_json(path)
	if typeof(value) == TYPE_DICTIONARY:
		return value
	push_error("Expected JSON object at %s" % path)
	return {}

func _load_json(path: String):
	var text = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Missing or empty JSON file: %s" % path)
		return null
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Could not parse JSON file: %s" % path)
	return parsed
