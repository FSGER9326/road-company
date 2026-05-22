extends Control
class_name RoadScreen

const RoadMapCanvasScript = preload("res://game/scripts/road/RoadMapCanvas.gd")
const WorldEconomySystemScript = preload("res://game/scripts/world/WorldEconomySystem.gd")

signal open_contract_board
signal travel_requested(route)
signal week_advanced(days)

var data
var company
var selected_route = {}
var route_buttons = []
var map_canvas
var detail_label: RichTextLabel
var resource_label: Label
var contract_label: Label
var location_label: RichTextLabel
var travel_button: Button
var economy_label: RichTextLabel
var economy_result_label: Label
var economy_system
var event_system
var rumor_system
var memory_system
var current_day = 0

var events_label: RichTextLabel
var rumors_label: RichTextLabel

func setup(new_data, new_company, message: String = "", new_current_day: int = 0) -> void:
	data = new_data
	company = new_company
	current_day = new_current_day
	economy_system = WorldEconomySystemScript.new()
	_build(message)

func _build(message: String) -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 42)
	root.add_child(header)

	var title = Label.new()
	title.text = "ROAD COMPANY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	header.add_child(title)

	resource_label = Label.new()
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Hide the text because we'll draw it in _draw() as requested
	resource_label.text = "" 
	header.add_child(resource_label)

	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	map_canvas = RoadMapCanvasScript.new()
	map_canvas.custom_minimum_size = Vector2(760, 580)
	map_canvas.set("data", data)
	map_canvas.set_map(data.locations, data.routes, company.current_location)
	split.add_child(map_canvas)

	var side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(390, 0)
	side.add_theme_constant_override("separation", 8)
	split.add_child(side)

	location_label = RichTextLabel.new()
	location_label.custom_minimum_size = Vector2(0, 130)
	location_label.fit_content = true
	side.add_child(location_label)

	contract_label = Label.new()
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(contract_label)

	economy_label = RichTextLabel.new()
	economy_label.custom_minimum_size = Vector2(0, 118)
	economy_label.fit_content = true
	side.add_child(economy_label)

	var tick_button = Button.new()
	tick_button.text = "Advance Week"
	tick_button.pressed.connect(_advance_week)
	side.add_child(tick_button)

	economy_result_label = Label.new()
	economy_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_result_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
	side.add_child(economy_result_label)
	
	events_label = RichTextLabel.new()
	events_label.bbcode_enabled = true
	events_label.custom_minimum_size = Vector2(0, 80)
	events_label.fit_content = true
	side.add_child(events_label)

	rumors_label = RichTextLabel.new()
	rumors_label.bbcode_enabled = true
	rumors_label.custom_minimum_size = Vector2(0, 100)
	rumors_label.fit_content = true
	side.add_child(rumors_label)

	var contracts_button = Button.new()
	contracts_button.text = "Contract Board"
	contracts_button.pressed.connect(func(): open_contract_board.emit())
	side.add_child(contracts_button)

	var route_title = Label.new()
	route_title.text = "Connected Roads"
	route_title.add_theme_font_size_override("font_size", 18)
	side.add_child(route_title)

	var route_list = VBoxContainer.new()
	route_list.add_theme_constant_override("separation", 5)
	side.add_child(route_list)
	route_buttons.clear()

	for route in data.connected_routes(company.current_location):
		var destination_id = data.other_end(route, company.current_location)
		var destination = data.by_id(data.locations, destination_id)
		var button = Button.new()
		button.text = "%s  |  %sd  food %s  vigor %s  danger %s" % [
			destination.get("name", destination_id),
			route.get("days", 1),
			route.get("food_cost", 0),
			route.get("vigor_cost", 0),
			route.get("danger", 0)
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_route.bind(route))
		route_list.add_child(button)
		route_buttons.append(button)

	detail_label = RichTextLabel.new()
	detail_label.custom_minimum_size = Vector2(0, 170)
	detail_label.fit_content = true
	side.add_child(detail_label)

	travel_button = Button.new()
	travel_button.text = "Travel Selected Route"
	travel_button.disabled = true
	travel_button.custom_minimum_size = Vector2(0, 42)
	travel_button.pressed.connect(func():
		if not selected_route.is_empty():
			travel_requested.emit(selected_route)
	)
	side.add_child(travel_button)

	if not message.is_empty():
		var msg = Label.new()
		msg.text = message
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
		side.add_child(msg)

	_refresh_labels()

