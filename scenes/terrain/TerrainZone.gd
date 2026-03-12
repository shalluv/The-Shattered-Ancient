extends Area2D

enum ZoneType { SLOW, DAMAGE }

signal unit_entered_zone(unit: Node, zone_type: ZoneType)
signal unit_exited_zone(unit: Node, zone_type: ZoneType)

@export var zone_type: ZoneType = ZoneType.SLOW
@export var slow_multiplier: float = 0.5
@export var damage_per_second: float = 1.0
@export var zone_size: Vector2 = Vector2(100, 100)

const DAMAGE_TICK_INTERVAL: float = 1.0

var _bodies_in_zone: Array[Node] = []
var _damage_timer: Timer = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3

	_create_visual()
	_create_collision()
	_create_zone_particles()

	if zone_type == ZoneType.DAMAGE:
		_damage_timer = Timer.new()
		_damage_timer.wait_time = DAMAGE_TICK_INTERVAL
		_damage_timer.one_shot = false
		_damage_timer.timeout.connect(_on_damage_tick)
		add_child(_damage_timer)
		_damage_timer.start()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if zone_type == ZoneType.DAMAGE:
		var zone_rect := Rect2(global_position - zone_size / 2.0, zone_size)
		Pathfinder.add_weighted_zone(zone_rect, Pathfinder.DAMAGE_ZONE_WEIGHT)


func _create_visual() -> void:
	# TODO: Replace with terrain zone art asset
	var visual := ColorRect.new()
	visual.size = zone_size
	visual.position = -zone_size / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if zone_type == ZoneType.SLOW:
		visual.color = Color(0.267, 0.267, 0.667, 0.4)
	else:
		visual.color = Color(1.0, 0.267, 0.0, 0.4)

	add_child(visual)


func _create_collision() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = zone_size
	shape.shape = rect
	add_child(shape)


func _create_zone_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(zone_size.x / 2.0, zone_size.y / 2.0, 0)

	if zone_type == ZoneType.SLOW:
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 20.0
		mat.initial_velocity_min = 5.0
		mat.initial_velocity_max = 12.0
		mat.gravity = Vector3(0, -8, 0)
		mat.scale_min = 0.8
		mat.scale_max = 1.5
		mat.color = Color(0.4, 0.4, 0.9, 0.5)
		particles.amount = 10
		particles.lifetime = 1.5
	else:
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 30.0
		mat.initial_velocity_min = 8.0
		mat.initial_velocity_max = 20.0
		mat.gravity = Vector3(0, -15, 0)
		mat.scale_min = 0.5
		mat.scale_max = 1.2
		mat.color = Color(1.0, 0.4, 0.1, 0.6)
		particles.amount = 12
		particles.lifetime = 1.0

	particles.process_material = mat
	particles.emitting = true
	add_child(particles)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("apply_slow"):
		return

	_bodies_in_zone.append(body)
	unit_entered_zone.emit(body, zone_type)

	if zone_type == ZoneType.SLOW:
		body.apply_slow(slow_multiplier)

	_spawn_entry_ripple(body.global_position)


func _on_body_exited(body: Node2D) -> void:
	if not body.has_method("remove_slow"):
		return

	_bodies_in_zone.erase(body)
	unit_exited_zone.emit(body, zone_type)

	if zone_type == ZoneType.SLOW:
		body.remove_slow()


func _on_damage_tick() -> void:
	for body in _bodies_in_zone:
		if is_instance_valid(body) and body.has_method("apply_damage_tick"):
			body.apply_damage_tick(damage_per_second)
			_spawn_damage_burst(body.global_position)


func _spawn_entry_ripple(pos: Vector2) -> void:
	var ripple := GPUParticles2D.new()
	ripple.top_level = true
	ripple.global_position = pos
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.0

	if zone_type == ZoneType.SLOW:
		mat.color = Color(0.4, 0.4, 0.9, 0.6)
	else:
		mat.color = Color(1.0, 0.4, 0.1, 0.6)

	ripple.process_material = mat
	ripple.amount = 6
	ripple.lifetime = 0.4
	ripple.one_shot = true
	ripple.explosiveness = 1.0
	ripple.emitting = true
	add_child(ripple)

	var tw := create_tween()
	tw.tween_interval(ripple.lifetime + 0.1)
	tw.tween_callback(ripple.queue_free)


func _spawn_damage_burst(pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.top_level = true
	burst.global_position = pos
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.color = Color(1.0, 0.3, 0.0, 0.7)
	burst.process_material = mat
	burst.amount = 4
	burst.lifetime = 0.3
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	add_child(burst)

	var tw := create_tween()
	tw.tween_interval(burst.lifetime + 0.1)
	tw.tween_callback(burst.queue_free)
