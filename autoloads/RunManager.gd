extends Node

signal room_cleared
signal run_ended(won: bool)
signal enemies_remaining_changed(count: int)

const STARTING_GOLD: int = 0
const TOTAL_ROOMS: int = 10
const BOSS_ROOM_INDEX: int = 9
const DRAFT_BUDGET: int = 20
const MAP_SCENE_PATH: String = "res://scenes/ui/RunMapScreen.tscn"

var current_room_index: int = 0
var gold: int = STARTING_GOLD
var is_run_active: bool = false
var enemies_remaining: int = 0

var drafted_army: Dictionary = {}
var surviving_army: Dictionary = {}
var chosen_path: int = -1
var last_run_won: bool = false
var initial_unit_total: int = 0
var total_units_lost: int = 0

var room_options: Array = []
var heroes_encountered_this_run: Array[String] = []
var heroes_joined_this_run: Array[String] = []
var active_boons: Array[String] = []
var chosen_room_data: Dictionary = {}

var shards_earned_this_run: int = 0
var units_at_room_start: int = 0
var run_end_trigger: String = ""
var shop_buffs: Dictionary = {}
var bonus_end_shards: int = 0
var hero_boons: Dictionary = {}
var map_data: MapData = null
var current_node_index: int = 0
var last_miniboss_scene: String = ""

const COMBAT_SMALL_SCENES: Array[String] = [
	"res://scenes/dungeon/CombatSmall1.tscn",
	"res://scenes/dungeon/CombatSmall2.tscn",
	"res://scenes/dungeon/CombatSmall3.tscn",
	"res://scenes/dungeon/CombatSmall4.tscn",
	"res://scenes/dungeon/CombatSmall5.tscn",
]

const MINIBOSS_SCENES: Array[String] = [
	"res://scenes/dungeon/RoomMiniBoss1.tscn",
	"res://scenes/dungeon/RoomMiniBoss2.tscn",
	"res://scenes/dungeon/RoomMiniBoss3.tscn",
	"res://scenes/dungeon/RoomMiniBoss4.tscn",
]

const BOSS_SCENES: Array[String] = [
	"res://scenes/dungeon/RoomBoss1.tscn",
	"res://scenes/dungeon/RoomBoss2.tscn",
	"res://scenes/dungeon/RoomBoss3.tscn",
]

const ROOM_DIFFICULTY: Array[Dictionary] = [
	{"enemy_count": 5, "enemy_hp": 1, "enemy_damage": 1},
	{"enemy_count": 5, "enemy_hp": 1, "enemy_damage": 1},
	{"enemy_count": 6, "enemy_hp": 1, "enemy_damage": 1},
	{"enemy_count": 3, "enemy_hp": 3, "enemy_damage": 2},
	{"enemy_count": 7, "enemy_hp": 2, "enemy_damage": 1},
	{"enemy_count": 7, "enemy_hp": 2, "enemy_damage": 1},
	{"enemy_count": 8, "enemy_hp": 2, "enemy_damage": 2},
	{"enemy_count": 3, "enemy_hp": 4, "enemy_damage": 2},
	{"enemy_count": 8, "enemy_hp": 3, "enemy_damage": 2},
	{"enemy_count": 0, "enemy_hp": 0, "enemy_damage": 0},
]


func get_combat_small_scene() -> String:
	return COMBAT_SMALL_SCENES[randi() % COMBAT_SMALL_SCENES.size()]


func get_miniboss_scene() -> String:
	var pool: Array[String] = []
	for scene in MINIBOSS_SCENES:
		if scene != last_miniboss_scene:
			pool.append(scene)
	if pool.is_empty():
		pool = MINIBOSS_SCENES.duplicate()
	var picked: String = pool[randi() % pool.size()]
	last_miniboss_scene = picked
	return picked


func get_boss_scene() -> String:
	return BOSS_SCENES[randi() % BOSS_SCENES.size()]


func start_run() -> void:
	current_room_index = 0
	gold = STARTING_GOLD
	is_run_active = true
	enemies_remaining = 0
	drafted_army = {}
	surviving_army = {}
	chosen_path = -1
	last_run_won = false
	initial_unit_total = 0
	total_units_lost = 0
	room_options = []
	heroes_encountered_this_run = []
	heroes_joined_this_run = []
	active_boons = []
	chosen_room_data = {}
	shards_earned_this_run = 0
	units_at_room_start = 0
	run_end_trigger = ""
	shop_buffs = {}
	bonus_end_shards = 0
	hero_boons = {}
	map_data = null
	current_node_index = 0
	last_miniboss_scene = ""
	SwarmManager.reset()
	generate_new_map()


func get_budget() -> int:
	return MetaProgress.get_draft_budget()


func set_drafted_army(army: Dictionary) -> void:
	drafted_army = army.duplicate()
	initial_unit_total = 0
	for unit_type in drafted_army:
		initial_unit_total += drafted_army[unit_type]


func snapshot_surviving_army() -> void:
	surviving_army = SwarmManager.get_unit_counts_by_type()
	var surviving_total: int = 0
	for unit_type in surviving_army:
		surviving_total += surviving_army[unit_type]
	total_units_lost = initial_unit_total - surviving_total


func snapshot_room_start_units() -> void:
	units_at_room_start = SwarmManager.unit_count


func award_room_shards(is_boss: bool) -> int:
	var amount: int = 2
	if is_boss:
		amount += 10
	var no_loss: bool = SwarmManager.unit_count >= units_at_room_start
	if no_loss:
		amount += 1
	if is_boss and no_loss:
		amount += 3
	shards_earned_this_run += amount
	MetaProgress.add_shards(amount)
	return amount


func award_loss_shards() -> int:
	shards_earned_this_run += 1
	MetaProgress.add_shards(1)
	return 1


