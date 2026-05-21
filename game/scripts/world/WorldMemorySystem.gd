extends RefCounted
class_name WorldMemorySystem

var _buffer = []
const MAX_ENTRIES = 200

func process_events(fired_events: Array, current_tick: int) -> void:
	for candidate in fired_events:
		var template = candidate.template
		var mem_data = template.get("memory_entry", {})
		if mem_data.is_empty():
			continue
			
		var title = mem_data.get("title", "").replace("{settlement_name}", candidate.settlement_name).replace("{route_name}", candidate.route_name)
		var summary = mem_data.get("summary", "").replace("{settlement_name}", candidate.settlement_name).replace("{route_name}", candidate.route_name)
		
		_buffer.append({
			"tick": current_tick,
			"category": mem_data.get("category", "event"),
			"title": title,
			"summary": summary
		})
		
		if _buffer.size() > MAX_ENTRIES:
			_buffer.pop_front()

func get_recent(limit: int = 5) -> Array:
	var copy = _buffer.duplicate(true)
	copy.reverse()
	if copy.size() > limit:
		return copy.slice(0, limit)
	return copy
