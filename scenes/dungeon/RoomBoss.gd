extends "res://scenes/dungeon/RoomBase.gd"

## Shared base for all boss room variants.
## Handles: boss spawning, entry sequence, defeat, ambient particles.
## Subclasses override: _get_spawn_position(), _spawn_enemies(), _spawn_terrain_zones()

const BOSS_ENTRY_PAUSE: float = 1.0
const BOSS_FLOOR_COLOR: Color = Color(0.05, 0.02, 0.02)

var DireAncientScene := preload("res://scenes/entities/enemies/DireAncient.tscn")

var boss_instance: CharacterBody2D = null


func _ready() -> void:
	floor_rect.color = BOSS_FLOOR_COLOR
	super()
	_spawn_terrain_zones()


func _on_room_cleared() -> void:
	AudioManager.stop_bgm()


func _spawn_terrain_zones() -> void:
	pass


func _boss_entry_sequence() -> void:
	await get_tree().create_timer(BOSS_ENTRY_PAUSE).timeout

	if not is_instance_valid(boss_instance):
		return

	var boss_visual: ColorRect = boss_instance.get_node("EnemyVisual")
	var tween := create_tween()
	tween.tween_property(boss_visual, "color", Color(0.545, 0.0, 0.0), 0.3)
	tween.tween_property(boss_visual, "color", Color(0.294, 0.0, 0.51), 0.3)

	game_camera.shake(3.0, 0.5)

	await tween.finished

	_create_ambient_particles()

	if is_instance_valid(boss_instance):
		boss_instance.start_fight()


func _on_boss_defeated() -> void:
	RunManager.award_room_shards(true)
	RunManager.snapshot_surviving_army()
	RunManager.end_run(true)

	if is_instance_valid(boss_instance):
		game_camera.global_position = boss_instance.global_position
	game_camera.pan_locked = true

	await get_tree().create_timer(1.5).timeout
	game_over_shown = true
	SceneTransition.is_transitioning = false
	SceneTransition.transition_to("res://scenes/ui/GameOver.tscn")


func _create_ambient_particles() -> void:
	var ambient := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(room_size.x / 2.0, room_size.y / 2.0, 0)
	mat.direction = Vector3(0, -0.5, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, 5, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.545, 0.0, 0.0, 0.3)
	ambient.process_material = mat
	ambient.amount = 30
	ambient.lifetime = 4.0
	ambient.emitting = true
	ambient.position = room_size / 2.0
	add_child(ambient)
