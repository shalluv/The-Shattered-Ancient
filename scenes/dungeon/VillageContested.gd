extends "res://scenes/dungeon/RoomBase.gd"

const BUILDING_COLOR: Color = Color("#2a2a2a")

var difficulty: Dictionary = {}

var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")
var ArcherVillagerScene := preload("res://scenes/entities/ArcherVillager.tscn")
var DirePriestScene := preload("res://scenes/entities/enemies/DirePriest.tscn")
var StationaryGuardScene := preload("res://scenes/entities/enemies/StationaryGuard.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var dire_priest_spawns: Array[Marker2D] = [$DirePriestSpawn1, $DirePriestSpawn2]
@onready var guard_spawns: Array[Marker2D] = [$GuardSpawn1, $GuardSpawn2, $GuardSpawn3, $GuardSpawn4]
@onready var aggressive_spawns: Array[Marker2D] = [$AggressiveSpawn1, $AggressiveSpawn2]
@onready var villager_spawns_left: Array[Marker2D] = [
	$VillagerLeft1, $VillagerLeft2, $VillagerLeft3, $VillagerLeft4
]
@onready var villager_spawns_right: Array[Marker2D] = [
	$VillagerRight1, $VillagerRight2, $VillagerRight3, $VillagerRight4
]

var building_positions: Array[Vector2] = [
	Vector2(150, 220), Vector2(874, 220),
	Vector2(150, 550), Vector2(874, 550)
]
var building_sizes: Array[Vector2] = [
	Vector2(60, 50), Vector2(60, 50),
	Vector2(60, 50), Vector2(60, 50)
]


func _ready() -> void:
	super._ready()
	_setup_initial_enemy_count()
	_spawn_buildings()
	_spawn_slow_zone()
	_add_building_obstacles()


func _setup_initial_enemy_count() -> void:
	difficulty = RunManager.get_village_difficulty()
	var extra_enemies: int = difficulty.get("extra_enemies", 0)
	var extra_priests: int = difficulty.get("extra_priests", 0)
	var total_priests: int = 1 + extra_priests  # Base 1 priest + scaling
	var base_count: int = 7  # 1 priest + 4 guards + 2 grunts (removed 2 base priests)
	var total_enemies: int = base_count + extra_enemies + extra_priests
	RunManager.set_room_enemy_count(total_enemies)


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	difficulty = RunManager.get_village_difficulty()
	var extra_enemies: int = difficulty.get("extra_enemies", 0)
	var extra_priests: int = difficulty.get("extra_priests", 0)
	var total_priests: int = 1 + extra_priests  # Base 1 priest + scaling
	
	# Spawn base priest at center (avoid water)
	var priest := DirePriestScene.instantiate()
	priest.global_position = Vector2(512, 250)  # Above water zone
	entities.add_child(priest)
	_play_spawn_particles(priest.global_position)
	
	# Spawn extra priests for higher difficulty (avoid water zones)
	for i in extra_priests:
		var scaled_priest := DirePriestScene.instantiate()
		var x_pos := 350.0 if i == 0 else 674.0
		scaled_priest.global_position = Vector2(x_pos, 250)  # Above water zone
		entities.add_child(scaled_priest)
		_play_spawn_particles(scaled_priest.global_position)
	
	for spawn in guard_spawns:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
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
			randf_range(250, 550)
		)
		extra_guard.global_position = spawn_pos
		entities.add_child(extra_guard)
	
	_spawn_villagers()


func _spawn_villagers() -> void:
	for i in villager_spawns_left.size():
		var villager: Node2D
		if i == 1:
			villager = ArcherVillagerScene.instantiate()
		else:
			villager = NeutralVillagerScene.instantiate()
		villager.global_position = villager_spawns_left[i].global_position
		entities.add_child(villager)
	
	for i in villager_spawns_right.size():
		var villager: Node2D
		if i == 2:
			villager = ArcherVillagerScene.instantiate()
		else:
			villager = NeutralVillagerScene.instantiate()
		villager.global_position = villager_spawns_right[i].global_position
		entities.add_child(villager)


func _spawn_buildings() -> void:
	var walls_node := $Walls
	for i in building_positions.size():
		var pos: Vector2 = building_positions[i]
		var bsize: Vector2 = building_sizes[i]
		
		var visual := ColorRect.new()
		visual.position = pos - bsize / 2.0
		visual.size = bsize
		visual.color = BUILDING_COLOR
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		
		_add_wall_body(walls_node, pos, bsize)


func _spawn_slow_zone() -> void:
	var slow_zone := SlowZoneScene.instantiate()
	slow_zone.global_position = Vector2(512, 400)
	if slow_zone.has_method("set_zone_size"):
		slow_zone.set_zone_size(Vector2(600, 100))
	else:
		slow_zone.scale = Vector2(6.0, 1.0)
	add_child(slow_zone)


func _add_building_obstacles() -> void:
	var building_rects: Array[Rect2] = []
	for i in building_positions.size():
		var pos: Vector2 = building_positions[i]
		var bsize: Vector2 = building_sizes[i]
		building_rects.append(Rect2(pos - bsize / 2.0, bsize))
	Pathfinder.add_obstacles(building_rects)
