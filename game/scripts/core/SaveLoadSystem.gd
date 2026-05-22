extends RefCounted
class_name SaveLoadSystem

const SCHEMA_VERSION = 1
const AUTOSAVE_PATH = "user://saves/autosave.json"
const MANUAL_1_PATH = "user://saves/manual_1.json"

var last_error := ""

func build_snapshot(
	data,
	company,
	game_day: int,
	rng_seed: int,
	event_system = null,
	rumor_system = null,
	memory_system = null
) -> Dictionary:
	var current_location = company.current_location if company != null else ""
	var contract_board = []
	if data != null and company != null:
		contract_board = data.contract_board_for_location(current_location, company.faction_reputation, rng_seed, game_day)
	return {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix_time": Time.get_unix_time_from_system(),
		"game_day": game_day,
		"current_location": current_location,
		"company": company.snapshot() if company != null else {},
		"world": {
			"settlement_economy": data.settlement_economy.duplicate(true) if data != null else [],
			"route_economy": data.route_economy.duplicate(true) if data != null else [],
			"active_events": event_system.snapshot_recent_events() if event_system != null and event_system.has_method("snapshot_recent_events") else [],
			"event_cooldowns": event_system.snapshot_cooldowns() if event_system != null and event_system.has_method("snapshot_cooldowns") else {}
		},
		"contracts": {
			"active_contract": company.active_contract.duplicate(true) if company != null else {},
			"contract_board": contract_board.duplicate(true)
		},
		"factions": {
			"settlement_factions": data.settlement_factions.duplicate(true) if data != null else []
		},
		"rumors": {
			"active": rumor_system.snapshot() if rumor_system != null and rumor_system.has_method("snapshot") else []
		},
		"memory": {
			"entries": memory_system.snapshot() if memory_system != null and memory_system.has_method("snapshot") else []
		},
		"rng_seed": rng_seed,
		"notes": "Save/load snapshot v1 for prototype state. Static content is loaded from data files before applying mutable sections.",
		"debug_metadata": {
			"format": "road_company_save_snapshot",
			"contract_board_location": current_location
		}
	}

func save_snapshot(snapshot_data: Dictionary, path: String = AUTOSAVE_PATH) -> Dictionary:
	var validation = validate_snapshot(snapshot_data)
	if not validation.get("ok", false):
		last_error = "; ".join(validation.get("errors", []))
		return {"ok": false, "error": last_error}
	var dir_error = _ensure_save_dir(path)
	if dir_error != OK:
		last_error = "Could not create save directory for %s" % path
		return {"ok": false, "error": last_error}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open save file for writing: %s" % path
		return {"ok": false, "error": last_error}
	file.store_string(JSON.stringify(snapshot_data, "\t", false))
	file.close()
	return {"ok": true, "path": path}