func get_current_army() -> Dictionary:
	if surviving_army.is_empty():
		return drafted_army
	return surviving_army


func is_boss_room() -> bool:
	return current_room_index == BOSS_ROOM_INDEX


func add_enemies(count: int) -> void:
	enemies_remaining += count
	enemies_remaining_changed.emit(enemies_remaining)


func get_room_scene_path() -> String:
	if current_room_index == BOSS_ROOM_INDEX:
		return get_boss_scene()

	if not chosen_room_data.is_empty():
		var room_type: String = chosen_room_data.get("type", "combat")
		match room_type:
			"village":
				return "res://scenes/dungeon/RoomMedium.tscn"
			"hero":
				return "res://scenes/dungeon/RoomHero.tscn"
			"shop":
				return "res://scenes/dungeon/RoomShop.tscn"
			"miniboss":
				return get_miniboss_scene()
			"boss":
				return "res://scenes/dungeon/RoomBoss.tscn"
			_:
				if current_room_index >= 4:
					return "res://scenes/dungeon/RoomMedium.tscn"
				return get_combat_small_scene()

	return get_combat_small_scene()


func on_enemy_killed() -> void:
	enemies_remaining -= 1
	enemies_remaining_changed.emit(enemies_remaining)
	if enemies_remaining <= 0 and is_run_active:
		room_cleared.emit()


func set_room_enemy_count(count: int) -> void:
	enemies_remaining = count
	enemies_remaining_changed.emit(enemies_remaining)


func end_run(won: bool) -> void:
	is_run_active = false
	last_run_won = won
	if won:
		snapshot_surviving_army()
		run_end_trigger = "after_win"
	else:
		run_end_trigger = "after_loss"
		award_loss_shards()
	if bonus_end_shards > 0:
		shards_earned_this_run += bonus_end_shards
		MetaProgress.add_shards(bonus_end_shards)
	MetaProgress.record_run(won)
	run_ended.emit(won)


func advance_room() -> void:
	current_room_index += 1


func generate_new_map() -> void:
	var generator := MapGenerator.new()
	map_data = generator.generate()


func advance_to_node(node_index: int) -> void:
	if not map_data:
		return
	var node := map_data.get_node_by_index(node_index)
	if not node:
		return
	map_data.mark_visited(node_index)
	map_data.set_player_position(node_index)
	current_node_index = node_index
	current_room_index = node.row

	match node.room_type:
		"combat_small":
			chosen_room_data = {"type": "combat"}
		"combat_medium":
			chosen_room_data = {"type": "combat"}
		"village":
			chosen_room_data = {"type": "village"}
		"hero_room":
			chosen_room_data = {"type": "hero"}
			var hero_id: String = node.room_data.get("hero_id", "")
			if hero_id != "":
				chosen_room_data["hero_id"] = hero_id
				if hero_id not in heroes_encountered_this_run:
					heroes_encountered_this_run.append(hero_id)
		"shop":
			chosen_room_data = {"type": "shop"}
		"mini_boss":
			chosen_room_data = {"type": "miniboss"}
		"boss":
			chosen_room_data = {"type": "boss"}
		_:
			chosen_room_data = {"type": "combat"}


func add_gold(amount: int) -> void:
	gold += amount


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


func add_shop_buff(buff_id: String, value = true) -> void:
	shop_buffs[buff_id] = value


func has_shop_buff(buff_id: String) -> bool:
	return shop_buffs.has(buff_id)


func generate_room_assignments() -> void:
	room_options = []
	var available_heroes := HeroData.get_available_heroes()
	var filtered_heroes: Array[Dictionary] = []
	for hero in available_heroes:
		if hero["id"] not in heroes_encountered_this_run:
			filtered_heroes.append(hero)
		elif hero_boons.has(hero["id"]):
			filtered_heroes.append(hero)
	filtered_heroes.shuffle()

	var special_pool: Array[Dictionary] = []
	if not filtered_heroes.is_empty():
		special_pool.append({"type": "hero", "hero_id": filtered_heroes[0]["id"]})
	if MetaProgress.has_upgrade("unlock_shop"):
		special_pool.append({"type": "shop"})
	special_pool.append({"type": "miniboss"})
	special_pool.shuffle()

	var slot_assignments: Array[Dictionary] = []
	for i in 3:
		if i < special_pool.size():
			slot_assignments.append(special_pool[i])
		else:
			slot_assignments.append({"type": "village"})
	slot_assignments.shuffle()

	for i in 3:
		var option_a: Dictionary = {"type": "combat"}
		var option_b: Dictionary = slot_assignments[i]
		room_options.append({"a": option_a, "b": option_b})


func get_room_options_for_current_index() -> Dictionary:
	var opt_index := current_room_index - 1
	if opt_index >= 0 and opt_index < room_options.size():
		return room_options[opt_index]
	return {}


func set_chosen_room_data(data: Dictionary) -> void:
	chosen_room_data = data


func get_chosen_room_data() -> Dictionary:
	return chosen_room_data


func add_boon(boon_id: String) -> void:
	if boon_id not in active_boons:
		active_boons.append(boon_id)


func has_boon(boon_id: String) -> bool:
	return boon_id in active_boons


func set_hero_boon(hero_id: String, boon_id: String) -> void:
	hero_boons[hero_id] = boon_id


func get_hero_boon(hero_id: String) -> String:
	return hero_boons.get(hero_id, "")


func has_hero(hero_id: String) -> bool:
	return hero_boons.has(hero_id)


func get_room_difficulty() -> Dictionary:
	if current_room_index < ROOM_DIFFICULTY.size():
		return ROOM_DIFFICULTY[current_room_index]
	return ROOM_DIFFICULTY[0]
