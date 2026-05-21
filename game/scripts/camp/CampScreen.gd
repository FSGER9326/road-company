extends Control
class_name CampScreen

signal continue_requested

const CampSystemScript = preload("res://game/scripts/camp/CampSystem.gd")

var data
var company
var summary = {}
var summary_label: RichTextLabel
var resources_label: Label
var action_label: Label
var camp_system

func setup(new_data, new_company, new_summary: Dictionary) -> void:
	data = new_data
	company = new_company
	summary = new_summary.duplicate(true)
	camp_system = CampSystemScript.new()
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title = Label.new()
	title.text = "Aftermath and Camp"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	summary_label = RichTextLabel.new()
	summary_label.bbcode_enabled = true
	summary_label.custom_minimum_size = Vector2(700, 0)
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(summary_label)

	var side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.add_theme_constant_override("separation", 8)
	split.add_child(side)

	resources_label = Label.new()
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(resources_label)

	var rest = Button.new()
	rest.text = "Rest"
	rest.pressed.connect(func(): _camp_action(camp_system.rest(company)))
	side.add_child(rest)

	var repair = Button.new()
	repair.text = "Repair"
	repair.pressed.connect(func(): _camp_action(camp_system.repair(company)))
	side.add_child(repair)

	var treat = Button.new()
	treat.text = "Treat Wounds"
	treat.pressed.connect(func(): _camp_action(camp_system.treat_wounds(company)))
	side.add_child(treat)

	action_label = Label.new()
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.add_theme_color_override("font_color", Color(0.82, 0.76, 0.62))
	side.add_child(action_label)

	var cont = Button.new()
	cont.text = "Continue"
	cont.custom_minimum_size = Vector2(0, 44)
	cont.pressed.connect(func(): continue_requested.emit())
	side.add_child(cont)

	_refresh()

func _camp_action(text: String) -> void:
	action_label.text = text
	_refresh()

func _refresh() -> void:
	var lines = []
	lines.append("[b]%s[/b]" % summary.get("headline", "The road leg ends."))
	lines.append("")
	var travel = summary.get("travel_summary", {})
	if not travel.is_empty():
		lines.append("[b]Travel[/b]")
		lines.append("Route: %s" % summary.get("route_id", ""))
		lines.append("Reached destination: %s" % str(summary.get("reached_destination", false)))
		lines.append("Food, vigor, and morale were updated by road costs.")
		lines.append("")
	var road_event = summary.get("road_event", {})
	if not road_event.is_empty():
		lines.append("[b]Road Event[/b]")
		lines.append("%s" % road_event.get("title", "Road Event"))
		lines.append("%s" % road_event.get("description", ""))
		lines.append("Effects: %s" % _format_effects(road_event.get("effects", {})))
		lines.append("")
	var combat = summary.get("combat", {})
	if not combat.is_empty():
		lines.append("[b]Combat[/b]")
		lines.append("Result: %s" % ("[color=#4a7a3a]Victory[/color]" if combat.get("victory", false) else "[color=#8a3a3a]Defeat[/color]"))
		lines.append("Casualties: %s" % _list_or_none(combat.get("casualties", [])))
		lines.append("Injuries: %s" % _list_or_none(combat.get("injuries", [])))
		lines.append("Loot: %s" % str(combat.get("loot", {})))
		lines.append("")
	if summary.get("contract_resolved", false):
		lines.append("[b]Contract: %s[/b]" % ("[color=#4a7a3a]SUCCESS[/color]" if summary.get("contract_success", false) else "[color=#8a3a3a]FAILURE[/color]"))
		lines.append("Effects: %s" % _format_effects(summary.get("contract_effect", {})))
		lines.append("")
	lines.append("[b]Roster[/b]")
	for fighter in company.roster:
		lines.append("%s | HP %s/%s | armor %s/%s | morale %s | injuries %s" % [
			fighter.get("name", ""),
			fighter.get("hp", 0),
			fighter.get("max_hp", 0),
			fighter.get("armor_body", 0),
			fighter.get("armor_head", 0),
			fighter.get("morale_state", "steady"),
			_list_or_none(fighter.get("injuries", []))
		])
	if company.graveyard.size() > 0:
		lines.append("")
		lines.append("[b]Graveyard[/b]")
		for dead in company.graveyard:
			lines.append("%s - %s" % [dead.get("name", ""), dead.get("death_note", "dead")])
	summary_label.text = "\n".join(lines)
	resources_label.text = "Crowns %s\nFood %s\nTools %s\nMedicine %s\nAmmo %s\nMorale %s\nVigor %s\nRenown %s\nLocation %s" % [
		company.crowns,
		company.food,
		company.tools,
		company.medicine,
		company.ammunition,
		company.morale,
		company.vigor,
		company.renown,
		company.current_location
	]

func _list_or_none(values: Array) -> String:
	if values.is_empty():
		return "none"
	return ", ".join(values)

func _format_effects(eff: Dictionary) -> String:
	var parts = []
	for k in eff.keys():
		var val = eff[k]
		if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
			if val > 0:
				parts.append("%s [color=#4a7a3a]+%s[/color]" % [k, val])
			elif val < 0:
				parts.append("%s [color=#8a3a3a]%s[/color]" % [k, val])
			else:
				parts.append("%s %s" % [k, val])
		else:
			parts.append("%s %s" % [k, val])
	return " · ".join(parts) if parts.size() > 0 else "None"
