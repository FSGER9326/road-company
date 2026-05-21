extends Control
class_name RoadMapCanvas

var locations = []
var routes = []
var current_location = ""
var selected_route_id = ""

func set_map(new_locations: Array, new_routes: Array, location_id: String) -> void:
	locations = new_locations
	routes = new_routes
	current_location = location_id
	queue_redraw()

func set_selected(route_id: String) -> void:
	selected_route_id = route_id
	queue_redraw()

func _draw() -> void:
	var font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.075, 0.065), true)
	for route in routes:
		var a = _location_by_id(route.get("from", ""))
		var b = _location_by_id(route.get("to", ""))
		if a.is_empty() or b.is_empty():
			continue
		var pa = _map_pos(a)
		var pb = _map_pos(b)
		var danger = int(route.get("danger", 1))
		var color = Color(0.42 + danger * 0.08, 0.34, 0.24)
		var width = 2.0 + danger * 0.4
		if route.get("id", "") == selected_route_id:
			color = Color(0.95, 0.68, 0.28)
			width = 5.0
		draw_line(pa, pb, color, width)
		var mid = (pa + pb) * 0.5
		draw_string(font, mid + Vector2(-18, -6), "D%s" % danger, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.82, 0.62))

	for loc in locations:
		var pos = _map_pos(loc)
		var is_current = loc.get("id", "") == current_location
		var radius = 16 if is_current else 12
		var color = Color(0.82, 0.68, 0.36) if is_current else Color(0.38, 0.42, 0.39)
		draw_circle(pos, radius + 3, Color(0.02, 0.02, 0.02))
		draw_circle(pos, radius, color)
		draw_string(font, pos + Vector2(18, 4), loc.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.86, 0.84, 0.78))

func _map_pos(location: Dictionary) -> Vector2:
	var pos = location.get("map_pos", [0.5, 0.5])
	return Vector2(float(pos[0]) * size.x, float(pos[1]) * size.y)

func _location_by_id(location_id: String) -> Dictionary:
	for loc in locations:
		if loc.get("id", "") == location_id:
			return loc
	return {}
