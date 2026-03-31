extends Node

signal unit_count_changed(new_count: int)
signal enemy_died(position: Vector2)
signal unit_absorbed(position: Vector2)
signal ore_pulse_triggered
signal unit_died_with_info(unit_type: String, pos: Vector2)
signal unit_registered(unit: Node2D)
signal synergy_activated(synergy_type: String)
signal synergy_deactivated(synergy_type: String)

const BASE_ABSORPTION_CHANCE: float = 0.3
const BASE_REVIVAL_DURATION: float = 2.0

const SYNERGY_THRESHOLDS: Dictionary = {
	"volley_mode": {"type": "archer", "count": 3},
	"holy_shield": {"type": "priest", "count": 2},
	"arcane_surge": {"type": "mage", "count": 2},
}

var units: Array[Node2D] = []
var reviving_units: Array[Node2D] = []
var priority_targets: Array[Node2D] = []
var swarm_core: Node2D = null
var absorption_chance: float = BASE_ABSORPTION_CHANCE
var revival_duration: float = BASE_REVIVAL_DURATION
var archer_count: int = 0
var priest_count: int = 0
var mage_count: int = 0
var active_synergies: Array[String] = []
var unit_count: int = 0:
	set(value):
		unit_count = value
		unit_count_changed.emit(unit_count)


func register_unit(unit: Node2D) -> void:
	if unit not in units:
		units.append(unit)
		unit_count = units.size()
		_update_type_counts()
		unit_registered.emit(unit)


func unregister_unit(unit: Node2D) -> void:
	units.erase(unit)
	unit_count = units.size()
	_update_type_counts()


func register_reviving_unit(unit: Node2D) -> void:
	if unit not in reviving_units:
		reviving_units.append(unit)


func unregister_reviving_unit(unit: Node2D) -> void:
	reviving_units.erase(unit)


func register_swarm_core(core: Node2D) -> void:
	swarm_core = core


func get_swarm_center() -> Vector2:
	if units.is_empty():
		if swarm_core:
			return swarm_core.global_position
		return Vector2.ZERO
	var total := Vector2.ZERO
	for unit in units:
		if is_instance_valid(unit):
			total += unit.global_position
	return total / units.size()


func update_core_position() -> void:
	if swarm_core and not units.is_empty():
		swarm_core.global_position = get_swarm_center()


func on_enemy_died(pos: Vector2) -> void:
	enemy_died.emit(pos)


func on_unit_absorbed(pos: Vector2) -> void:
	unit_absorbed.emit(pos)


func on_ore_pulse() -> void:
	ore_pulse_triggered.emit()


func get_unit_scene_path(unit_type: String) -> String:
	if unit_type.begins_with("champion_"):
		return "res://scenes/entities/units/Champion.tscn"
	match unit_type:
		"swordsman":
			return "res://scenes/entities/units/Swordsman.tscn"
		"archer":
			return "res://scenes/entities/units/Archer.tscn"
		"priest":
			return "res://scenes/entities/units/Priest.tscn"
		"mage":
			return "res://scenes/entities/units/Mage.tscn"
		_:
			return "res://scenes/entities/units/Swordsman.tscn"


func get_unit_counts_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type"):
			var utype: String = unit.get_unit_type()
			counts[utype] = counts.get(utype, 0) + 1
	return counts


func register_priority_target(target: Node2D) -> void:
	if target not in priority_targets:
		priority_targets.append(target)


func unregister_priority_target(target: Node2D) -> void:
	priority_targets.erase(target)


func get_priority_target() -> Node2D:
	for target in priority_targets:
		if is_instance_valid(target) and not target.is_dying:
			return target
	return null


func roll_absorption() -> bool:
	return randf() < absorption_chance


func apply_meta_modifiers() -> void:
	for unit in units:
		if is_instance_valid(unit):
			apply_meta_to_unit(unit)


func apply_meta_to_unit(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	if unit.has_method("get_unit_type"):
		var utype: String = unit.get_unit_type()
		match utype:
			"swordsman":
				if MetaProgress.has_upgrade("veteran_swordsmen"):
					unit.max_hp = 2
					unit.current_hp = 2
			"archer":
				if MetaProgress.has_upgrade("eagle_archers"):
					unit.pursuit_range = 210.0
			"priest":
				if MetaProgress.has_upgrade("holy_presence"):
					unit.aura_radius = 90.0
			"mage":
				pass
		if RunManager.has_shop_buff("sharpened_blades") and utype == "swordsman":
			unit.damage += 1
		if RunManager.has_shop_buff("enchanted_quiver") and utype == "archer":
			if "attack_cooldown" in unit:
				unit.attack_cooldown -= 0.3
		if RunManager.has_shop_buff("battle_standard"):
			unit.max_hp = max(unit.max_hp, 2)
			unit.current_hp = unit.max_hp


func _update_type_counts() -> void:
	archer_count = 0
	priest_count = 0
	mage_count = 0
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type"):
			match unit.get_unit_type():
				"archer":
					archer_count += 1
				"priest":
					priest_count += 1
				"mage":
					mage_count += 1
	_check_synergies()


func _check_synergies() -> void:
	var type_counts := {"archer": archer_count, "priest": priest_count, "mage": mage_count}
	for synergy_name in SYNERGY_THRESHOLDS:
		var info: Dictionary = SYNERGY_THRESHOLDS[synergy_name]
		var met: bool = type_counts[info["type"]] >= info["count"]
		if met and synergy_name not in active_synergies:
			active_synergies.append(synergy_name)
			synergy_activated.emit(synergy_name)
		elif not met and synergy_name in active_synergies:
			active_synergies.erase(synergy_name)
			synergy_deactivated.emit(synergy_name)


func reset() -> void:
	for synergy_name in active_synergies.duplicate():
		active_synergies.erase(synergy_name)
		synergy_deactivated.emit(synergy_name)
	units.clear()
	reviving_units.clear()
	priority_targets.clear()
	swarm_core = null
	unit_count = 0
	archer_count = 0
	priest_count = 0
	mage_count = 0
	absorption_chance = BASE_ABSORPTION_CHANCE
	revival_duration = BASE_REVIVAL_DURATION
