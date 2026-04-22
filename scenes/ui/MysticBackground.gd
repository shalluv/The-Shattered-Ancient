extends Control

@export var rune_circle_position: Vector2 = Vector2(512, 440)
@export var show_rune_circle: bool = true

const SCREEN_W: float = 1024.0
const SCREEN_H: float = 768.0
const CENTER := Vector2(512, 384)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_background()
	if show_rune_circle:
		_build_rune_circle()
	_build_corner_ornaments()
	_build_border_frame()
	_build_ambient_particles()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_rune_circle() -> void:
	var rune_circle := RuneCircleDrawer.new()
	rune_circle.position = rune_circle_position
	rune_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rune_circle)

	var tw := rune_circle.create_tween()
	tw.set_loops()
	tw.tween_property(rune_circle, "rotation", TAU, 120.0).from(0.0)

	var pulse_tw := rune_circle.create_tween()
	pulse_tw.set_loops()
	pulse_tw.tween_property(rune_circle, "modulate:a", 0.25, 4.0).from(0.15)
	pulse_tw.tween_property(rune_circle, "modulate:a", 0.15, 4.0)


class RuneCircleDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 1.0)
		var dim_gold := Color(0.6, 0.5, 0.2, 0.6)

		_draw_circle_arc(Vector2.ZERO, 160, 0, TAU, gold, 1.5)
		_draw_circle_arc(Vector2.ZERO, 125, 0, TAU, dim_gold, 1.0)
		_draw_circle_arc(Vector2.ZERO, 45, 0, TAU, dim_gold, 1.0)

		for i in 8:
			var angle: float = i * TAU / 8.0
			var inner_pt := Vector2.from_angle(angle) * 52
			var outer_pt := Vector2.from_angle(angle) * 120
			draw_line(inner_pt, outer_pt, dim_gold, 1.0)

		for i in 12:
			var angle: float = i * TAU / 12.0
			var p := Vector2.from_angle(angle) * 142
			var p2 := Vector2.from_angle(angle) * 155
			draw_line(p, p2, gold, 2.0)

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


func _build_corner_ornaments() -> void:
	var ornament_layer := Control.new()
	ornament_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ornament_layer)

	var drawer := CornerOrnamentDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament_layer.add_child(drawer)

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

		_draw_corner(Vector2(MARGIN, MARGIN), 1, 1, gold)
		_draw_corner(Vector2(w - MARGIN, MARGIN), -1, 1, gold)
		_draw_corner(Vector2(MARGIN, h - MARGIN), 1, -1, gold)
		_draw_corner(Vector2(w - MARGIN, h - MARGIN), -1, -1, gold)

	func _draw_corner(origin: Vector2, dx: int, dy: int, color: Color) -> void:
		draw_line(origin, origin + Vector2(ARM * dx, 0), color, 1.5, true)
		draw_line(origin, origin + Vector2(0, ARM * dy), color, 1.5, true)
		draw_circle(origin, 3.0, color)
		var inset := Vector2(10 * dx, 10 * dy)
		draw_line(origin + inset, origin + inset + Vector2(40 * dx, 0), Color(color, 0.5), 1.0, true)
		draw_line(origin + inset, origin + inset + Vector2(0, 40 * dy), Color(color, 0.5), 1.0, true)


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


func _build_ambient_particles() -> void:
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
