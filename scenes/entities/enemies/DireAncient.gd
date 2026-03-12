extends "res://scenes/entities/enemies/EnemyBase.gd"

signal boss_defeated

const BOSS_HP: int = 30
const BOSS_COLOR: Color = Color("#4B0082")
const AURA_COLOR: Color = Color("#8B0000")

const ATTACK_GAP: float = 8.0
const SURGE_TELEGRAPH: float = 1.5
const SURGE_GRUNT_COUNT: int = 3
const CORRUPTION_TELEGRAPH: float = 1.0
const CORRUPTION_RADIUS: float = 200.0
const GAZE_TELEGRAPH: float = 1.5
const GAZE_CONE_ANGLE: float = 45.0
const GAZE_RANGE: float = 250.0

const PHASE_2_HP_THRESHOLD: int = 15
const PHASE_2_ATTACK_GAP: float = 5.0
const PHASE_2_SURGE_COUNT: int = 5
const PHASE_2_CORRUPTION_RADIUS: float = 280.0
const PHASE_2_COLOR: Color = Color("#2D0057")

enum BossState { IDLE, TELEGRAPH, ATTACKING }
enum AttackType { DIRE_SURGE, CORRUPTION_WAVE, DIRE_GAZE }

var boss_state: BossState = BossState.IDLE
var current_attack: AttackType = AttackType.DIRE_SURGE
var attack_timer: float = 0.0
var telegraph_timer: float = 0.0
var fight_started: bool = false
var current_phase: int = 1
var phase_transition_triggered: bool = false

var hp_bar: ProgressBar = null
var aura_particles: GPUParticles2D = null
var telegraph_visual: Node2D = null
var phase_2_tint_layer: CanvasLayer = null

var DireGruntScene := preload("res://scenes/entities/enemies/DireGrunt.tscn")


func _ready() -> void:
	super()
	add_to_group("boss")

	_create_hp_bar()
	_create_aura_particles()

	attack_timer = 0.0


func _create_hp_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = BOSS_HP
	hp_bar.value = BOSS_HP
	hp_bar.size = Vector2(80, 8)
	hp_bar.position = Vector2(-40, -42)
	hp_bar.show_percentage = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.294, 0.0, 0.51, 1.0)
	hp_bar.add_theme_stylebox_override("fill", style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	hp_bar.add_theme_stylebox_override("background", bg_style)

	add_child(hp_bar)


func _create_aura_particles() -> void:
	aura_particles = GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 35.0
	mat.emission_ring_inner_radius = 25.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = AURA_COLOR
	aura_particles.process_material = mat
	aura_particles.amount = 16
	aura_particles.lifetime = 1.5
	aura_particles.emitting = true
	add_child(aura_particles)


func start_fight() -> void:
	fight_started = true
	attack_timer = 0.0


func _physics_process(delta: float) -> void:
	if is_dying or not fight_started:
		return

	_update_slow_state(delta)

	match boss_state:
		BossState.IDLE:
			_process_idle(delta)
		BossState.TELEGRAPH:
			_process_telegraph(delta)
		BossState.ATTACKING:
			pass


func _process_idle(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		boss_state = BossState.TELEGRAPH
		_start_telegraph()


func _start_telegraph() -> void:
	match current_attack:
		AttackType.DIRE_SURGE:
			telegraph_timer = SURGE_TELEGRAPH
			_show_surge_telegraph()
		AttackType.CORRUPTION_WAVE:
			telegraph_timer = CORRUPTION_TELEGRAPH
			_show_corruption_telegraph()
		AttackType.DIRE_GAZE:
			telegraph_timer = GAZE_TELEGRAPH
			_show_gaze_telegraph()


func _process_telegraph(delta: float) -> void:
	telegraph_timer -= delta
	if telegraph_timer <= 0.0:
		_clear_telegraph()
		boss_state = BossState.ATTACKING
		_execute_attack()


func _execute_attack() -> void:
	match current_attack:
		AttackType.DIRE_SURGE:
			_attack_dire_surge()
		AttackType.CORRUPTION_WAVE:
			_attack_corruption_wave()
		AttackType.DIRE_GAZE:
			_attack_dire_gaze()

	current_attack = (current_attack + 1) % 3 as AttackType
	attack_timer = PHASE_2_ATTACK_GAP if current_phase == 2 else ATTACK_GAP
	boss_state = BossState.IDLE


func _show_surge_telegraph() -> void:
	var tween := create_tween()
	var current_color := PHASE_2_COLOR if current_phase == 2 else BOSS_COLOR
	tween.tween_property(enemy_visual, "color", Color.WHITE, SURGE_TELEGRAPH * 0.5)
	tween.tween_property(enemy_visual, "color", current_color, SURGE_TELEGRAPH * 0.5)


func _show_corruption_telegraph() -> void:
	telegraph_visual = Node2D.new()
	add_child(telegraph_visual)

	var radius := PHASE_2_CORRUPTION_RADIUS if current_phase == 2 else CORRUPTION_RADIUS
	var ring := _create_ring_polygon(radius, 32, Color(0.545, 0.0, 0.0, 0.3))
	telegraph_visual.add_child(ring)

	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), CORRUPTION_TELEGRAPH).from(Vector2(0.1, 0.1))


