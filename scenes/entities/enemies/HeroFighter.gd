extends CharacterBody2D

signal hero_defeated

@export var hero_id: String = ""
@export var is_clone: bool = false
@export var hero_hp: int = 30
@export var hero_max_hp: int = 30
@export var move_speed: float = 60.0
@export var melee_damage: int = 10
@export var attack_cooldown: float = 0.6
@export var ability_cooldown: float = 8.0
@export var threshold_percent: float = 0.3

const SEPARATION_RADIUS: float = 20.0
const SEPARATION_STRENGTH: float = 80.0
const CONTACT_RAY_LENGTH: float = 14.0
const PATH_RECALC_INTERVAL: float = 0.4
const PATH_RECALC_TARGET_DRIFT: float = 30.0
const WAYPOINT_THRESHOLD: float = 12.0

@onready var enemy_visual: ColorRect = $EnemyVisual
@onready var hitbox_area: Area2D = $HitboxArea
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var damage_cooldown_timer: Timer = $DamageCooldownTimer

var is_dying: bool = false
var can_deal_damage: bool = true
var threshold_triggered: bool = false
var ability_timer: float = 0.0
var speed_multiplier: float = 1.0
var slow_timer: float = 0.0
var active_slow_zones: int = 0
var _zone_slow_value: float = 1.0
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_recalc_timer: float = 0.0
var last_pathed_target: Vector2 = Vector2.ZERO
var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null
var name_label: Label = null
var physics_enabled: bool = true


func _ready() -> void:
	hero_max_hp = hero_hp
	enemy_visual.color = _get_hero_color()
	add_to_group("enemies")
	hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	damage_cooldown_timer.wait_time = attack_cooldown
	damage_cooldown_timer.one_shot = true
	damage_cooldown_timer.timeout.connect(_on_damage_cooldown_timeout)
	_setup_death_particles()
	_create_hp_bar()
	path_recalc_timer = randf() * PATH_RECALC_INTERVAL
	ability_timer = ability_cooldown

	if is_clone:
		modulate = Color(1.0, 0.6, 0.6, 1.0)
		_create_clone_label()


func _physics_process(delta: float) -> void:
	if is_dying or not physics_enabled:
		return

	_update_slow_state(delta)
	_update_ability_timer(delta)
	_update_hp_bar()

	var effective_speed := move_speed * speed_multiplier
	var separation := _calculate_separation_force()

	_hero_movement(delta, effective_speed, separation)
	move_and_slide()


func _hero_movement(_delta: float, effective_speed: float, separation: Vector2) -> void:
	if SwarmManager.units.is_empty():
		velocity = separation
		return

	var nearest_unit := _find_nearest_unit()
	if nearest_unit == null:
		velocity = separation
		return

	var direction := global_position.direction_to(nearest_unit.global_position)
	if _is_target_in_contact(direction, 1):
		velocity = separation
	else:
		_pathfind_to_target(nearest_unit.global_position, effective_speed, separation)


func _pathfind_to_target(target_pos: Vector2, speed: float, separation: Vector2) -> void:
	var direction := global_position.direction_to(target_pos)
	path_recalc_timer -= get_physics_process_delta_time()
	var target_drift := target_pos.distance_to(last_pathed_target)
	if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
		current_path = Pathfinder.find_path(global_position, target_pos)
		path_index = 0
		_advance_path_index_enemy()
		last_pathed_target = target_pos
		path_recalc_timer = PATH_RECALC_INTERVAL
	if not _follow_path_enemy(speed, separation):
		if Pathfinder.has_line_of_sight(global_position, target_pos):
			velocity = direction * speed + separation
		else:
			current_path = Pathfinder.find_path(global_position, target_pos)
			path_index = 0
			_advance_path_index_enemy()
			if not _follow_path_enemy(speed, separation):
				velocity = direction * speed + separation


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


func _update_ability_timer(delta: float) -> void:
	ability_timer -= delta
	if ability_timer <= 0.0:
		ability_timer = ability_cooldown
		_start_ability()


func _start_ability() -> void:
	pass


func _on_threshold() -> void:
	pass


func _get_hero_color() -> Color:
	return Color(0.545, 0.0, 0.0)


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
		unit.take_damage(melee_damage)
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
	take_damage(amount)


func take_damage(amount: int) -> void:
	if is_dying:
		return
	hero_hp -= amount
	_flash_damage()

	if not threshold_triggered and hero_hp <= hero_max_hp * threshold_percent:
		threshold_triggered = true
		_on_threshold()

	if hero_hp <= 0:
		hero_hp = 0
		die()


func _flash_damage() -> void:
	if not is_instance_valid(enemy_visual):
		return
	var original_color := _get_hero_color()
	var tw := create_tween()
	tw.tween_property(enemy_visual, "color", Color.WHITE, 0.05)
	tw.tween_property(enemy_visual, "color", original_color, 0.1)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("enemies")

	AudioManager.play_sfx("enemy_death")
	death_particles.emitting = true
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(5.0, 0.25)
	enemy_visual.visible = false
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	if hp_bar_bg:
		hp_bar_bg.visible = false

	hero_defeated.emit()

	await get_tree().create_timer(death_particles.lifetime + 0.5).timeout
	queue_free()


func _create_hp_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(30, 4)
	hp_bar_bg.position = Vector2(-15, -18)
	hp_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar_bg)

	hp_bar_fill = ColorRect.new()
	hp_bar_fill.size = Vector2(30, 4)
	hp_bar_fill.position = Vector2.ZERO
	hp_bar_fill.color = Color(0.8, 0.1, 0.1, 1.0)
	hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.add_child(hp_bar_fill)


func _update_hp_bar() -> void:
	if not hp_bar_fill:
		return
	var ratio := float(hero_hp) / float(hero_max_hp)
	hp_bar_fill.size.x = 30.0 * ratio
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.8, 0.1, 0.1, 1.0)
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.9, 0.5, 0.0, 1.0)
	else:
		hp_bar_fill.color = Color(1.0, 0.0, 0.0, 1.0)


func _create_clone_label() -> void:
	var label := Label.new()
	label.text = "CORRUPTED CLONE"
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label.position = Vector2(-40, -28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _setup_death_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = _get_hero_color()
	death_particles.process_material = mat
	death_particles.amount = 25
	death_particles.lifetime = 0.6
	death_particles.one_shot = true
	death_particles.explosiveness = 1.0
	death_particles.emitting = false
