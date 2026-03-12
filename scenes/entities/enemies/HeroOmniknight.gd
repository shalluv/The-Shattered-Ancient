extends "res://scenes/entities/enemies/HeroFighter.gd"

const PURIFICATION_WINDUP: float = 0.4
const PURIFICATION_HEAL: int = 20
const PURIFICATION_DAMAGE: int = 30
const PURIFICATION_RADIUS: float = 60.0
const REPEL_DURATION: float = 4.0

var mage_immune: bool = false
var purification_visual: Polygon2D = null


func _ready() -> void:
	hero_id = "omniknight"
	hero_hp = 45
	hero_max_hp = 45
	move_speed = 60.0
	melee_damage = 18
	attack_cooldown = 1.4
	ability_cooldown = 8.0
	threshold_percent = 0.5
	super()


func _get_hero_color() -> Color:
	return Color("#FFFACD")


func _start_ability() -> void:
	_start_purification()


func _start_purification() -> void:
	var windup_particles := _create_windup_particles()
	add_child(windup_particles)

	var tw := create_tween()
	tw.tween_property(enemy_visual, "color", Color.WHITE, PURIFICATION_WINDUP)
	tw.tween_callback(func() -> void:
		windup_particles.queue_free()
		_execute_purification()
		enemy_visual.color = _get_hero_color()
	)


func _execute_purification() -> void:
	hero_hp = mini(hero_hp + PURIFICATION_HEAL, hero_max_hp)

	_create_purification_ring()

	for unit in SwarmManager.units:
		if not is_instance_valid(unit) or unit.is_dying:
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist < PURIFICATION_RADIUS and unit.has_method("take_damage"):
			unit.take_damage(PURIFICATION_DAMAGE)

	var heal_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(1.0, 0.98, 0.8, 0.8)
	heal_particles.process_material = mat
	heal_particles.amount = 15
	heal_particles.lifetime = 0.5
	heal_particles.one_shot = true
	heal_particles.explosiveness = 1.0
	heal_particles.emitting = true
	add_child(heal_particles)
	heal_particles.finished.connect(heal_particles.queue_free)


func _create_purification_ring() -> void:
	var ring := Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * PURIFICATION_RADIUS)
	ring.polygon = points
	ring.color = Color(1.0, 0.98, 0.8, 0.25)
	add_child(ring)

	var tw := create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.tween_callback(ring.queue_free)


func _on_threshold() -> void:
	mage_immune = true

	var aura_ring := Polygon2D.new()
	aura_ring.name = "RepelAura"
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * 20.0)
	aura_ring.polygon = points
	aura_ring.color = Color(1.0, 1.0, 1.0, 0.2)
	add_child(aura_ring)

	var pulse_tw := create_tween().set_loops(int(REPEL_DURATION / 0.5))
	pulse_tw.tween_property(aura_ring, "modulate:a", 0.5, 0.25)
	pulse_tw.tween_property(aura_ring, "modulate:a", 1.0, 0.25)

	var label := Label.new()
	label.text = "REPEL!"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	label.position = Vector2(-18, -35)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	get_tree().create_timer(REPEL_DURATION).timeout.connect(func() -> void:
		mage_immune = false
		if is_instance_valid(aura_ring):
			aura_ring.queue_free()
		if is_instance_valid(label):
			var fade := label.create_tween()
			fade.tween_property(label, "modulate:a", 0.0, 0.3)
			fade.tween_callback(label.queue_free)
	)


func take_hit(amount: int, from_mage: bool = false) -> void:
	if mage_immune and from_mage:
		_flash_immune()
		return
	take_damage(amount)


func _flash_immune() -> void:
	var tw := create_tween()
	tw.tween_property(enemy_visual, "color", Color(0.8, 0.8, 1.0), 0.05)
	tw.tween_property(enemy_visual, "color", _get_hero_color(), 0.1)


func _create_windup_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = PURIFICATION_RADIUS
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
	mat.color = Color(1.0, 0.98, 0.8, 0.6)
	particles.process_material = mat
	particles.amount = 10
	particles.lifetime = PURIFICATION_WINDUP
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.emitting = true
	return particles
