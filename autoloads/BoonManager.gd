extends Node

var healing_ward_used_this_room: bool = false
var healing_ward_max_revives: int = 1
var healing_ward_revive_hp: int = 1
var healing_ward_revives_done: int = 0
var omnislash_timer: Timer = null
var omnislash_damage: int = 5
var crystal_nova_timer: Timer = null
var crystal_nova_slow_duration: float = 3.0
var is_frost_aura_active: bool = false
var frost_aura_slow: float = 0.7
var frost_aura_radius: float = 150.0
var arcane_aura_conversion_time: float = 2.0
var arcane_aura_convert_hp: int = 1
var blade_fury_multiplier: float = 1.5
var blade_fury_speed_bonus: bool = false

var precision_aura_bonus: float = 0.0
var archer_extra_hp: bool = false
var is_frost_arrows_active: bool = false
var projectile_slow_amount: float = 0.8
var frost_arrows_bonus_damage: bool = false
var multishot_count: int = 1
var multishot_pierce: bool = false

var purification_timer: Timer = null
var purification_count: int = 3
var guardian_angel_max_uses: int = 0
var guardian_angel_uses: int = 0
var guardian_angel_spawn_count: int = 3
var is_degen_aura_active: bool = false
var degen_aura_slow: float = 0.75
var degen_aura_radius: float = 100.0


func _ready() -> void:
	SwarmManager.unit_died_with_info.connect(_on_unit_died_with_info)
	SwarmManager.unit_registered.connect(_on_unit_registered)
	SwarmManager.unit_count_changed.connect(_on_unit_count_changed)


func apply_all_boons() -> void:
	healing_ward_used_this_room = false
	healing_ward_revives_done = 0

	for boon_id in RunManager.active_boons:
		match boon_id:
			"blade_fury":
				_apply_blade_fury()
			"blade_fury_double":
				blade_fury_multiplier = 2.0
				_apply_blade_fury()
			"blade_fury_speed":
				blade_fury_speed_bonus = true
				_apply_blade_fury()
			"healing_ward":
				pass
			"healing_ward_double":
				healing_ward_max_revives = 2
			"healing_ward_tough":
				healing_ward_revive_hp = 2
			"omnislash":
				_start_omnislash_timer()
			"omnislash_fast":
				if omnislash_timer:
					omnislash_timer.wait_time = 10.0
				else:
					_start_omnislash_timer()
					omnislash_timer.wait_time = 10.0
			"omnislash_power":
				omnislash_damage = 8
				if not omnislash_timer:
					_start_omnislash_timer()
			"frost_aura":
				is_frost_aura_active = true
			"frost_aura_deep":
				is_frost_aura_active = true
				frost_aura_slow = 0.55
			"frost_aura_wide":
				is_frost_aura_active = true
				frost_aura_radius = 200.0
			"crystal_nova":
				_start_crystal_nova_timer()
			"crystal_nova_fast":
				if crystal_nova_timer:
					crystal_nova_timer.wait_time = 12.0
				else:
					_start_crystal_nova_timer()
					crystal_nova_timer.wait_time = 12.0
			"crystal_nova_long":
				crystal_nova_slow_duration = 5.0
				if not crystal_nova_timer:
					_start_crystal_nova_timer()
			"arcane_aura":
				_apply_arcane_aura()
			"arcane_aura_fast":
				arcane_aura_conversion_time = 1.0
				_apply_arcane_aura()
			"arcane_aura_tough":
				arcane_aura_convert_hp = 2
				_apply_arcane_aura()
			"precision_aura":
				precision_aura_bonus = 40.0
				_apply_precision_aura()
			"precision_aura_greater":
				precision_aura_bonus = 80.0
				_apply_precision_aura()
			"precision_aura_armor":
				archer_extra_hp = true
				_apply_archer_armor()
			"frost_arrows":
				is_frost_arrows_active = true
				projectile_slow_amount = 0.8
			"frost_arrows_deep":
				is_frost_arrows_active = true
				projectile_slow_amount = 0.6
			"frost_arrows_shatter":
				is_frost_arrows_active = true
				frost_arrows_bonus_damage = true
			"multishot":
				multishot_count = 2
			"multishot_triple":
				multishot_count = 3
			"multishot_pierce":
				multishot_pierce = true
				if multishot_count < 2:
					multishot_count = 2
			"purification":
				_start_purification_timer()
			"purification_more":
				purification_count = 5
				if not purification_timer:
					_start_purification_timer()
			"purification_fast":
				if purification_timer:
					purification_timer.wait_time = 7.0
				else:
					_start_purification_timer()
					purification_timer.wait_time = 7.0
			"guardian_angel":
				guardian_angel_max_uses = 1
				guardian_angel_spawn_count = 3
			"guardian_angel_more":
				guardian_angel_spawn_count = 6
				if guardian_angel_max_uses < 1:
					guardian_angel_max_uses = 1
			"guardian_angel_twice":
				guardian_angel_max_uses = 2
				if guardian_angel_spawn_count < 3:
					guardian_angel_spawn_count = 3
			"degen_aura":
				is_degen_aura_active = true
			"degen_aura_deep":
				is_degen_aura_active = true
				degen_aura_slow = 0.6
			"degen_aura_wide":
				is_degen_aura_active = true
				degen_aura_radius = 160.0


