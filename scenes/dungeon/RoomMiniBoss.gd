extends "res://scenes/dungeon/RoomBase.gd"

const MINIBOSS_FLOOR_COLOR: Color = Color(0.06, 0.02, 0.02)

var DamageZoneScene := preload("res://scenes/terrain/DamageZone.tscn")
var SlowZoneScene := preload("res://scenes/terrain/SlowZone.tscn")
var DireCaptainScene := preload("res://scenes/entities/enemies/DireCaptain.tscn")
var MiniBossRewardScene := preload("res://scenes/ui/MiniBossReward.tscn")
var DireHoundScene := preload("res://scenes/entities/enemies/DireHound.tscn")
var DirePriestScene := preload("res://scenes/entities/enemies/DirePriest.tscn")
var SpearwallGroupScene := preload("res://scenes/entities/enemies/SpearwallGroup.tscn")
var NeutralVillagerScene := preload("res://scenes/entities/NeutralVillager.tscn")

enum Archetype { WARLORD, AMBUSH, FORMATION, DARK_RITUAL }

var captain_instance: CharacterBody2D = null
var current_archetype: Archetype = Archetype.WARLORD

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var enemy_spawn_left: Marker2D = $EnemySpawnLeft
@onready var enemy_spawn_right: Marker2D = $EnemySpawnRight
@onready var enemy_spawn_center: Marker2D = $EnemySpawnCenter
@onready var villager_spawn_1: Marker2D = $VillagerSpawn1
@onready var villager_spawn_2: Marker2D = $VillagerSpawn2
@onready var villager_spawn_3: Marker2D = $VillagerSpawn3


func _ready() -> void:
	floor_rect.color = MINIBOSS_FLOOR_COLOR
	current_archetype = _pick_archetype()
	super()
	_spawn_terrain_zones()


func _get_spawn_position() -> Vector2:
	return player_spawn.global_position


func _pick_archetype() -> Archetype:
	var row: int = RunManager.current_room_index
	if row <= 3:
		# Row 3: easier archetypes
		return [Archetype.WARLORD, Archetype.AMBUSH].pick_random()
	else:
		# Row 7: harder archetypes
		return [Archetype.FORMATION, Archetype.DARK_RITUAL].pick_random()


func _spawn_enemies() -> void:
	match current_archetype:
		Archetype.WARLORD:
			_spawn_warlord()
		Archetype.AMBUSH:
			_spawn_ambush()
		Archetype.FORMATION:
			_spawn_formation()
		Archetype.DARK_RITUAL:
			_spawn_dark_ritual()

	captain_instance.captain_defeated.connect(_on_captain_defeated)
	_create_ambient_particles()


# --- Archetype: Warlord (original) ---
# DireCaptain + grunt/hound mix = 3 enemies
func _spawn_warlord() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var use_hound := randf() < 0.5
	var hound_side := randi() % 2

	if use_hound and hound_side == 0:
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawn_left.global_position
		entities.add_child(hound)
	else:
		var grunt_left := DireGruntScene.instantiate()
		grunt_left.global_position = enemy_spawn_left.global_position
		entities.add_child(grunt_left)

	if use_hound and hound_side == 1:
		var hound := DireHoundScene.instantiate()
		hound.global_position = enemy_spawn_right.global_position
		entities.add_child(hound)
	else:
		var grunt_right := DireGruntScene.instantiate()
		grunt_right.global_position = enemy_spawn_right.global_position
		entities.add_child(grunt_right)

	RunManager.set_room_enemy_count(3)


# --- Archetype: Ambush ---
# DireCaptain + 2 DireHounds flanking = 3 enemies
func _spawn_ambush() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var hound_left := DireHoundScene.instantiate()
	hound_left.global_position = enemy_spawn_left.global_position
	entities.add_child(hound_left)

	var hound_right := DireHoundScene.instantiate()
	hound_right.global_position = enemy_spawn_right.global_position
	entities.add_child(hound_right)

	RunManager.set_room_enemy_count(3)


