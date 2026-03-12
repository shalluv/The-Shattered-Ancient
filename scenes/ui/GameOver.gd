extends Control

@onready var title_label: Label = $VBoxContainer/GameOverLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var return_button: Button = $VBoxContainer/ReturnButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

var subtitle_label: Label = null
var shard_label: Label = null
var win_particles: GPUParticles2D = null
var stat_labels: Array[Label] = []


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_style_button(return_button)
	_style_button(quit_button)

	return_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 16)
	$VBoxContainer.add_child(subtitle_label)
	$VBoxContainer.move_child(subtitle_label, 1)

	shard_label = Label.new()
	shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_label.add_theme_font_size_override("font_size", 20)
	shard_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.804, 1.0))
	$VBoxContainer.add_child(shard_label)
	$VBoxContainer.move_child(shard_label, $VBoxContainer.get_child_count() - 2)

	shard_label.text = "Radiant Ore Shards earned: +%d\nTotal Shards: %d" % [
		RunManager.shards_earned_this_run, MetaProgress.radiant_ore_shards
	]
	shard_label.modulate.a = 0.0

	stats_label.visible = false

	if RunManager.last_run_won:
		_setup_win_screen()
	else:
		_setup_lose_screen()

	_animate_stats_in()


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.border_color = Color(0.3, 0.3, 0.4)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.35)
	hover.border_color = Color(0.5, 0.5, 0.6)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.25, 0.35)
	pressed.border_color = Color(0.5, 0.5, 0.6)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", pressed)

	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)


func _setup_win_screen() -> void:
	title_label.text = "The Dire Ancient Falls"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))

	subtitle_label.text = "The war is not over. It never ends."
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 0.6))

	var surviving: int = 0
	for unit_type in RunManager.surviving_army:
		surviving += RunManager.surviving_army[unit_type]

	var lines: PackedStringArray = PackedStringArray()
	lines.append("Units Remaining: %d" % surviving)
	lines.append("Units Lost: %d" % RunManager.total_units_lost)
	lines.append("Rooms Completed: %d / %d" % [RunManager.TOTAL_ROOMS, RunManager.TOTAL_ROOMS])
	if not RunManager.heroes_joined_this_run.is_empty():
		lines.append("Heroes Joined: " + ", ".join(RunManager.heroes_joined_this_run))

	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.modulate.a = 0.0
		$VBoxContainer.add_child(lbl)
		$VBoxContainer.move_child(lbl, $VBoxContainer.get_child_count() - 3)
		stat_labels.append(lbl)

	_create_win_particles()


func _setup_lose_screen() -> void:
	if RunManager.is_boss_room():
		title_label.text = "The Dire Ancient Endures"
		title_label.add_theme_color_override("font_color", Color(0.294, 0.0, 0.51, 1.0))
		subtitle_label.text = "Your fragments scatter. But the ore remembers."
		subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	else:
		title_label.text = "The Ancient Sleeps Again"
		title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		subtitle_label.text = ""

	var rooms_done: int = RunManager.current_room_index
	var units_lost: int = RunManager.initial_unit_total

	var lines: PackedStringArray = PackedStringArray()
	lines.append("Units Lost: %d" % units_lost)
	lines.append("Rooms Completed: %d / %d" % [rooms_done, RunManager.TOTAL_ROOMS])

	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.modulate.a = 0.0
		$VBoxContainer.add_child(lbl)
		$VBoxContainer.move_child(lbl, $VBoxContainer.get_child_count() - 3)
		stat_labels.append(lbl)

	_create_lose_particles()


func _animate_stats_in() -> void:
	var delay: float = 0.3
	for i in stat_labels.size():
		var lbl := stat_labels[i]
		var tw := lbl.create_tween()
		tw.tween_interval(delay * (i + 1))
		tw.tween_property(lbl, "modulate:a", 1.0, 0.3)

	var shard_delay: float = delay * (stat_labels.size() + 1)
	var stw := shard_label.create_tween()
	stw.tween_interval(shard_delay)
	stw.tween_property(shard_label, "modulate:a", 1.0, 0.3)

	var btn_delay: float = shard_delay + 0.5
	var btw := return_button.create_tween()
	btw.tween_interval(btn_delay)
	btw.tween_property(return_button, "modulate:a", 1.0, 0.3)
	var qtw := quit_button.create_tween()
	qtw.tween_interval(btn_delay)
	qtw.tween_property(quit_button, "modulate:a", 1.0, 0.3)


func _create_win_particles() -> void:
	win_particles = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 40, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.843, 0.0, 0.8)
	win_particles.process_material = mat
	win_particles.amount = 50
	win_particles.lifetime = 2.0
	win_particles.emitting = true
	win_particles.position = Vector2(get_viewport_rect().size.x / 2.0, 0)
	add_child(win_particles)


func _create_lose_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	mat.color = Color(0.4, 0.3, 0.5, 0.5)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(get_viewport_rect().size.x / 2.0, 10, 0)
	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 4.0
	particles.emitting = true
	particles.position = Vector2(get_viewport_rect().size.x / 2.0, 0)
	add_child(particles)


func _on_return_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
