extends Control
class_name CombatScreen

signal combat_finished(result)

const CombatBoardScript = preload("res://game/scripts/combat/CombatBoard.gd")
const CombatSystemScript = preload("res://game/scripts/combat/CombatSystem.gd")

var data: DataStore
var company: CompanyState
var context = {}
var board: CombatBoard
var cells = []
var units = []
var turn_queue = []
var current_index = 0
var round_number = 1
var mode = "move"
var selected_unit_id = ""
var active_unit_id = ""
var blocked_cells = {}
var slow_cells = {}
var log_lines = []
var rng = RandomNumberGenerator.new()
var combat_system: CombatSystem
var info_label: RichTextLabel
var log_label: RichTextLabel
var status_label: Label
var move_button: Button
var attack_button: Button
var wait_button: Button
var end_button: Button
var combat_over = false
var objective_rounds_to_hold = 5

func setup(new_data: DataStore, new_company: CompanyState, new_context: Dictionary) -> void:
	data = new_data
	company = new_company
	context = new_context.duplicate(true)
	rng.seed = int(context.get("seed", 12345))
	combat_system = CombatSystemScript.new()
	combat_system.setup(data, company, int(context.get("seed", 12345)))
	_build_ui()
	_build_battle()
	_start_round()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	var header = HBoxContainer.new()
	root.add_child(header)
	status_label = Label.new()
	status_label.text = "Combat"
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)

	var body = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	board = CombatBoardScript.new()
	board.custom_minimum_size = Vector2(840, 600)
	board.cell_clicked.connect(_on_cell_clicked)
	body.add_child(board)

	var side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(390, 0)
	side.add_theme_constant_override("separation", 7)
	body.add_child(side)

	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.custom_minimum_size = Vector2(0, 185)
	info_label.fit_content = true
	side.add_child(info_label)

	var actions = GridContainer.new()
	actions.columns = 2
	side.add_child(actions)
	move_button = Button.new()
	move_button.text = "Move"
	move_button.pressed.connect(func(): _set_mode("move"))
	actions.add_child(move_button)
	attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.pressed.connect(func(): _set_mode("attack"))
	actions.add_child(attack_button)
	wait_button = Button.new()
	wait_button.text = "Wait"
	wait_button.pressed.connect(_wait_action)
	actions.add_child(wait_button)
	end_button = Button.new()
	end_button.text = "End Turn"
	end_button.pressed.connect(_end_turn)
	actions.add_child(end_button)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(log_label)

func _build_battle() -> void:
	cells.clear()
	units.clear()
	cells = combat_system.build_cells()
	_build_terrain()
	units = combat_system.build_units(context)
	if context.get("ambush", false):
		_log("The company is hit before the road can be secured.")
	if context.get("low_vigor", false):
		_log("Low vigor adds fatigue to the first clash.")
	_refresh_board()

func _build_terrain() -> void:
	blocked_cells.clear()
	slow_cells.clear()
	var terrain = combat_system.build_terrain(context.get("terrain_tags", []))
	blocked_cells = terrain.get("blocked", {})
	slow_cells = terrain.get("slow", {})

func _start_round() -> void:
	_build_turn_queue()
	current_index = 0
	_log("Round %s begins." % round_number)
	_start_current_turn()

func _build_turn_queue() -> void:
	turn_queue.clear()
	for unit in units:
		if bool(unit.get("alive", true)) and unit.get("side", "") != "objective" and unit.get("morale_state", "steady") != "breaking":
			turn_queue.append(unit.get("id", ""))
	turn_queue.sort_custom(Callable(self, "_sort_by_initiative"))

func _sort_by_initiative(a_id: String, b_id: String) -> bool:
	return int(_unit_by_id(a_id).get("initiative", 0)) > int(_unit_by_id(b_id).get("initiative", 0))

func _start_current_turn() -> void:
	if combat_over:
		return
	if _check_end_conditions():
		return
	if turn_queue.is_empty():
		_finish_combat(false, "No one remains able to fight.")
		return
	if current_index >= turn_queue.size():
		round_number += 1
		if context.get("escort_objective", false) and round_number > objective_rounds_to_hold and _objective_alive():
			_finish_combat(true, "The wagon survives long enough for the ambush to break.")
			return
		_start_round()
		return
	var unit = _unit_by_id(turn_queue[current_index])
	if unit.is_empty() or not bool(unit.get("alive", true)) or unit.get("morale_state", "") == "breaking":
		current_index += 1
		_start_current_turn()
		return
	unit["ap"] = 9
	active_unit_id = unit.get("id", "")
	selected_unit_id = active_unit_id
	mode = "move"
	_log("%s acts." % unit.get("name", "Unit"))
	_refresh_board()
	if unit.get("side", "") == "enemy":
		_set_player_controls(false)
		get_tree().create_timer(0.25).timeout.connect(_enemy_turn)
	else:
		_set_player_controls(true)

func _on_cell_clicked(q: int, r: int) -> void:
	if combat_over:
		return
	var actor = _active_unit()
	if actor.is_empty() or actor.get("side", "") != "player":
		return
	var clicked_unit = _unit_at(q, r)
	if not clicked_unit.is_empty():
		selected_unit_id = clicked_unit.get("id", "")
	if mode == "move":
		_try_move(actor, q, r)
	elif mode == "attack":
		if not clicked_unit.is_empty() and clicked_unit.get("side", "") != "player":
			_try_attack(actor, clicked_unit)
	_refresh_board()

func _try_move(unit: Dictionary, q: int, r: int) -> bool:
	if not _unit_at(q, r).is_empty() or blocked_cells.has(_key(q, r)):
		_log("That hex is blocked.")
		return false
	if _distance(unit.get("q", 0), unit.get("r", 0), q, r) != 1:
		_log("Move one hex at a time in this prototype.")
		return false
	var cost = 3
	if slow_cells.has(_key(q, r)):
		cost += 1
	if int(unit.get("ap", 0)) < cost:
		_log("%s lacks AP to move." % unit.get("name", "Unit"))
		return false
	unit["q"] = q
	unit["r"] = r
	unit["ap"] = int(unit.get("ap", 0)) - cost
	unit["fatigue"] = int(unit.get("fatigue", 0)) + cost
	_log("%s moves." % unit.get("name", "Unit"))
	return true

func _try_attack(attacker: Dictionary, defender: Dictionary) -> bool:
	var weapon = data.get_weapon(attacker.get("weapon_id", ""))
	var max_range = int(weapon.get("range", 1))
	var dist = _distance(attacker.get("q", 0), attacker.get("r", 0), defender.get("q", 0), defender.get("r", 0))
	if dist > max_range:
		_log("Target is out of range.")
		return false
	var ap_cost = int(weapon.get("ap_cost", 4))
	if int(attacker.get("ap", 0)) < ap_cost:
		_log("%s lacks AP to attack." % attacker.get("name", "Unit"))
		return false
	attacker["ap"] = int(attacker.get("ap", 0)) - ap_cost
	attacker["fatigue"] = int(attacker.get("fatigue", 0)) + int(weapon.get("fatigue_cost", 6))
	var attack_skill = int(attacker.get("melee_skill", 50))
	var defense = int(defender.get("melee_defense", 0))
	if max_range > 1:
		attack_skill = int(attacker.get("ranged_skill", attack_skill))
		defense = int(defender.get("ranged_defense", defense))
	var chance = clamp(55 + attack_skill - defense, 15, 95)
	var roll = rng.randi_range(1, 100)
	if roll > chance:
		_log("%s misses %s (%s vs %s)." % [attacker.get("name", "Unit"), defender.get("name", "target"), roll, chance])
		return true
	var damage = rng.randi_range(int(weapon.get("damage_min", 12)), int(weapon.get("damage_max", 20)))
	_apply_damage(attacker, defender, damage, weapon)
	return true

func _apply_damage(attacker: Dictionary, defender: Dictionary, damage: int, weapon: Dictionary) -> void:
	var use_head = rng.randi_range(1, 100) <= 20 and int(defender.get("armor_head", 0)) > 0
	var armor_key = "armor_head" if use_head else "armor_body"
	var armor_before = int(defender.get(armor_key, 0))
	var armor_damage = min(armor_before, int(float(damage) * float(weapon.get("armor_damage", 1.0))))
	defender[armor_key] = max(0, armor_before - armor_damage)
	var hp_damage = max(0, damage - armor_before)
	if armor_before <= 0:
		hp_damage = damage
	defender["hp"] = max(0, int(defender.get("hp", 1)) - hp_damage)
	_log("%s hits %s for %s armor and %s HP." % [attacker.get("name", "Unit"), defender.get("name", "target"), armor_damage, hp_damage])
	if hp_damage >= 14 and defender.get("side", "") != "objective":
		_morale_check(defender, 18)
		if defender.get("side", "") == "player":
			_add_injury(defender)
	if int(defender.get("hp", 0)) <= 0:
		defender["alive"] = false
		_log("%s is killed." % defender.get("name", "Unit"))
		_ally_death_morale(defender.get("side", ""))

