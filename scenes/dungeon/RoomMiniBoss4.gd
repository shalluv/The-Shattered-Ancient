extends "res://scenes/dungeon/RoomMiniBoss.gd"

## Dark Ritual — DireCaptain + DirePriest + 2 grunts + 3 neutral villagers
## Race to convert neutrals before the enemy priest does.

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")
var DirePriestScene := preload("res://scenes/entities/enemies/DirePriest.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var enemy_spawn_left: Marker2D = $EnemySpawnLeft
@onready var enemy_spawn_right: Marker2D = $EnemySpawnRight
@onready var enemy_spawn_center: Marker2D = $EnemySpawnCenter
@onready var villager_spawn_1: Marker2D = $VillagerSpawn1
@onready var villager_spawn_2: Marker2D = $VillagerSpawn2
@onready var villager_spawn_3: Marker2D = $VillagerSpawn3


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var priest := DirePriestScene.instantiate()
	priest.global_position = enemy_spawn_left.global_position
	entities.add_child(priest)

	var grunt1 := DireGruntScene.instantiate()
	grunt1.global_position = enemy_spawn_right.global_position
	entities.add_child(grunt1)

	var grunt2 := DireGruntScene.instantiate()
	grunt2.global_position = enemy_spawn_center.global_position
	entities.add_child(grunt2)

	RunManager.set_room_enemy_count(4)
	captain_instance.captain_defeated.connect(_on_captain_defeated)
	_create_ambient_particles_colored(Color(0.4, 0.0, 0.545, 0.2))

	# Spawn neutral villagers for the priest to contest
	var spawns: Array[Marker2D] = [villager_spawn_1, villager_spawn_2, villager_spawn_3]
	for spawn in spawns:
		var villager := NeutralVillagerScene.instantiate()
		villager.global_position = spawn.global_position
		entities.add_child(villager)


func _spawn_terrain_zones() -> void:
	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.global_position = boss_spawn.global_position + Vector2(0, 80)
	add_child(damage_zone)

	var slow_zone := SlowZoneScene.instantiate()
	slow_zone.global_position = Vector2(512, 450)
	add_child(slow_zone)
