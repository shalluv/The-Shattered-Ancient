extends Control

const GOLD := Color(0.85, 0.7, 0.3, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.65, 1.0)
const GOLD_SOFT := Color(0.78, 0.74, 0.60, 1.0)
const PARCHMENT := Color(0.94, 0.92, 0.84, 1.0)
const PANEL_DARK := Color(0.08, 0.09, 0.12, 0.92)
const PANEL_BORDER := Color(0.55, 0.50, 0.35, 0.55)
const ROW_BG := Color(0.10, 0.11, 0.14, 0.55)
const ROW_BORDER := Color(0.40, 0.35, 0.22, 0.40)
const ENEMY_RED := Color(0.85, 0.20, 0.20, 1.0)

const UNIT_TYPES: Array = [
	{"key": "swordsman", "label": "Sw", "color": Color("#FFD700")},
	{"key": "archer",    "label": "Ar", "color": Color("#FFB347")},
	{"key": "priest",    "label": "Pr", "color": Color("#FFFACD")},
	{"key": "mage",      "label": "Ma", "color": Color("#9B59B6")},
]

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

var _unit_value_labels: Dictionary = {}
var _champion_row: HBoxContainer = null
var _champion_value: Label = null
var _gold_value: Label = null
var _shards_value: Label = null
var _enemies_value: Label = null
var _enemies_dot: ColorRect = null
var _room_label: Label = null
var _boons_panel: PanelContainer = null
var _boons_value: Label = null
var _synergy_panel: PanelContainer = null
var _synergy_list: VBoxContainer = null
var _synergy_rows: Dictionary = {}
var _prev_gold: int = 0


func _ready() -> void:
	_build_ui()
	SwarmManager.unit_count_changed.connect(_on_unit_count_changed)
	RunManager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	MetaProgress.shards_changed.connect(_on_shards_changed)
	SwarmManager.synergy_activated.connect(_on_synergy_activated)
	SwarmManager.synergy_deactivated.connect(_on_synergy_deactivated)

	_on_unit_count_changed(SwarmManager.unit_count)
	_refresh_room_label()
	_refresh_shards()
	_refresh_boons()
	for syn in SwarmManager.active_synergies:
		_add_synergy_row(syn)
	_prev_gold = RunManager.gold
	_gold_value.text = "%d" % _prev_gold


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


func _process(_delta: float) -> void:
	var current_gold := RunManager.gold
	if current_gold != _prev_gold:
		_gold_value.text = "%d" % current_gold
		if current_gold > _prev_gold:
			_pulse(_gold_value)
		_prev_gold = current_gold


# ── Build ─────────────────────────────────────────────────

func _build_ui() -> void:
	_build_left_panel()
	_build_right_panel()
	_build_synergy_panel()
	_build_boons_panel()


func _build_left_panel() -> void:
	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(248, 0)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	_add_section_header(v, "SWARM", GOLD)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)

	for type_info in UNIT_TYPES:
		var row := _make_unit_cell(type_info["label"], type_info["color"])
		grid.add_child(row)
		_unit_value_labels[type_info["key"]] = row.get_node("Value")

	_champion_row = _make_unit_cell("Cm", Color(1.0, 0.55, 0.20))
	_champion_value = _champion_row.get_node("Value")
	_champion_row.visible = false
	grid.add_child(_champion_row)

	_add_divider(v)
	_gold_value = _add_stat_row(v, "GOLD", Color(1.0, 0.84, 0.30), "0")


func _build_right_panel() -> void:
	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-266, 18)
	panel.custom_minimum_size = Vector2(248, 0)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 20)
	_room_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	v.add_child(_room_label)

	_add_divider(v)

	var enemy_row := _make_stat_row_panel("ENEMIES", ENEMY_RED, "0")
	_enemies_dot = enemy_row.get_node("Dot")
	_enemies_value = enemy_row.get_node("Value")
	v.add_child(enemy_row.get_node("Panel"))

	_shards_value = _add_stat_row(v, "SHARDS", Color("#FFFACD"), "%d" % MetaProgress.radiant_ore_shards)


func _build_synergy_panel() -> void:
	_synergy_panel = _make_panel()
	_synergy_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_synergy_panel.position = Vector2(18, -180)
	_synergy_panel.custom_minimum_size = Vector2(232, 0)
	_synergy_panel.visible = false
	add_child(_synergy_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_synergy_panel.add_child(v)

	_add_section_header(v, "SYNERGIES", GOLD)
	_add_divider(v)

	_synergy_list = VBoxContainer.new()
	_synergy_list.add_theme_constant_override("separation", 4)
	v.add_child(_synergy_list)


func _build_boons_panel() -> void:
	_boons_panel = _make_panel()
	_boons_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_boons_panel.position = Vector2(18, -82)
	_boons_panel.custom_minimum_size = Vector2(232, 0)
	_boons_panel.visible = false
	add_child(_boons_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_boons_panel.add_child(v)

	_add_section_header(v, "BOONS", GOLD)
	_add_divider(v)

	_boons_value = Label.new()
	_boons_value.add_theme_font_size_override("font_size", 13)
	_boons_value.add_theme_color_override("font_color", PARCHMENT)
	_boons_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_boons_value)


# ── Builders ──────────────────────────────────────────────

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_DARK
	s.border_color = PANEL_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", s)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _add_section_header(parent: VBoxContainer, text: String, dot_color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var dot := DiamondDot.new()
	dot.custom_minimum_size = Vector2(9, 9)
	dot.color = dot_color
	hbox.add_child(dot)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GOLD_SOFT)
	hbox.add_child(label)


func _add_divider(parent: VBoxContainer) -> void:
	var d := Divider.new()
	d.custom_minimum_size = Vector2(0, 4)
	parent.add_child(d)


