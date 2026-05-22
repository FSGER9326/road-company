extends Control

const DataStoreScript = preload("res://game/scripts/core/DataStore.gd")
const CompanyStateScript = preload("res://game/scripts/core/CompanyState.gd")
const MainMenuScript = preload("res://game/scripts/ui/MainMenu.gd")
const RoadScreenScript = preload("res://game/scripts/road/RoadScreen.gd")
const ContractBoardScript = preload("res://game/scripts/ui/ContractBoard.gd")
const CombatScreenScript = preload("res://game/scripts/combat/CombatScreen.gd")
const CampScreenScript = preload("res://game/scripts/camp/CampScreen.gd")
const RoadSystemScript = preload("res://game/scripts/road/RoadSystem.gd")
const ContractSystemScript = preload("res://game/scripts/contracts/ContractSystem.gd")
const AutoplaySmokeScript = preload("res://game/scripts/core/AutoplaySmoke.gd")
const EventSystemScript = preload("res://game/scripts/world/EventSystem.gd")
const RumorSystemScript = preload("res://game/scripts/world/RumorSystem.gd")
const WorldMemorySystemScript = preload("res://game/scripts/world/WorldMemorySystem.gd")
const SaveLoadSystemScript = preload("res://game/scripts/core/SaveLoadSystem.gd")

var data
var company
var pending_route = {}
var pending_destination = ""
var travel_summary = {}
var road_system
var contract_system
var event_system
var rumor_system
var memory_system
var run_seed = 12345
var game_day = 0
var save_load_system

func _ready() -> void:
	_parse_user_args()
	data = DataStoreScript.new()
	data.load_all()
	save_load_system = SaveLoadSystemScript.new()
	road_system = RoadSystemScript.new()
	road_system.call("setup", data, run_seed)
	
	event_system = EventSystemScript.new()
	event_system.configure(data.event_templates)
	rumor_system = RumorSystemScript.new()
	memory_system = WorldMemorySystemScript.new()
	
	contract_system = ContractSystemScript.new()
	contract_system.configure_event_system(event_system)
	contract_system.configure_rumor_system(rumor_system)
	contract_system.configure_memory_system(memory_system)
	
	if _user_arg("autoplay") != "":
		call_deferred("_run_autoplay_from_args")
		return
	show_menu()

func _set_screen(screen: Control) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)

func show_menu() -> void:
	var menu = MainMenuScript.new()
	menu.new_run_requested.connect(_start_new_run)
	_set_screen(menu)

func _start_new_run() -> void:
	company = CompanyStateScript.new()
	company.load_from_start(data.company_start)
	game_day = 0
	show_road("The company gathers at the road gate. Choose work, then choose a road.")

func save_game(path: String = SaveLoadSystemScript.AUTOSAVE_PATH) -> Dictionary:
	if company == null:
		return {"ok": false, "error": "No active company state to save."}
	var snapshot = save_load_system.build_snapshot(data, company, game_day, run_seed, event_system, rumor_system, memory_system)
	return save_load_system.save_snapshot(snapshot, path)

func load_game(path: String = SaveLoadSystemScript.AUTOSAVE_PATH) -> Dictionary:
	var loaded = save_load_system.load_snapshot(path)
	if not loaded.get("ok", false):
		return loaded
	if company == null:
		company = CompanyStateScript.new()
		company.load_from_start(data.company_start)
	var applied = save_load_system.apply_snapshot(loaded.get("snapshot", {}), data, company, event_system, rumor_system, memory_system)
	if applied.get("ok", false):
		game_day = int(applied.get("game_day", game_day))
		run_seed = int(applied.get("rng_seed", run_seed))
		road_system.call("setup", data, run_seed)
		show_road("Loaded save snapshot.")
	return applied

func show_road(message: String = "") -> void:
	var road = RoadScreenScript.new()
	road.call("setup", data, company, message, game_day)
	road.economy_system.configure_event_system(event_system)
	road.economy_system.configure_rumor_system(rumor_system)
	road.economy_system.configure_memory_system(memory_system)
	
	road.set("event_system", event_system)
	road.set("rumor_system", rumor_system)
	road.set("memory_system", memory_system)
	
	road.open_contract_board.connect(show_contract_board)
	road.travel_requested.connect(_begin_travel)
	road.week_advanced.connect(func(days): game_day += int(days))
	_set_screen(road)

