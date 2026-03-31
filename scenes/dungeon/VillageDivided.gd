extends "res://scenes/dungeon/RoomBase.gd"

const BASE_ENEMY_COUNT: int = 5
const SPAWN_STAGGER_DELAY: float = 0.3

var difficulty: Dictionary = {}

const BUILDING_COLOR: Color = Color("#2a2a2a")
const DAMAGE_ZONE_COLOR: Color = Color(0.6, 0.1, 0.1, 0.3)

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")
var ArcherVillagerScene := preload("res://scenes/entities/ArcherVillager.tscn")
var MageVillagerScene := preload("res://scenes/entities/MageVillager.tscn")
var StationaryGuardScene := preload("res://scenes/entities/enemies/StationaryGuard.tscn")
var DirePriestScene := preload("res://scenes/entities/enemies/DirePriest.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint

@onready var enemy_spawns_top: Array[Marker2D] = [$EnemySpawnTop1, $EnemySpawnTop2, $EnemySpawnTop3]
@onready var enemy_spawns_bottom: Array[Marker2D] = [$EnemySpawnBottom1, $EnemySpawnBottom2]

@onready var villager_spawns_top: Array[Marker2D] = [
	$VillagerSpawnTop1, $VillagerSpawnTop2, $VillagerSpawnTop3
]
@onready var villager_spawns_bottom: Array[Marker2D] = [
	$VillagerSpawnBottom1, $VillagerSpawnBottom2
]

var building_positions: Array[Vector2] = [
	Vector2(180, 280), Vector2(844, 280),
	Vector2(180, 488), Vector2(844, 488)
]
var building_sizes: Array[Vector2] = [
	Vector2(80, 60), Vector2(80, 60),
	Vector2(80, 60), Vector2(80, 60)
]


func _ready() -> void:
	super._ready()
	_setup_initial_enemy_count()
	_spawn_buildings()
	_spawn_damage_zone()
	_add_building_obstacles()


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
	
	# Spawn priests based on difficulty (0->1->2)
	for i in extra_priests:
		var priest := DirePriestScene.instantiate()
		var x_pos := 512.0 if i == 0 else (350.0 if i == 1 else 674.0)
		var y_pos := 200.0 if i == 0 else 250.0
		priest.global_position = Vector2(x_pos, y_pos)
		entities.add_child(priest)
		_play_spawn_particles(priest.global_position)
	
	for spawn in enemy_spawns_top:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
	for spawn in enemy_spawns_bottom:
		var guard := StationaryGuardScene.instantiate()
		guard.global_position = spawn.global_position
		entities.add_child(guard)
	
	# Spawn extra guards for higher difficulty
	for i in extra_enemies:
		var extra_guard := StationaryGuardScene.instantiate()
		var spawn_pos := Vector2(
			randf_range(200, 824),
			randf_range(150, 600) if i % 2 == 0 else randf_range(150, 600)
		)
		extra_guard.global_position = spawn_pos
		entities.add_child(extra_guard)
	
	_spawn_villagers()


func _spawn_villagers() -> void:
	var top_scenes: Array[PackedScene] = [ArcherVillagerScene, NeutralVillagerScene, ArcherVillagerScene]
	for i in villager_spawns_top.size():
		var villager: Node2D = top_scenes[i].instantiate()
		villager.global_position = villager_spawns_top[i].global_position
		entities.add_child(villager)
	
	var bottom_scenes: Array[PackedScene] = [MageVillagerScene, MageVillagerScene]
	for i in villager_spawns_bottom.size():
		var villager: Node2D = bottom_scenes[i].instantiate()
		villager.global_position = villager_spawns_bottom[i].global_position
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


func _spawn_damage_zone() -> void:
	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.global_position = Vector2(512, 384)
	if damage_zone.has_method("set_zone_size"):
		damage_zone.set_zone_size(Vector2(800, 80))
	else:
		damage_zone.scale = Vector2(8.0, 0.8)
	add_child(damage_zone)


func _add_building_obstacles() -> void:
	var building_rects: Array[Rect2] = []
	for i in building_positions.size():
		var pos: Vector2 = building_positions[i]
		var bsize: Vector2 = building_sizes[i]
		building_rects.append(Rect2(pos - bsize / 2.0, bsize))
	Pathfinder.add_obstacles(building_rects)
