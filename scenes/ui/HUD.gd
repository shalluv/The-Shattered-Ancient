extends Control

@onready var unit_count_label: Label = $UnitCountLabel
@onready var gold_label: Label = $GoldLabel
@onready var enemy_count_label: Label = $EnemyCountLabel
@onready var room_label: Label = $RoomLabel

var shard_icon: ColorRect = null
var shard_label: Label = null
var prev_gold: int = 0
var boon_label: Label = null
var synergy_container: VBoxContainer = null
var synergy_rows: Dictionary = {}

const SYNERGY_COLORS: Dictionary = {
	"volley_mode": Color("#FFD700"),
	"holy_shield": Color("#FFFFFF"),
	"arcane_surge": Color("#9B59B6"),
}
const SYNERGY_NAMES: Dictionary = {
	"volley_mode": "Volley Mode",
	"holy_shield": "Holy Shield",
	"arcane_surge": "Arcane Surge",
}


func _ready() -> void:
	SwarmManager.unit_count_changed.connect(_on_unit_count_changed)
	RunManager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	MetaProgress.shards_changed.connect(_on_shards_changed)

	unit_count_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_font_size_override("font_size", 16)

	_add_hud_backgrounds()
	_on_unit_count_changed(SwarmManager.unit_count)
	if RunManager.is_boss_room():
		room_label.text = "BOSS"
		room_label.add_theme_color_override("font_color", Color(0.545, 0.0, 0.0))
	else:
		room_label.text = "Room %d / %d" % [RunManager.current_room_index + 1, RunManager.TOTAL_ROOMS]

	_setup_shard_display()
	_setup_boon_display()
	_setup_synergy_display()
	prev_gold = RunManager.gold


func _exit_tree() -> void:
	if SwarmManager.unit_count_changed.is_connected(_on_unit_count_changed):
		SwarmManager.unit_count_changed.disconnect(_on_unit_count_changed)
	if RunManager.enemies_remaining_changed.is_connected(_on_enemies_remaining_changed):
		RunManager.enemies_remaining_changed.disconnect(_on_enemies_remaining_changed)
	if MetaProgress.shards_changed.is_connected(_on_shards_changed):
		MetaProgress.shards_changed.disconnect(_on_shards_changed)
	if SwarmManager.synergy_activated.is_connected(_on_synergy_activated):
		SwarmManager.synergy_activated.disconnect(_on_synergy_activated)
	if SwarmManager.synergy_deactivated.is_connected(_on_synergy_deactivated):
		SwarmManager.synergy_deactivated.disconnect(_on_synergy_deactivated)


func _add_hud_backgrounds() -> void:
	for label in [unit_count_label, gold_label, enemy_count_label, room_label]:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.5)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.show_behind_parent = true
		label.add_child(bg)


func _setup_shard_display() -> void:
	var container := HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.position = Vector2(-200, 55)
	container.size = Vector2(180, 25)
	container.alignment = BoxContainer.ALIGNMENT_END
	container.add_theme_constant_override("separation", 6)

	# TODO: Replace with Radiant Ore Shard art asset
	shard_icon = ColorRect.new()
	shard_icon.custom_minimum_size = Vector2(10, 10)
	shard_icon.color = Color("#FFFACD")
	container.add_child(shard_icon)

	shard_label = Label.new()
	shard_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.804, 1.0))
	shard_label.add_theme_font_size_override("font_size", 16)
	shard_label.text = "Shards: %d" % MetaProgress.radiant_ore_shards
	container.add_child(shard_label)

	add_child(container)


func _setup_boon_display() -> void:
	boon_label = Label.new()
	boon_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	boon_label.position = Vector2(10, -60)
	boon_label.add_theme_font_size_override("font_size", 14)
	boon_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84, 0.7))
	add_child(boon_label)
	_update_boon_display()


func _update_boon_display() -> void:
	if not boon_label:
		return
	if RunManager.active_boons.is_empty():
		boon_label.text = ""
		return
	var names: PackedStringArray = PackedStringArray()
	for boon_id in RunManager.active_boons:
		names.append(boon_id.capitalize().replace("_", " "))
	boon_label.text = "Boons: " + ", ".join(names)


func _setup_synergy_display() -> void:
	synergy_container = VBoxContainer.new()
	synergy_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	synergy_container.position = Vector2(10, -130)
	synergy_container.add_theme_constant_override("separation", 4)
	add_child(synergy_container)
	SwarmManager.synergy_activated.connect(_on_synergy_activated)
	SwarmManager.synergy_deactivated.connect(_on_synergy_deactivated)
	for synergy_name in SwarmManager.active_synergies:
		_add_synergy_row(synergy_name)


func _on_synergy_activated(synergy_type: String) -> void:
	_add_synergy_row(synergy_type)


func _on_synergy_deactivated(synergy_type: String) -> void:
	if synergy_type in synergy_rows:
		var row: HBoxContainer = synergy_rows[synergy_type]
		var tween := create_tween()
		tween.tween_property(row, "modulate:a", 0.0, 0.2)
		tween.tween_callback(row.queue_free)
		synergy_rows.erase(synergy_type)


func _add_synergy_row(synergy_type: String) -> void:
	if synergy_type in synergy_rows:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.modulate.a = 0.0

	# TODO: Replace with synergy icon art asset
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.color = SYNERGY_COLORS.get(synergy_type, Color.WHITE)
	row.add_child(icon)

	var label := Label.new()
	label.text = SYNERGY_NAMES.get(synergy_type, synergy_type)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SYNERGY_COLORS.get(synergy_type, Color.WHITE))
	row.add_child(label)

	synergy_container.add_child(row)
	synergy_rows[synergy_type] = row

	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.2)


func _on_shards_changed(new_amount: int) -> void:
	if shard_label:
		shard_label.text = "Shards: %d" % new_amount


func _on_unit_count_changed(_new_count: int) -> void:
	var counts := SwarmManager.get_unit_counts_by_type()
	var s: int = counts.get("swordsman", 0)
	var a: int = counts.get("archer", 0)
	var p: int = counts.get("priest", 0)
	var m: int = counts.get("mage", 0)
	var text := "Sw:%d  Ar:%d  Pr:%d  Ma:%d" % [s, a, p, m]
	var champion_count: int = 0
	for key in counts:
		if key.begins_with("champion_"):
			champion_count += counts[key]
	if champion_count > 0:
		text += "  C:%d" % champion_count
	unit_count_label.text = text


func _on_enemies_remaining_changed(count: int) -> void:
	if count <= 0:
		enemy_count_label.text = "CLEARED"
		enemy_count_label.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))
	else:
		enemy_count_label.text = "Enemies: %d" % count


func _process(_delta: float) -> void:
	var current_gold := RunManager.gold
	gold_label.text = "Gold: %d" % current_gold
	if current_gold > prev_gold:
		gold_label.pivot_offset = gold_label.size / 2.0
		var pulse := gold_label.create_tween()
		pulse.tween_property(gold_label, "scale", Vector2(1.1, 1.1), 0.1)
		pulse.tween_property(gold_label, "scale", Vector2.ONE, 0.1)
	prev_gold = current_gold
