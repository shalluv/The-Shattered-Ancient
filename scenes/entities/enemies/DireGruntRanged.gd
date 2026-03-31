extends "res://scenes/entities/enemies/EnemyBase.gd"

const GRUNT_COLOR: Color = Color("#6a2a2a")
const GRUNT_SPEED: float = 20.0
const GRUNT_HP: int = 1
const GRUNT_DAMAGE: int = 1
const GRUNT_ATTACK_COOLDOWN: float = 5.0
const GRUNT_PATH_RECALC: float = 0.4
const RANGED_ATTACK_RANGE: float = 140.0
const PROJECTILE_SPEED: float = 50.0

var attack_timer: float = 0.0


func _ready() -> void:
	enemy_hp = GRUNT_HP
	move_speed = GRUNT_SPEED
	damage = GRUNT_DAMAGE
	enemy_color = GRUNT_COLOR
	super._ready()
	enemy_visual.color = GRUNT_COLOR


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_update_slow_state(delta)
	var effective_speed := move_speed * speed_multiplier
	var separation := _calculate_separation_force()

	if SwarmManager.units.is_empty():
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

	var target := _find_nearest_unit()
	if target == null:
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

	var direction := global_position.direction_to(target.global_position)
	var dist := global_position.distance_to(target.global_position)
	
	if dist < RANGED_ATTACK_RANGE:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_shoot_target(target)
			attack_timer = GRUNT_ATTACK_COOLDOWN
		velocity = separation
	else:
		path_recalc_timer -= delta
		if current_path.is_empty() or path_recalc_timer <= 0.0:
			current_path = Pathfinder.find_path(global_position, target.global_position)
			path_index = 0
			_advance_path_index_enemy()
			path_recalc_timer = GRUNT_PATH_RECALC
		if not _follow_path_enemy(effective_speed, separation):
			velocity = direction * effective_speed + separation
	
	move_and_slide()


func _shoot_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	
	_play_attack_effect()
	
	var projectile := ColorRect.new()
	projectile.size = Vector2(6, 6)
	projectile.color = Color(0.8, 0.2, 0.2)
	projectile.position = Vector2(-3, -3)
	
	var container := Node2D.new()
	container.global_position = global_position
	container.z_index = 5
	get_parent().add_child(container)
	container.add_child(projectile)
	
	var target_pos := target.global_position
	var tween := create_tween()
	var travel_time := global_position.distance_to(target_pos) / PROJECTILE_SPEED
	tween.tween_property(container, "global_position", target_pos, travel_time)
	tween.tween_callback(func():
		_on_projectile_hit(container, target)
	)


func _on_projectile_hit(projectile_container: Node2D, target: Node2D) -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
	projectile_container.queue_free()


func _play_attack_effect() -> void:
	var tween := create_tween()
	tween.tween_property(enemy_visual, "color", Color.ORANGE, 0.1)
	tween.tween_property(enemy_visual, "color", GRUNT_COLOR, 0.1)
