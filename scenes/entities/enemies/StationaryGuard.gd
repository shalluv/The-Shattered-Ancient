extends "res://scenes/entities/enemies/EnemyBase.gd"

const GUARD_COLOR: Color = Color("#5a3a3a")
const AGGRO_RADIUS: float = 100.0
const PATROL_RADIUS: float = 40.0
const PATROL_SPEED: float = 12.5
const PATROL_PAUSE_MIN: float = 1.0
const PATROL_PAUSE_MAX: float = 2.5

var is_aggro: bool = false
var guard_position: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var patrol_pause_timer: float = 0.0
var has_patrol_target: bool = false


func _ready() -> void:
	enemy_hp = 2
	move_speed = 40.0
	damage = 1
	enemy_color = GUARD_COLOR
	super._ready()
	enemy_visual.color = GUARD_COLOR
	guard_position = global_position
	_pick_patrol_target()


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	
	if not is_aggro:
		_check_aggro()
		_patrol(delta)
		return
	
	super._physics_process(delta)


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
	tween.tween_property(enemy_visual, "color", Color.RED, 0.1)
	tween.tween_property(enemy_visual, "color", GUARD_COLOR, 0.1)
