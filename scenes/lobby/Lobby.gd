extends Control

var shard_label: Label = null
var dialogue_label: Label = null
var ui_root: Control = null
var rune_circle: Control = null

const SCREEN_W: float = 1024.0
const SCREEN_H: float = 768.0
const CENTER := Vector2(512, 384)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if SelectionManager:
		SelectionManager.set_process_input(false)
	tree_exiting.connect(_on_tree_exiting)

	_build_background()
	_build_rune_circle()
	_build_corner_ornaments()
	_build_border_frame()
	_build_ambient_particles()
	_build_ui()
	_animate_fade_in()


func _on_tree_exiting() -> void:
	if SelectionManager:
		SelectionManager.set_process_input(true)


# ── Button styling ─────────────────────────────────────────

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


# ── Background with gradient layers ───────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	add_child(bg)


# ── Rune circle (slowly rotating mystical symbol) ─────────

func _build_rune_circle() -> void:
	rune_circle = RuneCircleDrawer.new()
	rune_circle.position = Vector2(512, 440)
	rune_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rune_circle)

	# Slow rotation
	var tw := rune_circle.create_tween()
	tw.set_loops()
	tw.tween_property(rune_circle, "rotation", TAU, 120.0).from(0.0)

	# Gentle pulse
	var pulse_tw := rune_circle.create_tween()
	pulse_tw.set_loops()
	pulse_tw.tween_property(rune_circle, "modulate:a", 0.25, 4.0).from(0.15)
	pulse_tw.tween_property(rune_circle, "modulate:a", 0.15, 4.0)


class RuneCircleDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		var dim_gold := Color(0.6, 0.5, 0.2, 0.6)

		# Outer ring
		_draw_circle_arc(Vector2.ZERO, 160, 0, TAU, gold, 1.5)
		# Inner ring
		_draw_circle_arc(Vector2.ZERO, 125, 0, TAU, dim_gold, 1.0)
		# Innermost ring
		_draw_circle_arc(Vector2.ZERO, 45, 0, TAU, dim_gold, 1.0)

		# Cross lines through center
		for i in 8:
			var angle: float = i * TAU / 8.0
			var inner_pt := Vector2.from_angle(angle) * 52
			var outer_pt := Vector2.from_angle(angle) * 120
			draw_line(inner_pt, outer_pt, dim_gold, 1.0)

		# Rune marks on the outer ring
		for i in 12:
			var angle: float = i * TAU / 12.0
			var p := Vector2.from_angle(angle) * 142
			var p2 := Vector2.from_angle(angle) * 155
			draw_line(p, p2, gold, 2.0)

		# Small diamonds at cardinal points
		for i in 4:
			var angle: float = i * TAU / 4.0
			var p := Vector2.from_angle(angle) * 160
			_draw_diamond(p, 5, gold)

	func _draw_circle_arc(center: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void:
		var nb_points := 64
		var points := PackedVector2Array()
		for i in nb_points + 1:
			var angle := start + i * (end - start) / nb_points
			points.append(center + Vector2.from_angle(angle) * radius)
		for i in nb_points:
			draw_line(points[i], points[i + 1], color, width, true)

	func _draw_diamond(pos: Vector2, sz: float, color: Color) -> void:
		var pts := PackedVector2Array([
			pos + Vector2(0, -sz),
			pos + Vector2(sz, 0),
			pos + Vector2(0, sz),
			pos + Vector2(-sz, 0),
		])
		draw_colored_polygon(pts, color)


# ── Corner ornaments ───────────────────────────────────────

func _build_corner_ornaments() -> void:
	var ornament_layer := Control.new()
	ornament_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ornament_layer)

	var drawer := CornerOrnamentDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament_layer.add_child(drawer)

	# Soft breathing animation
	ornament_layer.modulate.a = 0.35
	var tw := ornament_layer.create_tween()
	tw.set_loops()
	tw.tween_property(ornament_layer, "modulate:a", 0.5, 3.0)
	tw.tween_property(ornament_layer, "modulate:a", 0.35, 3.0)


class CornerOrnamentDrawer extends Control:
	const MARGIN := 30.0
	const ARM := 80.0

	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		var w := size.x
		var h := size.y

		# Top-left
		_draw_corner(Vector2(MARGIN, MARGIN), 1, 1, gold)
		# Top-right
		_draw_corner(Vector2(w - MARGIN, MARGIN), -1, 1, gold)
		# Bottom-left
		_draw_corner(Vector2(MARGIN, h - MARGIN), 1, -1, gold)
		# Bottom-right
		_draw_corner(Vector2(w - MARGIN, h - MARGIN), -1, -1, gold)

	func _draw_corner(origin: Vector2, dx: int, dy: int, color: Color) -> void:
		# L-shape arms
		draw_line(origin, origin + Vector2(ARM * dx, 0), color, 1.5, true)
		draw_line(origin, origin + Vector2(0, ARM * dy), color, 1.5, true)
		# Small dot at corner
		draw_circle(origin, 3.0, color)
		# Inner shorter lines
		var inset := Vector2(10 * dx, 10 * dy)
		draw_line(origin + inset, origin + inset + Vector2(40 * dx, 0), Color(color, 0.5), 1.0, true)
		draw_line(origin + inset, origin + inset + Vector2(0, 40 * dy), Color(color, 0.5), 1.0, true)


