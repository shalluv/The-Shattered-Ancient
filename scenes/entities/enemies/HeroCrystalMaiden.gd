extends "res://scenes/entities/enemies/HeroFighter.gd"

const KITE_RANGE: float = 150.0
const RETREAT_RANGE: float = 80.0
const ATTACK_DAMAGE: int = 8
const ATTACK_SPEED: float = 180.0
const ATTACK_COOLDOWN_TIME: float = 1.2
const ATTACK_SLOW_AMOUNT: float = 0.7
const ATTACK_SLOW_DURATION: float = 2.0
const CRYSTAL_NOVA_WINDUP: float = 0.5
const CRYSTAL_NOVA_RADIUS: float = 120.0
const CRYSTAL_NOVA_DAMAGE: int = 12
const CRYSTAL_NOVA_SLOW: float = 0.5
const CRYSTAL_NOVA_SLOW_DURATION: float = 3.0
const FROSTBITE_DURATION: float = 4.0

var HeroProjectileScene := preload("res://scenes/entities/enemies/HeroProjectile.tscn")
var attack_timer: float = 0.0
var crystal_nova_cooldown: float = 10.0
var nova_timer: float = 10.0


func _ready() -> void:
	hero_id = "crystal_maiden"
	hero_hp = 22
	hero_max_hp = 22
	move_speed = 70.0
	melee_damage = 5
	attack_cooldown = 999.0
	ability_cooldown = 999.0
	threshold_percent = 0.3
	super()


func _get_hero_color() -> Color:
	return Color("#00CFFF")


func _physics_process(delta: float) -> void:
	if is_dying or not physics_enabled:
		return

	attack_timer -= delta
	nova_timer -= delta

	if nova_timer <= 0.0:
		nova_timer = crystal_nova_cooldown
		_start_crystal_nova()

	super(delta)


func _hero_movement(_delta: float, effective_speed: float, separation: Vector2) -> void:
	if SwarmManager.units.is_empty():
		velocity = separation
		return

	var nearest_unit := _find_nearest_unit()
	if nearest_unit == null:
		velocity = separation
		return

	var dist := global_position.distance_to(nearest_unit.global_position)

	if dist < RETREAT_RANGE:
		var away := global_position.direction_to(nearest_unit.global_position) * -1.0
		velocity = away * effective_speed + separation
	elif dist < KITE_RANGE:
		velocity = separation
		if attack_timer <= 0.0:
			_fire_projectile(nearest_unit)
			attack_timer = ATTACK_COOLDOWN_TIME
	else:
		var direction := global_position.direction_to(nearest_unit.global_position)
		if _is_target_in_contact(direction, 1):
			velocity = separation
		else:
			_pathfind_to_target(nearest_unit.global_position, effective_speed * 0.6, separation)

		if attack_timer <= 0.0 and dist < 250.0:
			_fire_projectile(nearest_unit)
			attack_timer = ATTACK_COOLDOWN_TIME


func _fire_projectile(target: Node2D) -> void:
	var proj := HeroProjectileScene.instantiate()
	proj.global_position = global_position
	proj.direction = global_position.direction_to(target.global_position)
	proj.projectile_speed = ATTACK_SPEED
	proj.projectile_damage = ATTACK_DAMAGE
	proj.projectile_color = Color(0.0, 0.6, 0.9, 1.0)
	proj.applies_slow = true
	proj.slow_amount = ATTACK_SLOW_AMOUNT
	proj.slow_duration = ATTACK_SLOW_DURATION
	proj.max_distance = 300.0
	get_parent().add_child(proj)


func _start_crystal_nova() -> void:
	var centroid := _get_unit_cluster_centroid()
	if centroid == Vector2.ZERO:
		return

	var telegraph := Polygon2D.new()
	telegraph.global_position = centroid
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * CRYSTAL_NOVA_RADIUS)
	telegraph.polygon = points
	telegraph.color = Color(0.0, 0.8, 1.0, 0.1)
	get_parent().add_child(telegraph)

	var tw := create_tween()
	tw.tween_property(telegraph, "color", Color(0.0, 0.8, 1.0, 0.3), CRYSTAL_NOVA_WINDUP)
	tw.tween_callback(func() -> void:
		_execute_crystal_nova(centroid)
		telegraph.color = Color(0.0, 0.8, 1.0, 0.5)
		var fade := telegraph.create_tween()
		fade.tween_property(telegraph, "modulate:a", 0.0, 0.3)
		fade.tween_callback(telegraph.queue_free)
	)


func _execute_crystal_nova(center: Vector2) -> void:
	for unit in SwarmManager.units:
		if not is_instance_valid(unit) or unit.is_dying:
			continue
		var dist := center.distance_to(unit.global_position)
		if dist < CRYSTAL_NOVA_RADIUS:
			if unit.has_method("take_damage"):
				unit.take_damage(CRYSTAL_NOVA_DAMAGE)
			if unit.has_method("apply_slow"):
				unit.apply_slow(CRYSTAL_NOVA_SLOW)
				get_tree().create_timer(CRYSTAL_NOVA_SLOW_DURATION).timeout.connect(func() -> void:
					if is_instance_valid(unit) and unit.has_method("remove_slow"):
						unit.remove_slow()
				)

	var burst := GPUParticles2D.new()
	burst.global_position = center
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 10, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.0, 0.8, 1.0, 0.8)
	burst.process_material = mat
	burst.amount = 20
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	get_parent().add_child(burst)
	burst.finished.connect(burst.queue_free)


func _get_unit_cluster_centroid() -> Vector2:
	if SwarmManager.units.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var count: int = 0
	for unit in SwarmManager.units:
		if is_instance_valid(unit):
			sum += unit.global_position
			count += 1
	if count == 0:
		return Vector2.ZERO
	return sum / float(count)


func _on_threshold() -> void:
	var nearest := _find_nearest_unit()
	if nearest == null or not nearest.has_method("apply_slow"):
		return

	nearest.apply_slow(0.0)

	var freeze_visual := ColorRect.new()
	freeze_visual.size = Vector2(14, 14)
	freeze_visual.position = Vector2(-7, -7)
	freeze_visual.color = Color(0.0, 0.7, 1.0, 0.4)
	freeze_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nearest.add_child(freeze_visual)

	var label := Label.new()
	label.text = "FROSTBITE!"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	label.position = Vector2(-30, -35)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var fade := create_tween()
	fade.tween_property(label, "modulate:a", 0.0, 1.5)
	fade.tween_callback(label.queue_free)

	get_tree().create_timer(FROSTBITE_DURATION).timeout.connect(func() -> void:
		if is_instance_valid(nearest) and nearest.has_method("remove_slow"):
			nearest.remove_slow()
		if is_instance_valid(freeze_visual):
			freeze_visual.queue_free()
	)
