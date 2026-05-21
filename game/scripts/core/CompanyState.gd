extends RefCounted
class_name CompanyState

var company_name = ""
var current_location = ""
var crowns = 0
var food = 0
var tools = 0
var medicine = 0
var ammunition = 0
var morale = 0
var vigor = 0
var renown = 0
var roster = []
var graveyard = []
var faction_reputation = {}
var active_contract = {}
var last_summary = {}

func load_from_start(start_data: Dictionary) -> void:
	company_name = start_data.get("company_name", "Ash Road Company")
	current_location = start_data.get("current_location", "")
	crowns = int(start_data.get("crowns", 0))
	food = int(start_data.get("food", 0))
	tools = int(start_data.get("tools", 0))
	medicine = int(start_data.get("medicine", 0))
	ammunition = int(start_data.get("ammunition", 0))
	morale = int(start_data.get("morale", 50))
	vigor = int(start_data.get("vigor", 60))
	renown = int(start_data.get("renown", 0))
	roster = start_data.get("roster", []).duplicate(true)
	graveyard = start_data.get("graveyard", []).duplicate(true)
	faction_reputation = start_data.get("faction_reputation", {}).duplicate(true)
	active_contract = {}
	last_summary = {}

func accept_contract(contract: Dictionary) -> void:
	active_contract = contract.duplicate(true)

func clear_contract() -> void:
	active_contract = {}

func has_active_contract() -> bool:
	return not active_contract.is_empty()

func apply_route_cost(route: Dictionary) -> Dictionary:
	var before = snapshot_resources()
	food = max(0, food - int(route.get("food_cost", 0)))
	vigor = clamp(vigor - int(route.get("vigor_cost", 0)), 0, 100)
	if int(route.get("danger", 0)) >= 4:
		morale = clamp(morale - 2, 0, 100)
	var after = snapshot_resources()
	return {"before": before, "after": after}

func move_to(location_id: String) -> void:
	current_location = location_id

func apply_contract_success() -> Dictionary:
	if active_contract.is_empty():
		return {}
	var result = {
		"crowns": int(active_contract.get("reward_crowns", 0)),
		"renown": int(active_contract.get("reward_renown", 0)),
		"factions": active_contract.get("faction_effects", {})
	}
	crowns += int(result.get("crowns", 0))
	renown += int(result.get("renown", 0))
	var faction_effects = result.get("factions", {})
	for faction_id in faction_effects.keys():
		faction_reputation[faction_id] = int(faction_reputation.get(faction_id, 0)) + int(faction_effects[faction_id])
	clear_contract()
	return result

func apply_contract_failure() -> Dictionary:
	if active_contract.is_empty():
		return {}
	var effects = active_contract.get("failure_faction_effects", {})
	for faction_id in effects.keys():
		faction_reputation[faction_id] = int(faction_reputation.get(faction_id, 0)) + int(effects[faction_id])
	var failed = active_contract.duplicate(true)
	clear_contract()
	return failed

func apply_combat_result(result: Dictionary) -> void:
	var updates = result.get("roster_updates", {})
	for fighter in roster:
		var id = fighter.get("id", "")
		if updates.has(id):
			var update = updates[id]
			fighter["hp"] = int(update.get("hp", fighter.get("hp", 1)))
			fighter["armor_body"] = int(update.get("armor_body", fighter.get("armor_body", 0)))
			fighter["armor_head"] = int(update.get("armor_head", fighter.get("armor_head", 0)))
			fighter["fatigue"] = int(update.get("fatigue", fighter.get("fatigue", 0)))
			fighter["morale_state"] = update.get("morale_state", fighter.get("morale_state", "steady"))
			fighter["injuries"] = update.get("injuries", fighter.get("injuries", [])).duplicate(true)
	var dead_ids = result.get("dead_ids", [])
	if dead_ids.size() > 0:
		var survivors = []
		for fighter in roster:
			if dead_ids.has(fighter.get("id", "")):
				var dead = fighter.duplicate(true)
				dead["death_note"] = result.get("death_note", "Fell on the road")
				graveyard.append(dead)
			else:
				survivors.append(fighter)
		roster = survivors
	crowns += int(result.get("crowns_delta", 0))
	food = max(0, food + int(result.get("food_delta", 0)))
	tools = max(0, tools + int(result.get("tools_delta", 0)))
	medicine = max(0, medicine + int(result.get("medicine_delta", 0)))
	ammunition = max(0, ammunition + int(result.get("ammo_delta", 0)))
	morale = clamp(morale + int(result.get("morale_delta", 0)), 0, 100)
	vigor = clamp(vigor + int(result.get("vigor_delta", 0)), 0, 100)

func rest() -> String:
	if food <= 0:
		return "No food remains for a proper rest."
	food = max(0, food - 2)
	vigor = clamp(vigor + 22, 0, 100)
	morale = clamp(morale + 4, 0, 100)
	for fighter in roster:
		fighter["fatigue"] = max(0, int(fighter.get("fatigue", 0)) - 15)
	return "The company eats, sleeps, and recovers some nerve."

func repair_armor() -> String:
	if tools <= 0:
		return "No tools remain for repairs."
	tools = max(0, tools - 2)
	for fighter in roster:
		fighter["armor_body"] = int(fighter.get("armor_body", 0)) + 12
		fighter["armor_head"] = int(fighter.get("armor_head", 0)) + 6
	return "Straps are tightened and plates are patched."

func treat_wounds() -> String:
	if medicine <= 0:
		return "No medicine remains for treatment."
	medicine = max(0, medicine - 1)
	for fighter in roster:
		fighter["hp"] = min(int(fighter.get("max_hp", 1)), int(fighter.get("hp", 1)) + 10)
		var injuries = fighter.get("injuries", [])
		if injuries.size() > 0:
			injuries.remove_at(0)
			fighter["injuries"] = injuries
	return "Wounds are cleaned and the worst bleeding is stopped."

func snapshot_resources() -> Dictionary:
	return {
		"crowns": crowns,
		"food": food,
		"tools": tools,
		"medicine": medicine,
		"ammunition": ammunition,
		"morale": morale,
		"vigor": vigor,
		"renown": renown
	}
