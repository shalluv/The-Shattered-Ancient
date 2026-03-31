extends CharacterBody2D

const WANDER_RADIUS: float = 150.0
const WANDER_SPEED: float = 25.0
var conversion_time: float = 4.0
const WANDER_PAUSE_MIN: float = 1.0
const WANDER_PAUSE_MAX: float = 3.0
const SEPARATION_RADIUS: float = 16.0
const SEPARATION_STRENGTH: float = 50.0

enum VillagerType { SWORDSMAN, ARCHER, MAGE, PRIEST }

@export var villager_type: VillagerType = VillagerType.SWORDSMAN
@export var villager_color: Color = Color(0.502, 0.502, 0.502, 1.0)

var SwordsmanScene := preload("res://scenes/entities/units/Swordsman.tscn")
var ArcherScene := preload("res://scenes/entities/units/Archer.tscn")
var MageScene := preload("res://scenes/entities/units/Mage.tscn")
var PriestScene := preload("res://scenes/entities/units/Priest.tscn")

@onready var villager_visual: ColorRect = $VillagerVisual
@onready var death_particles: GPUParticles2D = $DeathParticles

var unit_sprite: Sprite2D = null

var home_position: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var has_wander_target: bool = false
var wander_pause_timer: float = 0.0
var is_dying: bool = false
var is_converting: bool = false
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
const PATH_ARRIVAL_THRESHOLD: float = 3.0
const WAYPOINT_THRESHOLD: float = 12.0

var in_aura: bool = false
var converting_priest: Node2D = null
var conversion_timer: float = 4.0
var progress_ring: Polygon2D = null
var is_bound: bool = false
var is_auto_converting: bool = false

const RING_OUTER_RADIUS: float = 14.0
const RING_INNER_RADIUS: float = 12.0
const RING_SEGMENTS: int = 32
const RING_COLOR: Color = Color(1.0, 0.843, 0.0, 0.4)


func _ready() -> void:
	var sprite_node := villager_visual.get_node_or_null("Sprite2D")
	if sprite_node is Sprite2D:
		unit_sprite = sprite_node
		villager_visual.color = Color(0, 0, 0, 0)
	home_position = global_position
	add_to_group("neutrals")
	if is_instance_valid(BoonManager):
		conversion_time = BoonManager.get_conversion_time()
	conversion_timer = conversion_time
	villager_visual.color = villager_color
	_setup_death_particles()
	call_deferred("_pick_wander_target")
	call_deferred("_check_initial_position")


func _physics_process(delta: float) -> void:
	if is_dying or is_converting:
		return
	
	if is_bound:
		return

	if unit_sprite and velocity.length_squared() > 1.0:
		unit_sprite.rotation = velocity.angle() + PI / 2.0

	var separation := _calculate_separation_force()

	if is_auto_converting or in_aura:
		conversion_timer -= delta
		if in_aura:
			_update_progress_ring()
		if conversion_timer <= 0.0:
			_convert()
			return

	if wander_pause_timer > 0.0:
		wander_pause_timer -= delta
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

	if not has_wander_target:
		_pick_wander_target()
		return

	var distance := global_position.distance_to(wander_target)
	if distance > 3.0:
		if _is_in_danger_zone(global_position):
			var escape_dir := _get_escape_direction()
			velocity = escape_dir * WANDER_SPEED
			move_and_slide()
			has_wander_target = false
			return
		
		if not _follow_path_villager(separation):
			var next_pos := global_position + global_position.direction_to(wander_target) * 10.0
			if _is_in_danger_zone(next_pos):
				has_wander_target = false
				return
			var direction := global_position.direction_to(wander_target)
			velocity = direction * WANDER_SPEED + separation
		move_and_slide()
	else:
		has_wander_target = false
		current_path = PackedVector2Array()
		wander_pause_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


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


func _pick_wander_target() -> void:
	var center := home_position
	if in_aura and is_instance_valid(converting_priest) and randf() < 0.7:
		center = converting_priest.global_position

	for _attempt in 5:
		var angle := randf() * TAU
		var radius := randf() * WANDER_RADIUS
		var candidate := center + Vector2(cos(angle), sin(angle)) * radius
		
		if _is_in_danger_zone(candidate):
			continue
		
		wander_target = candidate
		current_path = Pathfinder.find_path(global_position, wander_target)
		path_index = 0
		_advance_path_index_villager()
		if current_path.is_empty() and global_position.distance_to(wander_target) >= 32.0:
			wander_target = center + Vector2(cos(angle + PI), sin(angle + PI)) * radius * 0.5
			if _is_in_danger_zone(wander_target):
				continue
			current_path = Pathfinder.find_path(global_position, wander_target)
			path_index = 0
			_advance_path_index_villager()
		has_wander_target = true
		return
	
	has_wander_target = true
	wander_target = global_position


func _follow_path_villager(separation: Vector2) -> bool:
	if current_path.is_empty() or path_index >= current_path.size():
		return false
	var waypoint := current_path[path_index]
	
	if _is_in_danger_zone(waypoint):
		current_path = PackedVector2Array()
		has_wander_target = false
		return false
	
	var dist := global_position.distance_to(waypoint)
	if dist <= WAYPOINT_THRESHOLD:
		path_index += 1
		if path_index >= current_path.size():
			return false
		waypoint = current_path[path_index]
		if _is_in_danger_zone(waypoint):
			current_path = PackedVector2Array()
			has_wander_target = false
			return false
	var direction := global_position.direction_to(waypoint)
	velocity = direction * WANDER_SPEED + separation
	return true


func _advance_path_index_villager() -> void:
	while path_index < current_path.size() - 1:
		var to_waypoint := current_path[path_index] - global_position
		var to_next := current_path[path_index + 1] - global_position
		if to_next.length() < to_waypoint.length():
			path_index += 1
		else:
			break


