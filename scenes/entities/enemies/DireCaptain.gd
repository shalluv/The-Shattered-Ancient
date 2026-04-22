extends "res://scenes/entities/enemies/EnemyBase.gd"

signal captain_defeated

const CAPTAIN_HP: int = 12
const ENRAGE_HP: int = 6
const ATTACK_COOLDOWN: float = 2.4
const ENRAGE_SPEED_MULT: float = 1.5
const ENRAGE_ATTACK_MULT: float = 1.5
const CAPTAIN_GOLD_DROP: int = 15

var attack_timer: float = 0.0
var is_enraged: bool = false
var hp_bar: ProgressBar = null
var aura_particles: GPUParticles2D = null

var DireGruntScene := preload("res://scenes/entities/enemies/DireGrunt.tscn")


func _ready() -> void:
	super()
	_create_hp_bar()
	_create_aura_particles()
	attack_timer = ATTACK_COOLDOWN


func _create_hp_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = CAPTAIN_HP
	hp_bar.value = CAPTAIN_HP
	hp_bar.size = Vector2(60, 6)
	hp_bar.position = Vector2(-30, -30)
	hp_bar.show_percentage = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.545, 0.0, 0.0, 1.0)
	hp_bar.add_theme_stylebox_override("fill", style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	hp_bar.add_theme_stylebox_override("background", bg_style)

	add_child(hp_bar)


func _create_aura_particles() -> void:
	aura_particles = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 22.0
	mat.emission_ring_inner_radius = 14.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.8
	mat.color = Color(0.545, 0.0, 0.0, 0.6)
	aura_particles.process_material = mat
	aura_particles.amount = 10
	aura_particles.lifetime = 1.2
	aura_particles.emitting = true
	add_child(aura_particles)


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_update_slow_state(delta)
	var effective_speed := move_speed * speed_multiplier
	var separation := _calculate_separation_force()

	if SwarmManager.units.is_empty():
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

	var nearest_unit := _find_nearest_unit()
	if nearest_unit == null:
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

	var direction := global_position.direction_to(nearest_unit.global_position)
	if _is_target_in_contact(direction, 1):
		attack_timer -= delta
		if attack_timer <= 0.0:
			_deal_contact_damage(nearest_unit)
			attack_timer = ATTACK_COOLDOWN
		velocity = separation
	else:
		path_recalc_timer -= delta
		var target_drift := nearest_unit.global_position.distance_to(last_pathed_target)
		if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
			current_path = Pathfinder.find_path(global_position, nearest_unit.global_position)
			path_index = 0
			_advance_path_index_enemy()
			last_pathed_target = nearest_unit.global_position
			path_recalc_timer = PATH_RECALC_INTERVAL
		if not _follow_path_enemy(effective_speed, separation):
			if Pathfinder.has_line_of_sight(global_position, nearest_unit.global_position):
				velocity = direction * effective_speed + separation
			else:
				current_path = Pathfinder.find_path(global_position, nearest_unit.global_position)
				path_index = 0
				_advance_path_index_enemy()
				if not _follow_path_enemy(effective_speed, separation):
					velocity = direction * effective_speed + separation
	move_and_slide()


func _deal_contact_damage(unit: Node2D) -> void:
	if unit.has_method("take_damage"):
		unit.take_damage(damage)


func take_hit(amount: int) -> void:
	super(amount)
	if hp_bar:
		hp_bar.value = enemy_hp
	if enemy_hp > 0 and enemy_hp <= ENRAGE_HP and not is_enraged:
		_trigger_enrage()


func _trigger_enrage() -> void:
	is_enraged = true

	var tween := create_tween()
	tween.tween_property(enemy_visual, "color", Color(1.0, 0.0, 0.0), 0.3)

	move_speed *= ENRAGE_SPEED_MULT

	for i in 2:
		var grunt := DireGruntScene.instantiate()
		var offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		grunt.global_position = global_position + offset
		get_parent().call_deferred("add_child", grunt)
	RunManager.add_enemies(2)

	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(4.0, 0.5)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("enemies")

	AudioManager.play_sfx("enemy_death")
	death_particles.emitting = true
	enemy_visual.visible = false
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	if aura_particles:
		aura_particles.emitting = false
	if hp_bar:
		hp_bar.visible = false

	SwarmManager.on_enemy_died(global_position)
	RunManager.on_enemy_killed()
	_drop_gold(CAPTAIN_GOLD_DROP)

	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(4.0, 0.5)

	await get_tree().create_timer(death_particles.lifetime + 0.3).timeout
	captain_defeated.emit()
	queue_free()
