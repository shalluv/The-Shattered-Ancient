extends "res://scenes/entities/units/UnitBase.gd"

const BASE_AURA_RADIUS: float = 50.0
var aura_radius: float = BASE_AURA_RADIUS
const AURA_SEGMENTS: int = 32
const AURA_ALPHA_SPEED: float = 0.0
const AURA_LAYER_COUNT: int = 1
const AURA_ROTATION_SPEED: float = 0.15

var aura_layers: Array[Polygon2D] = []
var aura_glitter: GPUParticles2D = null
var neutrals_in_aura: Array[Node2D] = []
var aura_time: float = 0.0

const LAYER_RADIUS_RATIOS: Array[float] = [1.0, 0.72, 0.42]
const LAYER_BASE_ALPHAS: Array[float] = [0.02, 0.10, 0.14]
const LAYER_PHASE_OFFSETS: Array[float] = [0.0, 2.1, 4.2]


func _ready() -> void:
	super._ready()
	_create_aura_visuals()
	_create_aura_glitter()


func _physics_process(delta: float) -> void:
	if is_dying or is_reviving:
		return

	if unit_sprite and velocity.length_squared() > 1.0:
		unit_sprite.rotation = velocity.angle() + PI / 2.0

	var separation := _calculate_separation_force()

	if has_move_target:
		var distance := global_position.distance_to(target_position)
		if distance > ARRIVAL_THRESHOLD:
			if not _follow_path(separation):
				if Pathfinder.has_line_of_sight(global_position, target_position):
					var direction := global_position.direction_to(target_position)
					velocity = direction * move_speed + separation
				else:
					current_path = Pathfinder.find_path(global_position, target_position)
					path_index = 0
					_advance_path_index()
					if not _follow_path(separation):
						velocity = separation
			move_and_slide()
		else:
			global_position = target_position
			velocity = separation
			has_move_target = false
			current_path = PackedVector2Array()
			if velocity.length_squared() > 0.1:
				move_and_slide()
	else:
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()

	aura_time += delta
	for i in AURA_LAYER_COUNT:
		var alpha_offset := 0.03 * sin(aura_time * AURA_ALPHA_SPEED * TAU + LAYER_PHASE_OFFSETS[i])
		var base_alpha: float = LAYER_BASE_ALPHAS[i]
		aura_layers[i].color.a = base_alpha + alpha_offset
	aura_layers[0].rotation += AURA_ROTATION_SPEED * delta

	_scan_neutrals()


func _create_aura_visuals() -> void:
	for i in AURA_LAYER_COUNT:
		var layer := Polygon2D.new()
		var radius := aura_radius * LAYER_RADIUS_RATIOS[i]
		var points: PackedVector2Array = PackedVector2Array()
		for j in AURA_SEGMENTS:
			var angle := float(j) / float(AURA_SEGMENTS) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		layer.polygon = points
		layer.color = Color(1.0, 0.843, 0.0, LAYER_BASE_ALPHAS[i])
		layer.z_index = 0
		add_child(layer)
		move_child(layer, 0)
		aura_layers.append(layer)


func _create_aura_glitter() -> void:
	aura_glitter = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = aura_radius
	mat.emission_ring_inner_radius = 0.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.843, 0.0, 0.6))
	gradient.set_color(1, Color(1.0, 0.843, 0.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	aura_glitter.process_material = mat
	aura_glitter.amount = 18
	aura_glitter.lifetime = 2.0
	aura_glitter.z_index = 0
	add_child(aura_glitter)
	move_child(aura_glitter, 0)


func _scan_neutrals() -> void:
	var current_neutrals: Array[Node2D] = []
	for neutral in get_tree().get_nodes_in_group("neutrals"):
		if not is_instance_valid(neutral):
			continue
		var dist := global_position.distance_to(neutral.global_position)
		if dist < aura_radius:
			current_neutrals.append(neutral)
			if neutral.has_method("set_in_aura"):
				neutral.set_in_aura(true, self)

	for old_neutral in neutrals_in_aura:
		if is_instance_valid(old_neutral) and old_neutral not in current_neutrals:
			if old_neutral.has_method("set_in_aura"):
				old_neutral.set_in_aura(false, null)

	neutrals_in_aura = current_neutrals


func die() -> void:
	for neutral in neutrals_in_aura:
		if is_instance_valid(neutral) and neutral.has_method("set_in_aura"):
			neutral.set_in_aura(false, null)
	neutrals_in_aura.clear()
	for layer in aura_layers:
		layer.visible = false
	if aura_glitter:
		aura_glitter.emitting = false
		aura_glitter.visible = false
	super.die()
