extends RefCounted
class_name DataStore

const ContractGeneratorScript = preload("res://game/scripts/contracts/ContractGenerator.gd")

var locations = []
var routes = []
var contracts = []
var contract_type_defaults = []
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
var settlement_factions = []
var asset_manifest = []
var art_asset_manifest = {}
var event_templates = []
var company_start = {}

func load_all() -> void:
	locations = _load_array("res://data/world/locations.json")
	routes = _load_array("res://data/world/routes.json")
	contracts = _load_array("res://data/contracts/contracts.json")
	contract_type_defaults = _load_array("res://data/contracts/contract_type_defaults.json")
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
	settlement_factions = _load_array("res://data/world/settlement_factions.json")
	asset_manifest = _load_dict("res://data/art/asset_manifest.json").get("assets", [])
	event_templates = _load_array("res://data/world/event_templates.json")
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

func generated_contracts_for_location(location_id: String, faction_reputation: Dictionary = {}, seed: int = 12345, tick: int = 0) -> Array:
	var generator = ContractGeneratorScript.new()
	generator.call("configure", contract_type_defaults, seed)
	return generator.call(
		"generate_contracts",
		location_id,
		settlement_economy,
		route_economy,
		routes,
		faction_reputation,
		contracts,
		locations,
		factions,
		tick,
		settlement_factions
	)

func settlement_factions_for_location(location_id: String) -> Array:
	var found = []
	for faction in settlement_factions:
		if faction.get("settlement_id", "") == location_id:
			found.append(faction)
	return found

func contract_board_for_location(location_id: String, faction_reputation: Dictionary = {}, seed: int = 12345, tick: int = 0) -> Array:
	var board = contracts_for_location(location_id)
	board.append_array(generated_contracts_for_location(location_id, faction_reputation, seed, tick))
	return board

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

func get_route_economy(route_id: String) -> Dictionary:
	for item in route_economy:
		if item.get("route_id", "") == route_id:
			return item
	return {}

func get_asset(asset_id: String) -> Dictionary:
	for item in asset_manifest:
		if item.get("asset_id", "") == asset_id:
			return item
	return {}

## Helper method to load a texture for an asset ID.
## Handles native ResourceLoader (if imported) and raw SVG string loading (headless/fallback).
func load_asset_texture(asset_id: String) -> Texture2D:
	var asset = get_asset(asset_id)
	if asset.is_empty() or not asset.has("path"):
		return null
		
	var path = asset["path"]
	if ResourceLoader.exists(path):
		return load(path)
	elif FileAccess.file_exists(path) and path.ends_with(".svg"):
		var svg_str = FileAccess.get_file_as_string(path)
		var img = Image.new()
		if img.load_svg_from_string(svg_str) == OK:
			return ImageTexture.create_from_image(img)
			
	return null

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
