extends RefCounted
class_name EventSystem

var templates = []
var _last_fired = {}

func configure(event_templates: Array) -> void:
	templates = event_templates
	_last_fired = {}

func evaluate_and_fire(world_state: Dictionary, current_tick: int) -> Array:
	var candidates = []
	var context_route = world_state.get("context_route", {})
	var context_settlement = world_state.get("context_settlement", {})
	
	for template in templates:
		var event_id = template.get("id", "")
		var cooldown = int(template.get("cooldown_days", 0))
		var ticks_passed = current_tick - _last_fired.get(event_id, -9999)
		if ticks_passed < cooldown:
			continue
			
		var category = template.get("category", "")
		if category == "settlement":
			for settlement in world_state.get("settlements", []):
				if _check_conditions(settlement, template.get("trigger_conditions", [])):
					candidates.append(_build_candidate(template, settlement, {}, {}))
		elif category == "route":
			for route in world_state.get("routes", []):
				if _check_conditions(route, template.get("trigger_conditions", [])):
					candidates.append(_build_candidate(template, {}, route, {}))
		elif category == "company":
			var company = world_state.get("company", {})
			if not company.is_empty() and _check_conditions(company, template.get("trigger_conditions", [])):
				var s = context_settlement if not context_settlement.is_empty() else {}
				var r = context_route if not context_route.is_empty() else {}
				candidates.append(_build_candidate(template, s, r, company))

	candidates.sort_custom(func(a, b): return int(a.template.get("weight", 0)) > int(b.template.get("weight", 0)))
	
	var fired = []
	for candidate in candidates:
		if fired.size() >= 3:
			break
		var event_id = candidate.template.get("id", "")
		if _last_fired.has(event_id):
			var ticks_passed = current_tick - _last_fired.get(event_id, -9999)
			if ticks_passed < candidate.template.get("cooldown_days", 0):
				continue
				
		_last_fired[event_id] = current_tick
		_apply_mechanical_effects(candidate)
		fired.append(candidate)
		
	return fired

func _check_conditions(target: Dictionary, conditions: Array) -> bool:
	for cond in conditions:
		var field = cond.get("field", "")
		var op = cond.get("op", "")
		var target_val = cond.get("value")
		var actual_val = target.get(field)
		if actual_val == null:
			actual_val = 0
			if typeof(target_val) == TYPE_BOOL:
				actual_val = false
			elif typeof(target_val) == TYPE_STRING:
				actual_val = ""
				
		var passed = false
		if typeof(target_val) == TYPE_INT or typeof(target_val) == TYPE_FLOAT:
			var act_f = float(actual_val)
			var tgt_f = float(target_val)
			if op == "lt": passed = act_f < tgt_f
			elif op == "lte": passed = act_f <= tgt_f
			elif op == "gt": passed = act_f > tgt_f
			elif op == "gte": passed = act_f >= tgt_f
			elif op == "eq": passed = act_f == tgt_f
			elif op == "neq": passed = act_f != tgt_f
		else:
			if op == "eq": passed = actual_val == target_val
			elif op == "neq": passed = actual_val != target_val
			
		if not passed:
			return false
	return true

func _build_candidate(template: Dictionary, settlement: Dictionary, route: Dictionary, company: Dictionary) -> Dictionary:
	var result = {
		"template": template,
		"settlement": settlement,
		"route": route,
		"company": company,
		"settlement_name": settlement.get("name", settlement.get("settlement_id", "")) if not settlement.is_empty() else "",
		"route_name": route.get("name", route.get("route_id", "")) if not route.is_empty() else ""
	}
	return result

func _apply_mechanical_effects(candidate: Dictionary) -> void:
	var effects = candidate.template.get("mechanical_effects", {})
	var target = null
	if candidate.template.get("category", "") == "settlement":
		target = candidate.settlement
	elif candidate.template.get("category", "") == "route":
		target = candidate.route
	elif candidate.template.get("category", "") == "company":
		target = candidate.company
		
	if target == null:
		return
		
	for field in effects.keys():
		var val = effects[field]
		if typeof(val) == TYPE_BOOL or typeof(val) == TYPE_STRING:
			target[field] = val
		else:
			var current = float(target.get(field, 0))
			target[field] = current + float(val)
