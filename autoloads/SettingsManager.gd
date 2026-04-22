extends Node

## Manages keybinding save / load via ConfigFile.
## Registered as autoload "SettingsManager".

const SAVE_PATH := "user://settings.cfg"

# Action name → human-readable label pairs, grouped by category.
const ACTION_CATEGORIES: Dictionary = {
	"UNITS": [
		["select_all", "Select All Units"],
		["select_all_other", "Select All Other Units"],
		["move_swarm", "Move"],
		["snap_to_core", "Center Camera"],
		["next_unit", "Next Unit"],
		["prev_unit", "Previous Unit"],
	],
	"SELECT BY TYPE": [
		["select_all_swordsman", "Select All Swordsmen"],
		["select_all_archer", "Select All Archers"],
		["select_all_priest", "Select All Priests"],
		["select_all_mage", "Select All Mages"],
	],
	"CONTROL GROUPS": [
		["group_1", "Group 1"],
		["group_2", "Group 2"],
		["group_3", "Group 3"],
		["group_4", "Group 4"],
		["group_5", "Group 5"],
		["group_6", "Group 6"],
		["group_7", "Group 7"],
		["group_8", "Group 8"],
		["group_9", "Group 9"],
	],
}

# Snapshot of the project's default bindings (captured on first launch).
var _default_events: Dictionary = {}

# Default key mappings for actions we register at runtime.
const _DEFAULT_KEYS: Dictionary = {
	"select_all_other": KEY_NONE,
	"next_unit": KEY_NONE,
	"prev_unit": KEY_NONE,
	"select_all_swordsman": KEY_F1,
	"select_all_archer": KEY_F2,
	"select_all_priest": KEY_F3,
	"select_all_mage": KEY_F4,
	"group_1": KEY_1,
	"group_2": KEY_2,
	"group_3": KEY_3,
	"group_4": KEY_4,
	"group_5": KEY_5,
	"group_6": KEY_6,
	"group_7": KEY_7,
	"group_8": KEY_8,
	"group_9": KEY_9,
}


func _ready() -> void:
	_register_actions()
	_capture_defaults()
	_load_settings()


func _register_actions() -> void:
	for action_name in _DEFAULT_KEYS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key: Key = _DEFAULT_KEYS[action_name]
			if key != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action_name, ev)


# ── Public API ──────────────────────────────────────────────

func get_events_for_action(action: String) -> Array[InputEvent]:
	var list: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		list.append(ev)
	return list


func rebind_action(action: String, new_event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)
	_save_settings()


func reset_to_defaults() -> void:
	for action in _default_events:
		InputMap.action_erase_events(action)
		for ev in _default_events[action]:
			InputMap.action_add_event(action, ev)
	_save_settings()


func get_event_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		var key_ev := ev as InputEventKey
		return OS.get_keycode_string(key_ev.physical_keycode) if key_ev.physical_keycode != 0 else OS.get_keycode_string(key_ev.keycode)
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "Mouse %d" % mb.button_index
	return ev.as_text()


# ── Internals ───────────────────────────────────────────────

func _capture_defaults() -> void:
	for cat in ACTION_CATEGORIES:
		for pair in ACTION_CATEGORIES[cat]:
			var action: String = pair[0]
			if InputMap.has_action(action):
				_default_events[action] = InputMap.action_get_events(action).duplicate()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for cat in ACTION_CATEGORIES:
		for pair in ACTION_CATEGORIES[cat]:
			var action: String = pair[0]
			var events := InputMap.action_get_events(action)
			if events.size() > 0:
				var ev: InputEvent = events[0]
				if ev is InputEventKey:
					var key_ev := ev as InputEventKey
					cfg.set_value("hotkeys", action + "_type", "key")
					cfg.set_value("hotkeys", action + "_keycode", key_ev.physical_keycode if key_ev.physical_keycode != 0 else key_ev.keycode)
				elif ev is InputEventMouseButton:
					var mb := ev as InputEventMouseButton
					cfg.set_value("hotkeys", action + "_type", "mouse")
					cfg.set_value("hotkeys", action + "_button", mb.button_index)
	cfg.save(SAVE_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for cat in ACTION_CATEGORIES:
		for pair in ACTION_CATEGORIES[cat]:
			var action: String = pair[0]
			if not cfg.has_section_key("hotkeys", action + "_type"):
				continue
			var type: String = cfg.get_value("hotkeys", action + "_type", "")
			var ev: InputEvent = null
			if type == "key":
				var kev := InputEventKey.new()
				kev.physical_keycode = cfg.get_value("hotkeys", action + "_keycode", 0) as Key
				ev = kev
			elif type == "mouse":
				var mev := InputEventMouseButton.new()
				mev.button_index = cfg.get_value("hotkeys", action + "_button", 1) as MouseButton
				mev.pressed = true
				ev = mev
			if ev:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, ev)
