extends "res://scenes/dungeon/RoomBase.gd"

var BoonSelectionScene := preload("res://scenes/ui/BoonSelection.tscn")

const HERO_SCENES: Dictionary = {
	"juggernaut": preload("res://scenes/entities/enemies/HeroJuggernaut.tscn"),
	"crystal_maiden": preload("res://scenes/entities/enemies/HeroCrystalMaiden.tscn"),
	"drow_ranger": preload("res://scenes/entities/enemies/HeroDrowRanger.tscn"),
	"omniknight": preload("res://scenes/entities/enemies/HeroOmniknight.tscn"),
}

const CORNER_CUT_RATIO: float = 0.2

var hero_data: Dictionary = {}
var hero_fighter: CharacterBody2D = null
var encounter_started: bool = false
var is_upgrade_encounter: bool = false

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var hero_spawn: Marker2D = $HeroSpawnPoint


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _ready() -> void:
	super()
	_create_octagonal_corners()


func _create_octagonal_corners() -> void:
	var cx := room_size.x * CORNER_CUT_RATIO
	var cy := room_size.y * CORNER_CUT_RATIO
	var wt := WALL_THICKNESS

	var corners: Array[Dictionary] = [
		{"points": PackedVector2Array([Vector2(wt, wt), Vector2(wt + cx, wt), Vector2(wt, wt + cy)]), "name": "CornerTL"},
		{"points": PackedVector2Array([Vector2(room_size.x - wt, wt), Vector2(room_size.x - wt - cx, wt), Vector2(room_size.x - wt, wt + cy)]), "name": "CornerTR"},
		{"points": PackedVector2Array([Vector2(wt, room_size.y - wt), Vector2(wt + cx, room_size.y - wt), Vector2(wt, room_size.y - wt - cy)]), "name": "CornerBL"},
		{"points": PackedVector2Array([Vector2(room_size.x - wt, room_size.y - wt), Vector2(room_size.x - wt - cx, room_size.y - wt), Vector2(room_size.x - wt, room_size.y - wt - cy)]), "name": "CornerBR"},
	]

	var obstacle_rects: Array[Rect2] = []
	for corner in corners:
		var poly := Polygon2D.new()
		poly.polygon = corner["points"]
		poly.color = Color("#1a2e1a")
		add_child(poly)

		var body := StaticBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 0

		var col := CollisionPolygon2D.new()
		col.polygon = corner["points"]
		body.add_child(col)
		$Walls.add_child(body)

		var polygon: PackedVector2Array = corner["points"]
		var min_pt := polygon[0]
		var max_pt := polygon[0]
		for pt in polygon:
			min_pt.x = min(min_pt.x, pt.x)
			min_pt.y = min(min_pt.y, pt.y)
			max_pt.x = max(max_pt.x, pt.x)
			max_pt.y = max(max_pt.y, pt.y)
		obstacle_rects.append(Rect2(min_pt, max_pt - min_pt))

	Pathfinder.add_obstacles(obstacle_rects)


func _spawn_enemies() -> void:
	var room_data := RunManager.get_chosen_room_data()
	var hero_id_str: String = room_data.get("hero_id", "")
	hero_data = HeroData.get_hero_by_id(hero_id_str)

	if hero_data.is_empty():
		RunManager.set_room_enemy_count(0)
		RunManager.on_enemy_killed()
		return

	is_upgrade_encounter = RunManager.has_hero(hero_id_str)
	RunManager.set_room_enemy_count(1)

	var scene: PackedScene = HERO_SCENES.get(hero_id_str)
	if not scene:
		RunManager.set_room_enemy_count(0)
		RunManager.on_enemy_killed()
		return

	hero_fighter = scene.instantiate()
	hero_fighter.is_clone = is_upgrade_encounter
	hero_fighter.global_position = hero_spawn.global_position
	hero_fighter.physics_enabled = false
	hero_fighter.hero_defeated.connect(_on_hero_defeated)
	entities.add_child(hero_fighter)

	_start_intro_sequence()


func _start_intro_sequence() -> void:
	var name_label := Label.new()
	var display_name: String = hero_data["name"]
	if is_upgrade_encounter:
		display_name = "Corrupted " + display_name
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", hero_data["color"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-60, -40)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_fighter.add_child(name_label)

	var intro_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 25.0
	mat.emission_ring_inner_radius = 5.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = hero_data["color"]
	intro_particles.process_material = mat
	intro_particles.amount = 12
	intro_particles.lifetime = 1.5
	intro_particles.emitting = true
	hero_fighter.add_child(intro_particles)

	await get_tree().create_timer(1.5).timeout

	var tw := create_tween()
	tw.tween_property(name_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		name_label.queue_free()
		intro_particles.emitting = false
	)

	hero_fighter.physics_enabled = true
	encounter_started = true


func _on_hero_defeated() -> void:
	await get_tree().create_timer(0.5).timeout

	var boon_ui := BoonSelectionScene.instantiate()
	boon_ui.hero_data = hero_data

	if is_upgrade_encounter:
		boon_ui.is_upgrade_mode = true
		var current_boon_id: String = RunManager.get_hero_boon(hero_data["id"])
		var upgrades := HeroData.get_upgrades_for_boon(current_boon_id)
		boon_ui.upgrade_options = upgrades

	boon_ui.boon_chosen.connect(_on_boon_chosen)
	hud_layer.add_child(boon_ui)


func _on_boon_chosen() -> void:
	if not is_upgrade_encounter:
		RunManager.heroes_joined_this_run.append(hero_data["name"])
		_spawn_champion()
	RunManager.on_enemy_killed()


func _spawn_champion() -> void:
	var champion_type: String = "champion_" + hero_data["id"]
	var scene_path: String = SwarmManager.get_unit_scene_path(champion_type)
	var champion_scene: PackedScene = load(scene_path)
	var champion := champion_scene.instantiate()
	champion.global_position = hero_spawn.global_position
	entities.add_child(champion)
