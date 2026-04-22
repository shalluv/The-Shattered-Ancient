extends "res://scenes/entities/enemies/EnemyBase.gd"

const GUARD_COLOR: Color = Color("#4a3a5a")
const AGGRO_RADIUS: float = 150.0
const RANGED_ATTACK_RANGE: float = 140.0
const RANGED_ATTACK_COOLDOWN: float = 4.0
const PROJECTILE_SPEED: float = 75.0
const PROJECTILE_DAMAGE: int = 1
const RETREAT_DISTANCE: float = 80.0
const PATROL_RADIUS: float = 30.0
const PATROL_SPEED: float = 10.0
const PATROL_PAUSE_MIN: float = 1.5
const PATROL_PAUSE_MAX: float = 3.0

var is_aggro: bool = false
var guard_position: Vector2 = Vector2.ZERO
var ranged_cooldown: float = 0.0
var patrol_target: Vector2 = Vector2.ZERO
var patrol_pause_timer: float = 0.0
var has_patrol_target: bool = false


func _ready() -> void:
	enemy_hp = 1
	move_speed = 12.5
	damage = 1
	enemy_color = Color.WHITE
	super._ready()
	guard_position = global_position
	_pick_patrol_target()


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	
	if not is_aggro:
		_check_aggro()
		_patrol(delta)
		return
	
	ranged_cooldown -= delta
	
	var target := _find_nearest_unit()
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		
		if dist < RETREAT_DISTANCE:
			var away_dir := target.global_position.direction_to(global_position)
			velocity = away_dir * move_speed
			move_and_slide()
			_update_facing()
			return
		
		if dist <= RANGED_ATTACK_RANGE and ranged_cooldown <= 0:
			_shoot_projectile(target)
			ranged_cooldown = RANGED_ATTACK_COOLDOWN
			return
		elif dist > RANGED_ATTACK_RANGE:
			var dir := global_position.direction_to(target.global_position)
			velocity = dir * move_speed
			move_and_slide()
			_update_facing()


func _patrol(delta: float) -> void:
	if patrol_pause_timer > 0:
		patrol_pause_timer -= delta
		return
	
	if not has_patrol_target:
		_pick_patrol_target()
		return
	
	var dist := global_position.distance_to(patrol_target)
	if dist < 5.0:
		has_patrol_target = false
		patrol_pause_timer = randf_range(PATROL_PAUSE_MIN, PATROL_PAUSE_MAX)
		return
	
	var direction := global_position.direction_to(patrol_target)
	velocity = direction * PATROL_SPEED
	move_and_slide()
	_update_facing()


func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var radius := randf() * PATROL_RADIUS
	patrol_target = guard_position + Vector2(cos(angle), sin(angle)) * radius
	has_patrol_target = true


func _check_aggro() -> void:
	for unit in SwarmManager.units:
		if not is_instance_valid(unit):
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist < AGGRO_RADIUS:
			is_aggro = true
			_play_aggro_effect()
			return


func _play_aggro_effect() -> void:
	var tween := create_tween()
	tween.tween_property(enemy_visual, "modulate", Color.PURPLE, 0.1)
	tween.tween_property(enemy_visual, "modulate", Color.WHITE, 0.1)


func _shoot_projectile(target: Node2D) -> void:
	var projectile := ColorRect.new()
	projectile.size = Vector2(6, 6)
	projectile.color = Color(0.6, 0.2, 0.8)
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
		var dist := projectile_container.global_position.distance_to(target.global_position)
		if dist < 20.0:
			target.take_damage(PROJECTILE_DAMAGE)
	projectile_container.queue_free()
