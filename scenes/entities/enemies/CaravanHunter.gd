extends "res://scenes/entities/enemies/EnemyBase.gd"

const HUNTER_COLOR: Color = Color("#4a2a1a")
const HUNTER_SPEED: float = 100.0
const HUNTER_HP: int = 2
const HUNTER_DAMAGE: int = 1
const HUNTER_ATTACK_COOLDOWN: float = 1.0
const HUNTER_PATH_RECALC: float = 0.3
const RANGED_ATTACK_RANGE: float = 120.0
const PROJECTILE_SPEED: float = 180.0

var attack_timer: float = 0.0
var caravan_target: Node2D = null


func _ready() -> void:
	enemy_hp = HUNTER_HP
	move_speed = HUNTER_SPEED
	damage = HUNTER_DAMAGE
	enemy_color = HUNTER_COLOR
	super._ready()  # Call super first to set up hitbox connections
	collision_layer = 2  # enemies layer
	collision_mask = 1   # can collide with swarm_units
	enemy_visual.color = HUNTER_COLOR
	_find_caravan()


func _find_caravan() -> void:
	var caravans := get_tree().get_nodes_in_group("caravan")
	if caravans.size() > 0:
		caravan_target = caravans[0]


func _on_hitbox_area_entered(other_area: Area2D) -> void:
	# CaravanHunter only receives damage, doesn't deal melee damage
	if not can_deal_damage or is_dying:
		return
	
	var unit := other_area.get_parent()
	if unit.has_method("take_damage"):
		# Only take damage, don't deal damage back
		var hit_damage: int = 1
		if unit.has_method("get_effective_damage"):
			hit_damage = unit.get_effective_damage()
		take_hit(hit_damage)
		# Don't set can_deal_damage = false (no melee cooldown)
		# Don't deal damage back to unit


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_update_slow_state(delta)
	var effective_speed := move_speed * speed_multiplier
	var separation := _calculate_separation_force()

	if not is_instance_valid(caravan_target):
		_find_caravan()
		if not is_instance_valid(caravan_target):
			velocity = separation
			if velocity.length_squared() > 0.1:
				move_and_slide()
			return

	var direction := global_position.direction_to(caravan_target.global_position)
	var dist := global_position.distance_to(caravan_target.global_position)
	
	if dist < RANGED_ATTACK_RANGE:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_shoot_caravan()
			attack_timer = HUNTER_ATTACK_COOLDOWN
		velocity = separation
	else:
		path_recalc_timer -= delta
		if current_path.is_empty() or path_recalc_timer <= 0.0:
			current_path = Pathfinder.find_path(global_position, caravan_target.global_position)
			path_index = 0
			_advance_path_index_enemy()
			path_recalc_timer = HUNTER_PATH_RECALC
		if not _follow_path_enemy(effective_speed, separation):
			velocity = direction * effective_speed + separation
	
	move_and_slide()


func _shoot_caravan() -> void:
	if not is_instance_valid(caravan_target):
		return
	
	_play_attack_effect()
	
	var projectile := ColorRect.new()
	projectile.size = Vector2(8, 8)
	projectile.color = Color(0.8, 0.4, 0.1)
	projectile.position = Vector2(-4, -4)
	
	var container := Node2D.new()
	container.global_position = global_position
	container.z_index = 5
	get_parent().add_child(container)
	container.add_child(projectile)
	
	var target_pos := caravan_target.global_position
	var tween := create_tween()
	var travel_time := global_position.distance_to(target_pos) / PROJECTILE_SPEED
	tween.tween_property(container, "global_position", target_pos, travel_time)
	tween.tween_callback(func():
		_on_projectile_hit(container)
	)


func _on_projectile_hit(projectile_container: Node2D) -> void:
	if is_instance_valid(caravan_target) and caravan_target.has_method("take_damage"):
		caravan_target.take_damage(damage)
	projectile_container.queue_free()


func _play_attack_effect() -> void:
	var tween := create_tween()
	tween.tween_property(enemy_visual, "color", Color.ORANGE, 0.1)
	tween.tween_property(enemy_visual, "color", HUNTER_COLOR, 0.1)
