extends "res://scenes/dungeon/RoomBase.gd"

const MINIBOSS_FLOOR_COLOR: Color = Color(0.06, 0.02, 0.02)

var DireCaptainScene := preload("res://scenes/entities/enemies/DireCaptain.tscn")
var MiniBossRewardScene := preload("res://scenes/ui/MiniBossReward.tscn")

var captain_instance: CharacterBody2D = null
var captain_defeated_flag: bool = false


func _ready() -> void:
	floor_rect.color = MINIBOSS_FLOOR_COLOR
	super()
	_spawn_terrain_zones()


func _on_room_cleared() -> void:
	AudioManager.play_sfx("room_clear")
	AudioManager.stop_bgm()
	if captain_defeated_flag:
		_show_reward()


func _on_captain_defeated() -> void:
	captain_defeated_flag = true
	RunManager.award_room_shards(false)
	if RunManager.enemies_remaining <= 0:
		_show_reward()


func _show_reward() -> void:
	var reward := MiniBossRewardScene.instantiate()
	reward.entities_node = entities
	reward.reward_chosen.connect(_on_reward_chosen)
	hud_layer.add_child(reward)


func _on_reward_chosen() -> void:
	_unlock_doors()
	room_clear_particles.global_position = game_camera.global_position
	room_clear_particles.emitting = true


func _spawn_terrain_zones() -> void:
	pass


func _create_ambient_particles_colored(particle_color: Color) -> void:
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
	mat.color = particle_color
	ambient.process_material = mat
	ambient.amount = 20
	ambient.lifetime = 3.0
	ambient.emitting = true
	ambient.position = room_size / 2.0
	add_child(ambient)
