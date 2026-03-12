extends "res://scenes/dungeon/RoomBase.gd"

const SPAWN_STAGGER_DELAY: float = 0.5

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var DireHoundScene := preload("res://scenes/entities/enemies/DireHound.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var enemy_spawns: Array[Marker2D] = [
	$EnemySpawnPoint1, $EnemySpawnPoint2, $EnemySpawnPoint3,
	$EnemySpawnPoint4, $EnemySpawnPoint5
]


func _ready() -> void:
	super._ready()
	_place_damage_zones()


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	RunManager.set_room_enemy_count(5)
	for i in 5:
		var enemy := DireHoundScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns[i].global_position
		enemy.global_position = spawn_pos
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < 4:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _place_damage_zones() -> void:
	var positions: Array[Vector2] = [
		Vector2(200, 250), Vector2(500, 350), Vector2(350, 180)
	]
	for pos in positions:
		var zone := DamageZoneScene.instantiate()
		zone.zone_size = Vector2(64, 64)
		zone.global_position = pos
		add_child(zone)