func _select_route(route: Dictionary) -> void:
	selected_route = route
	map_canvas.set_selected(route.get("id", ""))
	travel_button.disabled = false
	var dest = data.by_id(data.locations, data.other_end(route, company.current_location))
	
	var r_eco = data.by_id(data.route_economy, route.get("id", ""))
	var traffic = r_eco.get("traffic", 0) if not r_eco.is_empty() else 0
	var bandits = r_eco.get("bandit_pressure", 0) if not r_eco.is_empty() else 0
	var patrols = r_eco.get("patrol_presence", 0) if not r_eco.is_empty() else 0
	var trade = r_eco.get("trade_flow", 0) if not r_eco.is_empty() else 0
	var status = "Blocked" if r_eco.get("blocked", false) else "Normal"
	
	detail_label.text = "[b]Route: %s-%s[/b]\nDanger: %s    Traffic: %s\nBandits: %s    Patrols: %s\nTrade Flow: %s    Status: %s\n\nTerrain: %s\nBattlefield: %s\nEncounter table: %s" % [
		data.by_id(data.locations, route.get("from", "")).get("name", ""),
		data.by_id(data.locations, route.get("to", "")).get("name", ""),
		route.get("danger", 0), traffic,
		bandits, patrols,
		trade, status,
		", ".join(route.get("terrain_tags", [])),
		", ".join(route.get("battlefield_tags", [])),
		route.get("encounter_table", "none")
	]

func _refresh_labels() -> void:
	queue_redraw()
	var loc = data.by_id(data.locations, company.current_location)
	location_label.text = "[b]%s[/b]\n%s\nFaction pressure: %s\nMarket: %s" % [
		loc.get("name", company.current_location),
		loc.get("description", ""),
		str(loc.get("faction_influence", {})),
		", ".join(loc.get("market_tags", []))
	]
	if company.has_active_contract():
		contract_label.text = "Active contract: %s\n%s" % [
			company.active_contract.get("title", ""),
			company.active_contract.get("description", "")
		]
	else:
		contract_label.text = "Active contract: none"
	_refresh_economy_label()
	_refresh_world_state_labels()

func _refresh_world_state_labels() -> void:
	if events_label == null or rumors_label == null: return
	
	if rumor_system != null:
		var top_rumors = rumor_system.get_top_rumors(3)
		var rumor_lines = []
		for r in top_rumors:
			var urg = int(r.get("urgency", 1))
			var text = r.get("text", "")
			if urg >= 4:
				rumor_lines.append("[color=#ffffff]\"%s\"[/color]" % text)
			elif urg <= 2:
				rumor_lines.append("[color=#666666]\"%s\"[/color]" % text)
			else:
				rumor_lines.append("\"%s\"" % text)
		var r_text = "[b]RUMORS:[/b] " + " · ".join(rumor_lines)
		if top_rumors.is_empty(): r_text = "[b]RUMORS:[/b] The roads are quiet."
		rumors_label.text = r_text

	if memory_system != null:
		var recent = memory_system.get_recent(3)
		var event_lines = []
		for m in recent:
			event_lines.append("[color=#888888][t%s][/color] %s" % [m.get("tick", 0), m.get("title", "")])
		var m_text = "[b]LOG:[/b] " + " · ".join(event_lines)
		if recent.is_empty(): m_text = "[b]LOG:[/b] No recent events."
		events_label.text = m_text

