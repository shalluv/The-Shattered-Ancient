extends Control

@onready var prompt: Label = $Prompt
var _advanced: bool = false


func _ready() -> void:
	_start_blink()


func _start_blink() -> void:
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(prompt, "modulate:a", 0.15, 1.2)
	tw.tween_property(prompt, "modulate:a", 1.0, 1.2)


## Left / right click: handled here because TextureRect/Label use STOP by default
## and consume mouse before _unhandled_input. Children use IGNORE so this root gets _gui_input.
func _gui_input(event: InputEvent) -> void:
	if _advanced:
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		_advanced = true
		accept_event()
		SceneTransition.transition_to("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _advanced:
		return
	var is_action: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if is_action:
		_advanced = true
		get_viewport().set_input_as_handled()
		SceneTransition.transition_to("res://scenes/ui/MainMenu.tscn")
