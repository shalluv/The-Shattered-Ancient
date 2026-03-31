extends "res://scenes/entities/units/UnitBase.gd"

const ATTACK_RANGE: float = 140.0
const ATTACK_COOLDOWN: float = 4.0
const BASE_AOE_RADIUS: float = 60.0

var aoe_radius: float = BASE_AOE_RADIUS
var MageProjectileScene := preload("res://scenes/entities/units/MageProjectile.tscn")
var attack_timer: float = 0.0
var surge_visual: Polygon2D = null
var surge_particles: GPUParticles2D = null


func _physics_process(delta: float) -> void:
	if is_dying or is_reviving:
		return

	if unit_sprite and velocity.length_squared() > 1.0:
		unit_sprite.rotation = velocity.angle() + PI / 2.0

	var separation := _calculate_separation_force()

	if has_move_target:
		var distance := global_position.distance_to(target_position)
		if distance > ARRIVAL_THRESHOLD:
			if not _follow_path(separation):
				if Pathfinder.has_line_of_sight(global_position, target_position):
					var direction := global_position.direction_to(target_position)
					velocity = direction * move_speed + separation
				else:
					current_path = Pathfinder.find_path(global_position, target_position)
					path_index = 0
					_advance_path_index()
					if not _follow_path(separation):
						velocity = separation
			move_and_slide()
		else:
			global_position = target_position
			velocity = separation
			has_move_target = false
			current_path = PackedVector2Array()
			if velocity.length_squared() > 0.1:
				move_and_slide()
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		var target := _find_best_cluster_target()
		if target != null:
			_fire_mage_projectile(target)
			attack_timer = ATTACK_COOLDOWN

	velocity = separation
	if velocity.length_squared() > 0.1:
		move_and_slide()


func _find_best_cluster_target() -> Node2D:
	var priority := SwarmManager.get_priority_target()
	if priority != null:
		var dist_sq := global_position.distance_squared_to(priority.global_position)
		if dist_sq < ATTACK_RANGE * ATTACK_RANGE:
			return priority

	var best_target: Node2D = null
	var best_score: int = 0
	var best_dist_sq: float = INF
	var range_sq := ATTACK_RANGE * ATTACK_RANGE
	var aoe_sq := aoe_radius * aoe_radius

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq > range_sq:
			continue
		var cluster_count: int = 0
		for other in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(other):
				continue
			if enemy.global_position.distance_squared_to(other.global_position) <= aoe_sq:
				cluster_count += 1
		if cluster_count > best_score or (cluster_count == best_score and dist_sq < best_dist_sq):
			best_score = cluster_count
			best_dist_sq = dist_sq
			best_target = enemy

	return best_target


func _fire_mage_projectile(target: Node2D) -> void:
	if unit_sprite:
		var aim_dir := global_position.direction_to(target.global_position)
		unit_sprite.rotation = aim_dir.angle() + PI / 2.0
	var projectile := MageProjectileScene.instantiate()
	projectile.global_position = global_position
	projectile.target_position = target.global_position
	projectile.aoe_radius = aoe_radius
	get_parent().add_child(projectile)


func apply_arcane_surge(multiplier: float) -> void:
	aoe_radius = BASE_AOE_RADIUS * multiplier
	if surge_visual == null:
		# TODO: Replace with arcane surge art asset
		surge_visual = Polygon2D.new()
		var points: PackedVector2Array = PackedVector2Array()
		for i in 24:
			var angle := float(i) / 24.0 * TAU
			points.append(Vector2(cos(angle), sin(angle)) * aoe_radius)
		surge_visual.polygon = points
		surge_visual.color = Color(0.608, 0.349, 0.714, 0.1)
		surge_visual.z_index = 0
		add_child(surge_visual)
		move_child(surge_visual, 0)
	else:
		var points: PackedVector2Array = PackedVector2Array()
		for i in 24:
			var angle := float(i) / 24.0 * TAU
			points.append(Vector2(cos(angle), sin(angle)) * aoe_radius)
		surge_visual.polygon = points
		surge_visual.visible = true
	if surge_particles == null:
		surge_particles = GPUParticles2D.new()
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mat.emission_ring_radius = aoe_radius * 0.5
		mat.emission_ring_inner_radius = 0.0
		mat.emission_ring_height = 0.0
		mat.emission_ring_axis = Vector3(0, 0, 1)
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 5.0
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.5
		mat.scale_max = 1.0
		mat.color = Color(0.608, 0.349, 0.714, 0.5)
		surge_particles.process_material = mat
		surge_particles.amount = 8
		surge_particles.lifetime = 1.5
		add_child(surge_particles)
	else:
		surge_particles.emitting = true


func remove_arcane_surge() -> void:
	aoe_radius = BASE_AOE_RADIUS
	if surge_visual:
		surge_visual.visible = false
	if surge_particles:
		surge_particles.emitting = false
