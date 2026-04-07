extends Control

@onready var title_label: Label = $VBoxContainer/GameOverLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var return_button: Button = $VBoxContainer/ReturnButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

var subtitle_label: Label = null
var shard_label: Label = null
var win_particles: GPUParticles2D = null
var stat_labels: Array[Label] = []
var button_hbox: HBoxContainer = null

const CENTER := Vector2(512, 384)


func _ready() -> void:
	# Add decorative elements behind the VBox
	_build_decorations()

	# Hide original buttons — we'll re-parent them into an HBoxContainer
	return_button.visible = false
	quit_button.visible = false

	# Ornament separator + horizontal button row
	var ornament := GameOverOrnament.new()
	ornament.custom_minimum_size = Vector2(350, 16)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBoxContainer.add_child(ornament)

	button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)
	$VBoxContainer.add_child(button_hbox)

	# Reparent buttons into horizontal row
	return_button.get_parent().remove_child(return_button)
	quit_button.get_parent().remove_child(quit_button)
	return_button.visible = true
	quit_button.visible = true
	return_button.custom_minimum_size = Vector2(180, 48)
	quit_button.custom_minimum_size = Vector2(140, 48)
	button_hbox.add_child(return_button)
	button_hbox.add_child(quit_button)

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
	shard_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	$VBoxContainer.add_child(shard_label)
	$VBoxContainer.move_child(shard_label, $VBoxContainer.get_child_count() - 3)

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


# ── Decorative elements ────────────────────────────────────

func _build_decorations() -> void:
	# Rune circle behind content
	var rune := GameOverRuneCircle.new()
	rune.position = Vector2(512, 440)
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune.modulate.a = 0.0
	add_child(rune)
	# Move background and rune behind VBox
	move_child(rune, 1)

	# Animate rune appearing
	var rune_tw := rune.create_tween()
	rune_tw.tween_property(rune, "modulate:a", 0.15, 1.5)

	# Slow rotation
	var rot_tw := rune.create_tween()
	rot_tw.set_loops()
	rot_tw.tween_property(rune, "rotation", TAU, 90.0).from(0.0)

	# Corner ornaments
	var corners := GameOverCorners.new()
	corners.set_anchors_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.modulate.a = 0.0
	add_child(corners)
	move_child(corners, 2)
	var corner_tw := corners.create_tween()
	corner_tw.tween_property(corners, "modulate:a", 0.4, 1.2)

	# Border frame
	var frame := GameOverFrame.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.15
	add_child(frame)
	move_child(frame, 3)

	# Ambient dust particles
	var dust := GPUParticles2D.new()
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0.3, -1, 0)
	dust_mat.spread = 50.0
	dust_mat.initial_velocity_min = 4.0
	dust_mat.initial_velocity_max = 12.0
	dust_mat.gravity = Vector3(0, 0, 0)
	dust_mat.scale_min = 1.0
	dust_mat.scale_max = 2.0
	dust_mat.color = Color(0.85, 0.75, 0.4, 0.2)
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(512, 384, 0)
	dust.process_material = dust_mat
	dust.amount = 25
	dust.lifetime = 7.0
	dust.position = CENTER
	add_child(dust)
	move_child(dust, 4)


class GameOverRuneCircle extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		var dim := Color(0.6, 0.5, 0.2, 0.5)
		_draw_ring(Vector2.ZERO, 160, gold, 1.5)
		_draw_ring(Vector2.ZERO, 125, dim, 1.0)
		_draw_ring(Vector2.ZERO, 45, dim, 1.0)
		for i in 8:
			var angle: float = i * TAU / 8.0
			var p1 := Vector2.from_angle(angle) * 52
			var p2 := Vector2.from_angle(angle) * 120
			draw_line(p1, p2, dim, 1.0)
		for i in 12:
			var angle: float = i * TAU / 12.0
			var p := Vector2.from_angle(angle) * 142
			var p2 := Vector2.from_angle(angle) * 155
			draw_line(p, p2, gold, 2.0)
		for i in 4:
			var angle: float = i * TAU / 4.0
			var p := Vector2.from_angle(angle) * 160
			_draw_diamond(p, 5, gold)

	func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in 65:
			var angle := i * TAU / 64.0
			pts.append(center + Vector2.from_angle(angle) * radius)
		for i in 64:
			draw_line(pts[i], pts[i + 1], color, width, true)

	func _draw_diamond(pos: Vector2, sz: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -sz), pos + Vector2(sz, 0),
			pos + Vector2(0, sz), pos + Vector2(-sz, 0),
		]), color)


