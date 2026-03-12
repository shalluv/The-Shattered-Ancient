extends "res://scenes/dungeon/RoomBase.gd"

const MINIBOSS_FLOOR_COLOR: Color = Color(0.06, 0.02, 0.02)

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var DireCaptainScene := preload("res://scenes/entities/enemies/DireCaptain.tscn")
var MiniBossRewardScene := preload("res://scenes/ui/MiniBossReward.tscn")
var DireHoundScene := preload("res://scenes/entities/enemies/DireHound.tscn")

var captain_instance: CharacterBody2D = null

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var enemy_spawn_left: Marker2D = $EnemySpawnLeft
@onready var enemy_spawn_right: Marker2D = $EnemySpawnRight


func _ready() -> void:
	floor_rect.color = MINIBOSS_FLOOR_COLOR
	super()
	_spawn_terrain_zones()


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var use_hound := randf() < 0.5
	var hound_side := randi() % 2

	if use_hound and hound_side == 0:
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawn_left.global_position
		entities.add_child(hound)
	else:
		var grunt_left := DireGruntScene.instantiate()
		grunt_left.global_position = enemy_spawn_left.global_position
		entities.add_child(grunt_left)

	if use_hound and hound_side == 1:
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawn_right.global_position
		entities.add_child(hound)
	else:
		var grunt_right := DireGruntScene.instantiate()
		grunt_right.global_position = enemy_spawn_right.global_position
		entities.add_child(grunt_right)

	RunManager.set_room_enemy_count(3)
	captain_instance.captain_defeated.connect(_on_captain_defeated)

	_create_ambient_particles()


func _on_room_cleared() -> void:
	pass


func _on_captain_defeated() -> void:
	RunManager.award_room_shards(false)

	var reward := MiniBossRewardScene.instantiate()
	reward.entities_node = entities
	reward.reward_chosen.connect(_on_reward_chosen)
	hud_layer.add_child(reward)


func _on_reward_chosen() -> void:
	_unlock_doors()
	room_clear_particles.global_position = game_camera.global_position
	room_clear_particles.emitting = true


func _spawn_terrain_zones() -> void:
	var damage_zone := DamageZoneScene.instantiate()
	damage_zone.global_position = boss_spawn.global_position + Vector2(0, 80)
	add_child(damage_zone)


func _create_ambient_particles() -> void:
	var ambient := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(room_size.x / 2.0, room_size.y / 2.0, 0)
	mat.direction = Vector3(0, -0.5, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, 3, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.5
	mat.color = Color(0.545, 0.0, 0.0, 0.2)
	ambient.process_material = mat
	ambient.amount = 20
	ambient.lifetime = 3.0
	ambient.emitting = true
	ambient.position = room_size / 2.0
	add_child(ambient)
