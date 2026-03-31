extends "res://scenes/dungeon/RoomMiniBoss.gd"

## Formation — DireCaptain + SpearwallGroup, no terrain
## Tactical fight — player must break the formation.

var SpearwallGroupScene := preload("res://scenes/entities/enemies/SpearwallGroup.tscn")

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var formation_spawn: Marker2D = $FormationSpawn


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var spearwall := SpearwallGroupScene.instantiate()
	spearwall.global_position = formation_spawn.global_position
	entities.add_child(spearwall)

	RunManager.set_room_enemy_count(4)
	captain_instance.captain_defeated.connect(_on_captain_defeated)
	_create_ambient_particles_colored(Color(0.545, 0.4, 0.0, 0.2))


func _spawn_terrain_zones() -> void:
	# No terrain — pure tactical fight
	pass
