extends Camera2D

const EDGE_MARGIN: float = 50.0
const PAN_SPEED: float = 400.0
const SNAP_LERP_WEIGHT: float = 8.0

var is_snapping: bool = false
var snap_target: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_decay: float = 0.0
var pan_locked: bool = false


func _ready() -> void:
	zoom = Vector2(2, 2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("snap_to_core"):
		is_snapping = true
		snap_target = SwarmManager.get_swarm_center()


func _process(delta: float) -> void:
	if is_snapping:
		global_position = global_position.lerp(snap_target, SNAP_LERP_WEIGHT * delta)
		if global_position.distance_to(snap_target) < 2.0:
			global_position = snap_target
			is_snapping = false
		_clamp_to_room()
		return

	if not pan_locked:
		var viewport := get_viewport()
		if not viewport:
			return
		var mouse_pos := viewport.get_mouse_position()
		var viewport_size := viewport.get_visible_rect().size
		var pan_direction := Vector2.ZERO

		if mouse_pos.x < EDGE_MARGIN:
			pan_direction.x = -1.0
		elif mouse_pos.x > viewport_size.x - EDGE_MARGIN:
			pan_direction.x = 1.0

		if mouse_pos.y < EDGE_MARGIN:
			pan_direction.y = -1.0
		elif mouse_pos.y > viewport_size.y - EDGE_MARGIN:
			pan_direction.y = 1.0

		if pan_direction != Vector2.ZERO:
			global_position += pan_direction.normalized() * PAN_SPEED * delta

		_clamp_to_room()

	if shake_intensity > 0.0:
		shake_intensity -= shake_decay * delta
		if shake_intensity <= 0.0:
			shake_intensity = 0.0
			offset = Vector2.ZERO
		else:
			offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))


func shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_decay = intensity / duration if duration > 0.0 else intensity


func zoom_pulse(amount: float, duration: float) -> void:
	var base_zoom := zoom
	var target_zoom := base_zoom * (1.0 - amount)
	var tween := create_tween()
	tween.tween_property(self, "zoom", target_zoom, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", base_zoom, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _clamp_to_room() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var vp_size := vp.get_visible_rect().size / zoom
	var half_vp := vp_size / 2.0
	global_position.x = clampf(global_position.x, limit_left + half_vp.x, limit_right - half_vp.x)
	global_position.y = clampf(global_position.y, limit_top + half_vp.y, limit_bottom - half_vp.y)
