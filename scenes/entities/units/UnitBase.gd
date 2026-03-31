extends CharacterBody2D

const MOVE_LERP_WEIGHT: float = 6.0
const ARRIVAL_THRESHOLD: float = 3.0
const WAYPOINT_THRESHOLD: float = 12.0
const SEPARATION_RADIUS: float = 26.0
const SEPARATION_STRENGTH: float = 100.0
const CONTACT_RAY_LENGTH: float = 18.0
const PURSUIT_STOP_DISTANCE: float = 25.0

@export var unit_type: String = "swordsman"
@export var unit_color: Color = Color("#FFD700")
@export var max_hp: int = 1
@export var damage: int = 1
@export var move_speed: float = 100.0
@export var pursuit_range: float = 75.0

@onready var unit_visual: ColorRect = $UnitVisual
@onready var hitbox_area: Area2D = $HitboxArea
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var selection_indicator: ColorRect = $SelectionIndicator

var current_hp: int = 1
var is_dying: bool = false
var is_reviving: bool = false
var shield_charge: int = 0
var shield_visual: ColorRect = null
var unit_sprite: Sprite2D = null
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var active_slow_zones: int = 0
var _current_slow_value: float = 1.0
var target_position: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var is_selected: bool = false
var pursuit_target: Node2D = null
var pre_pursuit_position: Vector2 = Vector2.ZERO
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_recalc_timer: float = 0.0
const PATH_RECALC_INTERVAL: float = 0.3
const PATH_RECALC_TARGET_DRIFT: float = 30.0
var last_pathed_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	current_hp = max_hp
	var sprite_node := unit_visual.get_node_or_null("Sprite2D")
	if sprite_node is Sprite2D:
		unit_sprite = sprite_node
		unit_visual.color = Color(0, 0, 0, 0)
	else:
		unit_visual.color = unit_color
	if is_reviving:
		SwarmManager.register_reviving_unit(self)
	else:
		SwarmManager.register_unit(self)
	_setup_death_particles()
	path_recalc_timer = randf() * PATH_RECALC_INTERVAL


func _exit_tree() -> void:
	if is_reviving:
		SwarmManager.unregister_reviving_unit(self)
	elif not is_dying:
		SwarmManager.unregister_unit(self)


func _physics_process(delta: float) -> void:
	if is_dying or is_reviving:
		return
	if unit_sprite and velocity.length_squared() > 1.0:
		unit_sprite.rotation = velocity.angle() + PI / 2.0

	var separation := _calculate_separation_force()

	if pursuit_target != null:
		if not is_instance_valid(pursuit_target) or pursuit_target.is_dying:
			pursuit_target = null
			target_position = pre_pursuit_position
			has_move_target = true
			current_path = Pathfinder.find_path(global_position, target_position)
			path_index = 0
			_advance_path_index()
		else:
			var direction := global_position.direction_to(pursuit_target.global_position)
			var dist_to_target := global_position.distance_to(pursuit_target.global_position)
			if dist_to_target < PURSUIT_STOP_DISTANCE or _is_target_in_contact(direction, 2):
				velocity = separation
			else:
				path_recalc_timer -= delta
				var target_drift := pursuit_target.global_position.distance_to(last_pathed_target)
				if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
					current_path = Pathfinder.find_path(global_position, pursuit_target.global_position)
					path_index = 0
					_advance_path_index()
					last_pathed_target = pursuit_target.global_position
					path_recalc_timer = PATH_RECALC_INTERVAL
				if not _follow_path(separation):
					if Pathfinder.has_line_of_sight(global_position, pursuit_target.global_position):
						velocity = direction * move_speed * speed_multiplier + separation
					else:
						current_path = Pathfinder.find_path(global_position, pursuit_target.global_position)
						path_index = 0
						_advance_path_index()
						if not _follow_path(separation):
							velocity = direction * move_speed * speed_multiplier + separation
			move_and_slide()
			return

	if not has_move_target:
		var enemy := _find_nearest_enemy_in_range()
		if enemy != null:
			pre_pursuit_position = global_position
			pursuit_target = enemy
			var direction := global_position.direction_to(enemy.global_position)
			var dist_to_enemy := global_position.distance_to(enemy.global_position)
			if dist_to_enemy < PURSUIT_STOP_DISTANCE or _is_target_in_contact(direction, 2):
				velocity = separation
			else:
				if Pathfinder.has_line_of_sight(global_position, enemy.global_position):
					velocity = direction * move_speed * speed_multiplier + separation
				else:
					current_path = Pathfinder.find_path(global_position, enemy.global_position)
					path_index = 0
					_advance_path_index()
					if not _follow_path(separation):
						velocity = direction * move_speed * speed_multiplier + separation
			move_and_slide()
			return
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

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


func _calculate_separation_force() -> Vector2:
	var force := Vector2.ZERO
	var all_entities: Array = []
	all_entities.append_array(SwarmManager.units)
	all_entities.append_array(get_tree().get_nodes_in_group("enemies"))
	all_entities.append_array(get_tree().get_nodes_in_group("neutrals"))
	for entity in all_entities:
		if entity == self or not is_instance_valid(entity):
			continue
		var offset: Vector2 = global_position - entity.global_position
		var dist: float = offset.length()
		if dist > 0.0 and dist < SEPARATION_RADIUS:
			var strength: float = (1.0 - dist / SEPARATION_RADIUS) * SEPARATION_STRENGTH
			force += offset.normalized() * strength
	return force


