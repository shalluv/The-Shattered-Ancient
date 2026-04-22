extends Node

signal transition_midpoint
signal transition_finished

var overlay_layer: CanvasLayer = null
var overlay_rect: ColorRect = null
var is_transitioning: bool = false
var previous_scene_path: String = ""


func _ready() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 200
	add_child(overlay_layer)

	overlay_rect = ColorRect.new()
	overlay_rect.color = Color(0, 0, 0, 0)
	overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay_rect)

	# Start BGM for the initial scene (MainMenu)
	call_deferred("_start_initial_bgm")


func _start_initial_bgm() -> void:
	var scene := get_tree().current_scene
	if scene and is_instance_valid(AudioManager):
		AudioManager.update_bgm_for_scene(scene.name)


func transition_to(scene_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	var current := get_tree().current_scene
	if current:
		previous_scene_path = current.scene_file_path

	var tween := create_tween()
	tween.tween_property(overlay_rect, "color:a", 1.0, 0.3)
	await tween.finished

	transition_midpoint.emit()
	SelectionManager.clear_selection()

	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame

	# Extract scene name from path (e.g. "res://scenes/lobby/Lobby.tscn" → "Lobby")
	var scene_name := scene_path.get_file().get_basename()
	if is_instance_valid(AudioManager):
		AudioManager.update_bgm_for_scene(scene_name)

	var fade_in := create_tween()
	fade_in.tween_property(overlay_rect, "color:a", 0.0, 0.3)
	await fade_in.finished

	is_transitioning = false
	transition_finished.emit()
