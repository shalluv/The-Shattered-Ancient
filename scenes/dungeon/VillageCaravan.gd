extends "res://scenes/dungeon/RoomBase.gd"

const BUILDING_COLOR: Color = Color("#2a2a2a")
const ROAD_COLOR: Color = Color("#3a3530")
const PATH_LINE_COLOR: Color = Color(0.8, 0.7, 0.3, 0.6)

var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")
var ArcherVillagerScene := preload("res://scenes/entities/ArcherVillager.tscn")
var MageVillagerScene := preload("res://scenes/entities/MageVillager.tscn")
var CaravanScene := preload("res://scenes/entities/Caravan.tscn")
var CaravanHunterMeleeScene := preload("res://scenes/entities/enemies/CaravanHunterMelee.tscn")
var CaravanHunterRangedScene := preload("res://scenes/entities/enemies/CaravanHunter.tscn")
var DireGruntRangedScene := preload("res://scenes/entities/enemies/DireGruntRanged.tscn")

var VILLAGER_SCENES: Array = []

@onready var player_spawn: Marker2D = $PlayerSpawnPoint

var caravan_instance: Node2D = null
var caravan_destroyed: bool = false
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 3.5
var melee_hunter_timer: float = 2.0
const BASE_MELEE_HUNTER_INTERVAL: float = 15.0
var melee_hunter_interval: float = BASE_MELEE_HUNTER_INTERVAL
var ranged_hunter_timer: float = 5.0
const BASE_RANGED_HUNTER_INTERVAL: float = 25.0
var ranged_hunter_interval: float = BASE_RANGED_HUNTER_INTERVAL
var melee_grunt_timer: float = 0.0
const BASE_MELEE_GRUNT_INTERVAL: float = 14.0
var melee_grunt_interval: float = BASE_MELEE_GRUNT_INTERVAL
var ranged_grunt_timer: float = 10.0
const BASE_RANGED_GRUNT_INTERVAL: float = 30.0
var ranged_grunt_interval: float = BASE_RANGED_GRUNT_INTERVAL

var difficulty: Dictionary = {}
var spawn_zones: Array[Rect2] = [
	Rect2(Vector2(50, 50), Vector2(150, 150)),
	Rect2(Vector2(400, 50), Vector2(150, 100)),
	Rect2(Vector2(400, 550), Vector2(200, 150)),
	Rect2(Vector2(800, 450), Vector2(150, 200))
]
var path_progress_check: int = 0

var caravan_path: PackedVector2Array = PackedVector2Array([
	Vector2(100, 680),
	Vector2(100, 500),
	Vector2(300, 500),
	Vector2(300, 300),
	Vector2(500, 300),
	Vector2(500, 150),
	Vector2(700, 150),
	Vector2(700, 350),
	Vector2(900, 350),
	Vector2(900, 100)
])

var building_positions: Array[Vector2] = [
	Vector2(200, 600),
	Vector2(200, 400),
	Vector2(400, 400),
	Vector2(400, 200),
	Vector2(600, 250),
	Vector2(600, 450),
	Vector2(800, 250),
	Vector2(800, 450)
]
var building_sizes: Array[Vector2] = [
	Vector2(60, 60),
	Vector2(60, 60),
	Vector2(60, 60),
	Vector2(60, 60),
	Vector2(60, 60),
	Vector2(60, 60),
	Vector2(60, 60),
	Vector2(60, 60)
]

var path_line: Line2D = null


func _ready() -> void:
	super._ready()
	VILLAGER_SCENES = [NeutralVillagerScene, ArcherVillagerScene, MageVillagerScene]
	_apply_difficulty_scaling()
	_draw_path_line()
	_spawn_buildings()
	_spawn_caravan()
	_add_building_obstacles()
	game_camera.global_position = caravan_path[0]
	
	await get_tree().process_frame
	RunManager.set_room_enemy_count(-1)  # Special case for Caravan: shows "Escort" instead of count


func _apply_difficulty_scaling() -> void:
	difficulty = RunManager.get_village_difficulty()
	var spawn_mult: float = difficulty.get("spawn_rate_mult", 1.0)
	melee_hunter_interval = BASE_MELEE_HUNTER_INTERVAL * spawn_mult
	ranged_hunter_interval = BASE_RANGED_HUNTER_INTERVAL * spawn_mult
	melee_grunt_interval = BASE_MELEE_GRUNT_INTERVAL * spawn_mult
	ranged_grunt_interval = BASE_RANGED_GRUNT_INTERVAL * spawn_mult


