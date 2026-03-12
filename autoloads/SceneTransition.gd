extends Node

signal transition_midpoint
signal transition_finished

var overlay_layer: CanvasLayer = null
var overlay_rect: ColorRect = null
var is_transitioning: bool = false


func _ready() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 200
	add_child(overlay_layer)

	overlay_rect = ColorRect.new()
	overlay_rect.color = Color(0, 0, 0, 0)
	overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay_rect)


func transition_to(scene_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	var tween := create_tween()
	tween.tween_property(overlay_rect, "color:a", 1.0, 0.3)
	await tween.finished

	transition_midpoint.emit()
	SelectionManager.clear_selection()

	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.tween_property(overlay_rect, "color:a", 0.0, 0.3)
	await fade_in.finished

	is_transitioning = false
	transition_finished.emit()
