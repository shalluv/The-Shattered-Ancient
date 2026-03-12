extends "res://scenes/entities/units/UnitBase.gd"

const ATTACK_RANGE: float = 180.0
var champion_attack_cooldown: float = 1.5
const AURA_SEGMENTS: int = 32
const AURA_RADIUS: float = 20.0

const BLADEFURY_RADIUS: float = 40.0
const BLADEFURY_DPS: float = 10.0
const BLADEFURY_DURATION: float = 2.0
const BLADEFURY_WINDUP: float = 0.5
const BLADEFURY_COOLDOWN: float = 8.0

const CRYSTAL_NOVA_RADIUS: float = 120.0
const CRYSTAL_NOVA_DAMAGE: int = 12
const CRYSTAL_NOVA_SLOW: float = 0.5
const CRYSTAL_NOVA_SLOW_DURATION: float = 3.0
const CRYSTAL_NOVA_WINDUP: float = 0.5
const CRYSTAL_NOVA_COOLDOWN: float = 10.0

const MULTISHOT_COUNT: int = 5
const MULTISHOT_SPREAD: float = deg_to_rad(60.0)
const MULTISHOT_WINDUP: float = 0.3
const MULTISHOT_COOLDOWN: float = 6.0

const PURIFICATION_HEAL: int = 2
const PURIFICATION_DAMAGE: int = 30
const PURIFICATION_RADIUS: float = 60.0
const PURIFICATION_WINDUP: float = 0.4
const PURIFICATION_COOLDOWN: float = 8.0

var ProjectileScene := preload("res://scenes/entities/units/Projectile.tscn")
var attack_timer: float = 0.0
var combat_style: String = "melee"
var hero_color: Color = Color.WHITE
var aura_visual: Polygon2D = null
var hero_id_str: String = ""

var ability_cooldown: float = 8.0
var ability_timer: float = 0.0
var is_spinning: bool = false
var spin_timer: float = 0.0
var spin_visual: Polygon2D = null


func _ready() -> void:
	hero_id_str = unit_type.replace("champion_", "")
	var hero := HeroData.get_hero_by_id(hero_id_str)
	if not hero.is_empty():
		hero_color = hero["color"]
		unit_color = hero_color
		damage = hero["champion_damage"]
		max_hp = hero["champion_hp"]
		pursuit_range = float(hero["champion_range"])
		combat_style = hero["combat_style"]
		if hero.has("champion_attack_speed"):
			champion_attack_cooldown = hero["champion_attack_speed"]

	match hero_id_str:
		"juggernaut":
			ability_cooldown = BLADEFURY_COOLDOWN
		"crystal_maiden":
			ability_cooldown = CRYSTAL_NOVA_COOLDOWN
		"drow_ranger":
			ability_cooldown = MULTISHOT_COOLDOWN
		"omniknight":
			ability_cooldown = PURIFICATION_COOLDOWN

	ability_timer = ability_cooldown * 0.5

	super._ready()
	unit_visual.color = hero_color

	if hero_id_str == "omniknight":
		add_to_group("champions_omniknight")

	_create_aura_visual()


func _create_aura_visual() -> void:
	aura_visual = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in AURA_SEGMENTS:
		var angle := float(i) / float(AURA_SEGMENTS) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * AURA_RADIUS)
	aura_visual.polygon = points
	aura_visual.color = Color(hero_color.r, hero_color.g, hero_color.b, 0.1)
	aura_visual.z_index = -1
	add_child(aura_visual)
	move_child(aura_visual, 0)