func _process(delta: float) -> void:
	super._process(delta)
	
	if caravan_destroyed:
		return
	
	if caravan_instance and is_instance_valid(caravan_instance):
		if caravan_instance.is_destroyed:
			caravan_destroyed = true
			set_process(false)
			return
		_spawn_melee_hunters(delta)
		_spawn_ranged_hunters(delta)
		_spawn_melee_grunts(delta)
		_spawn_ranged_grunts(delta)
		_check_path_progress()


func _get_spawn_position() -> Vector2:
	return caravan_path[0] + Vector2(60, 0)


func _get_camera_start_position() -> Vector2:
	return caravan_path[0]


func _spawn_enemies() -> void:
	pass


func _draw_path_line() -> void:
	path_line = Line2D.new()
	path_line.points = caravan_path
	path_line.width = 40.0
	path_line.default_color = ROAD_COLOR
	path_line.z_index = -2
	add_child(path_line)
	
	var guide_line := Line2D.new()
	guide_line.points = caravan_path
	guide_line.width = 4.0
	guide_line.default_color = PATH_LINE_COLOR
	guide_line.z_index = -1
	add_child(guide_line)
	
	for i in range(caravan_path.size() - 1):
		var from_pos: Vector2 = caravan_path[i]
		var to_pos: Vector2 = caravan_path[i + 1]
		var mid_pos := (from_pos + to_pos) / 2.0
		var direction := from_pos.direction_to(to_pos)
		
		var arrow := Polygon2D.new()
		var arrow_size := 12.0
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(arrow_size, 0),
			Vector2(-arrow_size / 2, arrow_size / 2),
			Vector2(-arrow_size / 2, -arrow_size / 2)
		])
		arrow.polygon = points
		arrow.color = PATH_LINE_COLOR
		arrow.position = mid_pos
		arrow.rotation = direction.angle()
		arrow.z_index = 0
		add_child(arrow)
	
	var start_container := Node2D.new()
	start_container.position = caravan_path[0]
	add_child(start_container)
	
	var start_circle := Polygon2D.new()
	var start_points: PackedVector2Array = PackedVector2Array()
	for j in 16:
		var angle := float(j) / 16.0 * TAU
		start_points.append(Vector2(cos(angle), sin(angle)) * 15.0)
	start_circle.polygon = start_points
	start_circle.color = Color(0.2, 0.7, 0.2, 0.9)
	start_container.add_child(start_circle)
	
	var start_label := Label.new()
	start_label.text = "START"
	start_label.add_theme_font_size_override("font_size", 10)
	start_label.add_theme_color_override("font_color", Color.WHITE)
	start_label.position = Vector2(-18, -25)
	start_container.add_child(start_label)
	
	var end_container := Node2D.new()
	end_container.position = caravan_path[caravan_path.size() - 1]
	add_child(end_container)
	
	var end_circle := Polygon2D.new()
	var end_points: PackedVector2Array = PackedVector2Array()
	for j in 16:
		var angle := float(j) / 16.0 * TAU
		end_points.append(Vector2(cos(angle), sin(angle)) * 20.0)
	end_circle.polygon = end_points
	end_circle.color = Color(0.9, 0.7, 0.1, 0.9)
	end_container.add_child(end_circle)
	
	var end_label := Label.new()
	end_label.text = "GOAL"
	end_label.add_theme_font_size_override("font_size", 12)
	end_label.add_theme_color_override("font_color", Color.WHITE)
	end_label.position = Vector2(-15, -30)
	end_container.add_child(end_label)


func _spawn_caravan() -> void:
	caravan_instance = CaravanScene.instantiate()
	caravan_instance.global_position = caravan_path[0]
	caravan_instance.max_villagers = 6
	caravan_instance.set_path(caravan_path)
	entities.add_child(caravan_instance)
	
	caravan_instance.caravan_reached_exit.connect(_on_caravan_reached_exit)
	caravan_instance.caravan_destroyed.connect(_on_caravan_destroyed)


func _check_path_progress() -> void:
	if not caravan_instance or not is_instance_valid(caravan_instance):
		return
	
	var progress: int = caravan_instance.current_path_index
	
	if progress > path_progress_check:
		path_progress_check = progress
		_spawn_wave_at_progress(progress)