func _show_gaze_telegraph() -> void:
	telegraph_visual = Node2D.new()
	add_child(telegraph_visual)

	var target := SwarmManager.get_swarm_center()
	var direction := global_position.direction_to(target)
	var angle := direction.angle()

	var cone := _create_cone_polygon(GAZE_RANGE, GAZE_CONE_ANGLE, Color(0.545, 0.0, 0.0, 0.3))
	cone.rotation = angle
	telegraph_visual.add_child(cone)

	if current_phase == 2:
		var cone2 := _create_cone_polygon(GAZE_RANGE, GAZE_CONE_ANGLE, Color(0.545, 0.0, 0.0, 0.3))
		cone2.rotation = angle + PI / 2.0
		telegraph_visual.add_child(cone2)


func _clear_telegraph() -> void:
	if telegraph_visual and is_instance_valid(telegraph_visual):
		telegraph_visual.queue_free()
		telegraph_visual = null


func _attack_dire_surge() -> void:
	var room_size := Vector2(1600, 1000)
	var grunt_count := PHASE_2_SURGE_COUNT if current_phase == 2 else SURGE_GRUNT_COUNT
	var spawn_positions: Array[Vector2] = [
		Vector2(50, global_position.y),
		Vector2(room_size.x - 50, global_position.y),
		Vector2(global_position.x, 50),
	]
	if current_phase == 2:
		spawn_positions.append(Vector2(global_position.x, room_size.y - 50))
		spawn_positions.append(Vector2(room_size.x / 2.0, room_size.y / 2.0))

	RunManager.add_enemies(grunt_count)

	for i in grunt_count:
		var grunt := DireGruntScene.instantiate()
		grunt.global_position = spawn_positions[i % spawn_positions.size()]
		get_parent().add_child(grunt)


func _attack_corruption_wave() -> void:
	var radius := PHASE_2_CORRUPTION_RADIUS if current_phase == 2 else CORRUPTION_RADIUS
	for unit in SwarmManager.units:
		if not is_instance_valid(unit):
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist <= radius and unit.has_method("take_damage"):
			unit.take_damage(1)


func _attack_dire_gaze() -> void:
	var target := SwarmManager.get_swarm_center()
	var gaze_direction := global_position.direction_to(target)
	var half_angle := deg_to_rad(GAZE_CONE_ANGLE / 2.0)

	for unit in SwarmManager.units:
		if not is_instance_valid(unit):
			continue
		var to_unit := global_position.direction_to(unit.global_position)
		var dist := global_position.distance_to(unit.global_position)
		var angle_diff := absf(gaze_direction.angle_to(to_unit))
		if dist <= GAZE_RANGE and angle_diff <= half_angle and unit.has_method("take_damage"):
			unit.take_damage(1)

	if current_phase == 2:
		var gaze_dir_2 := gaze_direction.rotated(PI / 2.0)
		for unit in SwarmManager.units:
			if not is_instance_valid(unit):
				continue
			var to_unit := global_position.direction_to(unit.global_position)
			var dist := global_position.distance_to(unit.global_position)
			var angle_diff := absf(gaze_dir_2.angle_to(to_unit))
			if dist <= GAZE_RANGE and angle_diff <= half_angle and unit.has_method("take_damage"):
				unit.take_damage(1)


func take_hit(amount: int) -> void:
	super(amount)
	if hp_bar:
		hp_bar.value = enemy_hp
	if not phase_transition_triggered and enemy_hp <= PHASE_2_HP_THRESHOLD and enemy_hp > 0:
		_trigger_phase_2()