func _add_stat_row(parent: VBoxContainer, name_text: String, dot_color: Color, value_text: String) -> Label:
	var data := _make_stat_row_panel(name_text, dot_color, value_text)
	parent.add_child(data.get_node("Panel"))
	return data.get_node("Value")


func _make_stat_row_panel(name_text: String, dot_color: Color, value_text: String) -> _RowAccess:
	var panel := PanelContainer.new()
	panel.name = "RowPanel"
	var s := StyleBoxFlat.new()
	s.bg_color = ROW_BG
	s.border_color = ROW_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(0)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", s)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# TODO: Replace with proper stat icon art asset
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = dot_color
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(dot)

	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", GOLD_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", GOLD_BRIGHT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value)

	return _RowAccess.new(panel, dot, value)


class _RowAccess extends RefCounted:
	var _panel: PanelContainer
	var _dot: ColorRect
	var _value: Label
	func _init(panel: PanelContainer, dot: ColorRect, value: Label) -> void:
		_panel = panel
		_dot = dot
		_value = value
	func get_node(name: String) -> Variant:
		match name:
			"Panel": return _panel
			"Dot": return _dot
			"Value": return _value
		return null


func _make_unit_cell(label_text: String, dot_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# TODO: Replace with unit-class icon art asset
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = dot_color
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", GOLD_SOFT)
	row.add_child(name_label)

	var value := Label.new()
	value.name = "Value"
	value.text = "0"
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", PARCHMENT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	return row


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.10)


# ── Updates ───────────────────────────────────────────────

func _refresh_room_label() -> void:
	if RunManager.is_boss_room():
		_room_label.text = "◆  BOSS  ◆"
		_room_label.add_theme_color_override("font_color", Color(0.95, 0.30, 0.30))
	else:
		_room_label.text = "Room  %d  /  %d" % [RunManager.current_room_index + 1, RunManager.TOTAL_ROOMS]
		_room_label.add_theme_color_override("font_color", GOLD_BRIGHT)


func _refresh_shards() -> void:
	if _shards_value:
		_shards_value.text = "%d" % MetaProgress.radiant_ore_shards


func _refresh_boons() -> void:
	if not _boons_panel:
		return
	if RunManager.active_boons.is_empty():
		_boons_panel.visible = false
		return
	_boons_panel.visible = true
	var names: PackedStringArray = PackedStringArray()
	for boon_id in RunManager.active_boons:
		names.append(boon_id.capitalize().replace("_", " "))
	_boons_value.text = ", ".join(names)


func _on_unit_count_changed(_new_count: int) -> void:
	var counts := SwarmManager.get_unit_counts_by_type()
	for type_info in UNIT_TYPES:
		var key: String = type_info["key"]
		var label: Label = _unit_value_labels.get(key, null)
		if label:
			label.text = "%d" % counts.get(key, 0)
	var champion_count: int = 0
	for k in counts:
		if k.begins_with("champion_"):
			champion_count += counts[k]
	if champion_count > 0:
		_champion_row.visible = true
		_champion_value.text = "%d" % champion_count
	else:
		_champion_row.visible = false


func _on_enemies_remaining_changed(count: int) -> void:
	if count == -1:
		_enemies_value.text = "Escort"
		_enemies_value.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
		_enemies_dot.color = Color(0.95, 0.75, 0.25)
	elif count <= 0:
		_enemies_value.text = "Cleared"
		_enemies_value.add_theme_color_override("font_color", GOLD_BRIGHT)
		_enemies_dot.color = GOLD_BRIGHT
	else:
		_enemies_value.text = "%d" % count
		_enemies_value.add_theme_color_override("font_color", PARCHMENT)
		_enemies_dot.color = ENEMY_RED


func _on_shards_changed(_new_amount: int) -> void:
	_refresh_shards()


func _on_synergy_activated(synergy_type: String) -> void:
	_add_synergy_row(synergy_type)


func _on_synergy_deactivated(synergy_type: String) -> void:
	if synergy_type in _synergy_rows:
		var row: Control = _synergy_rows[synergy_type]
		var tween := create_tween()
		tween.tween_property(row, "modulate:a", 0.0, 0.2)
		tween.tween_callback(row.queue_free)
		_synergy_rows.erase(synergy_type)
		if _synergy_rows.is_empty():
			_synergy_panel.visible = false


func _add_synergy_row(synergy_type: String) -> void:
	if synergy_type in _synergy_rows:
		return
	_synergy_panel.visible = true

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.modulate.a = 0.0

	# TODO: Replace with synergy icon art asset
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(12, 12)
	icon.color = SYNERGY_COLORS.get(synergy_type, Color.WHITE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := Label.new()
	label.text = SYNERGY_NAMES.get(synergy_type, synergy_type)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", SYNERGY_COLORS.get(synergy_type, Color.WHITE))
	row.add_child(label)

	_synergy_list.add_child(row)
	_synergy_rows[synergy_type] = row

	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.2)


# ── Drawers ───────────────────────────────────────────────

class Divider extends Control:
	func _draw() -> void:
		var gold := Color(0.55, 0.50, 0.35, 0.5)
		var cy: float = size.y / 2.0
		draw_line(Vector2(0, cy), Vector2(size.x, cy), gold, 1.0)


class DiamondDot extends Control:
	var color: Color = Color.WHITE
	func _draw() -> void:
		var c := size / 2.0
		var s: float = min(size.x, size.y) / 2.0 - 1.0
		var pts := PackedVector2Array([
			c + Vector2(0, -s),
			c + Vector2(s, 0),
			c + Vector2(0, s),
			c + Vector2(-s, 0),
		])
		draw_colored_polygon(pts, color)
