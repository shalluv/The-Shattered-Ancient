extends Node2D

const ROOM_SIZE_SMALL: Vector2 = Vector2(800, 600)
const ROOM_SIZE_NORMAL: Vector2 = Vector2(1024, 768)
const ROOM_SIZE_LARGE: Vector2 = Vector2(1280, 720)

const WALL_THICKNESS: float = 16.0

const DOOR_WIDTH: float = 48.0
const DOOR_THICKNESS: float = 16.0
const DOOR_COLOR_LOCKED: Color = Color(0.6, 0.1, 0.1)
const DOOR_COLOR_UNLOCKED: Color = Color(1.0, 0.843, 0.0)
const DOOR_COLOR_DEFAULT: Color = Color(0.3, 0.3, 0.3)

@export var room_size: Vector2 = ROOM_SIZE_NORMAL

var SwarmCoreScene := preload("res://scenes/entities/SwarmCore.tscn")
var SwordsmanScene := preload("res://scenes/entities/units/Swordsman.tscn")
var DireGruntScene := preload("res://scenes/entities/enemies/DireGrunt.tscn")
var HUDScene := preload("res://scenes/ui/HUD.tscn")


@onready var floor_rect: ColorRect = $Floor
@onready var wall_top: ColorRect = $Walls/WallTop
@onready var wall_bottom: ColorRect = $Walls/WallBottom
@onready var wall_left: ColorRect = $Walls/WallLeft
@onready var wall_right: ColorRect = $Walls/WallRight
@onready var entities: Node2D = $Entities
@onready var game_camera: Camera2D = $GameCamera
@onready var hud_layer: CanvasLayer = $HUDLayer
@onready var room_clear_particles: GPUParticles2D = $RoomClearParticles
@onready var door_north: ColorRect = $Doors/DoorNorth
@onready var door_south: ColorRect = $Doors/DoorSouth
@onready var door_east: ColorRect = $Doors/DoorEast
@onready var door_west: ColorRect = $Doors/DoorWest

var swarm_core_instance: Node2D = null
var game_over_shown: bool = false
var doors_locked: bool = false
var door_triggered: bool = false
var door_blockers: Dictionary = {}
var wall_rects: Array[Rect2] = []
var door_blocker_rects: Array[Rect2] = []


func _ready() -> void:
	_configure_room_visuals()
	_create_wall_collisions()
	_setup_doors()
	_setup_room_clear_particles()
	Pathfinder.setup_grid(room_size, wall_rects, door_blocker_rects)
	SelectionManager.clear_selection()
	_spawn_player()
	_spawn_enemies()
	_spawn_hud()
	_lock_doors()
	RunManager.room_cleared.connect(_on_room_cleared)
	RunManager.game_over_requested.connect(_on_game_over_requested)
	SwarmManager.unit_count_changed.connect(_on_unit_count_changed)

	if is_instance_valid(BoonManager):
		BoonManager.apply_all_boons()

	SwarmManager.apply_meta_modifiers()
	call_deferred("_snapshot_room_start")

	SwarmManager.unit_registered.connect(_on_unit_registered_meta)

	game_camera.global_position = room_size / 2.0
	game_camera.limit_left = 0
	game_camera.limit_top = 0
	game_camera.limit_right = int(room_size.x)
	game_camera.limit_bottom = int(room_size.y)


func _exit_tree() -> void:
	if RunManager.room_cleared.is_connected(_on_room_cleared):
		RunManager.room_cleared.disconnect(_on_room_cleared)
	if RunManager.game_over_requested.is_connected(_on_game_over_requested):
		RunManager.game_over_requested.disconnect(_on_game_over_requested)
	if SwarmManager.unit_count_changed.is_connected(_on_unit_count_changed):
		SwarmManager.unit_count_changed.disconnect(_on_unit_count_changed)
	if SwarmManager.unit_registered.is_connected(_on_unit_registered_meta):
		SwarmManager.unit_registered.disconnect(_on_unit_registered_meta)


func _create_wall_collisions() -> void:
	var walls_node := $Walls
	var cx := room_size.x / 2.0
	var cy := room_size.y / 2.0

	_add_horizontal_wall_segments(walls_node, WALL_THICKNESS / 2.0, cx, "north")
	_add_horizontal_wall_segments(walls_node, room_size.y - WALL_THICKNESS / 2.0, cx, "south")
	_add_vertical_wall_segments(walls_node, WALL_THICKNESS / 2.0, cy, "west")
	_add_vertical_wall_segments(walls_node, room_size.x - WALL_THICKNESS / 2.0, cy, "east")