# --- Archetype: Formation ---
# DireCaptain + SpearwallGroup = 4 enemies (captain + 3 spearwall units)
func _spawn_formation() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var spearwall := SpearwallGroupScene.instantiate()
	spearwall.global_position = enemy_spawn_center.global_position
	entities.add_child(spearwall)

	RunManager.set_room_enemy_count(4)


# --- Archetype: Dark Ritual ---
# DireCaptain + DirePriest + 2 grunts = 4 enemies + 3 neutral villagers
func _spawn_dark_ritual() -> void:
	captain_instance = DireCaptainScene.instantiate()
	captain_instance.global_position = boss_spawn.global_position
	entities.add_child(captain_instance)

	var priest := DirePriestScene.instantiate()
	priest.global_position = enemy_spawn_left.global_position
	entities.add_child(priest)

	var grunt1 := DireGruntScene.instantiate()
	grunt1.global_position = enemy_spawn_right.global_position
	entities.add_child(grunt1)

	var grunt2 := DireGruntScene.instantiate()
	grunt2.global_position = enemy_spawn_center.global_position
	entities.add_child(grunt2)

	RunManager.set_room_enemy_count(4)

	# Spawn neutral villagers for the priest to contest
	var villager_spawns: Array[Marker2D] = [villager_spawn_1, villager_spawn_2, villager_spawn_3]
	for spawn in villager_spawns:
		var villager := NeutralVillagerScene.instantiate()
		villager.global_position = spawn.global_position
		entities.add_child(villager)


func _on_room_cleared() -> void:
	pass


func _on_captain_defeated() -> void:
	RunManager.award_room_shards(false)

	var reward := MiniBossRewardScene.instantiate()
	reward.entities_node = entities
	reward.reward_chosen.connect(_on_reward_chosen)
	hud_layer.add_child(reward)


func _on_reward_chosen() -> void:
	_unlock_doors()
	room_clear_particles.global_position = game_camera.global_position
	room_clear_particles.emitting = true


func _spawn_terrain_zones() -> void:
	match current_archetype:
		Archetype.WARLORD:
			# Single damage zone below boss
			var damage_zone := DamageZoneScene.instantiate()
			damage_zone.global_position = boss_spawn.global_position + Vector2(0, 80)
			add_child(damage_zone)

		Archetype.AMBUSH:
			# Two slow zones on flanks to trap the player
			var slow_left := SlowZoneScene.instantiate()
			slow_left.global_position = Vector2(250, 400)
			add_child(slow_left)

			var slow_right := SlowZoneScene.instantiate()
			slow_right.global_position = Vector2(774, 400)
			add_child(slow_right)

		Archetype.FORMATION:
			# No terrain — pure tactical fight
			pass

		Archetype.DARK_RITUAL:
			# Damage zone near boss + slow zone in the center
			var damage_zone := DamageZoneScene.instantiate()
			damage_zone.global_position = boss_spawn.global_position + Vector2(0, 80)
			add_child(damage_zone)

			var slow_zone := SlowZoneScene.instantiate()
			slow_zone.global_position = Vector2(512, 450)
			add_child(slow_zone)


func _create_ambient_particles() -> void:
	var ambient := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(room_size.x / 2.0, room_size.y / 2.0, 0)
	mat.direction = Vector3(0, -0.5, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, 3, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.5

	match current_archetype:
		Archetype.WARLORD:
			mat.color = Color(0.545, 0.0, 0.0, 0.2)  # Dark red
		Archetype.AMBUSH:
			mat.color = Color(0.0, 0.4, 0.545, 0.2)   # Teal/cyan
		Archetype.FORMATION:
			mat.color = Color(0.545, 0.4, 0.0, 0.2)   # Dark amber
		Archetype.DARK_RITUAL:
			mat.color = Color(0.4, 0.0, 0.545, 0.2)   # Purple

	ambient.process_material = mat
	ambient.amount = 20
	ambient.lifetime = 3.0
	ambient.emitting = true
	ambient.position = room_size / 2.0
	add_child(ambient)
