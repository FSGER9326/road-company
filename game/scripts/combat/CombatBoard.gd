extends Control
class_name CombatBoard

signal cell_clicked(q, r)

const HEX_SIZE = 34.0
const SQRT3 = 1.7320508

var cells = []
var units = []
var active_unit_id = ""
var selected_unit_id = ""
var mode = "inspect"
var blocked_cells = {}
var slow_cells = {}
var origin = Vector2(82, 62)
var data

func _get_asset_id_for_unit(unit: Dictionary) -> String:
	var side = unit.get("side", "")
	if side == "objective":
		return "token_wagon"
	elif side == "enemy":
		var base_id = unit.get("id", "").split("_0")[0].split("_1")[0].split("_2")[0].split("_3")[0]
		base_id = base_id.replace("raider_", "bandit_")
		return "token_enemy_" + base_id
	elif side == "player":
		var idx = 1
		for u in units:
			if u.get("side", "") == "player":
				if u.get("id", "") == unit.get("id", ""):
					break
				idx += 1
		return "token_fighter_0%s" % clamp(idx, 1, 6)
	return ""

func set_state(new_cells: Array, new_units: Array, active_id: String, selected_id: String, new_mode: String, blocked: Dictionary, slow: Dictionary) -> void:
	cells = new_cells
	units = new_units
	active_unit_id = active_id
	selected_unit_id = selected_id
	mode = new_mode
	blocked_cells = blocked
	slow_cells = slow
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var found = _cell_at(event.position)
		if not found.is_empty():
			cell_clicked.emit(found.get("q", 0), found.get("r", 0))

func _draw() -> void:
	var font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.065, 0.07, 0.065), true)
	for cell in cells:
		var key = _key(cell.get("q", 0), cell.get("r", 0))
		var fill = Color(0.17, 0.18, 0.15)
		if slow_cells.has(key):
			fill = Color(0.19, 0.16, 0.12)
		if blocked_cells.has(key):
			fill = Color(0.08, 0.12, 0.085)
		draw_colored_polygon(_hex_points(cell.get("q", 0), cell.get("r", 0)), fill)
		draw_polyline(_hex_points_closed(cell.get("q", 0), cell.get("r", 0)), Color(0.36, 0.34, 0.28), 1.0)

	for unit in units:
		if not bool(unit.get("alive", true)):
			continue
		var pos = hex_center(unit.get("q", 0), unit.get("r", 0))
		var side = unit.get("side", "")
		var color = Color(0.25, 0.48, 0.72)
		if side == "enemy":
			color = Color(0.62, 0.22, 0.18)
		elif side == "objective":
			color = Color(0.66, 0.50, 0.26)
		# Highlights
		if unit.get("id", "") == active_unit_id:
			draw_circle(pos, 36, Color(0.96, 0.78, 0.28, 0.3))
			draw_arc(pos, 36, 0, TAU, 32, Color(0.96, 0.78, 0.28), 3.0)
		elif unit.get("id", "") == selected_unit_id:
			draw_circle(pos, 32, Color(0.84, 0.84, 0.76, 0.3))
			draw_arc(pos, 32, 0, TAU, 32, Color(0.84, 0.84, 0.76), 2.0)
		
		var texture = null
		if get("data") != null:
			var asset_id = _get_asset_id_for_unit(unit)
			if asset_id != "":
				var asset = data.get_asset(asset_id)
				if not asset.is_empty() and asset.has("path") and ResourceLoader.exists(asset["path"]):
					texture = load(asset["path"])
		
		if texture != null:
			var s = 64.0
			draw_texture_rect(texture, Rect2(pos - Vector2(s/2.0, s/2.0), Vector2(s, s)), false)
		else:
			draw_circle(pos, 19, Color(0.025, 0.025, 0.02))
			if side == "objective":
				draw_rect(Rect2(pos - Vector2(13, 13), Vector2(26, 26)), color)
			else:
				draw_circle(pos, 16, color)
			var label = unit.get("abbr", unit.get("name", "?").left(2)).to_upper()
			draw_string(font, pos + Vector2(-10, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			
		# Badges
		var badge_y = 20
		var hp = unit.get("hp", 0)
		var armor = int(unit.get("armor_body", 0)) + int(unit.get("armor_head", 0))
		
		# HP Badge
		draw_rect(Rect2(pos + Vector2(-18, badge_y), Vector2(16, 14)), Color(0.6, 0.15, 0.15, 0.95), true)
		draw_string(font, pos + Vector2(-15, badge_y + 11), str(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		
		# Armor Badge
		if armor > 0:
			draw_rect(Rect2(pos + Vector2(2, badge_y), Vector2(16, 14)), Color(0.45, 0.5, 0.55, 0.95), true)
			draw_string(font, pos + Vector2(5, badge_y + 11), str(armor), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			
		# AP Badge (active only)
		if unit.get("id", "") == active_unit_id:
			var ap = unit.get("ap", 0)
			draw_rect(Rect2(pos + Vector2(-8, -34), Vector2(16, 14)), Color(0.85, 0.65, 0.15, 0.95), true)
			draw_string(font, pos + Vector2(-4, -34 + 11), str(ap), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
			
		# Status condition icon
		var morale = unit.get("morale_state", "steady")
		if morale == "breaking":
			_draw_condition_icon(pos + Vector2(-24, -20), "icon_condition_frightened", font, "!")
		elif morale == "wavering":
			_draw_condition_icon(pos + Vector2(-24, -20), "icon_condition_exposed", font, "?")
		elif unit.get("injuries", []).size() > 0:
			_draw_condition_icon(pos + Vector2(-24, -20), "icon_condition_bleeding", font, "+")

func _draw_condition_icon(icon_pos: Vector2, icon_id: String, font: Font, fallback_char: String) -> void:
	var tex = null
	if get("data") != null:
		var asset = data.get_asset(icon_id)
		if not asset.is_empty() and asset.has("path") and ResourceLoader.exists(asset["path"]):
			tex = load(asset["path"])
			
	if tex != null:
		draw_texture_rect(tex, Rect2(icon_pos, Vector2(16, 16)), false)
	else:
		draw_rect(Rect2(icon_pos, Vector2(14, 14)), Color(0.1, 0.1, 0.1, 0.8), true)
		draw_string(font, icon_pos + Vector2(4, 11), fallback_char, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)

func hex_center(q: int, r: int) -> Vector2:
	return origin + Vector2(HEX_SIZE * SQRT3 * (float(q) + float(r) * 0.5), HEX_SIZE * 1.5 * float(r))

func _hex_points(q: int, r: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	var center = hex_center(q, r)
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE)
	return points

func _hex_points_closed(q: int, r: int) -> PackedVector2Array:
	var points = _hex_points(q, r)
	points.append(points[0])
	return points

func _cell_at(pos: Vector2) -> Dictionary:
	var best = {}
	var best_dist = 99999.0
	for cell in cells:
		var dist = pos.distance_to(hex_center(cell.get("q", 0), cell.get("r", 0)))
		if dist < best_dist:
			best_dist = dist
			best = cell
	if best_dist <= HEX_SIZE:
		return best
	return {}

func _key(q: int, r: int) -> String:
	return "%s,%s" % [q, r]

