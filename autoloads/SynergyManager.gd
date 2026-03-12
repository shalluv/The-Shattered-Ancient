extends Node

const VOLLEY_INTERVAL: float = 3.0
const HOLY_SHIELD_SCAN_INTERVAL: float = 0.5
const ARCANE_SURGE_MULTIPLIER: float = 1.4

var active_synergies: Array[String] = []
var volley_timer: Timer = null
var shield_scan_timer: float = 0.0
var units_with_shield_aura: Dictionary = {}


func _ready() -> void:
	SwarmManager.synergy_activated.connect(_on_synergy_activated)
	SwarmManager.synergy_deactivated.connect(_on_synergy_deactivated)
	SwarmManager.unit_registered.connect(_on_unit_registered)


func _on_synergy_activated(synergy_type: String) -> void:
	active_synergies.append(synergy_type)
	match synergy_type:
		"volley_mode":
			_activate_volley()
		"holy_shield":
			_activate_holy_shield()
		"arcane_surge":
			_activate_arcane_surge()


func _on_synergy_deactivated(synergy_type: String) -> void:
	active_synergies.erase(synergy_type)
	match synergy_type:
		"volley_mode":
			_deactivate_volley()
		"holy_shield":
			_deactivate_holy_shield()
		"arcane_surge":
			_deactivate_arcane_surge()


func _on_unit_registered(unit: Node2D) -> void:
	if not is_instance_valid(unit) or not unit.has_method("get_unit_type"):
		return
	var utype: String = unit.get_unit_type()
	if "arcane_surge" in active_synergies and utype == "mage" and unit.has_method("apply_arcane_surge"):
		unit.apply_arcane_surge(ARCANE_SURGE_MULTIPLIER)


func _physics_process(delta: float) -> void:
	if "holy_shield" in active_synergies:
		shield_scan_timer -= delta
		if shield_scan_timer <= 0.0:
			shield_scan_timer = HOLY_SHIELD_SCAN_INTERVAL
			_scan_holy_shield()


func _activate_volley() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type") and unit.get_unit_type() == "archer":
			unit.volley_mode = true
	if volley_timer == null:
		volley_timer = Timer.new()
		volley_timer.wait_time = VOLLEY_INTERVAL
		volley_timer.timeout.connect(_on_volley_timer)
		add_child(volley_timer)
	volley_timer.start()


func _deactivate_volley() -> void:
	if volley_timer:
		volley_timer.stop()
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type") and unit.get_unit_type() == "archer":
			unit.volley_mode = false


func _on_volley_timer() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type") and unit.get_unit_type() == "archer":
			if unit.has_method("volley_fire"):
				unit.volley_fire()


func _activate_holy_shield() -> void:
	units_with_shield_aura.clear()
	shield_scan_timer = 0.0


func _deactivate_holy_shield() -> void:
	units_with_shield_aura.clear()


func _scan_holy_shield() -> void:
	var priests: Array[Node2D] = []
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type") and unit.get_unit_type() == "priest":
			priests.append(unit)

	if priests.is_empty():
		return

	var aura_radius: float = 50.0
	if priests.size() > 0 and "aura_radius" in priests[0]:
		aura_radius = priests[0].aura_radius

	for unit in SwarmManager.units:
		if not is_instance_valid(unit):
			continue
		if unit.has_method("get_unit_type") and unit.get_unit_type() == "priest":
			continue

		var unit_id := unit.get_instance_id()
		var in_any_aura := false

		for priest in priests:
			if not is_instance_valid(priest):
				continue
			var dist := unit.global_position.distance_to(priest.global_position)
			if dist < aura_radius:
				in_any_aura = true
				break

		var was_in: bool = units_with_shield_aura.get(unit_id, false)

		if in_any_aura and not was_in:
			units_with_shield_aura[unit_id] = true
			if unit.shield_charge == 0 and unit.has_method("apply_shield"):
				unit.apply_shield()
		elif not in_any_aura and was_in:
			units_with_shield_aura[unit_id] = false


func _activate_arcane_surge() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type") and unit.get_unit_type() == "mage":
			if unit.has_method("apply_arcane_surge"):
				unit.apply_arcane_surge(ARCANE_SURGE_MULTIPLIER)


func _deactivate_arcane_surge() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type") and unit.get_unit_type() == "mage":
			if unit.has_method("remove_arcane_surge"):
				unit.remove_arcane_surge()


func reset() -> void:
	active_synergies.clear()
	units_with_shield_aura.clear()
	if volley_timer:
		volley_timer.stop()
	shield_scan_timer = 0.0
