extends Control
class_name ContractBoard

signal contract_accepted(contract)
signal back_requested

var data: DataStore
var company: CompanyState

func setup(new_data: DataStore, new_company: CompanyState) -> void:
	data = new_data
	company = new_company
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

	for contract in data.contracts_for_location(company.current_location):
		list.add_child(_contract_row(contract))

func _contract_row(contract: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title = Label.new()
	title.text = "%s  |  %s crowns  renown %s  danger %s" % [
		contract.get("title", ""),
		contract.get("reward_crowns", 0),
		contract.get("reward_renown", 0),
		contract.get("danger", 0)
	]
	title.add_theme_font_size_override("font_size", 19)
	box.add_child(title)

	var body = Label.new()
	body.text = "%s\nPatron: %s\nTarget: %s" % [
		contract.get("description", ""),
		contract.get("patron_faction", ""),
		contract.get("target_location", contract.get("target_route", ""))
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	var accept = Button.new()
	accept.text = "Accept Contract"
	accept.disabled = company.has_active_contract()
	accept.pressed.connect(func(): contract_accepted.emit(contract))
	box.add_child(accept)
	return panel
