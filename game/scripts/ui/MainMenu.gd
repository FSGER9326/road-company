extends Control
class_name MainMenu

signal new_run_requested

func _ready() -> void:
	_build()

func _build() -> void:
	var background = ColorRect.new()
	background.color = Color(0.06, 0.055, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -180
	box.offset_top = -150
	box.offset_right = 180
	box.offset_bottom = 150
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title = Label.new()
	title.text = "ROAD COMPANY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A mercenary caravan-company prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56))
	box.add_child(subtitle)

	var new_button = Button.new()
	new_button.text = "New Prototype Run"
	new_button.custom_minimum_size = Vector2(260, 44)
	new_button.pressed.connect(func(): new_run_requested.emit())
	box.add_child(new_button)

	var load_button = Button.new()
	load_button.text = "Load Run"
	load_button.disabled = true
	load_button.custom_minimum_size = Vector2(260, 38)
	box.add_child(load_button)

	var quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(260, 38)
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)