func load_snapshot(path: String = AUTOSAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		last_error = "Save file does not exist: %s" % path
		return {"ok": false, "error": last_error}
	var text = FileAccess.get_file_as_string(path)
	var json = JSON.new()
	var parse_error = json.parse(text)
	if parse_error != OK:
		last_error = "Malformed save JSON at line %s: %s" % [json.get_error_line(), json.get_error_message()]
		return {"ok": false, "error": last_error}
	var snapshot_data = json.data
	var validation = validate_snapshot(snapshot_data)
	if not validation.get("ok", false):
		last_error = "; ".join(validation.get("errors", []))
		return {"ok": false, "error": last_error}
	return {"ok": true, "snapshot": normalize_snapshot(snapshot_data)}

func apply_snapshot(
	snapshot_data: Dictionary,
	data,
	company,
	event_system = null,
	rumor_system = null,
	memory_system = null
) -> Dictionary:
	var validation = validate_snapshot(snapshot_data)
	if not validation.get("ok", false):
		last_error = "; ".join(validation.get("errors", []))
		return {"ok": false, "error": last_error}
	var normalized = normalize_snapshot(snapshot_data)
	if company != null:
		company.restore_from_snapshot(normalized.get("company", {}))
	if data != null:
		var world = normalized.get("world", {})
		var factions = normalized.get("factions", {})
		data.settlement_economy = world.get("settlement_economy", data.settlement_economy).duplicate(true)
		data.route_economy = world.get("route_economy", data.route_economy).duplicate(true)
		data.settlement_factions = factions.get("settlement_factions", data.settlement_factions).duplicate(true)
	if event_system != null and event_system.has_method("restore_snapshot"):
		event_system.restore_snapshot(normalized.get("world", {}))
	if rumor_system != null and rumor_system.has_method("restore_snapshot"):
		rumor_system.restore_snapshot(normalized.get("rumors", {}))
	if memory_system != null and memory_system.has_method("restore_snapshot"):
		memory_system.restore_snapshot(normalized.get("memory", {}))
	return {
		"ok": true,
		"game_day": int(normalized.get("game_day", 0)),
		"rng_seed": int(normalized.get("rng_seed", 12345)),
		"current_location": normalized.get("current_location", "")
	}

func validate_snapshot(snapshot_data) -> Dictionary:
	var errors = []
	if typeof(snapshot_data) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["Snapshot must be a JSON object."]}
	if not snapshot_data.has("schema_version"):
		errors.append("schema_version is required.")
	elif int(snapshot_data.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("Unsupported schema_version %s; expected %s." % [snapshot_data.get("schema_version"), SCHEMA_VERSION])
	if not snapshot_data.has("saved_at_unix_time") and not snapshot_data.has("saved_at_text"):
		errors.append("saved_at_unix_time or saved_at_text is required.")
	if not snapshot_data.has("notes") and not snapshot_data.has("debug_metadata"):
		errors.append("notes or debug_metadata is required.")
	for key in ["game_day", "current_location", "company", "world", "contracts", "factions", "rumors", "memory", "rng_seed"]:
		if not snapshot_data.has(key):
			errors.append("%s is required." % key)
	if snapshot_data.has("company") and typeof(snapshot_data.get("company")) != TYPE_DICTIONARY:
		errors.append("company must be an object.")
	if snapshot_data.has("world") and typeof(snapshot_data.get("world")) != TYPE_DICTIONARY:
		errors.append("world must be an object.")
	if snapshot_data.has("contracts") and typeof(snapshot_data.get("contracts")) != TYPE_DICTIONARY:
		errors.append("contracts must be an object.")
	return {"ok": errors.is_empty(), "errors": errors}

func normalize_snapshot(snapshot_data: Dictionary) -> Dictionary:
	var normalized = snapshot_data.duplicate(true)
	normalized["company"] = normalized.get("company", {})
	var company_data = normalized["company"]
	if not company_data.has("resources"):
		company_data["resources"] = {}
	if not company_data.has("current_location"):
		company_data["current_location"] = normalized.get("current_location", "")
	if not company_data.has("roster"):
		company_data["roster"] = []
	if not company_data.has("graveyard"):
		company_data["graveyard"] = []
	if not company_data.has("faction_reputation"):
		company_data["faction_reputation"] = {}
	if not company_data.has("active_contract"):
		company_data["active_contract"] = normalized.get("contracts", {}).get("active_contract", {})
	normalized["world"] = normalized.get("world", {})
	normalized["world"]["settlement_economy"] = normalized["world"].get("settlement_economy", [])
	normalized["world"]["route_economy"] = normalized["world"].get("route_economy", [])
	normalized["world"]["active_events"] = normalized["world"].get("active_events", [])
	normalized["world"]["event_cooldowns"] = normalized["world"].get("event_cooldowns", {})
	normalized["contracts"] = normalized.get("contracts", {})
	normalized["contracts"]["active_contract"] = normalized["contracts"].get("active_contract", company_data.get("active_contract", {}))
	normalized["contracts"]["contract_board"] = normalized["contracts"].get("contract_board", [])
	normalized["factions"] = normalized.get("factions", {})
	normalized["factions"]["settlement_factions"] = normalized["factions"].get("settlement_factions", [])
	normalized["rumors"] = normalized.get("rumors", {})
	normalized["rumors"]["active"] = normalized["rumors"].get("active", [])
	normalized["memory"] = normalized.get("memory", {})
	normalized["memory"]["entries"] = normalized["memory"].get("entries", [])
	return normalized

func _ensure_save_dir(path: String) -> Error:
	var base_dir = path.get_base_dir()
	if base_dir.is_empty():
		return OK
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