func _physics_process(delta: float) -> void:
	if is_dying or is_reviving:
		return

	if is_spinning:
		spin_timer -= delta
		_deal_spin_damage(delta)
		if spin_timer <= 0.0:
			_end_bladefury()
		var spin_separation := _calculate_separation_force()
		var enemy := _find_nearest_enemy_in_range()
		if enemy != null:
			var direction := global_position.direction_to(enemy.global_position)
			velocity = direction * move_speed * 1.2 + spin_separation
		else:
			velocity = spin_separation
		move_and_slide()
		return

	ability_timer -= delta
	if ability_timer <= 0.0:
		var enemies := get_tree().get_nodes_in_group("enemies")
		if not enemies.is_empty():
			_use_ability()
			ability_timer = ability_cooldown

	var separation := _calculate_separation_force()

	if combat_style == "ranged":
		_ranged_process(delta, separation)
		return

	if pursuit_target != null:
		if not is_instance_valid(pursuit_target) or pursuit_target.is_dying:
			pursuit_target = null
			target_position = pre_pursuit_position
			has_move_target = true
			current_path = Pathfinder.find_path(global_position, target_position)
			path_index = 0
			_advance_path_index()
		else:
			var direction := global_position.direction_to(pursuit_target.global_position)
			var dist_to_target := global_position.distance_to(pursuit_target.global_position)
			if dist_to_target < PURSUIT_STOP_DISTANCE or _is_target_in_contact(direction, 2):
				velocity = separation
			else:
				path_recalc_timer -= delta
				var target_drift := pursuit_target.global_position.distance_to(last_pathed_target)
				if current_path.is_empty() or path_recalc_timer <= 0.0 or target_drift > PATH_RECALC_TARGET_DRIFT:
					current_path = Pathfinder.find_path(global_position, pursuit_target.global_position)
					path_index = 0
					_advance_path_index()
					last_pathed_target = pursuit_target.global_position
					path_recalc_timer = PATH_RECALC_INTERVAL
				if not _follow_path(separation):
					if Pathfinder.has_line_of_sight(global_position, pursuit_target.global_position):
						velocity = direction * move_speed + separation
					else:
						current_path = Pathfinder.find_path(global_position, pursuit_target.global_position)
						path_index = 0
						_advance_path_index()
						if not _follow_path(separation):
							velocity = direction * move_speed + separation
			move_and_slide()
			return

	if not has_move_target:
		var enemy := _find_nearest_enemy_in_range()
		if enemy != null:
			pre_pursuit_position = global_position
			pursuit_target = enemy
			current_path = Pathfinder.find_path(global_position, enemy.global_position)
			path_index = 0
			_advance_path_index()
			last_pathed_target = enemy.global_position
			path_recalc_timer = PATH_RECALC_INTERVAL
			var direction := global_position.direction_to(enemy.global_position)
			var dist_to_enemy := global_position.distance_to(enemy.global_position)
			if dist_to_enemy < PURSUIT_STOP_DISTANCE or _is_target_in_contact(direction, 2):
				velocity = separation
			else:
				if not _follow_path(separation):
					if Pathfinder.has_line_of_sight(global_position, enemy.global_position):
						velocity = direction * move_speed + separation
					else:
						current_path = Pathfinder.find_path(global_position, enemy.global_position)
						path_index = 0
						_advance_path_index()
						if not _follow_path(separation):
							velocity = direction * move_speed + separation
			move_and_slide()
			return
		velocity = separation
		if velocity.length_squared() > 0.1:
			move_and_slide()
		return

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


func _ranged_process(delta: float, separation: Vector2) -> void:
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
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		var enemy := _find_nearest_enemy_in_range()
		if enemy != null:
			_fire_projectile(enemy)
			attack_timer = champion_attack_cooldown

	velocity = separation
	if velocity.length_squared() > 0.1:
		move_and_slide()


func _fire_projectile(target: Node2D) -> void:
	var projectile := ProjectileScene.instantiate()
	projectile.global_position = global_position
	projectile.direction = global_position.direction_to(target.global_position)
	projectile.applies_slow = true
	projectile.slow_duration = 1.5
	get_parent().add_child(projectile)


func _use_ability() -> void:
	match hero_id_str:
		"juggernaut":
			_juggernaut_bladefury()
		"crystal_maiden":
			_cm_crystal_nova()
		"drow_ranger":
			_drow_multishot()
		"omniknight":
			_omni_purification()


