extends Control
class_name ContractBoard

signal contract_accepted(contract)
signal back_requested

var data
var company
var seed = 12345
var tick = 0

func setup(new_data, new_company, new_seed: int = 12345, new_tick: int = 0) -> void:
	data = new_data
	company = new_company
	seed = new_seed
	tick = new_tick
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header = HBoxContainer.new()
	root.add_child(header)
	var title = Label.new()
	title.text = "Contract Board"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back = Button.new()
	back.text = "Back to Road"
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	if company.has_active_contract():
		var active = Label.new()
		active.text = "The company already has an active contract: %s" % company.active_contract.get("title", "")
		active.add_theme_color_override("font_color", Color(0.9, 0.72, 0.45))
		root.add_child(active)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var generated = []
	var static_contracts = []
	for contract in data.contract_board_for_location(company.current_location, company.faction_reputation, seed, tick):
		if contract.has("generated_from"):
			generated.append(contract)
		else:
			static_contracts.append(contract)
			
	if generated.size() > 0:
		var lbl = Label.new()
		lbl.text = "--- Dynamic Contracts ---"
		lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
		list.add_child(lbl)
		for contract in generated:
			list.add_child(_contract_row(contract))
			
	if static_contracts.size() > 0:
		var lbl = Label.new()
		lbl.text = "--- Static Contracts ---"
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		list.add_child(lbl)
		for contract in static_contracts:
			list.add_child(_contract_row(contract))

func _get_type_icon(t: String) -> String:
	match t:
		"escort_caravan": return "[E]"
		"patrol_route": return "[P]"
		"hunt_bandits": return "[H]"
		"recover_wagon": return "[R]"
		"deliver_medicine": return "[M]"
		"defend_settlement": return "[D]"
		"bounty_target": return "[B]"
	return "[?]"

func _contract_row(contract: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title = Label.new()
	title.text = "%s %s  |  Reward: %sc  ·  %s renown" % [
		_get_type_icon(contract.get("type", "")),
		contract.get("title", ""),
		contract.get("reward_crowns", 0),
		contract.get("reward_renown", 0)
	]
	title.add_theme_font_size_override("font_size", 19)
	box.add_child(title)

	var target = contract.get("target_location", contract.get("target_route", ""))
	var patron = contract.get("patron_faction", "Local Authority")
	
	var effect_str = "None"
	if contract.has("generated_from") and contract.get("generated_from", {}).has("mechanical_effects"):
		effect_str = str(contract.get("generated_from", {}).get("mechanical_effects", {}))
		
	var body = Label.new()
	body.text = "Patron: %s\nTarget: %s\nDanger: %s\nEffects: %s" % [
		patron, target, contract.get("danger", 0), effect_str
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	if contract.has("generated_from"):
		var reason = Label.new()
		reason.text = "Why: %s" % contract.get("generated_from", {}).get("world_state_reason", "")
		reason.add_theme_color_override("font_color", Color(0.64, 0.73, 0.78))
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reason)

	var accept = Button.new()
	accept.text = "Accept Contract"
	accept.disabled = company.has_active_contract()
	accept.pressed.connect(func(): contract_accepted.emit(contract))
	box.add_child(accept)
	return panel
