extends CharacterBody2D

@export var enemy_hp: int = 3
@export var move_speed: float = 20.0
@export var damage: int = 1
@export var enemy_color: Color = Color("#8B0000")

const GOLD_DROP_AMOUNT: int = 3
const DAMAGE_COOLDOWN: float = 0.3
const CONTACT_RAY_LENGTH: float = 14.0
const SEPARATION_RADIUS: float = 20.0
const SEPARATION_STRENGTH: float = 80.0

@onready var enemy_visual: ColorRect = $EnemyVisual
@onready var hitbox_area: Area2D = $HitboxArea
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var absorption_particles: GPUParticles2D = $AbsorptionParticles
@onready var damage_cooldown_timer: Timer = $DamageCooldownTimer

var is_dying: bool = false
var can_deal_damage: bool = true
var last_killed_unit_type: String = "swordsman"
var speed_multiplier: float = 1.0
var slow_timer: float = 0.0
var active_slow_zones: int = 0
var _zone_slow_value: float = 1.0
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_recalc_timer: float = 0.0
const PATH_RECALC_INTERVAL: float = 0.4
const PATH_RECALC_TARGET_DRIFT: float = 30.0
const PATH_ARRIVAL_THRESHOLD: float = 3.0
const WAYPOINT_THRESHOLD: float = 12.0
var last_pathed_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	enemy_visual.color = enemy_color
	add_to_group("enemies")
	hitbox_area.collision_mask = 1  # Detect swarm_units (layer 1)
	hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	damage_cooldown_timer.wait_time = DAMAGE_COOLDOWN
	damage_cooldown_timer.one_shot = true
	damage_cooldown_timer.timeout.connect(_on_damage_cooldown_timeout)
	_setup_death_particles()
	_setup_absorption_particles()
	path_recalc_timer = randf() * PATH_RECALC_INTERVAL


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


