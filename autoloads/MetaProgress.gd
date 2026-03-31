extends Node

signal shards_changed(new_amount: int)

const SAVE_PATH: String = "user://meta_progress.save"

var radiant_ore_shards: int = 0
var total_shards_lifetime: int = 0
var runs_completed: int = 0
var runs_won: int = 0
var unlocked_upgrades: Array[String] = []


func _ready() -> void:
	load_progress()


func add_shards(amount: int) -> void:
	radiant_ore_shards += amount
	total_shards_lifetime += amount
	save_progress()
	shards_changed.emit(radiant_ore_shards)


func spend_shards(amount: int) -> bool:
	if radiant_ore_shards < amount:
		return false
	radiant_ore_shards -= amount
	save_progress()
	shards_changed.emit(radiant_ore_shards)
	return true


func purchase_upgrade(upgrade_id: String) -> bool:
	if has_upgrade(upgrade_id):
		return false
	var upgrade := UpgradeData.get_upgrade_by_id(upgrade_id)
	if upgrade.is_empty():
		return false
	var prereq: String = upgrade.get("prerequisite", "")
	if prereq != "" and not has_upgrade(prereq):
		return false
	var cost: int = upgrade["cost"]
	if not spend_shards(cost):
		return false
	unlock_upgrade(upgrade_id)
	return true


func has_upgrade(id: String) -> bool:
	return is_upgrade_unlocked(id)


func is_upgrade_unlocked(upgrade_id: String) -> bool:
	return upgrade_id in unlocked_upgrades


func unlock_upgrade(upgrade_id: String) -> void:
	if upgrade_id not in unlocked_upgrades:
		unlocked_upgrades.append(upgrade_id)
		save_progress()


func get_draft_budget() -> int:
	var budget: int = 30
	if has_upgrade("budget_35"):
		budget += 5
	if has_upgrade("budget_40"):
		budget += 5
	if has_upgrade("budget_50"):
		budget += 10
	if has_upgrade("budget_60"):
		budget += 10
	return budget


func record_run(won: bool) -> void:
	runs_completed += 1
	if won:
		runs_won += 1
	save_progress()


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data := {
			"radiant_ore_shards": radiant_ore_shards,
			"total_shards_lifetime": total_shards_lifetime,
			"runs_completed": runs_completed,
			"runs_won": runs_won,
			"unlocked_upgrades": unlocked_upgrades,
		}
		file.store_string(JSON.stringify(data))
		file.close()


func load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var result := json.parse(file.get_as_text())
			file.close()
			if result == OK:
				var data: Dictionary = json.data
				radiant_ore_shards = data.get("radiant_ore_shards", 0)
				total_shards_lifetime = data.get("total_shards_lifetime", 0)
				runs_completed = data.get("runs_completed", 0)
				runs_won = data.get("runs_won", 0)
				unlocked_upgrades.assign(data.get("unlocked_upgrades", []))


func reset_all() -> void:
	radiant_ore_shards = 0
	total_shards_lifetime = 0
	runs_completed = 0
	runs_won = 0
	unlocked_upgrades.clear()
	save_progress()