# ── Border frame (thin line around viewport) ───────────────

func _build_border_frame() -> void:
	var frame := BorderFrameDrawer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.2
	add_child(frame)


class BorderFrameDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		var rect := Rect2(15, 15, size.x - 30, size.y - 30)
		draw_rect(rect, gold, false, 1.0)


# ── Ambient particles (multiple layers) ───────────────────

func _build_ambient_particles() -> void:
	# Layer 1: Gold dust (slow, wide)
	var dust := GPUParticles2D.new()
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0.5, -1, 0)
	dust_mat.spread = 60.0
	dust_mat.initial_velocity_min = 5.0
	dust_mat.initial_velocity_max = 15.0
	dust_mat.gravity = Vector3(0, 0, 0)
	dust_mat.scale_min = 1.0
	dust_mat.scale_max = 2.5
	dust_mat.color = Color(1.0, 0.85, 0.4, 0.25)
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(512, 384, 0)
	dust.process_material = dust_mat
	dust.amount = 40
	dust.lifetime = 8.0
	dust.position = CENTER
	add_child(dust)

	# Layer 2: Warm embers (rising, brighter, fewer)
	var embers := GPUParticles2D.new()
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.direction = Vector3(0, -1, 0)
	ember_mat.spread = 25.0
	ember_mat.initial_velocity_min = 20.0
	ember_mat.initial_velocity_max = 50.0
	ember_mat.gravity = Vector3(0, -5, 0)
	ember_mat.scale_min = 2.0
	ember_mat.scale_max = 4.0
	ember_mat.color = Color(1.0, 0.6, 0.2, 0.5)
	ember_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_mat.emission_box_extents = Vector3(300, 20, 0)
	embers.process_material = ember_mat
	embers.amount = 12
	embers.lifetime = 3.0
	embers.position = Vector2(512, 750)
	add_child(embers)

	# Layer 3: Faint mystical shimmer (scattered, slow-moving)
	var shimmer := GPUParticles2D.new()
	var shimmer_mat := ParticleProcessMaterial.new()
	shimmer_mat.direction = Vector3(0, -0.5, 0)
	shimmer_mat.spread = 180.0
	shimmer_mat.initial_velocity_min = 2.0
	shimmer_mat.initial_velocity_max = 8.0
	shimmer_mat.gravity = Vector3(0, 0, 0)
	shimmer_mat.scale_min = 1.5
	shimmer_mat.scale_max = 3.5
	shimmer_mat.color = Color(0.7, 0.6, 1.0, 0.12)
	shimmer_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	shimmer_mat.emission_box_extents = Vector3(450, 350, 0)
	shimmer.process_material = shimmer_mat
	shimmer.amount = 15
	shimmer.lifetime = 10.0
	shimmer.position = CENTER
	add_child(shimmer)


