extends Area2D

const PROJECTILE_SPEED: float = 125.0
const MAX_DISTANCE: float = 200.0
const PROJECTILE_DAMAGE: int = 1

var direction: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0
var applies_slow: bool = false
var slow_duration: float = 0.0
var pierces: bool = false
var pierce_count: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_setup_impact_particles()


func _physics_process(delta: float) -> void:
	var move := direction * PROJECTILE_SPEED * delta
	position += move
	distance_traveled += move.length()
	if distance_traveled >= MAX_DISTANCE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_hit"):
		var hit_damage: int = PROJECTILE_DAMAGE
		if is_instance_valid(BoonManager) and BoonManager.frost_arrows_bonus_damage and "slow_timer" in body and body.slow_timer > 0.0:
			hit_damage = PROJECTILE_DAMAGE + 1
		body.take_hit(hit_damage)
		if applies_slow and slow_duration > 0.0 and "slow_timer" in body:
			body.slow_timer = slow_duration
		if pierces and pierce_count < 1:
			pierce_count += 1
			return
		AudioManager.play_sfx("projectile_hit")
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
	mat.color = Color(1.0, 0.843, 0.0, 1.0)
	particles.process_material = mat
	particles.amount = 6
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