func _enemy_turn() -> void:
	if combat_over:
		return
	var enemy = _active_unit()
	if enemy.is_empty() or enemy.get("side", "") != "enemy":
		_end_turn()
		return
	var target = _choose_enemy_target(enemy)
	if target.is_empty():
		_end_turn()
		return
	if _distance(enemy.get("q", 0), enemy.get("r", 0), target.get("q", 0), target.get("r", 0)) <= int(data.get_weapon(enemy.get("weapon_id", "")).get("range", 1)):
		_try_attack(enemy, target)
	else:
		var step = _best_step_toward(enemy, target)
		if not step.is_empty():
			_try_move(enemy, step.get("q", 0), step.get("r", 0))
		if bool(target.get("alive", true)) and _distance(enemy.get("q", 0), enemy.get("r", 0), target.get("q", 0), target.get("r", 0)) <= int(data.get_weapon(enemy.get("weapon_id", "")).get("range", 1)):
			_try_attack(enemy, target)
	_end_turn()

func _choose_enemy_target(enemy: Dictionary) -> Dictionary:
	var objective = _objective_unit()
	if not objective.is_empty() and _distance(enemy.get("q", 0), enemy.get("r", 0), objective.get("q", 0), objective.get("r", 0)) <= 5:
		return objective
	var best = {}
	var best_dist = 999
	for unit in units:
		if unit.get("side", "") == "player" and bool(unit.get("alive", true)) and unit.get("morale_state", "") != "breaking":
			var dist = _distance(enemy.get("q", 0), enemy.get("r", 0), unit.get("q", 0), unit.get("r", 0))
			if dist < best_dist:
				best_dist = dist
				best = unit
	return best

func _best_step_toward(unit: Dictionary, target: Dictionary) -> Dictionary:
	var best = {}
	var best_dist = _distance(unit.get("q", 0), unit.get("r", 0), target.get("q", 0), target.get("r", 0))
	for n in _neighbors(unit.get("q", 0), unit.get("r", 0)):
		if blocked_cells.has(_key(n.x, n.y)) or not _unit_at(n.x, n.y).is_empty():
			continue
		var dist = _distance(n.x, n.y, target.get("q", 0), target.get("r", 0))
		if dist < best_dist:
			best_dist = dist
			best = {"q": n.x, "r": n.y}
	return best

func _wait_action() -> void:
	var actor = _active_unit()
	if actor.is_empty() or actor.get("side", "") != "player":
		return
	actor["ap"] = max(0, int(actor.get("ap", 0)) - 2)
	actor["initiative"] = max(1, int(actor.get("initiative", 1)) - 4)
	_log("%s waits." % actor.get("name", "Unit"))
	_end_turn()

func _end_turn() -> void:
	current_index += 1
	_refresh_board()
	_start_current_turn()

func _set_mode(new_mode: String) -> void:
	mode = new_mode
	_refresh_board()

func _set_player_controls(enabled: bool) -> void:
	move_button.disabled = not enabled
	attack_button.disabled = not enabled
	wait_button.disabled = not enabled
	end_button.disabled = not enabled

func _check_end_conditions() -> bool:
	if _alive_units("enemy").is_empty():
		_finish_combat(true, "The attackers are routed.")
		return true
	if context.get("escort_objective", false) and not _objective_alive():
		_finish_combat(false, "The wagon is destroyed.")
		return true
	if _active_player_units().is_empty():
		_finish_combat(false, "The company line collapses.")
		return true
	return false

func _finish_combat(victory: bool, headline: String) -> void:
	if combat_over:
		return
	combat_over = true
	_set_player_controls(false)
	var result = _make_result(victory, headline)
	var finish = Button.new()
	finish.text = "Return to Aftermath"
	finish.custom_minimum_size = Vector2(0, 42)
	finish.pressed.connect(func(): combat_finished.emit(result))
	get_child(0).get_child(1).get_child(1).add_child(finish)
	status_label.text = "Victory" if victory else "Defeat"
	_log(headline)
	_refresh_board()

func _make_result(victory: bool, headline: String) -> Dictionary:
	var updates = {}
	var dead_ids = []
	var casualties = []
	var injuries = []
	for unit in units:
		if unit.get("side", "") == "player":
			updates[unit.get("id", "")] = {
				"hp": int(unit.get("hp", 0)),
				"armor_body": int(unit.get("armor_body", 0)),
				"armor_head": int(unit.get("armor_head", 0)),
				"fatigue": int(unit.get("fatigue", 0)),
				"morale_state": unit.get("morale_state", "steady"),
				"injuries": unit.get("injuries", [])
			}
			if not bool(unit.get("alive", true)):
				dead_ids.append(unit.get("id", ""))
				casualties.append(unit.get("name", "Unknown"))
			elif unit.get("injuries", []).size() > 0:
				injuries.append("%s: %s" % [unit.get("name", "Unknown"), ", ".join(unit.get("injuries", []))])
	var loot_crowns = 95 if victory else 0
	var loot_tools = 1 if victory else 0
	return {
		"victory": victory,
		"headline": headline,
		"objective_failed": context.get("escort_objective", false) and not _objective_alive(),
		"roster_updates": updates,
		"dead_ids": dead_ids,
		"casualties": casualties,
		"injuries": injuries,
		"crowns_delta": loot_crowns,
		"food_delta": 0,
		"tools_delta": loot_tools,
		"medicine_delta": 0,
		"ammo_delta": -1 if _ranged_was_present() else 0,
		"morale_delta": 5 if victory else -10,
		"vigor_delta": -8,
		"loot": {"crowns": loot_crowns, "tools": loot_tools}
	}