func _add_horizontal_wall_segments(parent: Node, y_pos: float, center_x: float, door_name: String) -> void:
	var half_door := DOOR_WIDTH / 2.0
	var left_width := center_x - half_door
	var right_width := room_size.x - center_x - half_door

	_add_wall_body(parent,
		Vector2(left_width / 2.0, y_pos),
		Vector2(left_width, WALL_THICKNESS))
	_add_wall_body(parent,
		Vector2(center_x + half_door + right_width / 2.0, y_pos),
		Vector2(right_width, WALL_THICKNESS))

	_add_door_blocker(parent, door_name,
		Vector2(center_x, y_pos),
		Vector2(DOOR_WIDTH, WALL_THICKNESS))


func _add_vertical_wall_segments(parent: Node, x_pos: float, center_y: float, door_name: String) -> void:
	var half_door := DOOR_WIDTH / 2.0
	var top_height := center_y - half_door
	var bottom_height := room_size.y - center_y - half_door

	_add_wall_body(parent,
		Vector2(x_pos, top_height / 2.0),
		Vector2(WALL_THICKNESS, top_height))
	_add_wall_body(parent,
		Vector2(x_pos, center_y + half_door + bottom_height / 2.0),
		Vector2(WALL_THICKNESS, bottom_height))

	_add_door_blocker(parent, door_name,
		Vector2(x_pos, center_y),
		Vector2(WALL_THICKNESS, DOOR_WIDTH))


