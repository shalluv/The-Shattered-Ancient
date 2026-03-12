extends "res://scenes/dungeon/RoomBase.gd"

const SPAWN_STAGGER_DELAY: float = 0.5

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var enemy_spawns: Array[Marker2D] = [
	$EnemySpawnPoint1, $EnemySpawnPoint2, $EnemySpawnPoint3,
	$EnemySpawnPoint4, $EnemySpawnPoint5
]


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	var difficulty: Dictionary = RunManager.get_room_difficulty()
	var count: int = difficulty.get("enemy_count", 5)
	var hp: int = difficulty.get("enemy_hp", 1)
	var dmg: int = difficulty.get("enemy_damage", 1)
	RunManager.set_room_enemy_count(count)
	for i in count:
		var enemy := DireGruntScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns[i % enemy_spawns.size()].global_position
		enemy.global_position = spawn_pos
		enemy.enemy_hp = hp
		enemy.damage = dmg
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < count - 1:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout
