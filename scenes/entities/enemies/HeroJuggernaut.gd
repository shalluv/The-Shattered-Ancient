extends "res://scenes/entities/enemies/HeroFighter.gd"

const BLADEFURY_WINDUP: float = 0.5
const BLADEFURY_DURATION: float = 2.0
const BLADEFURY_RADIUS: float = 40.0
const BLADEFURY_DPS: float = 10.0
const ENRAGED_SPEED: float = 220.0

var is_spinning: bool = false
var spin_timer: float = 0.0
var spin_visual: Polygon2D = null


func _ready() -> void:
	hero_id = "juggernaut"
	hero_hp = 30
	hero_max_hp = 30
	move_speed = 120.0
	melee_damage = 15
	attack_cooldown = 1.0
	ability_cooldown = 8.0
	threshold_percent = 0.3
	super()


func _get_hero_color() -> Color:
	return Color("#FF6B00")


func _physics_process(delta: float) -> void:
	if is_dying or not physics_enabled:
		return

	if is_spinning:
		spin_timer -= delta
		_deal_spin_damage(delta)
		enemy_visual.rotation += delta * 12.0
		if spin_timer <= 0.0:
			_end_bladefury()
	super(delta)


func _start_ability() -> void:
	if is_spinning:
		return
	_start_bladefury()


func _start_bladefury() -> void:
	var windup_particles := _create_windup_particles()
	add_child(windup_particles)

	var tw := create_tween()
	tw.tween_property(enemy_visual, "color", Color.WHITE, BLADEFURY_WINDUP * 0.5)
	tw.tween_property(enemy_visual, "color", _get_hero_color(), BLADEFURY_WINDUP * 0.5)
	tw.tween_callback(func() -> void:
		windup_particles.queue_free()
		is_spinning = true
		spin_timer = BLADEFURY_DURATION
		_create_spin_visual()
	)


func _deal_spin_damage(delta: float) -> void:
	for unit in SwarmManager.units:
		if not is_instance_valid(unit) or unit.is_dying:
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist < BLADEFURY_RADIUS and unit.has_method("take_damage"):
			unit.take_damage(int(max(1, BLADEFURY_DPS * delta)))


func _end_bladefury() -> void:
	is_spinning = false
	enemy_visual.rotation = 0.0
	if spin_visual:
		spin_visual.queue_free()
		spin_visual = null


func _create_spin_visual() -> void:
	spin_visual = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * BLADEFURY_RADIUS)
	spin_visual.polygon = points
	spin_visual.color = Color(1.0, 0.42, 0.0, 0.15)
	add_child(spin_visual)


func _on_threshold() -> void:
	move_speed = ENRAGED_SPEED

	var label := Label.new()
	label.text = "ENRAGED!"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
	label.position = Vector2(-25, -35)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 1.5)
	tw.tween_callback(label.queue_free)


func _create_windup_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = BLADEFURY_RADIUS
	mat.emission_ring_inner_radius = 5.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.42, 0.0, 0.6)
	particles.process_material = mat
	particles.amount = 10
	particles.lifetime = BLADEFURY_WINDUP
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.emitting = true
	return particles
