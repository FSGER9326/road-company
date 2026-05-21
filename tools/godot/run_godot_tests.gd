extends SceneTree

const DataStoreScript = preload("res://game/scripts/core/DataStore.gd")
const CompanyStateScript = preload("res://game/scripts/core/CompanyState.gd")
const MainMenuScript = preload("res://game/scripts/ui/MainMenu.gd")
const RoadScreenScript = preload("res://game/scripts/road/RoadScreen.gd")
const CombatScreenScript = preload("res://game/scripts/combat/CombatScreen.gd")
const CampScreenScript = preload("res://game/scripts/camp/CampScreen.gd")
const AutoplaySmokeScript = preload("res://game/scripts/core/AutoplaySmoke.gd")
const WorldEconomySystemScript = preload("res://game/scripts/world/WorldEconomySystem.gd")

var failures := 0
var data
var company

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	data = DataStoreScript.new()
	data.load_all()
	company = CompanyStateScript.new()
	company.load_from_start(data.company_start)

	_test_load_main_scene()
	_test_main_menu_instantiates()
	_test_road_map_instantiates()
	_test_combat_instantiates()
	_test_camp_instantiates()
	_test_world_economy_ticks()
	_test_autoplay_escort_smoke()

	if failures == 0:
		print("PASS: Godot headless test suite")
		quit(0)
	else:
		print("FAIL: Godot headless test suite had %s failure(s)" % failures)
		quit(1)

func _pass(message: String) -> void:
	print("PASS: %s" % message)

func _fail(message: String) -> void:
	failures += 1
	push_error("FAIL: %s" % message)

func _test_load_main_scene() -> void:
	var scene = load("res://game/scenes/main/Main.tscn")
	if scene == null:
		_fail("project can load main scene")
		return
	var instance = scene.instantiate()
	if instance == null:
		_fail("main scene instantiates")
		return
	instance.queue_free()
	_pass("project can load core main scene")

func _test_main_menu_instantiates() -> void:
	var menu = MainMenuScript.new()
	get_root().add_child(menu)
	if menu.get_child_count() > 0:
		_pass("loaded main menu")
	else:
		_fail("main menu did not build children")
	get_root().remove_child(menu)
	menu.queue_free()

func _test_road_map_instantiates() -> void:
	var road = RoadScreenScript.new()
	road.call("setup", data, company, "headless test")
	get_root().add_child(road)
	if road.get_child_count() > 0:
		_pass("loaded road map")
	else:
		_fail("road map did not build children")
	get_root().remove_child(road)
	road.queue_free()

func _test_combat_instantiates() -> void:
	var context = _escort_context()
	var combat = CombatScreenScript.new()
	combat.call("setup", data, company, context)
	get_root().add_child(combat)
	var has_units = combat.units.size() >= 11
	var has_wagon = false
	for unit in combat.units:
		if unit.get("id", "") == "escort_wagon":
			has_wagon = true
	if has_units and has_wagon:
		_pass("loaded combat scene with escort objective")
	else:
		_fail("combat scene missing units or wagon objective")
	get_root().remove_child(combat)
	combat.queue_free()

func _test_camp_instantiates() -> void:
	var camp = CampScreenScript.new()
	camp.call("setup", data, company, {"headline": "Headless aftermath", "had_combat": false, "reached_destination": true})
	get_root().add_child(camp)
	if camp.get_child_count() > 0:
		_pass("loaded camp aftermath")
	else:
		_fail("camp aftermath did not build children")
	get_root().remove_child(camp)
	camp.queue_free()

func _test_autoplay_escort_smoke() -> void:
	var runner = AutoplaySmokeScript.new()
	runner.call("setup", data, 12345)
	var result = runner.call("run_escort_smoke")
	if result.get("ok", false) and result.get("location", "") == "embermill" and not result.get("active_contract", true):
		_pass("autoplay escort scenario reached aftermath")
	else:
		_fail("autoplay escort scenario failed: %s" % str(result))

func _test_world_economy_ticks() -> void:
	var economy = WorldEconomySystemScript.new()
	var settlements = data.settlement_economy.duplicate(true)
	var routes = data.route_economy.duplicate(true)
	var result = economy.call("weekly_tick", settlements, routes, data.routes)
	if result.get("settlements", []).size() == data.settlement_economy.size() and result.get("routes", []).size() == data.route_economy.size():
		_pass("world economy weekly tick")
	else:
		_fail("world economy weekly tick did not return expected updates")

func _escort_context() -> Dictionary:
	var contract = data.by_id(data.contracts, "escort_embermill")
	var route = data.by_id(data.routes, contract.get("target_route", ""))
	return {
		"route": route,
		"destination": "embermill",
		"contract": contract,
		"starts_combat": true,
		"ambush": true,
		"low_vigor": false,
		"scouts_low": false,
		"escort_objective": true,
		"terrain_tags": route.get("terrain_tags", []),
		"battlefield_tags": route.get("battlefield_tags", []),
		"encounter_id": contract.get("encounter_id", "escort_ambush"),
		"seed": 12345
	}