func _juggernaut_bladefury() -> void:
	var windup_tween := create_tween()
	windup_tween.tween_property(unit_visual, "color", Color.WHITE, BLADEFURY_WINDUP * 0.5)
	windup_tween.tween_property(unit_visual, "color", hero_color, BLADEFURY_WINDUP * 0.5)

	var windup_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = BLADEFURY_RADIUS * 0.5
	mat.emission_ring_inner_radius = 5.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = hero_color
	windup_particles.process_material = mat
	windup_particles.amount = 8
	windup_particles.lifetime = 0.4
	windup_particles.one_shot = true
	windup_particles.explosiveness = 1.0
	windup_particles.emitting = true
	add_child(windup_particles)
	windup_particles.finished.connect(windup_particles.queue_free)

	await get_tree().create_timer(BLADEFURY_WINDUP).timeout
	if is_dying:
		return

	is_spinning = true
	spin_timer = BLADEFURY_DURATION
	_create_spin_visual()


func _deal_spin_damage(delta: float) -> void:
	var tick_damage := int(max(1, BLADEFURY_DPS * delta))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_hit"):
			continue
		if global_position.distance_to(enemy.global_position) <= BLADEFURY_RADIUS:
			enemy.take_hit(tick_damage)


func _end_bladefury() -> void:
	is_spinning = false
	spin_timer = 0.0
	if spin_visual and is_instance_valid(spin_visual):
		spin_visual.queue_free()
		spin_visual = null


func _create_spin_visual() -> void:
	spin_visual = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in AURA_SEGMENTS:
		var angle := float(i) / float(AURA_SEGMENTS) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * BLADEFURY_RADIUS)
	spin_visual.polygon = points
	spin_visual.color = Color(hero_color.r, hero_color.g, hero_color.b, 0.2)
	add_child(spin_visual)

	var spin_particles := GPUParticles2D.new()
	spin_particles.name = "SpinParticles"
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = BLADEFURY_RADIUS
	mat.emission_ring_inner_radius = BLADEFURY_RADIUS * 0.8
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = hero_color
	spin_particles.process_material = mat
	spin_particles.amount = 16
	spin_particles.lifetime = 0.5
	spin_visual.add_child(spin_particles)


func _cm_crystal_nova() -> void:
	var center := _get_enemy_cluster_centroid()
	if center == Vector2.ZERO:
		return

	# TODO: Replace with crystal nova telegraph art asset
	var telegraph := Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in AURA_SEGMENTS:
		var angle := float(i) / float(AURA_SEGMENTS) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * CRYSTAL_NOVA_RADIUS)
	telegraph.polygon = points
	telegraph.color = Color(0.0, 0.81, 1.0, 0.15)
	telegraph.global_position = center
	get_parent().add_child(telegraph)

	var windup_tween := create_tween()
	windup_tween.tween_property(telegraph, "color", Color(0.0, 0.81, 1.0, 0.35), CRYSTAL_NOVA_WINDUP)

	await get_tree().create_timer(CRYSTAL_NOVA_WINDUP).timeout
	if is_dying:
		telegraph.queue_free()
		return

	telegraph.queue_free()
	_execute_crystal_nova(center)


func _execute_crystal_nova(center: Vector2) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) <= CRYSTAL_NOVA_RADIUS:
			if enemy.has_method("take_hit"):
				enemy.take_hit(CRYSTAL_NOVA_DAMAGE)
			if "slow_timer" in enemy:
				enemy.slow_timer = CRYSTAL_NOVA_SLOW_DURATION

	var burst := GPUParticles2D.new()
	burst.global_position = center
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = CRYSTAL_NOVA_RADIUS
	mat.emission_ring_inner_radius = CRYSTAL_NOVA_RADIUS * 0.3
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 20, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.0, 0.81, 1.0, 1.0)
	burst.process_material = mat
	burst.amount = 20
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	get_parent().add_child(burst)
	burst.finished.connect(burst.queue_free)


func _get_enemy_cluster_centroid() -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var count: int = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			sum += enemy.global_position
			count += 1
	if count == 0:
		return Vector2.ZERO
	return sum / float(count)


