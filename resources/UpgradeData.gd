extends RefCounted
class_name UpgradeData

const UPGRADES: Array[Dictionary] = [
	{
		"id": "unlock_priest",
		"name": "Priest Unit",
		"cost": 10,
		"category": "unit_unlock",
		"description": "Unlocks Priest in draft",
		"prerequisite": "",
	},
	{
		"id": "unlock_mage",
		"name": "Mage Unit",
		"cost": 15,
		"category": "unit_unlock",
		"description": "Unlocks Mage in draft",
		"prerequisite": "",
	},
	{
		"id": "budget_35",
		"name": "Larger Budget",
		"cost": 20,
		"category": "budget",
		"description": "Draft budget 30 → 35",
		"prerequisite": "",
	},
	{
		"id": "budget_40",
		"name": "Even Larger Budget",
		"cost": 30,
		"category": "budget",
		"description": "Draft budget 35 → 40",
		"prerequisite": "budget_35",
	},
	{
		"id": "budget_50",
		"name": "Massive Budget",
		"cost": 45,
		"category": "budget",
		"description": "Draft budget 40 → 50",
		"prerequisite": "budget_40",
	},
	{
		"id": "budget_60",
		"name": "Ultimate Budget",
		"cost": 70,
		"category": "budget",
		"description": "Draft budget 50 → 60",
		"prerequisite": "budget_50",
	},
	{
		"id": "unlock_drow",
		"name": "Drow Ranger",
		"cost": 15,
		"category": "hero_unlock",
		"description": "Adds Drow Ranger to hero pool",
		"prerequisite": "",
	},
	{
		"id": "unlock_omniknight",
		"name": "Omniknight",
		"cost": 15,
		"category": "hero_unlock",
		"description": "Adds Omniknight to hero pool",
		"prerequisite": "",
	},
	{
		"id": "unlock_shop",
		"name": "Shop Room",
		"cost": 20,
		"category": "room_unlock",
		"description": "Enables shop rooms in path choices",
		"prerequisite": "",
	},
	{
		"id": "veteran_swordsmen",
		"name": "Veteran Swordsmen",
		"cost": 40,
		"category": "stat_boost",
		"description": "Swordsman HP 1 → 2",
		"prerequisite": "",
	},
	{
		"id": "eagle_archers",
		"name": "Eagle Archers",
		"cost": 30,
		"category": "stat_boost",
		"description": "Archer range +40px",
		"prerequisite": "",
	},
	{
		"id": "holy_presence",
		"name": "Holy Presence",
		"cost": 20,
		"category": "stat_boost",
		"description": "Priest aura radius +40px",
		"prerequisite": "",
	},
]


static func get_all_upgrades() -> Array[Dictionary]:
	return UPGRADES


static func get_upgrade_by_id(id: String) -> Dictionary:
	for upgrade in UPGRADES:
		if upgrade["id"] == id:
			return upgrade
	return {}


static func get_prerequisite(id: String) -> String:
	var upgrade := get_upgrade_by_id(id)
	return upgrade.get("prerequisite", "")
