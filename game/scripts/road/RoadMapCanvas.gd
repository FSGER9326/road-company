extends Control
class_name RoadMapCanvas

var locations = []
var routes = []
var current_location = ""
var selected_route_id = ""
var data

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
		var blocked = false
		var status = "normal"
		if get("data") != null and data.route_economy != null:
			var r_eco = data.by_id(data.route_economy, route.get("id", ""))
			if not r_eco.is_empty():
				danger = int(r_eco.get("effective_danger", danger))
				blocked = r_eco.get("blocked", false)
				status = r_eco.get("status", "normal")

		var color = Color(0.29, 0.48, 0.23) # <30
		var width = 3.0
		
		if blocked:
			color = Color(0.35, 0.16, 0.16)
			width = 2.0
		elif danger >= 70:
			color = Color(0.54, 0.23, 0.23)
			width = 5.0
		elif danger >= 50:
			color = Color(0.60, 0.35, 0.16)
			width = 4.0
		elif danger >= 30:
			color = Color(0.54, 0.48, 0.23)
			width = 3.0

		if route.get("id", "") == selected_route_id:
			color = Color(0.95, 0.68, 0.28)
			width += 2.0
			
		draw_line(pa, pb, color, width)
		var mid = (pa + pb) * 0.5
		var tex = null
		if get("data") != null:
			var icon_id = "icon_danger_%s" % clamp(danger, 1, 5)
			if blocked:
				icon_id = "icon_route_blocked"
			elif status == "stabilizing":
				icon_id = "icon_route_stabilizing"
			elif status == "secure":
				icon_id = "icon_route_secure"
			
			tex = data.load_asset_texture(icon_id)
		if tex != null:
			draw_texture_rect(tex, Rect2(mid - Vector2(12, 12), Vector2(24, 24)), false)
		else:
			draw_string(font, mid + Vector2(-18, -6), "D%s" % danger, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.82, 0.62))

	for loc in locations:
		var pos = _map_pos(loc)
		var is_current = loc.get("id", "") == current_location
		
		var tier = 1
		if get("data") != null and data.settlement_economy != null:
			var s_eco = data.get_settlement_economy(loc.get("id", ""))
			if not s_eco.is_empty():
				tier = int(s_eco.get("market_tier", 1))

		var icon_id = "icon_settlement_town"
		if tier >= 4:
			icon_id = "icon_settlement_city"
		elif tier <= 2:
			icon_id = "icon_settlement_village"
			
		var tex = null
		if get("data") != null:
			tex = data.load_asset_texture(icon_id)
				
		if tex != null:
			var s = 40 if is_current else 32
			draw_texture_rect(tex, Rect2(pos - Vector2(s/2.0, s/2.0), Vector2(s, s)), false)
		else:
			var radius = 8
			if tier == 2: radius = 10
			elif tier == 3: radius = 14
			elif tier == 4: radius = 18
			elif tier >= 5: radius = 22
				
			if is_current: radius += 4
			
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