func _add_door_blocker(parent: Node, door_name: String, pos: Vector2, blocker_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = pos

	var shape := RectangleShape2D.new()
	shape.size = blocker_size

	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	door_blockers[door_name] = body
	door_blocker_rects.append(Rect2(pos - blocker_size / 2.0, blocker_size))


func _add_wall_body(parent: Node, pos: Vector2, wall_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = pos

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	wall_rects.append(Rect2(pos - wall_size / 2.0, wall_size))


func _configure_room_visuals() -> void:
	floor_rect.position = Vector2.ZERO
	floor_rect.size = room_size

	wall_top.position = Vector2.ZERO
	wall_top.size = Vector2(room_size.x, WALL_THICKNESS)

	wall_bottom.position = Vector2(0, room_size.y - WALL_THICKNESS)
	wall_bottom.size = Vector2(room_size.x, WALL_THICKNESS)

	wall_left.position = Vector2.ZERO
	wall_left.size = Vector2(WALL_THICKNESS, room_size.y)

	wall_right.position = Vector2(room_size.x - WALL_THICKNESS, 0)
	wall_right.size = Vector2(WALL_THICKNESS, room_size.y)


# TODO: Replace door ColorRects with door art assets
func _setup_doors() -> void:
	door_north.position = Vector2(room_size.x / 2.0 - DOOR_WIDTH / 2.0, 0)
	door_north.size = Vector2(DOOR_WIDTH, DOOR_THICKNESS)

	door_south.position = Vector2(room_size.x / 2.0 - DOOR_WIDTH / 2.0, room_size.y - DOOR_THICKNESS)
	door_south.size = Vector2(DOOR_WIDTH, DOOR_THICKNESS)

	door_east.position = Vector2(room_size.x - DOOR_THICKNESS, room_size.y / 2.0 - DOOR_WIDTH / 2.0)
	door_east.size = Vector2(DOOR_THICKNESS, DOOR_WIDTH)

	door_west.position = Vector2(0, room_size.y / 2.0 - DOOR_WIDTH / 2.0)
	door_west.size = Vector2(DOOR_THICKNESS, DOOR_WIDTH)

	var inward_pad: float = 10.0
	_create_door_trigger(door_north, "north", Vector2(DOOR_WIDTH, DOOR_THICKNESS + inward_pad), Vector2(0, inward_pad / 2.0))
	_create_door_trigger(door_south, "south", Vector2(DOOR_WIDTH, DOOR_THICKNESS + inward_pad), Vector2(0, -inward_pad / 2.0))
	_create_door_trigger(door_east, "east", Vector2(DOOR_THICKNESS + inward_pad, DOOR_WIDTH), Vector2(-inward_pad / 2.0, 0))
	_create_door_trigger(door_west, "west", Vector2(DOOR_THICKNESS + inward_pad, DOOR_WIDTH), Vector2(inward_pad / 2.0, 0))


func _create_door_trigger(door: ColorRect, door_name: String, trigger_size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	area.position = door.size / 2.0 + offset

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = trigger_size
	shape.shape = rect_shape
	area.add_child(shape)
	door.add_child(area)

	area.body_entered.connect(_on_door_body_entered.bind(door_name))


func _on_door_body_entered(_body: Node2D, _door_name: String) -> void:
	if doors_locked or game_over_shown or door_triggered:
		return
	door_triggered = true
	_handle_room_exit()


func _handle_room_exit() -> void:
	game_over_shown = true
	if is_instance_valid(BoonManager):
		BoonManager.clear_room_effects()
	RunManager.snapshot_surviving_army()

	if RunManager.current_room_index >= RunManager.BOSS_ROOM_INDEX:
		RunManager.end_run(true)
		_show_game_over()
		return

	SceneTransition.transition_to(RunManager.MAP_SCENE_PATH)


func _lock_doors() -> void:
	doors_locked = true
	for door: ColorRect in [door_north, door_south, door_east, door_west]:
		door.color = DOOR_COLOR_LOCKED
	for blocker_name in door_blockers:
		door_blockers[blocker_name].collision_layer = 8


func _unlock_doors() -> void:
	doors_locked = false
	for door: ColorRect in [door_north, door_south, door_east, door_west]:
		var dtw := door.create_tween()
		dtw.tween_property(door, "color", Color.WHITE, 0.1)
		dtw.tween_property(door, "color", DOOR_COLOR_UNLOCKED, 0.2)
	for blocker_name in door_blockers:
		door_blockers[blocker_name].collision_layer = 0
	Pathfinder.open_doors()


func _get_spawn_position() -> Vector2:
	return room_size / 2.0


func _spawn_player() -> void:
	swarm_core_instance = SwarmCoreScene.instantiate()
	swarm_core_instance.global_position = _get_spawn_position()
	entities.add_child(swarm_core_instance)

	var army: Dictionary = RunManager.get_current_army()
	for unit_type in army:
		var count: int = army[unit_type]
		var scene_path: String = SwarmManager.get_unit_scene_path(unit_type)
		var unit_scene: PackedScene = load(scene_path)
		for i in count:
			var unit := unit_scene.instantiate()
			var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
			unit.global_position = _get_spawn_position() + offset
			entities.add_child(unit)


func _spawn_enemies() -> void:
	var grunt := DireGruntScene.instantiate()
	var edge := randi() % 4
	var safe_margin: float = WALL_THICKNESS + 30.0
	match edge:
		0:
			grunt.global_position = Vector2(randf_range(100, room_size.x - 100), safe_margin)
		1:
			grunt.global_position = Vector2(randf_range(100, room_size.x - 100), room_size.y - safe_margin)
		2:
			grunt.global_position = Vector2(safe_margin, randf_range(100, room_size.y - 100))
		3:
			grunt.global_position = Vector2(room_size.x - safe_margin, randf_range(100, room_size.y - 100))
	entities.add_child(grunt)
	RunManager.set_room_enemy_count(1)


func _spawn_enemies_staggered(scene: PackedScene, spawn_points: Array[Marker2D], count: int, delay: float) -> void:
	RunManager.set_room_enemy_count(count)
	for i in count:
		var enemy := scene.instantiate()
		var spawn_pos: Vector2 = spawn_points[i % spawn_points.size()].global_position
		enemy.global_position = spawn_pos
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < count - 1:
			await get_tree().create_timer(delay).timeout


func _play_spawn_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.545, 0.0, 0.0, 1.0)
	particles.process_material = mat
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = pos
	add_child(particles)
	await get_tree().create_timer(0.5).timeout
	particles.queue_free()


func _spawn_hud() -> void:
	var hud := HUDScene.instantiate()
	hud_layer.add_child(hud)


func _snapshot_room_start() -> void:
	RunManager.snapshot_room_start_units()


func _on_unit_registered_meta(unit: Node2D) -> void:
	SwarmManager.apply_meta_to_unit(unit)


func _on_room_cleared() -> void:
	AudioManager.play_sfx("room_clear")
	AudioManager.stop_bgm()
	RunManager.award_room_shards(false)
	room_clear_particles.global_position = game_camera.global_position
	room_clear_particles.emitting = true
	game_camera.zoom_pulse(0.05, 0.3)
	_unlock_doors()


func _on_unit_count_changed(new_count: int) -> void:
	if new_count <= 0 and not game_over_shown:
		game_over_shown = true
		RunManager.end_run(false)
		_show_game_over()


func _process(_delta: float) -> void:
	if game_over_shown:
		return
	if SwarmManager.units.is_empty() and SwarmManager.unit_count <= 0:
		game_over_shown = true
		RunManager.end_run(false)
		_show_game_over()


func _on_game_over_requested(won: bool) -> void:
	if not game_over_shown:
		game_over_shown = true
		_show_game_over()


func _show_game_over() -> void:
	await get_tree().create_timer(0.5).timeout
	SceneTransition.is_transitioning = false
	SceneTransition.transition_to("res://scenes/ui/GameOver.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		SceneTransition.transition_to(RunManager.MAP_SCENE_PATH)


func _setup_room_clear_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.843, 0.0, 1.0)
	room_clear_particles.process_material = mat
	room_clear_particles.amount = 30
	room_clear_particles.lifetime = 1.0
	room_clear_particles.one_shot = true
	room_clear_particles.explosiveness = 1.0
	room_clear_particles.emitting = false
	room_clear_particles.position = room_size / 2.0
