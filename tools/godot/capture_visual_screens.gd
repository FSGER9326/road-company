extends SceneTree

const DataStoreScript = preload("res://game/scripts/core/DataStore.gd")
const CompanyStateScript = preload("res://game/scripts/core/CompanyState.gd")
const MainMenuScript = preload("res://game/scripts/ui/MainMenu.gd")
const RoadScreenScript = preload("res://game/scripts/road/RoadScreen.gd")
const CombatScreenScript = preload("res://game/scripts/combat/CombatScreen.gd")
const CampScreenScript = preload("res://game/scripts/camp/CampScreen.gd")
const ContractBoardScript = preload("res://game/scripts/ui/ContractBoard.gd")

var output_dir: String = "tests/visual/runs/latest"
var capture_seed: int = 12345
var data
var company

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args = OS.get_cmdline_args()
	var next_is_out = false
	for arg in args:
		if next_is_out:
			output_dir = arg
			next_is_out = false
		elif arg == "--out":
			next_is_out = true
	
	print("Capturing screens to: ", output_dir)
	var d = DirAccess.open("res://")
	if not d.dir_exists(output_dir):
		d.make_dir_recursive(output_dir)

	data = DataStoreScript.new()
	data.load_all()
	company = CompanyStateScript.new()
	company.load_from_start(data.company_start)
	
	root.size = Vector2i(1280, 720)

	await _capture_main_menu()
	await _capture_road_map()
	await _capture_contract_board()
	await _capture_combat_board()
	await _capture_aftermath_camp()

	print("Finished visual capture.")
	quit(0)

func _wait_for_render() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _capture(filename: String) -> void:
	await _wait_for_render()
	var img = root.get_texture().get_image()
	if img.is_empty():
		push_error("Failed to capture: image is empty for " + filename)
	else:
		var path = output_dir + "/" + filename
		var err = img.save_png(path)
		if err != OK:
			push_error("Failed to save: " + path + " with error code " + str(err))
		else:
			print("Captured: ", path)

func _capture_main_menu() -> void:
	var menu = MainMenuScript.new()
	root.add_child(menu)
	await _capture("main_menu.png")
	root.remove_child(menu)
	menu.queue_free()

func _capture_road_map() -> void:
	var road = RoadScreenScript.new()
	road.call("setup", data, company, "headless test")
	root.add_child(road)
	await _capture("road_map.png")
	root.remove_child(road)
	road.queue_free()

func _capture_contract_board() -> void:
	var board = ContractBoardScript.new()
	board.call("setup", data, company, capture_seed)
	root.add_child(board)
	await _capture("contract_board.png")
	root.remove_child(board)
	board.queue_free()

func _capture_combat_board() -> void:
	var context = _escort_context()
	var combat = CombatScreenScript.new()
	combat.call("setup", data, company, context)
	root.add_child(combat)
	await _capture("combat_board.png")
	root.remove_child(combat)
	combat.queue_free()

func _capture_aftermath_camp() -> void:
	var camp = CampScreenScript.new()
	camp.call("setup", data, company, {"headline": "Headless aftermath", "had_combat": false, "reached_destination": true})
	root.add_child(camp)
	await _capture("aftermath_camp.png")
	root.remove_child(camp)
	camp.queue_free()

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
		"seed": capture_seed
	}
