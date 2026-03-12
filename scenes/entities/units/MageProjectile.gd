extends Area2D

const PROJECTILE_SPEED: float = 200.0
const PROJECTILE_DAMAGE: int = 1

var target_position: Vector2 = Vector2.ZERO
var aoe_radius: float = 60.0
var direction: Vector2 = Vector2.ZERO
var max_distance: float = 0.0
var distance_traveled: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	direction = global_position.direction_to(target_position)
	max_distance = global_position.distance_to(target_position)
	_setup_impact_particles()


func _physics_process(delta: float) -> void:
	var move := direction * PROJECTILE_SPEED * delta
	position += move
	distance_traveled += move.length()
	if distance_traveled >= max_distance:
		_explode()


func _explode() -> void:
	set_physics_process(false)
	$ProjectileVisual.visible = false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= aoe_radius:
			if enemy.has_method("take_hit"):
				enemy.take_hit(PROJECTILE_DAMAGE)

	_create_aoe_ring()
	$ImpactParticles.emitting = true

	await get_tree().create_timer($ImpactParticles.lifetime + 0.3).timeout
	queue_free()


func _create_aoe_ring() -> void:
	var ring := Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in segments + 1:
		var angle := (float(i) / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * aoe_radius)
	ring.polygon = points
	ring.color = Color(0.878, 1.0, 1.0, 0.3)
	add_child(ring)

	var tween := create_tween()
	tween.tween_property(ring, "color:a", 0.0, 0.3)


func _setup_impact_particles() -> void:
	var particles: GPUParticles2D = $ImpactParticles
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = Color(0.878, 1.0, 1.0, 1.0)
	particles.process_material = mat
	particles.amount = 10
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
