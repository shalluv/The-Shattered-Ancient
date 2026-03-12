extends "res://scenes/entities/enemies/HeroFighter.gd"

const KITE_RANGE: float = 200.0
const ATTACK_DAMAGE: int = 12
const ATTACK_SPEED: float = 300.0
const ATTACK_COOLDOWN_TIME: float = 0.7
const MULTISHOT_WINDUP: float = 0.3
const MULTISHOT_COUNT: int = 5
const MULTISHOT_SPREAD: float = deg_to_rad(60.0)
const MULTISHOT_DAMAGE: int = 10
const GUST_RANGE: float = 90.0
const GUST_KNOCKBACK: float = 60.0
const GUST_TWEEN_TIME: float = 0.2
const BASE_GUST_COOLDOWN: float = 5.0

var HeroProjectileScene := preload("res://scenes/entities/enemies/HeroProjectile.tscn")
var attack_timer: float = 0.0
var multishot_cooldown: float = 6.0
var multishot_timer: float = 6.0
var gust_cooldown: float = BASE_GUST_COOLDOWN
var gust_timer: float = BASE_GUST_COOLDOWN


func _ready() -> void:
	hero_id = "drow_ranger"
	hero_hp = 25
	hero_max_hp = 25
	move_speed = 130.0
	melee_damage = 6
	attack_cooldown = 999.0
	ability_cooldown = 999.0
	threshold_percent = 0.3
	super()


func _get_hero_color() -> Color:
	return Color("#008080")


func _physics_process(delta: float) -> void:
	if is_dying or not physics_enabled:
		return

	attack_timer -= delta
	multishot_timer -= delta
	gust_timer -= delta

	_check_gust()

	if multishot_timer <= 0.0:
		multishot_timer = multishot_cooldown
		_start_multishot()

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

	if dist < KITE_RANGE:
		var away := global_position.direction_to(nearest_unit.global_position) * -1.0
		velocity = away * effective_speed + separation
		if attack_timer <= 0.0:
			_fire_arrow(nearest_unit)
			attack_timer = ATTACK_COOLDOWN_TIME
	else:
		var direction := global_position.direction_to(nearest_unit.global_position)
		velocity = direction * effective_speed * 0.5 + separation

		if attack_timer <= 0.0 and dist < 350.0:
			_fire_arrow(nearest_unit)
			attack_timer = ATTACK_COOLDOWN_TIME


func _fire_arrow(target: Node2D) -> void:
	var proj := HeroProjectileScene.instantiate()
	proj.global_position = global_position
	proj.direction = global_position.direction_to(target.global_position)
	proj.projectile_speed = ATTACK_SPEED
	proj.projectile_damage = ATTACK_DAMAGE
	proj.projectile_color = Color(0.0, 0.5, 0.5, 1.0)
	proj.max_distance = 400.0
	get_parent().add_child(proj)


func _start_multishot() -> void:
	var nearest := _find_nearest_unit()
	if nearest == null:
		return

	var base_dir := global_position.direction_to(nearest.global_position)

	var tw := create_tween()
	tw.tween_property(enemy_visual, "color", Color.WHITE, MULTISHOT_WINDUP)
	tw.tween_callback(func() -> void:
		enemy_visual.color = _get_hero_color()
		_fire_multishot_volley(base_dir)
	)


func _fire_multishot_volley(base_dir: Vector2) -> void:
	var base_angle := base_dir.angle()
	var half_spread := MULTISHOT_SPREAD / 2.0
	for i in MULTISHOT_COUNT:
		var angle_offset: float = -half_spread + (MULTISHOT_SPREAD * float(i) / float(MULTISHOT_COUNT - 1))
		var dir := Vector2.from_angle(base_angle + angle_offset)
		var proj := HeroProjectileScene.instantiate()
		proj.global_position = global_position
		proj.direction = dir
		proj.projectile_speed = ATTACK_SPEED
		proj.projectile_damage = MULTISHOT_DAMAGE
		proj.projectile_color = Color(0.0, 0.5, 0.5, 1.0)
		proj.max_distance = 350.0
		get_parent().add_child(proj)

	var burst := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(base_dir.x, base_dir.y, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.0, 0.5, 0.5, 0.8)
	burst.process_material = mat
	burst.amount = 8
	burst.lifetime = 0.3
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _check_gust() -> void:
	if gust_timer > 0.0:
		return

	var any_close: bool = false
	for unit in SwarmManager.units:
		if not is_instance_valid(unit) or unit.is_dying:
			continue
		if global_position.distance_to(unit.global_position) < 80.0:
			any_close = true
			break

	if any_close:
		gust_timer = gust_cooldown
		_execute_gust()


func _execute_gust() -> void:
	var gust_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.5, 0.8, 0.8, 0.5)
	gust_particles.process_material = mat
	gust_particles.amount = 15
	gust_particles.lifetime = 0.3
	gust_particles.one_shot = true
	gust_particles.explosiveness = 1.0
	gust_particles.emitting = true
	add_child(gust_particles)
	gust_particles.finished.connect(gust_particles.queue_free)

	for unit in SwarmManager.units:
		if not is_instance_valid(unit) or unit.is_dying:
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist < GUST_RANGE and dist > 0.0:
			var push_dir := global_position.direction_to(unit.global_position)
			var target_pos := unit.global_position + push_dir * GUST_KNOCKBACK
			var tw := unit.create_tween()
			tw.tween_property(unit, "global_position", target_pos, GUST_TWEEN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_threshold() -> void:
	gust_cooldown = BASE_GUST_COOLDOWN / 2.0

	var label := Label.new()
	label.text = "GUST EMPOWERED!"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.0, 0.6, 0.6))
	label.position = Vector2(-40, -35)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 1.5)
	tw.tween_callback(label.queue_free)