func _refresh_economy_label() -> void:
	if economy_label == null:
		return
	var economy = data.get_settlement_economy(company.current_location)
	if economy.is_empty():
		economy_label.text = "[b]Settlement Economy[/b]\nNo economy entry for this settlement."
		return
	var faction_lines = []
	for faction in data.settlement_factions_for_location(company.current_location):
		faction_lines.append("%s %s/%s" % [faction.get("name", ""), faction.get("influence", 0), faction.get("attitude_to_company", 0)])
	economy_label.text = "[b]Settlement Economy[/b]\nProsperity\nSecurity\nUnrest\nTrade Acc\nMarket Tier %s  ·  Pop %s  ·  Food %s\nRecruits %s\nDominant: %s  Tension %s\n%s" % [
		economy.get("market_tier", 1),
		economy.get("population", 0),
		economy.get("food_stock", 0),
		economy.get("recruitment_pool_quality", 0),
		economy.get("dominant_internal_faction", ""),
		economy.get("faction_tension", 0),
		"\n".join(faction_lines)
	]
	
func _draw() -> void:
	if company == null or data == null: return
	var font = get_theme_default_font()
	
	# 1. Company Resource Strip (draw_string)
	var res_text = "%s  |  %sc  %sf  %st  %sm  M:%s  V:%s  R:%s" % [
		company.company_name, company.crowns, company.food, company.tools,
		company.medicine, company.morale, company.vigor, company.renown
	]
	draw_string(font, Vector2(250, 32), res_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 260, 16, Color(0.86, 0.84, 0.78))
	
	# 2. Settlement Economy Bars (draw_rect)
	if economy_label != null and economy_label.is_visible_in_tree():
		var eco = data.get_settlement_economy(company.current_location)
		if eco.is_empty(): return
		var base_pos = economy_label.global_position + Vector2(200, 20)
		
		# Prosperity
		_draw_eco_bar(base_pos, eco.get("prosperity", 0), false)
		# Security
		_draw_eco_bar(base_pos + Vector2(0, 18), eco.get("security", 0), false)
		# Unrest
		_draw_eco_bar(base_pos + Vector2(0, 36), eco.get("unrest", 0), true)
		# Trade
		_draw_eco_bar(base_pos + Vector2(0, 54), eco.get("trade_access", 0), false)

func _draw_eco_bar(pos: Vector2, value: float, invert_colors: bool) -> void:
	var w = 40.0
	var h = 6.0
	var bg = Color(0.23, 0.16, 0.16)
	var fill = Color.GREEN
	
	if invert_colors:
		if value > 60: fill = Color.RED
		elif value > 30: fill = Color.YELLOW
	else:
		if value < 30: fill = Color.RED
		elif value < 60: fill = Color.YELLOW
		
	draw_rect(Rect2(pos, Vector2(w, h)), bg)
	var fw = clamp(value / 100.0 * w, 0, w)
	draw_rect(Rect2(pos, Vector2(fw, h)), fill)

func _advance_week() -> void:
	current_day += 7
	var result = economy_system.weekly_tick(data.settlement_economy, data.route_economy, data.routes, current_day, data.settlement_factions)
	week_advanced.emit(7)
	var current = {}
	for entry in result.get("settlements", []):
		if entry.get("settlement_id", "") == company.current_location:
			current = entry
			break
	if current.is_empty():
		economy_result_label.text = "Week advanced. No local economy delta found."
	else:
		economy_result_label.text = "Week advanced: food -%s, prosperity %s, unrest %s, population %s" % [
			current.get("food_consumed", 0),
			_signed_delta(int(current.get("prosperity_delta", 0))),
			_signed_delta(int(current.get("unrest_delta", 0))),
			_signed_delta(int(current.get("population_delta", 0)))
		]
	_refresh_economy_label()

func _signed_delta(value: int) -> String:
	if value > 0:
		return "+%s" % value
	return str(value)
