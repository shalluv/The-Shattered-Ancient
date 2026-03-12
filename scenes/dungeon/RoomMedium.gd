extends "res://scenes/dungeon/RoomBase.gd"

const ENEMY_COUNT: int = 3
const VILLAGER_COUNT: int = 4
const SPAWN_STAGGER_DELAY: float = 0.5

const BUILDING_COLOR: Color = Color("#2a2a2a")
const BUILDING_POSITIONS: Array[Vector2] = [
	Vector2(300, 280), Vector2(500, 250), Vector2(700, 300)
]
const BUILDING_SIZES: Array[Vector2] = [
	Vector2(40, 40), Vector2(50, 35), Vector2(35, 45)
]

var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")
var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")
var DirePriestScene := preload("res://scenes/entities/enemies/DirePriest.tscn")
var DireHoundScene := preload("res://scenes/entities/enemies/DireHound.tscn")
var SpearwallGroupScene := preload("res://scenes/entities/enemies/SpearwallGroup.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var enemy_spawns: Array[Marker2D] = [
	$EnemySpawnPoint1, $EnemySpawnPoint2, $EnemySpawnPoint3
]
@onready var villager_spawns: Array[Marker2D] = [
	$VillagerSpawnPoint1, $VillagerSpawnPoint2,
	$VillagerSpawnPoint3, $VillagerSpawnPoint4
]


func _ready() -> void:
	super._ready()
	_spawn_buildings()
	_spawn_terrain_zones()
	var building_rects: Array[Rect2] = []
	for i in BUILDING_POSITIONS.size():
		var pos: Vector2 = BUILDING_POSITIONS[i]
		var bsize: Vector2 = BUILDING_SIZES[i]
		building_rects.append(Rect2(pos - bsize / 2.0, bsize))
	Pathfinder.add_obstacles(building_rects)


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	var roll := randf()
	if roll < 0.3:
		var priest := DirePriestScene.instantiate()
		priest.global_position = enemy_spawns[0].global_position
		entities.add_child(priest)
		_play_spawn_particles(enemy_spawns[0].global_position)

		var grunt_count: int = 2
		var grunt_spawns: Array[Marker2D] = [enemy_spawns[1], enemy_spawns[2]]
		RunManager.set_room_enemy_count(1 + grunt_count)
		for i in grunt_count:
			var grunt := DireGruntScene.instantiate()
			grunt.global_position = grunt_spawns[i].global_position
			entities.add_child(grunt)
			_play_spawn_particles(grunt_spawns[i].global_position)
			if i < grunt_count - 1:
				await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout
	elif roll < 0.6:
		_spawn_enemies_staggered(DireGruntScene, enemy_spawns, ENEMY_COUNT, SPAWN_STAGGER_DELAY)
	elif roll < 0.8:
		RunManager.set_room_enemy_count(ENEMY_COUNT)
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawns[0].global_position
		entities.add_child(hound)
		_play_spawn_particles(enemy_spawns[0].global_position)
		for i in 2:
			var grunt := DireGruntScene.instantiate()
			grunt.global_position = enemy_spawns[i + 1].global_position
			entities.add_child(grunt)
			_play_spawn_particles(enemy_spawns[i + 1].global_position)
			if i < 1:
				await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout
	else:
		RunManager.set_room_enemy_count(ENEMY_COUNT)
		var spearwall_group := SpearwallGroupScene.instantiate()
		spearwall_group.global_position = enemy_spawns[1].global_position
		entities.add_child(spearwall_group)
		_play_spawn_particles(enemy_spawns[1].global_position)
	_spawn_villagers()


func _spawn_villagers() -> void:
	for i in VILLAGER_COUNT:
		var villager := NeutralVillagerScene.instantiate()
		villager.global_position = villager_spawns[i % villager_spawns.size()].global_position
		entities.add_child(villager)


func _spawn_buildings() -> void:
	var walls_node := $Walls
	for i in BUILDING_POSITIONS.size():
		var pos: Vector2 = BUILDING_POSITIONS[i]
		var bsize: Vector2 = BUILDING_SIZES[i]

		# TODO: Replace with village building art asset
		var visual := ColorRect.new()
		visual.position = pos - bsize / 2.0
		visual.size = bsize
		visual.color = BUILDING_COLOR
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)

		_add_wall_body(walls_node, pos, bsize)


func _spawn_terrain_zones() -> void:
	var slow_zone := SlowZoneScene.instantiate()
	slow_zone.global_position = Vector2(350, 300)
	add_child(slow_zone)

	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.global_position = Vector2(650, 320)
	add_child(damage_zone)