func _drow_multishot() -> void:
	var enemy := _find_nearest_enemy_in_range()
	if enemy == null:
		return

	var base_dir := global_position.direction_to(enemy.global_position)

	var windup_tween := create_tween()
	windup_tween.tween_property(unit_visual, "color", Color.WHITE, MULTISHOT_WINDUP * 0.5)
	windup_tween.tween_property(unit_visual, "color", hero_color, MULTISHOT_WINDUP * 0.5)

	var charge_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = hero_color
	charge_particles.process_material = mat
	charge_particles.amount = 6
	charge_particles.lifetime = 0.3
	charge_particles.one_shot = true
	charge_particles.explosiveness = 1.0
	charge_particles.emitting = true
	add_child(charge_particles)
	charge_particles.finished.connect(charge_particles.queue_free)

	await get_tree().create_timer(MULTISHOT_WINDUP).timeout
	if is_dying:
		return

	_fire_multishot_volley(base_dir)


func _fire_multishot_volley(base_dir: Vector2) -> void:
	var base_angle := base_dir.angle()
	var half_spread := MULTISHOT_SPREAD * 0.5
	var step := MULTISHOT_SPREAD / float(MULTISHOT_COUNT - 1) if MULTISHOT_COUNT > 1 else 0.0

	for i in MULTISHOT_COUNT:
		var angle := base_angle - half_spread + step * float(i)
		var dir := Vector2(cos(angle), sin(angle))
		var projectile := ProjectileScene.instantiate()
		projectile.global_position = global_position
		projectile.direction = dir
		projectile.applies_slow = true
		projectile.slow_duration = 1.0
		get_parent().add_child(projectile)

	var volley_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(base_dir.x, base_dir.y, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = hero_color
	volley_particles.process_material = mat
	volley_particles.amount = 10
	volley_particles.lifetime = 0.3
	volley_particles.one_shot = true
	volley_particles.explosiveness = 1.0
	volley_particles.emitting = true
	add_child(volley_particles)
	volley_particles.finished.connect(volley_particles.queue_free)


func _omni_purification() -> void:
	var windup_tween := create_tween()
	windup_tween.tween_property(unit_visual, "color", Color.WHITE, PURIFICATION_WINDUP * 0.5)
	windup_tween.tween_property(unit_visual, "color", hero_color, PURIFICATION_WINDUP * 0.5)

	var charge_particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 15.0
	mat.emission_ring_inner_radius = 5.0
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -15, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.98, 0.8, 1.0)
	charge_particles.process_material = mat
	charge_particles.amount = 8
	charge_particles.lifetime = 0.4
	charge_particles.one_shot = true
	charge_particles.explosiveness = 1.0
	charge_particles.emitting = true
	add_child(charge_particles)
	charge_particles.finished.connect(charge_particles.queue_free)

	await get_tree().create_timer(PURIFICATION_WINDUP).timeout
	if is_dying:
		return

	_execute_purification()


func _execute_purification() -> void:
	current_hp = min(current_hp + PURIFICATION_HEAL, max_hp)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= PURIFICATION_RADIUS:
			if enemy.has_method("take_hit"):
				enemy.take_hit(PURIFICATION_DAMAGE)

	_create_purification_ring()

	var burst := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = PURIFICATION_RADIUS
	mat.emission_ring_inner_radius = PURIFICATION_RADIUS * 0.5
	mat.emission_ring_height = 0.0
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(1.0, 0.98, 0.8, 1.0)
	burst.process_material = mat
	burst.amount = 16
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _create_purification_ring() -> void:
	var ring := Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in AURA_SEGMENTS:
		var angle := float(i) / float(AURA_SEGMENTS) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * PURIFICATION_RADIUS)
	ring.polygon = points
	ring.color = Color(1.0, 0.98, 0.8, 0.3)
	add_child(ring)

	var fade_tween := create_tween()
	fade_tween.tween_property(ring, "color", Color(1.0, 0.98, 0.8, 0.0), 0.5)
	fade_tween.tween_callback(ring.queue_free)


func take_damage(amount: int) -> void:
	if is_reviving:
		return
	current_hp -= amount
	if current_hp <= 0:
		if is_spinning:
			_end_bladefury()
		die()
	else:
		var tween := create_tween()
		tween.tween_property(unit_visual, "color", Color.WHITE, 0.05)
		tween.tween_property(unit_visual, "color", hero_color, 0.15)
