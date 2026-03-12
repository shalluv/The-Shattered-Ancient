extends "res://scenes/dungeon/RoomBase.gd"

const SPAWN_STAGGER_DELAY: float = 0.5
const HP_THRESHOLD: float = 0.5

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var enemy_spawns_top: Array[Marker2D] = [
	$EnemySpawnPoint1, $EnemySpawnPoint2, $EnemySpawnPoint3
]
@onready var enemy_spawns_bottom: Array[Marker2D] = [
	$EnemySpawnPoint4, $EnemySpawnPoint5, $EnemySpawnPoint6
]

var wave_1_enemies: Array[Node2D] = []
var wave_1_max_hp: int = 0
var wave_2_triggered: bool = false
var wave_difficulty: Dictionary = {}


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _spawn_enemies() -> void:
	wave_difficulty = RunManager.get_room_difficulty()
	var hp: int = wave_difficulty.get("enemy_hp", 1)
	var dmg: int = wave_difficulty.get("enemy_damage", 1)
	RunManager.set_room_enemy_count(3)
	wave_1_max_hp = 3 * hp
	for i in 3:
		var enemy := DireGruntScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns_top[i].global_position
		enemy.global_position = spawn_pos
		enemy.enemy_hp = hp
		enemy.damage = dmg
		entities.add_child(enemy)
		wave_1_enemies.append(enemy)
		_play_spawn_particles(spawn_pos)
		if i < 2:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _process(_delta: float) -> void:
	super._process(_delta)
	if wave_2_triggered or wave_1_enemies.is_empty():
		return

	var current_hp: int = 0
	for enemy in wave_1_enemies:
		if is_instance_valid(enemy) and not enemy.is_dying:
			current_hp += enemy.enemy_hp

	if current_hp <= int(wave_1_max_hp * HP_THRESHOLD):
		wave_2_triggered = true
		_trigger_ambush()


func _trigger_ambush() -> void:
	for spawn in enemy_spawns_bottom:
		_play_warning_particles(spawn.global_position)

	await get_tree().create_timer(0.3).timeout

	var hp: int = wave_difficulty.get("enemy_hp", 1)
	var dmg: int = wave_difficulty.get("enemy_damage", 1)
	RunManager.add_enemies(3)
	for i in 3:
		var enemy := DireGruntScene.instantiate()
		var spawn_pos: Vector2 = enemy_spawns_bottom[i].global_position
		enemy.global_position = spawn_pos
		enemy.enemy_hp = hp
		enemy.damage = dmg
		entities.add_child(enemy)
		_play_spawn_particles(spawn_pos)
		if i < 2:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _play_warning_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.3, 0.0, 1.0)
	particles.process_material = mat
	particles.amount = 8
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = pos
	add_child(particles)
	await get_tree().create_timer(0.5).timeout
	particles.queue_free()
