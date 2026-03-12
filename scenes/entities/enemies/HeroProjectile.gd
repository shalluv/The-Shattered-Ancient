extends Area2D

@export var projectile_speed: float = 180.0
@export var max_distance: float = 300.0
@export var projectile_damage: int = 8
@export var projectile_color: Color = Color(0.545, 0.0, 0.0, 1.0)
@export var applies_slow: bool = false
@export var slow_amount: float = 0.7
@export var slow_duration: float = 2.0

var direction: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	$ProjectileVisual.color = projectile_color
	_setup_impact_particles()


func _physics_process(delta: float) -> void:
	var move := direction * projectile_speed * delta
	position += move
	distance_traveled += move.length()
	if distance_traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	body.take_damage(projectile_damage)
	if applies_slow and body.has_method("apply_slow"):
		body.apply_slow(slow_amount)
		var tree := get_tree()
		if tree:
			tree.create_timer(slow_duration).timeout.connect(func() -> void:
				if is_instance_valid(body) and body.has_method("remove_slow"):
					body.remove_slow()
			)
	$ImpactParticles.emitting = true
	$ProjectileVisual.visible = false
	set_physics_process(false)
	collision_mask = 0
	await get_tree().create_timer($ImpactParticles.lifetime).timeout
	queue_free()


func _setup_impact_particles() -> void:
	var particles: GPUParticles2D = $ImpactParticles
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = projectile_color
	particles.process_material = mat
	particles.amount = 6
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
