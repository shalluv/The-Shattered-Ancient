extends "res://scenes/entities/enemies/EnemyBase.gd"

const SPEARWALL_HP: int = 4
const SPEARWALL_DAMAGE: int = 12
const SPEARWALL_ATTACK_COOLDOWN: float = 2.4
const FRONT_ARC_THRESHOLD: float = 0.3
const REFLECT_FRACTION: float = 0.5
const FORMATION_ARRIVE_SPEED: float = 60.0
const SPEARWALL_GOLD_DROP: int = 4

var group: Node2D = null
var formation_offset: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_attached: bool = true
var facing_direction: Vector2 = Vector2.RIGHT
var front_indicator: Polygon2D = null
var deflect_particles: GPUParticles2D = null


func _ready() -> void:
	super()
	_create_front_indicator()
	_create_deflect_particles()


func _create_front_indicator() -> void:
	# TODO: Replace with Spearwall unit sprite
	front_indicator = Polygon2D.new()
	front_indicator.polygon = PackedVector2Array([
		Vector2(14, 0),
		Vector2(-6, -8),
		Vector2(-6, 8)
	])
	front_indicator.color = Color(0.7, 0.0, 0.0, 0.8)
	add_child(front_indicator)


func _create_deflect_particles() -> void:
	deflect_particles = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = Color(1.0, 0.6, 0.0, 0.8)
	deflect_particles.process_material = mat
	deflect_particles.amount = 8
	deflect_particles.lifetime = 0.3
	deflect_particles.one_shot = true
	deflect_particles.explosiveness = 1.0
	deflect_particles.emitting = false
	add_child(deflect_particles)


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if is_attached and is_instance_valid(group):
		var dir := global_position.direction_to(target_position)
		var dist := global_position.distance_to(target_position)
		if dist > 2.0:
			velocity = dir * FORMATION_ARRIVE_SPEED
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		front_indicator.rotation = facing_direction.angle()
	else:
		super._physics_process(delta)
		if velocity.length() > 1.0:
			facing_direction = velocity.normalized()
			front_indicator.rotation = facing_direction.angle()


func take_hit(amount: int) -> void:
	if is_instance_valid(last_attacker) and facing_direction.length() > 0.1:
		var dir_to_attacker := global_position.direction_to(last_attacker.global_position)
		var dot := facing_direction.dot(dir_to_attacker)
		if dot > FRONT_ARC_THRESHOLD:
			var reflected_amount := int(ceil(float(amount) * REFLECT_FRACTION))
			if last_attacker.has_method("take_damage"):
				last_attacker.take_damage(reflected_amount)
			deflect_particles.emitting = true
			if is_instance_valid(group) and group.has_signal("attack_reflected"):
				group.attack_reflected.emit(last_attacker)
			var reduced := maxi(amount - reflected_amount, 1)
			super.take_hit(reduced)
			last_attacker = null
			return

	last_attacker = null
	super.take_hit(amount)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("enemies")

	if is_attached and is_instance_valid(group):
		group.on_unit_died(self)

	death_particles.emitting = true
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(3.0, 0.15)
	enemy_visual.visible = false
	if front_indicator:
		front_indicator.visible = false
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	SwarmManager.on_enemy_died(global_position)
	RunManager.on_enemy_killed()
	_drop_gold(SPEARWALL_GOLD_DROP)

	if SwarmManager.roll_absorption():
		_play_absorption_effect()
		_spawn_absorbed_unit()

	await get_tree().create_timer(death_particles.lifetime + 0.5).timeout
	queue_free()


func detach() -> void:
	is_attached = false
	group = null