func clear_room_effects() -> void:
	is_frost_aura_active = false
	frost_aura_slow = 0.7
	frost_aura_radius = 150.0
	healing_ward_used_this_room = false
	healing_ward_revives_done = 0
	healing_ward_max_revives = 1
	healing_ward_revive_hp = 1
	blade_fury_multiplier = 1.5
	blade_fury_speed_bonus = false
	omnislash_damage = 5
	crystal_nova_slow_duration = 3.0
	arcane_aura_conversion_time = 2.0
	arcane_aura_convert_hp = 1
	precision_aura_bonus = 0.0
	archer_extra_hp = false
	is_frost_arrows_active = false
	projectile_slow_amount = 0.8
	frost_arrows_bonus_damage = false
	multishot_count = 1
	multishot_pierce = false
	purification_count = 3
	is_degen_aura_active = false
	degen_aura_slow = 0.75
	degen_aura_radius = 100.0

	if omnislash_timer:
		omnislash_timer.stop()
		omnislash_timer.queue_free()
		omnislash_timer = null

	if crystal_nova_timer:
		crystal_nova_timer.stop()
		crystal_nova_timer.queue_free()
		crystal_nova_timer = null

	if purification_timer:
		purification_timer.stop()
		purification_timer.queue_free()
		purification_timer = null


func _apply_blade_fury() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type"):
			if unit.get_unit_type() == "swordsman":
				unit.damage_multiplier = blade_fury_multiplier
				if blade_fury_speed_bonus and "attack_cooldown" in unit:
					pass


func _apply_precision_aura() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type"):
			if unit.get_unit_type() == "archer":
				unit.pursuit_range = 180.0 + precision_aura_bonus


func _apply_archer_armor() -> void:
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.has_method("get_unit_type"):
			if unit.get_unit_type() == "archer":
				unit.max_hp = 2
				unit.current_hp = 2


func _on_unit_registered(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	if not unit.has_method("get_unit_type"):
		return
	var utype: String = unit.get_unit_type()
	if RunManager.has_boon("blade_fury") and utype == "swordsman":
		unit.damage_multiplier = blade_fury_multiplier
	if precision_aura_bonus > 0.0 and utype == "archer":
		unit.pursuit_range = 180.0 + precision_aura_bonus
	if archer_extra_hp and utype == "archer":
		unit.max_hp = 2
		unit.current_hp = 2
	if arcane_aura_convert_hp > 1 and unit.is_reviving:
		unit.max_hp = arcane_aura_convert_hp
		unit.current_hp = arcane_aura_convert_hp


func _on_unit_died_with_info(died_unit_type: String, pos: Vector2) -> void:
	if not RunManager.has_boon("healing_ward"):
		return
	if healing_ward_revives_done >= healing_ward_max_revives:
		return
	if died_unit_type != "swordsman":
		return

	healing_ward_revives_done += 1
	_spawn_replacement_swordsman(pos)


func _spawn_replacement_swordsman(pos: Vector2) -> void:
	await get_tree().create_timer(0.5).timeout
	var scene: PackedScene = load("res://scenes/entities/units/Swordsman.tscn")
	var unit := scene.instantiate()
	unit.global_position = pos
	unit.is_reviving = true
	unit.modulate.a = 0.0

	var entities := get_tree().get_first_node_in_group("entities")
	if entities == null:
		var current_scene := get_tree().current_scene
		current_scene.get_node("Entities").add_child(unit)
	else:
		entities.add_child(unit)

	if healing_ward_revive_hp > 1:
		unit.max_hp = healing_ward_revive_hp
		unit.current_hp = healing_ward_revive_hp

	var tween := unit.create_tween()
	tween.tween_property(unit, "modulate:a", 1.0, 0.5)
	tween.tween_callback(unit.finish_revival)


func _start_omnislash_timer() -> void:
	if omnislash_timer:
		return
	omnislash_timer = Timer.new()
	omnislash_timer.wait_time = 15.0
	omnislash_timer.autostart = true
	omnislash_timer.timeout.connect(_on_omnislash_timeout)
	add_child(omnislash_timer)


func _on_omnislash_timeout() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var center := SwarmManager.get_swarm_center()
	var closest: Node2D = null
	var closest_dist := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := center.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	if closest and closest.has_method("take_hit"):
		closest.take_hit(omnislash_damage)
		_play_omnislash_particles(closest.global_position)


func _play_omnislash_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.843, 0.0, 1.0)
	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.global_position = pos
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)