func _is_target_in_contact(direction: Vector2, target_layer_mask: int) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * CONTACT_RAY_LENGTH,
		target_layer_mask,
		[get_rid()]
	)
	var result := space_state.intersect_ray(query)
	return not result.is_empty()


func get_unit_type() -> String:
	return unit_type


func get_effective_damage() -> int:
	return int(damage * damage_multiplier)


func select() -> void:
	is_selected = true
	selection_indicator.visible = true


func deselect() -> void:
	is_selected = false
	selection_indicator.visible = false


func finish_revival() -> void:
	is_reviving = false
	SwarmManager.unregister_reviving_unit(self)
	SwarmManager.register_unit(self)
	hitbox_area.set_deferred("monitoring", true)
	hitbox_area.set_deferred("monitorable", true)


func command_move(pos: Vector2) -> void:
	if is_reviving:
		return
	pursuit_target = null
	target_position = pos
	has_move_target = true
	current_path = Pathfinder.find_path(global_position, pos)
	path_index = 0
	_advance_path_index()
	last_pathed_target = pos


func _find_nearest_enemy_in_range() -> Node2D:
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


func apply_shield() -> void:
	shield_charge = 1
	if shield_visual == null:
		# TODO: Replace with shield art asset
		shield_visual = ColorRect.new()
		shield_visual.size = Vector2(14, 14)
		shield_visual.position = Vector2(-7, -7)
		shield_visual.color = Color(1.0, 1.0, 1.0, 0.3)
		shield_visual.z_index = 1
		add_child(shield_visual)
		var shield_particles := GPUParticles2D.new()
		shield_particles.name = "ShieldGrantParticles"
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 10.0
		mat.initial_velocity_max = 20.0
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.5
		mat.scale_max = 1.0
		mat.color = Color.WHITE
		shield_particles.process_material = mat
		shield_particles.amount = 8
		shield_particles.lifetime = 0.3
		shield_particles.one_shot = true
		shield_particles.explosiveness = 1.0
		shield_particles.emitting = true
		add_child(shield_particles)
		shield_particles.finished.connect(shield_particles.queue_free)
	shield_visual.visible = true


func consume_shield() -> bool:
	if shield_charge > 0:
		shield_charge -= 1
		if shield_visual:
			shield_visual.visible = false
		var burst := GPUParticles2D.new()
		burst.name = "ShieldConsumeParticles"
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 20.0
		mat.initial_velocity_max = 40.0
		mat.gravity = Vector3(0, 30, 0)
		mat.scale_min = 1.0
		mat.scale_max = 2.0
		mat.color = Color.WHITE
		burst.process_material = mat
		burst.amount = 10
		burst.lifetime = 0.4
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.emitting = true
		add_child(burst)
		burst.finished.connect(burst.queue_free)
		return true
	return false


func take_damage(amount: int) -> void:
	if consume_shield():
		return
	if is_reviving:
		return
	current_hp -= amount
	if current_hp <= 0:
		die()


func die() -> void:
	if is_dying:
		return
	is_dying = true
	SwarmManager.unit_died_with_info.emit(unit_type, global_position)
	SwarmManager.unregister_unit(self)

	# TODO: Add unit death sound effect
	death_particles.emitting = true
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(3.0, 0.15)
	var flash_tween := create_tween()
	if unit_sprite:
		flash_tween.tween_property(unit_sprite, "modulate", Color(5, 5, 5, 1), 0.05)
	else:
		flash_tween.tween_property(unit_visual, "color", Color.WHITE, 0.05)
	flash_tween.tween_callback(func() -> void:
		unit_visual.visible = false
	)
	selection_indicator.visible = false
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	if not is_inside_tree():
		queue_free()
		return
	await get_tree().create_timer(death_particles.lifetime).timeout
	queue_free()


func _follow_path(separation: Vector2) -> bool:
	if current_path.is_empty() or path_index >= current_path.size():
		return false
	var waypoint := current_path[path_index]
	var dist := global_position.distance_to(waypoint)
	if dist <= WAYPOINT_THRESHOLD:
		path_index += 1
		if path_index >= current_path.size():
			return false
		waypoint = current_path[path_index]
	var direction := global_position.direction_to(waypoint)
	velocity = direction * move_speed * speed_multiplier + separation
	return true


func _advance_path_index() -> void:
	while path_index < current_path.size() - 1:
		var to_waypoint := current_path[path_index] - global_position
		var to_next := current_path[path_index + 1] - global_position
		if to_next.length() < to_waypoint.length():
			path_index += 1
		else:
			break


func apply_slow(multiplier: float) -> void:
	active_slow_zones += 1
	_current_slow_value = min(_current_slow_value, multiplier)
	speed_multiplier = _current_slow_value


func remove_slow() -> void:
	active_slow_zones -= 1
	if active_slow_zones <= 0:
		active_slow_zones = 0
		speed_multiplier = 1.0
		_current_slow_value = 1.0


func apply_damage_tick(amount: float) -> void:
	take_damage(int(max(1, amount)))


func _setup_death_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 50, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = unit_color
	death_particles.process_material = mat
	death_particles.amount = 8
	death_particles.lifetime = 0.4
	death_particles.one_shot = true
	death_particles.explosiveness = 1.0
	death_particles.emitting = false
