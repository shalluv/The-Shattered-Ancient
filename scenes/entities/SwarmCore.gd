extends CharacterBody2D

@onready var core_visual: ColorRect = $CoreVisual
@onready var destination_indicator: GPUParticles2D = $DestinationIndicator


func _ready() -> void:
	SwarmManager.register_swarm_core(self)
	core_visual.visible = false
	_setup_destination_indicator()


func _physics_process(_delta: float) -> void:
	SwarmManager.update_core_position()


func show_destination(pos: Vector2) -> void:
	destination_indicator.global_position = pos
	destination_indicator.restart()
	destination_indicator.emitting = true


func _setup_destination_indicator() -> void:
	destination_indicator.top_level = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	mat.color = Color(1.0, 0.98, 0.8, 1.0)
	destination_indicator.process_material = mat
	destination_indicator.amount = 10
	destination_indicator.lifetime = 0.5
	destination_indicator.one_shot = true
	destination_indicator.explosiveness = 1.0
	destination_indicator.emitting = false