func _refresh_board() -> void:
	board.set_state(cells, units, active_unit_id, selected_unit_id, mode, blocked_cells, slow_cells)
	status_label.text = "Round %s | Mode: %s" % [round_number, mode.capitalize()]
	var selected = _unit_by_id(selected_unit_id)
	if selected.is_empty():
		selected = _active_unit()
	if selected.is_empty():
		info_label.text = ""
	else:
		info_label.text = "[b]%s[/b]\nSide: %s  Morale: %s\nHP: %s/%s  Armor: %s body / %s head\nAP: %s  Fatigue: %s/%s\nWeapon: %s" % [
			selected.get("name", ""),
			selected.get("side", ""),
			selected.get("morale_state", "steady"),
			selected.get("hp", 0),
			selected.get("max_hp", 0),
			selected.get("armor_body", 0),
			selected.get("armor_head", 0),
			selected.get("ap", 0),
			selected.get("fatigue", 0),
			selected.get("max_fatigue", 0),
			selected.get("weapon_id", "")
		]
	log_label.text = "\n".join(log_lines.slice(max(0, log_lines.size() - 16), log_lines.size()))

func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 80:
		log_lines.pop_front()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(log_lines.slice(max(0, log_lines.size() - 16), log_lines.size()))

func _morale_check(unit: Dictionary, penalty: int) -> void:
	var target = clamp(int(unit.get("resolve", 40)) + int(company.morale * 0.25) - penalty, 10, 95)
	if rng.randi_range(1, 100) <= target:
		return
	var state = unit.get("morale_state", "steady")
	if state == "steady":
		unit["morale_state"] = "wavering"
		_log("%s wavers." % unit.get("name", "Unit"))
	elif state == "wavering":
		unit["morale_state"] = "breaking"
		_log("%s breaks." % unit.get("name", "Unit"))

func _ally_death_morale(side: String) -> void:
	for unit in units:
		if unit.get("side", "") == side and bool(unit.get("alive", true)):
			_morale_check(unit, 24)

func _add_injury(unit: Dictionary) -> void:
	var injuries = unit.get("injuries", []).duplicate(true)
	var possible = ["cut arm", "cracked ribs", "rattled skull", "split hand"]
	if injuries.size() < 2:
		injuries.append(possible[rng.randi_range(0, possible.size() - 1)])
	unit["injuries"] = injuries

func _active_unit() -> Dictionary:
	if active_unit_id.is_empty():
		return {}
	return _unit_by_id(active_unit_id)

func _unit_by_id(unit_id: String) -> Dictionary:
	for unit in units:
		if unit.get("id", "") == unit_id:
			return unit
	return {}

func _unit_at(q: int, r: int) -> Dictionary:
	for unit in units:
		if bool(unit.get("alive", true)) and int(unit.get("q", -1)) == q and int(unit.get("r", -1)) == r:
			return unit
	return {}

func _alive_units(side: String) -> Array:
	var found = []
	for unit in units:
		if unit.get("side", "") == side and bool(unit.get("alive", true)):
			found.append(unit)
	return found

func _active_player_units() -> Array:
	var found = []
	for unit in units:
		if unit.get("side", "") == "player" and bool(unit.get("alive", true)) and unit.get("morale_state", "steady") != "breaking":
			found.append(unit)
	return found

func _objective_unit() -> Dictionary:
	for unit in units:
		if unit.get("side", "") == "objective":
			return unit
	return {}

func _objective_alive() -> bool:
	var objective = _objective_unit()
	return objective.is_empty() or bool(objective.get("alive", true))

func _ranged_was_present() -> bool:
	for unit in units:
		if unit.get("side", "") == "player" and int(data.get_weapon(unit.get("weapon_id", "")).get("range", 1)) > 1:
			return true
	return false

func _neighbors(q: int, r: int) -> Array:
	return [
		Vector2i(q + 1, r),
		Vector2i(q - 1, r),
		Vector2i(q, r + 1),
		Vector2i(q, r - 1),
		Vector2i(q + 1, r - 1),
		Vector2i(q - 1, r + 1)
	]

func _distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 = -q1 - r1
	var s2 = -q2 - r2
	return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2)

func _key(q: int, r: int) -> String:
	return "%s,%s" % [q, r]