# ── Main UI layout ─────────────────────────────────────────

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	# ── Top section: Title ──
	var title_container := VBoxContainer.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_container.offset_left = -400
	title_container.offset_right = 400
	title_container.offset_top = 50
	title_container.offset_bottom = 250
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 2)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(title_container)

	var title_line1 := Label.new()
	title_line1.text = "— T H E —"
	title_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_line1.add_theme_color_override("font_color", Color(0.7, 0.65, 0.50, 0.7))
	title_line1.add_theme_font_size_override("font_size", 16)
	title_line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title_line1)

	var title_line2 := Label.new()
	title_line2.text = "SHATTERED"
	title_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_line2.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	title_line2.add_theme_font_size_override("font_size", 58)
	title_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title_line2)

	var title_line3 := Label.new()
	title_line3.text = "ANCIENT"
	title_line3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_line3.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 0.9))
	title_line3.add_theme_font_size_override("font_size", 30)
	title_line3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title_line3)

	# Title underline ornament
	var title_ornament := TitleOrnamentDrawer.new()
	title_ornament.custom_minimum_size = Vector2(400, 20)
	title_ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title_ornament)

	# ── Center section: Shard + Dialogue ──
	var center_container := VBoxContainer.new()
	center_container.set_anchors_preset(Control.PRESET_CENTER)
	center_container.offset_left = -280
	center_container.offset_right = 280
	center_container.offset_top = 10
	center_container.offset_bottom = 140
	center_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_theme_constant_override("separation", 14)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(center_container)

	shard_label = Label.new()
	shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	shard_label.add_theme_font_size_override("font_size", 22)
	shard_label.text = "Radiant Ore Shards: %d" % MetaProgress.radiant_ore_shards
	shard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_container.add_child(shard_label)

	shard_label.pivot_offset = Vector2(280, 12)
	var shard_pulse := shard_label.create_tween()
	shard_pulse.set_loops()
	shard_pulse.tween_property(shard_label, "scale", Vector2(1.03, 1.03), 1.2)
	shard_pulse.tween_property(shard_label, "scale", Vector2.ONE, 1.2)

	dialogue_label = Label.new()
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(500, 0)
	dialogue_label.add_theme_color_override("font_color", Color(0.58, 0.55, 0.45, 0.85))
	dialogue_label.add_theme_font_size_override("font_size", 15)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trigger := _get_dialogue_trigger()
	dialogue_label.text = "\"" + DialogueManager.get_line(trigger) + "\""
	center_container.add_child(dialogue_label)

	var full_text: String = dialogue_label.text
	dialogue_label.visible_ratio = 0.0
	var char_count: int = full_text.length()
	var type_duration: float = float(char_count) / 40.0
	var type_tw := dialogue_label.create_tween()
	type_tw.tween_property(dialogue_label, "visible_ratio", 1.0, type_duration)

	# ── Bottom section: Button bar ──
	_build_button_bar()


class TitleOrnamentDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 0.6)
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		# Main line
		draw_line(Vector2(cx - 150, cy), Vector2(cx + 150, cy), gold, 1.0, true)
		# Center diamond
		var pts := PackedVector2Array([
			Vector2(cx, cy - 5), Vector2(cx + 5, cy),
			Vector2(cx, cy + 5), Vector2(cx - 5, cy),
		])
		draw_colored_polygon(pts, gold)
		# End dots
		draw_circle(Vector2(cx - 150, cy), 2.5, gold)
		draw_circle(Vector2(cx + 150, cy), 2.5, gold)
		# Short perpendicular ticks
		for offset in [-80.0, -40.0, 40.0, 80.0]:
			draw_line(Vector2(cx + offset, cy - 3), Vector2(cx + offset, cy + 3), Color(gold, 0.4), 1.0)


func _build_button_bar() -> void:
	var bar_panel := PanelContainer.new()
	bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_panel.offset_top = -90
	bar_panel.offset_bottom = 0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	bar_style.border_color = Color(0.45, 0.38, 0.20, 0.5)
	bar_style.border_width_top = 1
	bar_style.set_content_margin_all(0)
	bar_style.content_margin_top = 20
	bar_style.content_margin_bottom = 20
	bar_style.content_margin_left = 40
	bar_style.content_margin_right = 40
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	ui_root.add_child(bar_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	bar_panel.add_child(hbox)

	var begin_btn := Button.new()
	begin_btn.text = "Begin New Run"
	begin_btn.custom_minimum_size = Vector2(180, 48)
	begin_btn.pressed.connect(_on_begin_pressed)
	_style_button(begin_btn)
	hbox.add_child(begin_btn)

	var upgrades_btn := Button.new()
	upgrades_btn.text = "Upgrades"
	upgrades_btn.custom_minimum_size = Vector2(140, 48)
	upgrades_btn.pressed.connect(_on_upgrades_pressed)
	_style_button(upgrades_btn)
	hbox.add_child(upgrades_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(140, 48)
	settings_btn.pressed.connect(_on_settings_pressed)
	_style_button(settings_btn)
	hbox.add_child(settings_btn)

	var title_btn := Button.new()
	title_btn.text = "Back to Title"
	title_btn.custom_minimum_size = Vector2(150, 48)
	title_btn.pressed.connect(_on_title_pressed)
	_style_button(title_btn)
	hbox.add_child(title_btn)


# ── Fade-in animation ──────────────────────────────────────

func _animate_fade_in() -> void:
	ui_root.modulate.a = 0.0
	var tw := ui_root.create_tween()
	tw.tween_property(ui_root, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


# ── Callbacks ──────────────────────────────────────────────

func _get_dialogue_trigger() -> String:
	if RunManager.run_end_trigger != "":
		return RunManager.run_end_trigger
	if MetaProgress.runs_completed == 0:
		return "first_visit"
	return "first_visit"


func _on_begin_pressed() -> void:
	RunManager.start_run()
	SceneTransition.transition_to("res://scenes/ui/ArmyDraft.tscn")


func _on_upgrades_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/MetaUpgrades.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.transition_to("res://scenes/ui/Settings.tscn")


func _on_title_pressed() -> void:
	SceneTransition.transition_to("res://scenes/ui/MainMenu.tscn")
