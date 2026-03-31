extends "res://scenes/entities/enemies/EnemyBase.gd"

const AURA_CONVERT_RADIUS: float = 130.0
const AURA_CONVERT_TIME: float = 4.0
const AURA_SEGMENTS: int = 32
const PRIEST_COLOR: Color = Color("#4B0082")

var DireGruntScene := preload("res://scenes/entities/enemies/DireGrunt.tscn")

var neutrals_in_aura: Dictionary = {}
var aura_ring: Polygon2D = null
var aura_glitter: GPUParticles2D = null


func _ready() -> void:
	enemy_hp = 3
	move_speed = 15.0
	damage = 0
	enemy_color = PRIEST_COLOR
	super._ready()
	enemy_visual.color = PRIEST_COLOR
	add_to_group("dire_priests")
	SwarmManager.register_priority_target(self)
	_create_aura_visual()
	_create_aura_glitter()


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_update_slow_state(delta)
	var effective_speed := move_speed * speed_multiplier
	var separation := _calculate_separation_force()

	var nearest_neutral := _find_nearest_neutral()
	if nearest_neutral != null:
		var direction := global_position.direction_to(nearest_neutral.global_position)
		path_recalc_timer -= delta
		var target_drift := nearest_neutral.global_position.distance_to(last_pathed_target)
		if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
			current_path = Pathfinder.find_path(global_position, nearest_neutral.global_position)
			path_index = 0
			_advance_path_index_enemy()
			last_pathed_target = nearest_neutral.global_position
			path_recalc_timer = PATH_RECALC_INTERVAL
		if not _follow_path_enemy(effective_speed, separation):
			if Pathfinder.has_line_of_sight(global_position, nearest_neutral.global_position):
				velocity = direction * effective_speed + separation
			else:
				current_path = Pathfinder.find_path(global_position, nearest_neutral.global_position)
				path_index = 0
				_advance_path_index_enemy()
				if not _follow_path_enemy(effective_speed, separation):
					velocity = direction * effective_speed + separation
	else:
		velocity = separation

	if velocity.length_squared() > 0.1:
		move_and_slide()

	_scan_neutrals(delta)


func _find_nearest_neutral() -> Node2D:
	var closest: Node2D = null
	var closest_dist_sq: float = INF
	for neutral in get_tree().get_nodes_in_group("neutrals"):
		if not is_instance_valid(neutral):
			continue
		var dist_sq := global_position.distance_squared_to(neutral.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = neutral
	return closest


func _scan_neutrals(delta: float) -> void:
	var current_neutrals: Array[Node2D] = []
	for neutral in get_tree().get_nodes_in_group("neutrals"):
		if not is_instance_valid(neutral):
			continue
		var dist := global_position.distance_to(neutral.global_position)
		if dist < AURA_CONVERT_RADIUS:
			current_neutrals.append(neutral)

	var to_remove: Array = []
	for n in neutrals_in_aura:
		if not is_instance_valid(n) or n not in current_neutrals:
			to_remove.append(n)
	for n in to_remove:
		neutrals_in_aura.erase(n)

	for neutral in current_neutrals:
		if neutral not in neutrals_in_aura:
			neutrals_in_aura[neutral] = 0.0
		neutrals_in_aura[neutral] += delta
		if neutrals_in_aura[neutral] >= AURA_CONVERT_TIME:
			_convert_neutral(neutral)
			neutrals_in_aura.erase(neutral)


func _convert_neutral(neutral: Node2D) -> void:
	if not is_instance_valid(neutral):
		return
	var pos := neutral.global_position
	neutral.queue_free()

	var grunt := DireGruntScene.instantiate()
	grunt.global_position = pos
	get_parent().add_child(grunt)
	RunManager.add_enemies(1)

	_play_conversion_particles(pos)


func _play_conversion_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.294, 0.0, 0.51, 1.0)
	particles.process_material = mat
	particles.amount = 10
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.global_position = pos
	get_parent().add_child(particles)
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)


func _create_aura_visual() -> void:
	aura_ring = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in AURA_SEGMENTS:
		var angle := float(i) / float(AURA_SEGMENTS) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * AURA_CONVERT_RADIUS)
	aura_ring.polygon = points
	aura_ring.color = Color(0.294, 0.0, 0.51, 0.05)
	aura_ring.z_index = -1
	add_child(aura_ring)
	move_child(aura_ring, 0)


func _create_aura_glitter() -> void:
	aura_glitter = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = AURA_CONVERT_RADIUS
	mat.emission_ring_inner_radius = 0.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.294, 0.0, 0.51, 0.6))
	gradient.set_color(1, Color(0.294, 0.0, 0.51, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	aura_glitter.process_material = mat
	aura_glitter.amount = 18
	aura_glitter.lifetime = 2.0
	aura_glitter.z_index = 0
	add_child(aura_glitter)
	move_child(aura_glitter, 0)


func die() -> void:
	SwarmManager.unregister_priority_target(self)
	if aura_ring:
		aura_ring.visible = false
	if aura_glitter:
		aura_glitter.emitting = false
	super.die()
