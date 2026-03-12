extends "res://scenes/entities/enemies/EnemyBase.gd"

signal hound_died(hound: Node)

const HOUND_SPEED: float = 180.0
const HOUND_HP: int = 2
const HOUND_DAMAGE: int = 8
const HOUND_ATTACK_COOLDOWN: float = 0.8
const HOUND_PATH_RECALC: float = 0.2
const HOUND_GOLD_DROP: int = 5

var attack_timer: float = 0.0
var trail_particles: GPUParticles2D = null


func _ready() -> void:
	super()
	_create_trail_particles()
	attack_timer = HOUND_ATTACK_COOLDOWN


func _create_trail_particles() -> void:
	trail_particles = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.545, 0.0, 0.0, 0.5)
	trail_particles.process_material = mat
	trail_particles.amount = 6
	trail_particles.lifetime = 0.3
	trail_particles.emitting = false
	add_child(trail_particles)


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
		trail_particles.emitting = false
		return

	var target := _find_champion_target()
	if target == null:
		target = _find_nearest_unit()
	if target == null:
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		trail_particles.emitting = false
		return

	var direction := global_position.direction_to(target.global_position)
	if _is_target_in_contact(direction, 1):
		attack_timer -= delta
		if attack_timer <= 0.0:
			_deal_contact_damage(target)
			attack_timer = HOUND_ATTACK_COOLDOWN
		velocity = separation
	else:
		path_recalc_timer -= delta
		var target_drift := target.global_position.distance_to(last_pathed_target)
		if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
			current_path = Pathfinder.find_path(global_position, target.global_position)
			path_index = 0
			_advance_path_index_enemy()
			last_pathed_target = target.global_position
			path_recalc_timer = HOUND_PATH_RECALC
		if not _follow_path_enemy(effective_speed, separation):
			if Pathfinder.has_line_of_sight(global_position, target.global_position):
				velocity = direction * effective_speed + separation
			else:
				current_path = Pathfinder.find_path(global_position, target.global_position)
				path_index = 0
				_advance_path_index_enemy()
				if not _follow_path_enemy(effective_speed, separation):
					velocity = direction * effective_speed + separation
	move_and_slide()

	trail_particles.emitting = velocity.length() > 10.0


func _deal_contact_damage(unit: Node2D) -> void:
	if unit.has_method("take_damage"):
		unit.take_damage(damage)


func _find_champion_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist_sq: float = INF
	for unit in SwarmManager.units:
		if not is_instance_valid(unit):
			continue
		if not unit.has_method("get_unit_type"):
			continue
		if not unit.get_unit_type().begins_with("champion_"):
			continue
		var dist_sq := global_position.distance_squared_to(unit.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = unit
	return closest


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("enemies")

	hound_died.emit(self)

	if trail_particles:
		trail_particles.emitting = false

	death_particles.emitting = true
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(3.0, 0.15)
	enemy_visual.visible = false
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	SwarmManager.on_enemy_died(global_position)
	RunManager.on_enemy_killed()
	_drop_gold(HOUND_GOLD_DROP)

	await get_tree().create_timer(death_particles.lifetime + 0.5).timeout
	queue_free()
