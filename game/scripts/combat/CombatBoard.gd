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
		if unit.get("id", "") == active_unit_id:
			draw_circle(pos, 20, Color(0.96, 0.78, 0.28))
		if unit.get("id", "") == selected_unit_id:
			draw_circle(pos, 24, Color(0.84, 0.84, 0.76))
		draw_circle(pos, 17, Color(0.025, 0.025, 0.02))
		draw_circle(pos, 14, color)
		var label = unit.get("abbr", unit.get("name", "?").left(2)).to_upper()
		draw_string(font, pos + Vector2(-10, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		var bar_w = 32.0
		var hp_ratio = float(unit.get("hp", 1)) / max(1.0, float(unit.get("max_hp", 1)))
		draw_rect(Rect2(pos + Vector2(-16, 20), Vector2(bar_w, 4)), Color(0.12, 0.04, 0.04), true)
		draw_rect(Rect2(pos + Vector2(-16, 20), Vector2(bar_w * hp_ratio, 4)), Color(0.64, 0.08, 0.08), true)

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