func show_contract_board() -> void:
	var board = ContractBoardScript.new()
	board.call("setup", data, company, run_seed, game_day)
	board.back_requested.connect(func(): show_road())
	board.contract_accepted.connect(func(contract):
		if contract_system.accept(company, contract):
			show_road("Accepted contract: %s" % contract.get("title", ""))
		else:
			show_road("The company cannot accept another contract right now.")
	)
	_set_screen(board)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			var save_result = save_game()
			if save_result.get("ok", false):
				print("Saved snapshot: %s" % save_result.get("path", ""))
			else:
				push_error("Save failed: %s" % save_result.get("error", "unknown"))
		elif event.keycode == KEY_F9:
			var load_result = load_game()
			if load_result.get("ok", false):
				print("Loaded snapshot: day=%s location=%s" % [load_result.get("game_day", 0), load_result.get("current_location", "")])
			else:
				push_error("Load failed: %s" % load_result.get("error", "unknown"))

func _begin_travel(route: Dictionary) -> void:
	var travel = road_system.travel(company, route)
	if not travel.get("ok", false):
		show_road(travel.get("error", "Travel failed."))
		return
	pending_route = route.duplicate(true)
	pending_destination = travel.get("destination", "")
	travel_summary = travel.get("travel_summary", {})
	var context = travel.get("context", {})
	context["seed"] = run_seed
	if context.get("starts_combat", false):
		show_combat(context)
	else:
		company.move_to(pending_destination)
		var road_event = road_system.apply_road_event(company, route)
		var summary = _make_travel_aftermath(false, true, road_event.get("headline", "The road was tense, but no blades were drawn."))
		summary["road_event"] = road_event
		show_camp(summary)

func show_combat(context: Dictionary) -> void:
	var combat = CombatScreenScript.new()
	combat.call("setup", data, company, context)
	combat.combat_finished.connect(_finish_combat)
	_set_screen(combat)

func _finish_combat(result: Dictionary) -> void:
	company.apply_combat_result(result)
	var victory = bool(result.get("victory", false))
	var contract_resolved = false
	var contract_success = false
	var contract_failure = false
	var contract_effect = {}
	if victory:
		company.move_to(pending_destination)
		if contract_system.active_contract_completed(company, pending_route, pending_destination):
			contract_success = true
			contract_resolved = true
			contract_effect = contract_system.complete(company, data.get_route_economy(pending_route.get("id", "")), game_day, data.settlement_economy)
	else:
		if company.has_active_contract() and result.get("objective_failed", false):
			contract_failure = true
			contract_resolved = true
			contract_effect = contract_system.fail(company, data.get_route_economy(pending_route.get("id", "")), game_day, data.settlement_economy)
	var summary = _make_travel_aftermath(true, victory, result.get("headline", "The fight ends."))
	summary["combat"] = result
	summary["contract_resolved"] = contract_resolved
	summary["contract_success"] = contract_success
	summary["contract_failure"] = contract_failure
	summary["contract_effect"] = contract_effect
	show_camp(summary)

func _make_travel_aftermath(had_combat: bool, reached_destination: bool, headline: String) -> Dictionary:
	var route = pending_route
	return {
		"headline": headline,
		"had_combat": had_combat,
		"reached_destination": reached_destination,
		"from": route.get("from", ""),
		"to": pending_destination,
		"route_id": route.get("id", ""),
		"travel_summary": travel_summary,
		"resource_snapshot": company.snapshot_resources()
	}

func show_camp(summary: Dictionary) -> void:
	var camp = CampScreenScript.new()
	camp.call("setup", data, company, summary)
	camp.continue_requested.connect(func(): show_road("The company is ready for the next leg."))
	_set_screen(camp)

func _parse_user_args() -> void:
	var seed_text = _user_arg("seed")
	if seed_text.is_valid_int():
		run_seed = int(seed_text)

func _user_arg(name: String) -> String:
	var prefix = "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg == "--%s" % name:
			return "true"
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func _run_autoplay_from_args() -> void:
	var scenario = _user_arg("autoplay")
	if scenario == "" or scenario == "true":
		scenario = "escort_smoke"
	var result = {}
	if scenario == "escort_smoke":
		var runner = AutoplaySmokeScript.new()
		runner.call("setup", data, run_seed)
		result = runner.call("run_escort_smoke")
	else:
		result = {"ok": false, "error": "Unknown autoplay scenario: %s" % scenario}
	if result.get("ok", false):
		print("PASS: autoplay %s seed=%s result=%s" % [scenario, run_seed, str(result)])
		get_tree().quit(0)
	else:
		push_error("FAIL: autoplay %s seed=%s error=%s" % [scenario, run_seed, result.get("error", "unknown")])
		get_tree().quit(1)
