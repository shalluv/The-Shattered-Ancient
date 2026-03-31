extends "res://scenes/entities/units/UnitBase.gd"

const ATTACK_RANGE: float = 170.0
var attack_cooldown: float = 2.8

var ProjectileScene := preload("res://scenes/entities/units/Projectile.tscn")
var attack_timer: float = 0.0
var volley_mode: bool = false


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
					velocity = direction * move_speed * speed_multiplier + separation
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

	if not volley_mode:
		attack_timer -= delta
		if attack_timer <= 0.0:
			var enemy := _find_nearest_enemy_in_range()
			if enemy != null:
				_fire_projectile(enemy)
				attack_timer = attack_cooldown

	velocity = separation
	if velocity.length_squared() > 0.1:
		move_and_slide()


func volley_fire() -> void:
	if is_dying or is_reviving:
		return
	var enemy := _find_nearest_enemy_in_range()
	if enemy != null:
		_fire_projectile(enemy)
		attack_timer = attack_cooldown
		_play_volley_flash()


func _find_nearest_enemy_in_range() -> Node2D:
	var priority := SwarmManager.get_priority_target()
	if priority != null:
		var dist_sq := global_position.distance_squared_to(priority.global_position)
		if dist_sq < pursuit_range * pursuit_range:
			return priority

	var closest: Node2D = null
	var closest_dist_sq: float = pursuit_range * pursuit_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = enemy
	return closest


func _fire_projectile(target: Node2D) -> void:
	if unit_sprite:
		var aim_dir := global_position.direction_to(target.global_position)
		unit_sprite.rotation = aim_dir.angle() + PI / 2.0
	var base_dir := global_position.direction_to(target.global_position)
	var count: int = 1
	if is_instance_valid(BoonManager):
		count = BoonManager.multishot_count

	var spread_angle := deg_to_rad(10.0)
	for i in count:
		var dir := base_dir
		if count > 1:
			var offset_angle := (-spread_angle * (count - 1) / 2.0) + spread_angle * i
			dir = base_dir.rotated(offset_angle)

		var projectile := ProjectileScene.instantiate()
		projectile.global_position = global_position
		projectile.direction = dir

		if is_instance_valid(BoonManager) and BoonManager.is_frost_arrows_active:
			projectile.applies_slow = true
			projectile.slow_duration = 2.0

		if is_instance_valid(BoonManager) and BoonManager.multishot_pierce:
			projectile.pierces = true

		get_parent().add_child(projectile)


func _play_volley_flash() -> void:
	var flash := create_tween()
	flash.tween_property(unit_visual, "color", Color(1.0, 0.95, 0.6), 0.05)
	flash.tween_property(unit_visual, "color", unit_color, 0.15)
	var burst := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = Color("#FFD700")
	burst.process_material = mat
	burst.amount = 6
	burst.lifetime = 0.3
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	add_child(burst)
	burst.finished.connect(burst.queue_free)
