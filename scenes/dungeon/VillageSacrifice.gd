extends "res://scenes/dungeon/RoomBase.gd"

const BASE_ENEMY_COUNT: int = 8
const ALTAR_COLOR: Color = Color("#3a1a1a")
const BUILDING_COLOR: Color = Color("#2a2a2a")
const BASE_SACRIFICE_TIME: float = 30.0
const RESCUE_RADIUS: float = 50.0
const RESCUE_TIME: float = 2.0

var difficulty: Dictionary = {}
var sacrifice_time: float = BASE_SACRIFICE_TIME
var rescue_timers: Array[float] = []

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")
var MageVillagerScene := preload("res://scenes/entities/MageVillager.tscn")
var PriestVillagerScene := preload("res://scenes/entities/PriestVillager.tscn")
var StationaryGuardScene := preload("res://scenes/entities/enemies/StationaryGuard.tscn")
var RangedGuardScene := preload("res://scenes/entities/enemies/RangedGuard.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint

@onready var altar_spawns: Array[Marker2D] = [$AltarSpawn1, $AltarSpawn2, $AltarSpawn3]
@onready var melee_guard_spawns: Array[Marker2D] = [$GuardSpawn1, $GuardSpawn3, $GuardSpawn5]
@onready var ranged_guard_spawns: Array[Marker2D] = [$GuardSpawn2, $GuardSpawn4, $GuardSpawn6]
@onready var aggressive_spawns: Array[Marker2D] = [$AggressiveSpawn1, $AggressiveSpawn2]

var bound_villagers: Array[Node2D] = []
var sacrifice_timers: Array[float] = []
var timer_labels: Array[Label] = []
var rescue_progress_bars: Array[ColorRect] = []
var rescue_progress_bgs: Array[ColorRect] = []

var altar_positions: Array[Vector2] = [
	Vector2(512, 150),
	Vector2(250, 350),
	Vector2(774, 350)
]
var altar_sizes: Array[Vector2] = [
	Vector2(40, 30),
	Vector2(40, 30),
	Vector2(40, 30)
]


func _ready() -> void:
	super._ready()
	_setup_initial_enemy_count()
	_spawn_altars()
	_spawn_damage_zone()


func _setup_initial_enemy_count() -> void:
	difficulty = RunManager.get_village_difficulty()
	var extra_enemies: int = difficulty.get("extra_enemies", 0)
	var total_enemies: int = BASE_ENEMY_COUNT + extra_enemies
	RunManager.set_room_enemy_count(total_enemies)


func _process(delta: float) -> void:
	super._process(delta)
	_update_sacrifice_timers(delta)


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	difficulty = RunManager.get_village_difficulty()
	var extra_enemies: int = difficulty.get("extra_enemies", 0)
	var timer_reduction: float = difficulty.get("timer_reduction", 0.0)
	sacrifice_time = BASE_SACRIFICE_TIME - timer_reduction
	
	for spawn in melee_guard_spawns:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
	for spawn in ranged_guard_spawns:
		var ranged := RangedGuardScene.instantiate()
		ranged.global_position = spawn.global_position
		entities.add_child(ranged)
	
	for spawn in aggressive_spawns:
		var grunt := DireGruntScene.instantiate()
		grunt.global_position = spawn.global_position
		entities.add_child(grunt)
		_play_spawn_particles(spawn.global_position)
	
	# Spawn extra guards for higher difficulty
	for i in extra_enemies:
		var extra_guard := StationaryGuardScene.instantiate()
		var spawn_pos := Vector2(
			randf_range(200, 824),
			randf_range(250, 450)
		)
		extra_guard.global_position = spawn_pos
		entities.add_child(extra_guard)
	
	_spawn_villagers()


func _spawn_villagers() -> void:
	var altar_villager_scenes: Array[PackedScene] = [
		PriestVillagerScene,
		MageVillagerScene,
		MageVillagerScene
	]
	
	for i in altar_spawns.size():
		var villager: Node2D = altar_villager_scenes[i].instantiate()
		villager.global_position = altar_spawns[i].global_position
		villager.z_index = 10
		entities.add_child(villager)
		
		villager.is_bound = true
		bound_villagers.append(villager)
		sacrifice_timers.append(sacrifice_time)
		rescue_timers.append(0.0)
		
		var timer_label := Label.new()
		timer_label.text = str(int(sacrifice_time))
		timer_label.add_theme_font_size_override("font_size", 16)
		timer_label.add_theme_color_override("font_color", Color.RED)
		timer_label.z_index = 100
		entities.add_child(timer_label)
		timer_labels.append(timer_label)
		
		var progress_bg := ColorRect.new()
		progress_bg.size = Vector2(30, 6)
		progress_bg.color = Color(0.2, 0.2, 0.2, 0.8)
		progress_bg.z_index = 100
		progress_bg.visible = false
		entities.add_child(progress_bg)
		rescue_progress_bgs.append(progress_bg)
		
		var progress_bar := ColorRect.new()
		progress_bar.size = Vector2(0, 4)
		progress_bar.color = Color(0.2, 0.8, 0.2, 1.0)
		progress_bar.z_index = 101
		progress_bar.visible = false
		entities.add_child(progress_bar)
		rescue_progress_bars.append(progress_bar)


func _update_sacrifice_timers(delta: float) -> void:
	for i in bound_villagers.size():
		var villager = bound_villagers[i]
		if not is_instance_valid(villager):
			if i < timer_labels.size() and timer_labels[i]:
				timer_labels[i].visible = false
			_hide_rescue_progress(i)
			continue
		
		if not villager.is_bound:
			if i < timer_labels.size() and timer_labels[i]:
				timer_labels[i].visible = false
			continue
		
		if i < timer_labels.size() and timer_labels[i]:
			timer_labels[i].global_position = villager.global_position + Vector2(-10, -30)
		
		var player_nearby := _is_player_nearby(villager.global_position)
		if player_nearby:
			rescue_timers[i] += delta
			_update_rescue_progress(i, villager, true)
			if rescue_timers[i] >= RESCUE_TIME:
				villager.is_bound = false
				if i < timer_labels.size() and timer_labels[i]:
					timer_labels[i].visible = false
				_hide_rescue_progress(i)
				continue
		else:
			rescue_timers[i] = 0.0
			_update_rescue_progress(i, villager, false)
		
		sacrifice_timers[i] -= delta
		if i < timer_labels.size() and timer_labels[i]:
			timer_labels[i].text = str(int(sacrifice_timers[i]))
			if sacrifice_timers[i] < 5:
				timer_labels[i].add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		
		if sacrifice_timers[i] <= 0:
			villager.die()
			if i < timer_labels.size() and timer_labels[i]:
				timer_labels[i].visible = false


func _is_player_nearby(pos: Vector2) -> bool:
	for unit in SwarmManager.units:
		if is_instance_valid(unit):
			if unit.global_position.distance_to(pos) < RESCUE_RADIUS:
				return true
	return false


func _update_rescue_progress(idx: int, villager: Node2D, show: bool) -> void:
	if idx >= rescue_progress_bars.size() or idx >= rescue_progress_bgs.size():
		return
	
	var progress_bg := rescue_progress_bgs[idx]
	var progress_bar := rescue_progress_bars[idx]
	
	if not show:
		progress_bg.visible = false
		progress_bar.visible = false
		return
	
	progress_bg.visible = true
	progress_bar.visible = true
	
	var bar_pos := villager.global_position + Vector2(-15, 15)
	progress_bg.global_position = bar_pos
	progress_bar.global_position = bar_pos + Vector2(0, 1)
	
	var progress := rescue_timers[idx] / RESCUE_TIME
	progress_bar.size.x = 30.0 * progress


func _hide_rescue_progress(idx: int) -> void:
	if idx < rescue_progress_bars.size():
		rescue_progress_bars[idx].visible = false
	if idx < rescue_progress_bgs.size():
		rescue_progress_bgs[idx].visible = false


func _spawn_altars() -> void:
	var walls_node := $Walls
	
	for i in altar_positions.size():
		var pos: Vector2 = altar_positions[i]
		var asize: Vector2 = altar_sizes[i]
		
		var altar_visual := ColorRect.new()
		altar_visual.position = pos - asize / 2.0
		altar_visual.size = asize
		altar_visual.color = ALTAR_COLOR
		altar_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		altar_visual.add_to_group("altars")
		add_child(altar_visual)
		
		var glow := ColorRect.new()
		glow.position = pos - asize / 2.0 - Vector2(4, 4)
		glow.size = asize + Vector2(8, 8)
		glow.color = Color(0.6, 0.1, 0.1, 0.3)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.z_index = -1
		add_child(glow)
	
	var altar_rects: Array[Rect2] = []
	for i in altar_positions.size():
		var pos: Vector2 = altar_positions[i]
		var asize: Vector2 = altar_sizes[i]
		altar_rects.append(Rect2(pos - asize / 2.0, asize))
	Pathfinder.add_obstacles(altar_rects)


func _spawn_damage_zone() -> void:
	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.zone_size = Vector2(700, 60)
	damage_zone.global_position = Vector2(512, 480)
	add_child(damage_zone)