func _start_crystal_nova_timer() -> void:
	if crystal_nova_timer:
		return
	crystal_nova_timer = Timer.new()
	crystal_nova_timer.wait_time = 20.0
	crystal_nova_timer.autostart = true
	crystal_nova_timer.timeout.connect(_on_crystal_nova_timeout)
	add_child(crystal_nova_timer)


func _on_crystal_nova_timeout() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and "slow_timer" in enemy:
			enemy.slow_timer = crystal_nova_slow_duration

	_play_crystal_nova_particles()


func _play_crystal_nova_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(0.0, 0.812, 1.0, 0.8)
	particles.process_material = mat
	particles.amount = 25
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	var center := SwarmManager.get_swarm_center()
	particles.global_position = center
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)


func _apply_arcane_aura() -> void:
	for neutral in get_tree().get_nodes_in_group("neutrals"):
		if is_instance_valid(neutral) and "conversion_time" in neutral:
			neutral.conversion_time = arcane_aura_conversion_time


func get_conversion_time() -> float:
	if RunManager.has_boon("arcane_aura") or RunManager.has_boon("arcane_aura_fast") or RunManager.has_boon("arcane_aura_tough"):
		return arcane_aura_conversion_time
	return 4.0


func _start_purification_timer() -> void:
	if purification_timer:
		return
	purification_timer = Timer.new()
	purification_timer.wait_time = 12.0
	purification_timer.autostart = true
	purification_timer.timeout.connect(_on_purification_timeout)
	add_child(purification_timer)


func _on_purification_timeout() -> void:
	var healed: int = 0
	for unit in SwarmManager.units:
		if healed >= purification_count:
			break
		if not is_instance_valid(unit):
			continue
		if unit.current_hp < unit.max_hp:
			unit.current_hp = unit.max_hp
			healed += 1
			_play_heal_particles(unit.global_position)


func _play_heal_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -15, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.843, 0.0, 0.8)
	particles.process_material = mat
	particles.amount = 8
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.global_position = pos
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)


func _on_unit_count_changed(new_count: int) -> void:
	if new_count > 0 or guardian_angel_max_uses <= 0:
		return
	if guardian_angel_uses >= guardian_angel_max_uses:
		return
	guardian_angel_uses += 1
	_trigger_guardian_angel()


func _trigger_guardian_angel() -> void:
	for i in guardian_angel_spawn_count:
		var scene: PackedScene = load("res://scenes/entities/units/Swordsman.tscn")
		var unit := scene.instantiate()
		unit.global_position = SwarmManager.get_swarm_center() + Vector2(randf_range(-20, 20), randf_range(-20, 20))

		var entities := get_tree().get_first_node_in_group("entities")
		if entities == null:
			get_tree().current_scene.get_node("Entities").add_child(unit)
		else:
			entities.add_child(unit)

	_play_guardian_angel_particles()


func _play_guardian_angel_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.98, 0.8, 1.0)
	particles.process_material = mat
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.global_position = SwarmManager.get_swarm_center()
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
