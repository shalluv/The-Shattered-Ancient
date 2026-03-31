extends "res://scenes/dungeon/RoomBase.gd"

const BASE_ENEMY_COUNT: int = 8
const BUILDING_COLOR: Color = Color("#2a2a2a")

var difficulty: Dictionary = {}
const SAFE_ZONE_COLOR: Color = Color("#1a3a1a")

var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")
var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")
var ArcherVillagerScene := preload("res://scenes/entities/ArcherVillager.tscn")
var MageVillagerScene := preload("res://scenes/entities/MageVillager.tscn")
var PriestVillagerScene := preload("res://scenes/entities/PriestVillager.tscn")
var StationaryGuardScene := preload("res://scenes/entities/enemies/StationaryGuard.tscn")
var DirePriestScene := preload("res://scenes/entities/enemies/DirePriest.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint

@onready var enemy_spawns_layer1: Array[Marker2D] = [$EnemyLayer1_1, $EnemyLayer1_2]
@onready var enemy_spawns_layer2: Array[Marker2D] = [$EnemyLayer2_1, $EnemyLayer2_2]
@onready var enemy_spawns_layer3: Array[Marker2D] = [$EnemyLayer3_1, $EnemyLayer3_2]
@onready var entrance_guards: Array[Marker2D] = [$EntranceGuard1, $EntranceGuard2]

@onready var villager_spawns: Array[Marker2D] = [
	$VillagerSpawn1, $VillagerSpawn2, $VillagerSpawn3,
	$VillagerSpawn4, $VillagerSpawn5, $VillagerSpawn6
]

var safe_zone_pos: Vector2 = Vector2(512, 130)
var safe_zone_size: Vector2 = Vector2(700, 120)


func _ready() -> void:
	super._ready()
	_setup_initial_enemy_count()
	_spawn_safe_zone_visual()
	_spawn_terrain_zones()
	_add_safe_zone_walls()


func _setup_initial_enemy_count() -> void:
	difficulty = RunManager.get_village_difficulty()
	var extra_enemies: int = difficulty.get("extra_enemies", 0)
	var extra_priests: int = difficulty.get("extra_priests", 0)
	var total_enemies: int = BASE_ENEMY_COUNT + extra_enemies + extra_priests  # No base priest
	RunManager.set_room_enemy_count(total_enemies)


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	difficulty = RunManager.get_village_difficulty()
	var extra_enemies: int = difficulty.get("extra_enemies", 0)
	var extra_priests: int = difficulty.get("extra_priests", 0)
	
	for spawn in enemy_spawns_layer1:
		var grunt := DireGruntScene.instantiate()
		grunt.global_position = spawn.global_position
		entities.add_child(grunt)
		_play_spawn_particles(spawn.global_position)
	
	for spawn in enemy_spawns_layer2:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
	for spawn in enemy_spawns_layer3:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
	for spawn in entrance_guards:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
	# Spawn priests based on difficulty (0->1->2)
	for i in extra_priests:
		var priest := DirePriestScene.instantiate()
		var x_pos := 512.0 if i == 0 else (350.0 if i == 1 else 674.0)
		var y_pos := 200.0 if i == 0 else 250.0  # Above damage zone (lava)
		priest.global_position = Vector2(x_pos, y_pos)
		entities.add_child(priest)
		_play_spawn_particles(priest.global_position)
	
	# Spawn extra guards for higher difficulty
	for i in extra_enemies:
		var extra_guard := StationaryGuardScene.instantiate()
		var spawn_pos := Vector2(
			randf_range(250, 774),
			randf_range(350, 550)
		)
		extra_guard.global_position = spawn_pos
		entities.add_child(extra_guard)
	
	_spawn_villagers()


func _spawn_villagers() -> void:
	var villager_scenes: Array[PackedScene] = [
		MageVillagerScene,
		PriestVillagerScene,
		ArcherVillagerScene,
		ArcherVillagerScene,
		NeutralVillagerScene,
		NeutralVillagerScene
	]
	
	for i in villager_spawns.size():
		var villager: Node2D = villager_scenes[i].instantiate()
		villager.global_position = villager_spawns[i].global_position
		entities.add_child(villager)


func _spawn_safe_zone_visual() -> void:
	var safe_visual := ColorRect.new()
	safe_visual.position = safe_zone_pos - safe_zone_size / 2.0
	safe_visual.size = safe_zone_size
	safe_visual.color = SAFE_ZONE_COLOR
	safe_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_visual.z_index = -1
	add_child(safe_visual)
	
	var border := ColorRect.new()
	border.position = Vector2(safe_zone_pos.x - safe_zone_size.x / 2.0, safe_zone_pos.y + safe_zone_size.y / 2.0 - 4)
	border.size = Vector2(safe_zone_size.x, 8)
	border.color = BUILDING_COLOR
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)


func _spawn_terrain_zones() -> void:
	var slow_zone := SlowZoneScene.instantiate()
	slow_zone.global_position = Vector2(512, 580)
	if slow_zone.has_method("set_zone_size"):
		slow_zone.set_zone_size(Vector2(500, 80))
	else:
		slow_zone.scale = Vector2(5.0, 0.8)
	add_child(slow_zone)
	
	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.global_position = Vector2(512, 320)
	if damage_zone.has_method("set_zone_size"):
		damage_zone.set_zone_size(Vector2(500, 60))
	else:
		damage_zone.scale = Vector2(5.0, 0.6)
	add_child(damage_zone)


func _add_safe_zone_walls() -> void:
	var walls_node := $Walls
	
	var left_wall_pos := Vector2(safe_zone_pos.x - safe_zone_size.x / 2.0 - 20, safe_zone_pos.y)
	var right_wall_pos := Vector2(safe_zone_pos.x + safe_zone_size.x / 2.0 + 20, safe_zone_pos.y)
	var wall_size := Vector2(40, safe_zone_size.y)
	
	_add_wall_body(walls_node, left_wall_pos, wall_size)
	_add_wall_body(walls_node, right_wall_pos, wall_size)
	
	var left_visual := ColorRect.new()
	left_visual.position = left_wall_pos - wall_size / 2.0
	left_visual.size = wall_size
	left_visual.color = BUILDING_COLOR
	left_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_visual)
	
	var right_visual := ColorRect.new()
	right_visual.position = right_wall_pos - wall_size / 2.0
	right_visual.size = wall_size
	right_visual.color = BUILDING_COLOR
	right_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_visual)
	
	var bottom_wall_pos := Vector2(safe_zone_pos.x, safe_zone_pos.y + safe_zone_size.y / 2.0 + 4)
	var bottom_wall_size := Vector2(safe_zone_size.x, 8)
	_add_wall_body(walls_node, bottom_wall_pos, bottom_wall_size)
	
	var wall_rects: Array[Rect2] = [
		Rect2(left_wall_pos - wall_size / 2.0, wall_size),
		Rect2(right_wall_pos - wall_size / 2.0, wall_size),
		Rect2(bottom_wall_pos - bottom_wall_size / 2.0, bottom_wall_size)
	]
	Pathfinder.add_obstacles(wall_rects)