func _trigger_phase_2() -> void:
	phase_transition_triggered = true
	current_phase = 2

	# TODO: Add boss phase 2 sound effect
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(8.0, 1.5)

	var tween := create_tween()
	tween.tween_property(enemy_visual, "color", Color.WHITE, 0.3)
	tween.tween_property(enemy_visual, "color", PHASE_2_COLOR, 0.5)

	if aura_particles:
		var aura_mat: ParticleProcessMaterial = aura_particles.process_material
		aura_mat.color = PHASE_2_COLOR
		aura_particles.amount = 24

	_show_phase_2_text()
	_play_phase_2_burst()

	phase_2_tint_layer = CanvasLayer.new()
	phase_2_tint_layer.layer = 5
	var tint_rect := ColorRect.new()
	tint_rect.color = Color(0.545, 0.0, 0.0, 0.0)
	tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_2_tint_layer.add_child(tint_rect)
	get_tree().current_scene.add_child(phase_2_tint_layer)
	var tint_tween := tint_rect.create_tween()
	tint_tween.tween_property(tint_rect, "color:a", 0.15, 0.5)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and is_instance_valid(enemy):
			var vis: ColorRect = enemy.get_node_or_null("EnemyVisual")
			if vis:
				var orig_color: Color = vis.color
				var ftw := vis.create_tween()
				ftw.tween_property(vis, "color", Color.WHITE, 0.15)
				ftw.tween_property(vis, "color", orig_color, 0.15)


func _show_phase_2_text() -> void:
	var label := Label.new()
	label.text = "The Dire Awakens"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", PHASE_2_COLOR)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 60
	label.offset_left = -200
	label.offset_right = 200

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(label)

	var fade_tween := label.create_tween()
	fade_tween.tween_interval(1.0)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(canvas.queue_free)


func _play_phase_2_burst() -> void:
	var particles := GPUParticles2D.new()
	particles.top_level = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 3.0
	mat.scale_max = 6.0
	mat.color = PHASE_2_COLOR
	particles.process_material = mat
	particles.amount = 40
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.global_position = global_position
	get_parent().add_child(particles)
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("enemies")

	_clear_telegraph()
	fight_started = false

	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)

	var death_color := PHASE_2_COLOR if current_phase == 2 else BOSS_COLOR
	var tween := create_tween()
	tween.tween_property(enemy_visual, "color", Color.WHITE, 0.25)
	tween.tween_property(enemy_visual, "color", death_color, 0.25)

	_create_boss_death_explosion()

	# TODO: Add boss death sound effect
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(12.0, 0.6)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 10
	var flash_rect := ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0.8)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(flash_rect)
	get_tree().current_scene.add_child(flash_layer)
	var flash_tw := flash_rect.create_tween()
	flash_tw.tween_property(flash_rect, "color:a", 0.0, 0.4)
	flash_tw.tween_callback(flash_layer.queue_free)

	var remaining_enemies := get_tree().get_nodes_in_group("enemies").duplicate()
	for i in remaining_enemies.size():
		var enemy = remaining_enemies[i]
		if enemy != self and is_instance_valid(enemy) and not enemy.is_dying and enemy.has_method("die"):
			if i > 0:
				await get_tree().create_timer(0.1).timeout
			var vis: ColorRect = enemy.get_node_or_null("EnemyVisual")
			if vis:
				var etw := vis.create_tween()
				etw.tween_property(vis, "color", Color.WHITE, 0.15)
				etw.tween_callback(enemy.die)
			else:
				enemy.die()

	if aura_particles:
		aura_particles.emitting = false

	if phase_2_tint_layer and is_instance_valid(phase_2_tint_layer):
		phase_2_tint_layer.queue_free()

	await tween.finished
	await get_tree().create_timer(0.5).timeout

	boss_defeated.emit()

	enemy_visual.visible = false
	if hp_bar:
		hp_bar.visible = false

	await get_tree().create_timer(0.3).timeout
	queue_free()


func _create_boss_death_explosion() -> void:
	var particles := GPUParticles2D.new()
	particles.top_level = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 3.0
	mat.scale_max = 6.0
	var death_color := PHASE_2_COLOR if current_phase == 2 else BOSS_COLOR
	mat.color = death_color
	particles.process_material = mat
	particles.amount = 40
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.global_position = global_position
	get_parent().add_child(particles)
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


func _create_ring_polygon(radius: float, segments: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in segments + 1:
		var angle := (float(i) / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = points
	poly.color = color
	return poly


func _create_cone_polygon(length: float, angle_deg: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var half_angle := deg_to_rad(angle_deg / 2.0)
	var segments: int = 12
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in segments + 1:
		var a := -half_angle + (float(i) / float(segments)) * half_angle * 2.0
		points.append(Vector2(cos(a), sin(a)) * length)
	poly.polygon = points
	poly.color = color
	return poly