func _update_slow_state(delta: float) -> void:
	var base_multiplier: float = 1.0

	if slow_timer > 0.0:
		slow_timer -= delta
		if is_instance_valid(BoonManager):
			base_multiplier = BoonManager.projectile_slow_amount
		else:
			base_multiplier = 0.7
	elif is_instance_valid(BoonManager) and BoonManager.is_frost_aura_active:
		var nearest_dist := INF
		for unit in SwarmManager.units:
			if is_instance_valid(unit):
				var dist := global_position.distance_to(unit.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
		var frost_radius: float = BoonManager.frost_aura_radius
		if nearest_dist < frost_radius:
			base_multiplier = BoonManager.frost_aura_slow
	elif is_instance_valid(BoonManager) and BoonManager.is_degen_aura_active:
		var champions := get_tree().get_nodes_in_group("champions_omniknight")
		for champ in champions:
			if is_instance_valid(champ) and not champ.is_dying:
				var dist := global_position.distance_to(champ.global_position)
				if dist < BoonManager.degen_aura_radius:
					base_multiplier = BoonManager.degen_aura_slow
					break

	if active_slow_zones > 0:
		speed_multiplier = min(base_multiplier, _zone_slow_value)
	else:
		speed_multiplier = base_multiplier


func apply_slow(multiplier: float) -> void:
	active_slow_zones += 1
	_zone_slow_value = min(_zone_slow_value, multiplier)


func remove_slow() -> void:
	active_slow_zones -= 1
	if active_slow_zones <= 0:
		active_slow_zones = 0
		_zone_slow_value = 1.0


func apply_damage_tick(amount: float) -> void:
	take_hit(int(max(1, amount)))


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


func _follow_path_enemy(speed: float, separation: Vector2) -> bool:
	if current_path.is_empty() or path_index >= current_path.size():
		return false
	var waypoint := current_path[path_index]
	var dist := global_position.distance_to(waypoint)
	if dist <= WAYPOINT_THRESHOLD:
		path_index += 1
		if path_index >= current_path.size():
			return false
		waypoint = current_path[path_index]
	var dir := global_position.direction_to(waypoint)
	velocity = dir * speed + separation
	return true


func _advance_path_index_enemy() -> void:
	while path_index < current_path.size() - 1:
		var to_waypoint := current_path[path_index] - global_position
		var to_next := current_path[path_index + 1] - global_position
		if to_next.length() < to_waypoint.length():
			path_index += 1
		else:
			break


func _find_nearest_unit() -> Node2D:
	var closest: Node2D = null
	var closest_dist_sq: float = INF
	for unit in SwarmManager.units:
		if not is_instance_valid(unit):
			continue
		var dist_sq := global_position.distance_squared_to(unit.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = unit
	return closest


func _on_hitbox_area_entered(other_area: Area2D) -> void:
	if not can_deal_damage or is_dying:
		return

	var unit := other_area.get_parent()
	if unit.has_method("take_damage"):
		if unit.has_method("get_unit_type"):
			last_killed_unit_type = unit.get_unit_type()
		unit.take_damage(damage)
		var hit_damage: int = 1
		if unit.has_method("get_effective_damage"):
			hit_damage = unit.get_effective_damage()
		take_hit(hit_damage)
		can_deal_damage = false
		damage_cooldown_timer.start()


func _on_damage_cooldown_timeout() -> void:
	can_deal_damage = true
	if is_dying or not hitbox_area.monitoring:
		return
	for area in hitbox_area.get_overlapping_areas():
		_on_hitbox_area_entered(area)
		break


func take_hit(amount: int) -> void:
	enemy_hp -= amount
	if enemy_hp <= 0:
		die()


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("enemies")

	# TODO: Add enemy death sound effect
	death_particles.emitting = true
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(3.0, 0.15)
	enemy_visual.visible = false
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	SwarmManager.on_enemy_died(global_position)
	RunManager.on_enemy_killed()
	_drop_gold(GOLD_DROP_AMOUNT)

	if SwarmManager.roll_absorption():
		_play_absorption_effect()
		_spawn_absorbed_unit()

	await get_tree().create_timer(death_particles.lifetime + 0.5).timeout
	queue_free()


func _play_absorption_effect() -> void:
	# TODO: Add unit absorption sound effect
	absorption_particles.global_position = global_position
	absorption_particles.emitting = true
	SwarmManager.on_unit_absorbed(global_position)

	var target := SwarmManager.get_swarm_center()
	var tween := create_tween()
	tween.tween_property(
		absorption_particles, "global_position",
		target, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _spawn_absorbed_unit() -> void:
	var spawn_type: String = last_killed_unit_type
	if spawn_type.begins_with("champion_"):
		spawn_type = "swordsman"
	var scene_path: String = SwarmManager.get_unit_scene_path(spawn_type)
	var unit_scene: PackedScene = load(scene_path) as PackedScene
	if not unit_scene:
		return

	var new_unit: CharacterBody2D = unit_scene.instantiate() as CharacterBody2D
	new_unit.is_reviving = true
	new_unit.global_position = global_position
	new_unit.modulate.a = 0.0
	get_parent().call_deferred("add_child", new_unit)

	await get_tree().process_frame
	new_unit.hitbox_area.set_deferred("monitoring", false)
	new_unit.hitbox_area.set_deferred("monitorable", false)

	_play_revival_effect(new_unit)


func _play_revival_effect(unit: CharacterBody2D) -> void:
	var duration: float = SwarmManager.revival_duration
	var revival_particles := GPUParticles2D.new()
	revival_particles.top_level = true
	revival_particles.z_index = 1
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.843, 0.0, 0.6)
	revival_particles.process_material = mat
	revival_particles.amount = 8
	revival_particles.lifetime = duration
	revival_particles.one_shot = false
	revival_particles.emitting = true
	unit.add_child(revival_particles)

	var tween := unit.create_tween()
	tween.tween_property(unit, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(unit):
			return
		unit.finish_revival()
		if unit.unit_sprite:
			var flash := unit.create_tween()
			flash.tween_property(unit.unit_sprite, "modulate", Color(5, 5, 5, 1), 0.1)
			flash.tween_property(unit.unit_sprite, "modulate", Color.WHITE, 0.1)
		else:
			var unit_visual_node: ColorRect = unit.get_node("UnitVisual")
			if unit_visual_node:
				var flash := unit.create_tween()
				flash.tween_property(unit_visual_node, "color", Color.WHITE, 0.1)
				flash.tween_property(unit_visual_node, "color", unit.unit_color, 0.1)
		if is_instance_valid(revival_particles):
			revival_particles.emitting = false
			var cleanup_tween := unit.create_tween()
			cleanup_tween.tween_interval(revival_particles.lifetime)
			cleanup_tween.tween_callback(revival_particles.queue_free)
	)


func _setup_death_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.545, 0.0, 0.0, 1.0)
	death_particles.process_material = mat
	death_particles.amount = 15
	death_particles.lifetime = 0.5
	death_particles.one_shot = true
	death_particles.explosiveness = 1.0
	death_particles.emitting = false


func _drop_gold(amount: int) -> void:
	var container := Node2D.new()
	container.global_position = global_position
	get_parent().add_child(container)

	# TODO: Replace with coin art asset
	var coin := ColorRect.new()
	coin.size = Vector2(6, 6)
	coin.position = Vector2(-3, -3)
	coin.color = Color("#FFD700")
	container.add_child(coin)

	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_color_override("font_color", Color("#FFD700"))
	popup.add_theme_font_size_override("font_size", 16)
	popup.position = Vector2(-10, -20)
	container.add_child(popup)

	var popup_tw := popup.create_tween()
	popup_tw.set_parallel(true)
	popup_tw.tween_property(popup, "position:y", popup.position.y - 30, 0.8)
	popup_tw.tween_property(popup, "modulate:a", 0.0, 0.8)

	var sparkle := GPUParticles2D.new()
	var smat := ParticleProcessMaterial.new()
	smat.direction = Vector3(0, -1, 0)
	smat.spread = 90.0
	smat.initial_velocity_min = 10.0
	smat.initial_velocity_max = 20.0
	smat.gravity = Vector3(0, 10, 0)
	smat.scale_min = 0.5
	smat.scale_max = 1.0
	smat.color = Color(1.0, 0.843, 0.0, 0.8)
	sparkle.process_material = smat
	sparkle.amount = 4
	sparkle.lifetime = 0.3
	sparkle.one_shot = true
	sparkle.explosiveness = 1.0
	sparkle.emitting = true
	container.add_child(sparkle)

	var tw := container.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(container, "scale", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(container, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(container):
			RunManager.add_gold(amount)
			container.queue_free()
	)


func _setup_absorption_particles() -> void:
	absorption_particles.top_level = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.843, 0.0, 0.8)
	absorption_particles.process_material = mat
	absorption_particles.amount = 12
	absorption_particles.lifetime = 0.6
	absorption_particles.one_shot = true
	absorption_particles.emitting = false