func _spawn_wave_at_progress(_progress: int) -> void:
	pass


func _get_distance_to_path(pos: Vector2) -> float:
	var min_dist := INF
	for i in range(caravan_path.size() - 1):
		var a: Vector2 = caravan_path[i]
		var b: Vector2 = caravan_path[i + 1]
		var ab := b - a
		var ap := pos - a
		var t := clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
		var closest := a + ab * t
		var dist := pos.distance_to(closest)
		if dist < min_dist:
			min_dist = dist
	return min_dist


func _get_valid_spawn_pos() -> Vector2:
	var zone: Rect2 = spawn_zones[randi() % spawn_zones.size()]
	var spawn_pos := Vector2(
		randf_range(zone.position.x, zone.position.x + zone.size.x),
		randf_range(zone.position.y, zone.position.y + zone.size.y)
	)
	return spawn_pos


func _spawn_melee_hunters(delta: float) -> void:
	melee_hunter_timer += delta
	if melee_hunter_timer >= melee_hunter_interval:
		melee_hunter_timer = randf_range(-2.0, 0.0)
		
		var spawn_pos := _get_valid_spawn_pos()
		
		var hunter := CaravanHunterMeleeScene.instantiate()
		hunter.global_position = spawn_pos
		entities.add_child(hunter)
		_play_spawn_particles(spawn_pos)


func _spawn_ranged_hunters(delta: float) -> void:
	ranged_hunter_timer += delta
	if ranged_hunter_timer >= ranged_hunter_interval:
		ranged_hunter_timer = randf_range(-3.0, 0.0)
		
		var spawn_pos := _get_valid_spawn_pos()
		
		var hunter := CaravanHunterRangedScene.instantiate()
		hunter.global_position = spawn_pos
		entities.add_child(hunter)
		_play_spawn_particles(spawn_pos)


func _spawn_melee_grunts(delta: float) -> void:
	melee_grunt_timer += delta
	if melee_grunt_timer >= melee_grunt_interval:
		melee_grunt_timer = randf_range(-2.5, 0.0)
		
		var spawn_pos := _get_valid_spawn_pos()
		
		var grunt := DireGruntScene.instantiate()
		grunt.global_position = spawn_pos
		entities.add_child(grunt)
		_play_spawn_particles(spawn_pos)


func _spawn_ranged_grunts(delta: float) -> void:
	ranged_grunt_timer += delta
	if ranged_grunt_timer >= ranged_grunt_interval:
		ranged_grunt_timer = randf_range(-4.0, 0.0)
		
		var spawn_pos := _get_valid_spawn_pos()
		
		var grunt := DireGruntRangedScene.instantiate()
		grunt.global_position = spawn_pos
		entities.add_child(grunt)
		_play_spawn_particles(spawn_pos)


func _on_caravan_reached_exit() -> void:
	var villagers_saved: int = caravan_instance.get_villagers_remaining()
	
	# Spawn unit ใหม่ให้ player แทน neutral villager
	var unit_scenes: Array[PackedScene] = [
		preload("res://scenes/entities/units/Swordsman.tscn"),
		preload("res://scenes/entities/units/Archer.tscn"),
		preload("res://scenes/entities/units/Mage.tscn"),
		preload("res://scenes/entities/units/Priest.tscn")
	]
	
	for i in villagers_saved:
		var scene: PackedScene = unit_scenes[randi() % unit_scenes.size()]
		var unit := scene.instantiate()
		unit.global_position = caravan_instance.global_position + Vector2(randf_range(-30, 30), randf_range(20, 50))
		entities.add_child(unit)
		SwarmManager.register_unit(unit)
	
	# Force HUD to show CLEARED
	RunManager.enemies_remaining = 0
	RunManager.enemies_remaining_changed.emit(0)
	RunManager.room_cleared.emit()


func _on_caravan_destroyed() -> void:
	set_process(false)
	RunManager.end_run(false)


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


func _add_building_obstacles() -> void:
	var building_rects: Array[Rect2] = []
	for i in building_positions.size():
		var pos: Vector2 = building_positions[i]
		var bsize: Vector2 = building_sizes[i]
		building_rects.append(Rect2(pos - bsize / 2.0, bsize))
	Pathfinder.add_obstacles(building_rects)