func _check_initial_position() -> void:
	if _is_in_danger_zone(global_position):
		var escape_dir := _get_escape_direction()
		global_position += escape_dir * 50.0
		home_position = global_position


func _is_in_danger_zone(pos: Vector2) -> bool:
	var damage_zones := get_tree().get_nodes_in_group("damage_zones")
	for zone in damage_zones:
		if not is_instance_valid(zone):
			continue
		var zone_pos: Vector2 = zone.global_position
		var zone_size: Vector2 = zone.zone_size if zone.has_method("get") else Vector2(100, 100)
		if "zone_size" in zone:
			zone_size = zone.zone_size
		var rect := Rect2(zone_pos - zone_size / 2.0, zone_size)
		if rect.has_point(pos):
			return true
	
	var altars := get_tree().get_nodes_in_group("altars")
	for altar in altars:
		if not is_instance_valid(altar):
			continue
		var altar_rect: Rect2 = altar.get_rect() if altar.has_method("get_rect") else Rect2()
		if "position" in altar and "size" in altar:
			altar_rect = Rect2(altar.position, altar.size)
		if altar_rect.has_point(pos):
			return true
	
	return false


func _get_escape_direction() -> Vector2:
	var escape_dir := Vector2.ZERO
	
	var damage_zones := get_tree().get_nodes_in_group("damage_zones")
	for zone in damage_zones:
		if not is_instance_valid(zone):
			continue
		var zone_pos: Vector2 = zone.global_position
		var dist := global_position.distance_to(zone_pos)
		if dist < 150.0:
			escape_dir += zone_pos.direction_to(global_position)
	
	var altars := get_tree().get_nodes_in_group("altars")
	for altar in altars:
		if not is_instance_valid(altar):
			continue
		if "position" in altar and "size" in altar:
			var altar_center: Vector2 = Vector2(altar.position.x, altar.position.y) + Vector2(altar.size.x, altar.size.y) / 2.0
			var dist := global_position.distance_to(altar_center)
			if dist < 80.0:
				escape_dir += altar_center.direction_to(global_position)
	
	if escape_dir.length_squared() < 0.01:
		escape_dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
	
	return escape_dir.normalized()


func set_in_aura(value: bool, priest: Node2D) -> void:
	if value == in_aura and priest == converting_priest:
		return
	in_aura = value
	converting_priest = priest
	if not in_aura:
		if not is_auto_converting:
			conversion_timer = conversion_time
		_remove_progress_ring()


func _create_progress_ring() -> void:
	if progress_ring != null:
		return
	progress_ring = Polygon2D.new()
	progress_ring.color = RING_COLOR
	progress_ring.z_index = 1
	add_child(progress_ring)


func _remove_progress_ring() -> void:
	if progress_ring != null:
		progress_ring.queue_free()
		progress_ring = null


func _update_progress_ring() -> void:
	if progress_ring == null:
		_create_progress_ring()
	var progress := 1.0 - (conversion_timer / conversion_time)
	progress = clampf(progress, 0.0, 1.0)
	var arc_angle := progress * TAU
	var seg_count := maxi(int(RING_SEGMENTS * progress), 1)
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(seg_count + 1):
		var angle := float(i) / float(seg_count) * arc_angle - PI / 2.0
		points.append(Vector2(cos(angle), sin(angle)) * RING_OUTER_RADIUS)
	for i in range(seg_count, -1, -1):
		var angle := float(i) / float(seg_count) * arc_angle - PI / 2.0
		points.append(Vector2(cos(angle), sin(angle)) * RING_INNER_RADIUS)
	progress_ring.polygon = points


func _convert() -> void:
	is_converting = true
	remove_from_group("neutrals")
	_remove_progress_ring()

	# TODO: Add unit conversion sound effect
	var tween := create_tween()
	if unit_sprite:
		tween.tween_property(unit_sprite, "modulate", Color(1.0, 0.843, 0.0, 1.0), 0.5)
		for i in 3:
			tween.tween_property(unit_sprite, "modulate", Color.WHITE, 0.08)
			tween.tween_property(unit_sprite, "modulate", Color(1.0, 0.843, 0.0, 1.0), 0.08)
	else:
		tween.tween_property(villager_visual, "color", Color(1.0, 0.843, 0.0, 1.0), 0.5)
		for i in 3:
			tween.tween_property(villager_visual, "color", Color.WHITE, 0.08)
			tween.tween_property(villager_visual, "color", Color(1.0, 0.843, 0.0, 1.0), 0.08)

	_play_conversion_particles()

	await tween.finished

	var unit := _get_unit_scene().instantiate()
	unit.global_position = global_position
	get_parent().add_child(unit)

	queue_free()


func _get_unit_scene() -> PackedScene:
	match villager_type:
		VillagerType.ARCHER:
			return ArcherScene
		VillagerType.MAGE:
			return MageScene
		VillagerType.PRIEST:
			return PriestScene
		_:
			return SwordsmanScene


func _play_conversion_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.843, 0.0, 1.0)
	particles.process_material = mat
	particles.amount = 25
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	add_child(particles)


func take_damage(_amount: int) -> void:
	if is_dying:
		return
	die()


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("neutrals")
	_remove_progress_ring()
	death_particles.emitting = true
	villager_visual.visible = false
	await get_tree().create_timer(death_particles.lifetime).timeout
	queue_free()


func _setup_death_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 50, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.502, 0.502, 0.502, 1.0)
	death_particles.process_material = mat
	death_particles.amount = 8
	death_particles.lifetime = 0.4
	death_particles.one_shot = true
	death_particles.explosiveness = 1.0
	death_particles.emitting = false
