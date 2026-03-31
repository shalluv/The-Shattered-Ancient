extends CharacterBody2D

signal caravan_reached_exit
signal caravan_destroyed
signal villager_died

const CARAVAN_COLOR: Color = Color("#8B4513")
const CARAVAN_SIZE: Vector2 = Vector2(40, 24)
const MOVE_SPEED: float = 40.0
const STUN_DURATION: float = 1.5

@export var max_villagers: int = 6
@export var hits_per_villager: int = 3

var villagers_remaining: int = 6
var current_hits: int = 0
var is_stunned: bool = false
var stun_timer: float = 0.0
var is_destroyed: bool = false
var has_reached_exit: bool = false

var path_points: PackedVector2Array = PackedVector2Array()
var current_path_index: int = 0

@onready var caravan_visual: ColorRect = $CaravanVisual
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar: ColorRect = $HPBar

var villager_label: Label = null


func _ready() -> void:
	villagers_remaining = max_villagers
	add_to_group("caravan")
	_create_villager_label()
	_update_hp_bar()


func set_path(points: PackedVector2Array) -> void:
	path_points = points
	current_path_index = 0


func _physics_process(delta: float) -> void:
	if is_destroyed or has_reached_exit:
		return
	
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stunned = false
			caravan_visual.color = CARAVAN_COLOR
		return
	
	if path_points.is_empty():
		return
	
	if current_path_index >= path_points.size():
		_reach_exit()
		return
	
	var target := path_points[current_path_index]
	var dist := global_position.distance_to(target)
	
	if dist < 10.0:
		current_path_index += 1
		if current_path_index >= path_points.size():
			_reach_exit()
			return
		target = path_points[current_path_index]
	
	var direction := global_position.direction_to(target)
	velocity = direction * MOVE_SPEED
	move_and_slide()


func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	
	current_hits += amount
	_flash_damage()
	
	if current_hits >= hits_per_villager:
		current_hits = 0
		villagers_remaining -= 1
		villager_died.emit()
		_update_hp_bar()
		
		if villagers_remaining <= 0:
			_destroy()
			return
	
	is_stunned = true
	stun_timer = STUN_DURATION


func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(caravan_visual, "color", Color.RED, 0.1)
	tween.tween_property(caravan_visual, "color", CARAVAN_COLOR, 0.1)


func _update_hp_bar() -> void:
	var hp_ratio := float(villagers_remaining) / float(max_villagers)
	hp_bar.size.x = hp_bar_bg.size.x * hp_ratio
	
	if hp_ratio > 0.5:
		hp_bar.color = Color.GREEN
	elif hp_ratio > 0.25:
		hp_bar.color = Color.YELLOW
	else:
		hp_bar.color = Color.RED
	
	if villager_label:
		villager_label.text = str(villagers_remaining)


func _reach_exit() -> void:
	has_reached_exit = true
	caravan_reached_exit.emit()
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _destroy() -> void:
	is_destroyed = true
	caravan_destroyed.emit()
	_play_destruction_particles()
	
	RunManager.end_run(false)
	
	var tween := create_tween()
	tween.tween_property(caravan_visual, "color", Color(0.2, 0.1, 0.05), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _has_player_unit_nearby() -> bool:
	var overwatch_range := 120.0
	
	# Check SwarmManager units
	for unit in SwarmManager.units:
		if is_instance_valid(unit) and unit.global_position.distance_to(global_position) <= overwatch_range:
			return true
	
	# Check SwarmManager reviving units
	for unit in SwarmManager.reviving_units:
		if is_instance_valid(unit) and unit.global_position.distance_to(global_position) <= overwatch_range:
			return true
	
	return false


func _play_destruction_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 50, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.545, 0.27, 0.07, 1.0)
	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	add_child(particles)


func _create_villager_label() -> void:
	villager_label = Label.new()
	villager_label.text = str(villagers_remaining)
	villager_label.add_theme_font_size_override("font_size", 12)
	villager_label.add_theme_color_override("font_color", Color.WHITE)
	villager_label.position = Vector2(-6, -8)
	add_child(villager_label)


func get_villagers_remaining() -> int:
	return villagers_remaining