class GameOverCorners extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		var m := 25.0
		var arm := 70.0
		var w := size.x
		var h := size.y
		_draw_corner(Vector2(m, m), 1, 1, arm, gold)
		_draw_corner(Vector2(w - m, m), -1, 1, arm, gold)
		_draw_corner(Vector2(m, h - m), 1, -1, arm, gold)
		_draw_corner(Vector2(w - m, h - m), -1, -1, arm, gold)

	func _draw_corner(o: Vector2, dx: int, dy: int, arm: float, color: Color) -> void:
		draw_line(o, o + Vector2(arm * dx, 0), color, 1.5, true)
		draw_line(o, o + Vector2(0, arm * dy), color, 1.5, true)
		draw_circle(o, 2.5, color)
		var inset := Vector2(8 * dx, 8 * dy)
		draw_line(o + inset, o + inset + Vector2(35 * dx, 0), Color(color, 0.4), 1.0, true)
		draw_line(o + inset, o + inset + Vector2(0, 35 * dy), Color(color, 0.4), 1.0, true)


class GameOverFrame extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		draw_rect(Rect2(12, 12, size.x - 24, size.y - 24), gold, false, 1.0)


class GameOverOrnament extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 0.5)
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		draw_line(Vector2(cx - 140, cy), Vector2(cx + 140, cy), gold, 1.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, cy - 4), Vector2(cx + 4, cy),
			Vector2(cx, cy + 4), Vector2(cx - 4, cy),
		]), gold)
		draw_circle(Vector2(cx - 140, cy), 2.0, gold)
		draw_circle(Vector2(cx + 140, cy), 2.0, gold)


# ── Button style (dark, matching Lobby) ────────────────────

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.13, 0.18, 0.9)
	normal.border_color = Color(0.55, 0.50, 0.35, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.18, 0.25, 0.95)
	hover.border_color = Color(0.75, 0.65, 0.30, 0.8)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(8)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.10, 0.09, 0.14, 0.95)
	pressed.border_color = Color(0.75, 0.65, 0.30, 0.8)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(8)
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", Color(0.78, 0.74, 0.60))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.65))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.55))
	button.add_theme_font_size_override("font_size", 17)

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
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))

	subtitle_label.text = "The war is not over. It never ends."
	subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 0.7))

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
		lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65, 1.0))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.modulate.a = 0.0
		$VBoxContainer.add_child(lbl)
		$VBoxContainer.move_child(lbl, $VBoxContainer.get_child_count() - 4)
		stat_labels.append(lbl)

	_create_win_particles()


func _setup_lose_screen() -> void:
	if RunManager.is_boss_room():
		title_label.text = "The Dire Ancient Endures"
		title_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.65, 1.0))
		subtitle_label.text = "Your fragments scatter. But the ore remembers."
		subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.55, 0.8))
	else:
		title_label.text = "The Ancient Sleeps Again"
		title_label.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42, 1.0))
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
		lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48, 1.0))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.modulate.a = 0.0
		$VBoxContainer.add_child(lbl)
		$VBoxContainer.move_child(lbl, $VBoxContainer.get_child_count() - 4)
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
	# Celebratory gold shower
	win_particles = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 40, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.85, 0.3, 0.7)
	win_particles.process_material = mat
	win_particles.amount = 50
	win_particles.lifetime = 2.0
	win_particles.emitting = true
	win_particles.position = Vector2(get_viewport_rect().size.x / 2.0, 0)
	add_child(win_particles)

	# Extra shimmer layer
	var shimmer := GPUParticles2D.new()
	var s_mat := ParticleProcessMaterial.new()
	s_mat.direction = Vector3(0, -0.3, 0)
	s_mat.spread = 180.0
	s_mat.initial_velocity_min = 3.0
	s_mat.initial_velocity_max = 10.0
	s_mat.gravity = Vector3(0, 0, 0)
	s_mat.scale_min = 1.5
	s_mat.scale_max = 3.0
	s_mat.color = Color(1.0, 0.9, 0.5, 0.15)
	s_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	s_mat.emission_box_extents = Vector3(400, 300, 0)
	shimmer.process_material = s_mat
	shimmer.amount = 20
	shimmer.lifetime = 8.0
	shimmer.position = CENTER
	add_child(shimmer)


func _create_lose_particles() -> void:
	# Somber falling ash
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	mat.color = Color(0.4, 0.3, 0.5, 0.4)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(get_viewport_rect().size.x / 2.0, 10, 0)
	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 4.0
	particles.emitting = true
	particles.position = Vector2(get_viewport_rect().size.x / 2.0, 0)
	add_child(particles)

	# Faint purple mist
	var mist := GPUParticles2D.new()
	var m_mat := ParticleProcessMaterial.new()
	m_mat.direction = Vector3(0, -0.2, 0)
	m_mat.spread = 180.0
	m_mat.initial_velocity_min = 2.0
	m_mat.initial_velocity_max = 6.0
	m_mat.gravity = Vector3(0, 0, 0)
	m_mat.scale_min = 2.0
	m_mat.scale_max = 4.0
	m_mat.color = Color(0.4, 0.25, 0.5, 0.08)
	m_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m_mat.emission_box_extents = Vector3(400, 300, 0)
	mist.process_material = m_mat
	mist.amount = 12
	mist.lifetime = 10.0
	mist.position = CENTER
	add_child(mist)


func _on_return_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
