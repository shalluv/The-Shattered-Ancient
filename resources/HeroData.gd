extends RefCounted
class_name HeroData

const HERO_POOL: Array[Dictionary] = [
	{
		"id": "juggernaut",
		"name": "Juggernaut",
		"color": Color("#FF6B00"),
		"stub": false,
		"combat_style": "melee",
		"champion_damage": 2,
		"champion_range": 40,
		"champion_hp": 5,
		"boons": [
			{
				"id": "blade_fury", "name": "Blade Fury",
				"description": "Swordsmen deal 50% more damage",
				"upgrades": [
					{"id": "blade_fury_double", "name": "Spinning Death", "description": "Swordsmen deal 100% more damage"},
					{"id": "blade_fury_speed", "name": "Whirling Blades", "description": "Swordsmen attack 25% faster"},
				]
			},
			{
				"id": "healing_ward", "name": "Healing Ward",
				"description": "Once per room, revive a fallen swordsman",
				"upgrades": [
					{"id": "healing_ward_double", "name": "Greater Ward", "description": "Revive 2 swordsmen per room"},
					{"id": "healing_ward_tough", "name": "Hardened Ward", "description": "Revived swordsman has 2 HP"},
				]
			},
			{
				"id": "omnislash", "name": "Omnislash",
				"description": "Every 15s, slash the nearest enemy for 5 damage",
				"upgrades": [
					{"id": "omnislash_fast", "name": "Swift Slash", "description": "Omnislash cooldown reduced to 10s"},
					{"id": "omnislash_power", "name": "Brutal Slash", "description": "Omnislash deals 8 damage"},
				]
			},
		]
	},
	{
		"id": "crystal_maiden",
		"name": "Crystal Maiden",
		"color": Color("#00CFFF"),
		"stub": false,
		"combat_style": "ranged",
		"champion_damage": 1,
		"champion_range": 160,
		"champion_hp": 5,
		"boons": [
			{
				"id": "frost_aura", "name": "Frost Aura",
				"description": "Enemies near your units are slowed by 30%",
				"upgrades": [
					{"id": "frost_aura_deep", "name": "Deep Freeze", "description": "Frost Aura slows by 45%"},
					{"id": "frost_aura_wide", "name": "Spreading Cold", "description": "Frost Aura radius 200px"},
				]
			},
			{
				"id": "crystal_nova", "name": "Crystal Nova",
				"description": "Every 20s, slow all enemies for 3 seconds",
				"upgrades": [
					{"id": "crystal_nova_fast", "name": "Rapid Nova", "description": "Crystal Nova cooldown 12s"},
					{"id": "crystal_nova_long", "name": "Lingering Frost", "description": "Crystal Nova slow lasts 5s"},
				]
			},
			{
				"id": "arcane_aura", "name": "Arcane Aura",
				"description": "Neutral conversion time halved",
				"upgrades": [
					{"id": "arcane_aura_fast", "name": "Swift Conversion", "description": "Conversion takes only 1s"},
					{"id": "arcane_aura_tough", "name": "Empowered Converts", "description": "Converted units have 2 HP"},
				]
			},
		]
	},
	{
		"id": "drow_ranger",
		"name": "Drow Ranger",
		"color": Color("#008080"),
		"stub": false,
		"meta_unlock": "unlock_drow",
		"combat_style": "ranged",
		"champion_damage": 1,
		"champion_range": 200,
		"champion_hp": 5,
		"champion_attack_speed": 1.0,
		"boons": [
			{
				"id": "precision_aura", "name": "Precision Aura",
				"description": "All Archers +40px range",
				"upgrades": [
					{"id": "precision_aura_greater", "name": "True Aim", "description": "Archers get +80px total range"},
					{"id": "precision_aura_armor", "name": "Marksmanship", "description": "Archers gain an extra hit point"},
				]
			},
			{
				"id": "frost_arrows", "name": "Frost Arrows",
				"description": "Archer projectiles slow enemies 20% for 2s",
				"upgrades": [
					{"id": "frost_arrows_deep", "name": "Bitter Cold", "description": "Slow increased to 40%"},
					{"id": "frost_arrows_shatter", "name": "Shatter", "description": "Slowed enemies take double damage from arrows"},
				]
			},
			{
				"id": "multishot", "name": "Multishot",
				"description": "Archers fire 2 projectiles per attack",
				"upgrades": [
					{"id": "multishot_triple", "name": "Triple Shot", "description": "Archers fire 3 projectiles"},
					{"id": "multishot_pierce", "name": "Piercing Arrows", "description": "Projectiles pierce through 1 enemy"},
				]
			},
		]
	},
	{
		"id": "omniknight",
		"name": "Omniknight",
		"color": Color("#FFFACD"),
		"stub": false,
		"meta_unlock": "unlock_omniknight",
		"combat_style": "melee",
		"champion_damage": 2,
		"champion_range": 45,
		"champion_hp": 8,
		"champion_attack_speed": 1.8,
		"boons": [
			{
				"id": "purification", "name": "Purification",
				"description": "Every 12s, restore 3 damaged units to full HP",
				"upgrades": [
					{"id": "purification_more", "name": "Greater Purification", "description": "Restore 5 units instead of 3"},
					{"id": "purification_fast", "name": "Rapid Purification", "description": "Cooldown reduced to 7s"},
				]
			},
			{
				"id": "guardian_angel", "name": "Guardian Angel",
				"description": "When units would reach 0, survive with 3 units (once per run)",
				"upgrades": [
					{"id": "guardian_angel_more", "name": "Greater Guardian", "description": "Survive with 6 units instead of 3"},
					{"id": "guardian_angel_twice", "name": "Eternal Guardian", "description": "Guardian Angel can trigger twice per run"},
				]
			},
			{
				"id": "degen_aura", "name": "Degen Aura",
				"description": "Enemies within 100px of Omniknight champion move 25% slower",
				"upgrades": [
					{"id": "degen_aura_deep", "name": "Crippling Aura", "description": "Slow increased to 40%"},
					{"id": "degen_aura_wide", "name": "Expanded Aura", "description": "Aura radius increased to 160px"},
				]
			},
		]
	},
]


static func get_available_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in HERO_POOL:
		if hero.get("stub", false):
			continue
		var unlock_id: String = hero.get("meta_unlock", "")
		if unlock_id != "" and not MetaProgress.has_upgrade(unlock_id):
			continue
		result.append(hero)
	return result


static func get_hero_by_id(hero_id: String) -> Dictionary:
	for hero in HERO_POOL:
		if hero["id"] == hero_id:
			return hero
	return {}


static func get_upgrades_for_boon(boon_id: String) -> Array:
	for hero in HERO_POOL:
		for boon in hero.get("boons", []):
			if boon["id"] == boon_id:
				return boon.get("upgrades", [])
	return []
