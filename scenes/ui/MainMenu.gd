extends Control

var ui_root: Control = null
var rune_circle: Control = null

const SCREEN_W: float = 1024.0
const SCREEN_H: float = 768.0
const CENTER := Vector2(512, 384)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_background()
	_build_rune_circle()
	_build_corner_ornaments()
	_build_border_frame()
	_build_ambient_particles()
	_build_ui()
	_animate_fade_in()


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

	# ── Title section ──
	var title_container := VBoxContainer.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER)
	title_container.offset_left = -280
	title_container.offset_right = 280
	title_container.offset_top = -80
	title_container.offset_bottom = 120
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 10)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(title_container)

	var title_label := Label.new()
	title_label.text = "The Shattered Ancient"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Summon your swarm and conquer the dungeons"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.50, 0.7))
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(subtitle_label)

	# ── Buttons ──
	var button_container := VBoxContainer.new()
	button_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button_container.offset_left = -150
	button_container.offset_right = 150
	button_container.offset_top = -200
	button_container.offset_bottom = -20
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 12)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(button_container)

	var begin_btn := Button.new()
	begin_btn.text = "Begin Run"
	begin_btn.custom_minimum_size = Vector2(280, 48)
	begin_btn.pressed.connect(_on_begin_pressed)
	_style_button(begin_btn)
	button_container.add_child(begin_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(280, 48)
	settings_btn.pressed.connect(_on_settings_pressed)
	_style_button(settings_btn)
	button_container.add_child(settings_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(280, 48)
	quit_btn.pressed.connect(_on_quit_pressed)
	_style_button(quit_btn)
	button_container.add_child(quit_btn)

	# Version label
	var version := Label.new()
	version.text = "v0.10"
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-60, -30)
	ui_root.add_child(version)


# ── Fade-in animation ──────────────────────────────────────

func _animate_fade_in() -> void:
	ui_root.modulate.a = 0.0
	var tw := ui_root.create_tween()
	tw.tween_property(ui_root, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


# ── Callbacks ──────────────────────────────────────────────

func _on_begin_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.transition_to("res://scenes/ui/Settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
