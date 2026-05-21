extends RefCounted
class_name RumorSystem

var active_rumors = []

func process_events(fired_events: Array, current_tick: int) -> void:
	for candidate in fired_events:
		var template = candidate.template
		var rumor_data = template.get("rumor_entry", {})
		if rumor_data.is_empty():
			continue
			
		var text = rumor_data.get("text", "").replace("{settlement_name}", candidate.settlement_name).replace("{route_name}", candidate.route_name)
		var urgency = int(rumor_data.get("urgency", 5))
		var expires = current_tick + int(rumor_data.get("expires_after_days", 14))
		
		var found = false
		for r in active_rumors:
			if r.text == text:
				r.expires = max(r.expires, expires)
				r.urgency = max(r.urgency, urgency)
				found = true
				break
				
		if not found:
			active_rumors.append({
				"text": text,
				"urgency": urgency,
				"expires": expires
			})

func expire_old_rumors(current_tick: int) -> void:
	var next_rumors = []
	for r in active_rumors:
		if current_tick <= r.expires:
			next_rumors.append(r)
	active_rumors = next_rumors

func get_top_rumors(limit: int = 5) -> Array:
	active_rumors.sort_custom(func(a, b): return a.urgency > b.urgency)
	if active_rumors.size() > limit:
		return active_rumors.slice(0, limit)
	return active_rumors
