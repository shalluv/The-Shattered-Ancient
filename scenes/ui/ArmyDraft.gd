extends Control

const MysticBackground = preload("res://scenes/ui/MysticBackground.gd")

const UNIT_COSTS: Dictionary = {"swordsman": 2, "archer": 3, "priest": 5, "mage": 4}
const UNIT_COLORS: Dictionary = {
	"swordsman": Color("#FFD700"),
	"archer": Color("#FFA500"),
	"priest": Color("#FFFACD"),
	"mage": Color("#9370DB"),
}
const UNIT_NAMES: Dictionary = {
	"swordsman": "Swordsman",
	"archer": "Archer",
	"priest": "Priest",
	"mage": "Mage",
}
const UNIT_BLURBS: Dictionary = {
	"swordsman": "Steadfast frontline blade.",
	"archer": "Patient eye, piercing shaft.",
	"priest": "A circle of converting light.",
	"mage": "Channeller of arcane fire.",
}

const ALL_UNIT_TYPES: Array[String] = ["swordsman", "archer", "priest", "mage"]

const GOLD := Color(0.85, 0.7, 0.3, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.65, 1.0)
const GOLD_SOFT := Color(0.78, 0.74, 0.60, 1.0)
const PARCHMENT := Color(0.94, 0.92, 0.84, 1.0)
const PANEL_DARK := Color(0.08, 0.09, 0.12, 0.85)
const ROW_TINT := Color(0.10, 0.11, 0.14, 0.55)

var counts: Dictionary = {}
var remaining_budget: int = 0
var total_budget: int = 0
var count_labels: Dictionary = {}
var plus_buttons: Dictionary = {}
var minus_buttons: Dictionary = {}
var budget_bar: ProgressBar = null
var budget_label: Label = null
var enter_button: Button = null
var rows_container: VBoxContainer = null
var ui_root: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if SelectionManager:
		SelectionManager.set_process_input(false)
	tree_exiting.connect(_on_tree_exiting)

	total_budget = MetaProgress.get_draft_budget()
	remaining_budget = total_budget

	var bg := MysticBackground.new()
	bg.show_rune_circle = false
	add_child(bg)

	_build_ui()
	_update_display()
	_animate_fade_in()


func _on_tree_exiting() -> void:
	if SelectionManager:
		SelectionManager.set_process_input(true)


# ── Build UI ───────────────────────────────────────────────

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	_build_title()
	_build_main_panel()
	_build_button_bar()


func _build_title() -> void:
	var title_container := VBoxContainer.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_container.offset_left = -400
	title_container.offset_right = 400
	title_container.offset_top = 40
	title_container.offset_bottom = 160
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 4)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(title_container)

	var kicker := Label.new()
	kicker.text = "— D R A F T —"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", Color(0.7, 0.65, 0.50, 0.7))
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(kicker)

	var title := Label.new()
	title.text = "ASSEMBLE YOUR SWARM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 42)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title)

	var ornament := TitleOrnamentDrawer.new()
	ornament.custom_minimum_size = Vector2(400, 18)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(ornament)


class TitleOrnamentDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.85, 0.7, 0.3, 0.6)
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		draw_line(Vector2(cx - 150, cy), Vector2(cx + 150, cy), gold, 1.0, true)
		var pts := PackedVector2Array([
			Vector2(cx, cy - 5), Vector2(cx + 5, cy),
			Vector2(cx, cy + 5), Vector2(cx - 5, cy),
		])
		draw_colored_polygon(pts, gold)
		draw_circle(Vector2(cx - 150, cy), 2.5, gold)
		draw_circle(Vector2(cx + 150, cy), 2.5, gold)
		for offset in [-80.0, -40.0, 40.0, 80.0]:
			draw_line(Vector2(cx + offset, cy - 3), Vector2(cx + offset, cy + 3), Color(gold, 0.4), 1.0)


func _build_main_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -180
	panel.offset_bottom = 230

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_DARK
	panel_style.border_color = Color(0.55, 0.50, 0.35, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Budget header
	var budget_row := HBoxContainer.new()
	budget_row.alignment = BoxContainer.ALIGNMENT_CENTER
	budget_row.add_theme_constant_override("separation", 10)
	vbox.add_child(budget_row)

	var budget_caption := Label.new()
	budget_caption.text = "RECRUITMENT BUDGET"
	budget_caption.add_theme_color_override("font_color", GOLD_SOFT)
	budget_caption.add_theme_font_size_override("font_size", 14)
	budget_row.add_child(budget_caption)

	budget_label = Label.new()
	budget_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	budget_label.add_theme_font_size_override("font_size", 18)
	budget_row.add_child(budget_label)

	# Budget bar
	budget_bar = ProgressBar.new()
	budget_bar.min_value = 0
	budget_bar.max_value = total_budget
	budget_bar.value = 0
	budget_bar.custom_minimum_size = Vector2(540, 8)
	budget_bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(2)
	budget_bar.add_theme_stylebox_override("fill", fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.05, 0.07, 0.9)
	bar_bg.border_color = Color(0.35, 0.30, 0.18, 0.6)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(2)
	budget_bar.add_theme_stylebox_override("background", bar_bg)
	vbox.add_child(budget_bar)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer)

	# Rows
	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 8)
	vbox.add_child(rows_container)

	_build_unit_rows()


func _is_unit_available(unit_type: String) -> bool:
	match unit_type:
		"swordsman", "archer":
			return true
		"priest":
			return MetaProgress.has_upgrade("unlock_priest")
		"mage":
			return MetaProgress.has_upgrade("unlock_mage")
	return false


func _build_unit_rows() -> void:
	for unit_type in ALL_UNIT_TYPES:
		var available: bool = _is_unit_available(unit_type)
		if available:
			counts[unit_type] = 0

		var row_panel := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = ROW_TINT
		row_style.border_color = Color(0.40, 0.35, 0.22, 0.4)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(4)
		row_style.set_content_margin_all(10)
		row_panel.add_theme_stylebox_override("panel", row_style)
		rows_container.add_child(row_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)

		var swatch := UnitSwatchDrawer.new()
		swatch.custom_minimum_size = Vector2(36, 36)
		swatch.unit_color = UNIT_COLORS.get(unit_type, Color.WHITE) if available else Color(0.25, 0.25, 0.25, 1.0)
		swatch.is_locked = not available
		row.add_child(swatch)

		var info_box := VBoxContainer.new()
		info_box.add_theme_constant_override("separation", 0)
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_box)

		var name_label := Label.new()
		if available:
			var cost: int = UNIT_COSTS.get(unit_type, 0)
			name_label.text = "%s   ·   %d" % [UNIT_NAMES.get(unit_type, unit_type), cost]
			name_label.add_theme_color_override("font_color", PARCHMENT)
		else:
			var upgrade_cost: int = _get_unlock_cost(unit_type)
			name_label.text = "%s  [LOCKED — %d shards]" % [UNIT_NAMES.get(unit_type, unit_type), upgrade_cost]
			name_label.add_theme_color_override("font_color", Color(0.40, 0.38, 0.32, 1.0))
		name_label.add_theme_font_size_override("font_size", 17)
		info_box.add_child(name_label)

		var blurb := Label.new()
		if available:
			blurb.text = UNIT_BLURBS.get(unit_type, "")
			blurb.add_theme_color_override("font_color", Color(0.62, 0.58, 0.48, 0.9))
		else:
			blurb.text = "Unlock at the Camp."
			blurb.add_theme_color_override("font_color", Color(0.30, 0.28, 0.24, 1.0))
		blurb.add_theme_font_size_override("font_size", 12)
		info_box.add_child(blurb)

		var minus_btn := Button.new()
		minus_btn.text = "−"
		minus_btn.custom_minimum_size = Vector2(38, 34)
		_style_button(minus_btn)
		if available:
			minus_btn.pressed.connect(_on_minus_pressed.bind(unit_type))
		else:
			minus_btn.disabled = true
		row.add_child(minus_btn)
		minus_buttons[unit_type] = minus_btn

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_lbl.custom_minimum_size = Vector2(44, 0)
		if available:
			count_lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
		else:
			count_lbl.add_theme_color_override("font_color", Color(0.30, 0.28, 0.24, 1.0))
		count_lbl.add_theme_font_size_override("font_size", 26)
		row.add_child(count_lbl)
		count_labels[unit_type] = count_lbl

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(38, 34)
		_style_button(plus_btn)
		if available:
			plus_btn.pressed.connect(_on_plus_pressed.bind(unit_type))
		else:
			plus_btn.disabled = true
		row.add_child(plus_btn)
		plus_buttons[unit_type] = plus_btn


class UnitSwatchDrawer extends Control:
	var unit_color: Color = Color.WHITE
	var is_locked: bool = false

	func _draw() -> void:
		var center := size / 2.0
		var r: float = min(size.x, size.y) / 2.0 - 2.0
		var ring := Color(0.55, 0.50, 0.35, 0.7) if not is_locked else Color(0.30, 0.28, 0.22, 0.7)
		# Outer ring
		_draw_ring(center, r, ring, 1.0)
		# Inner glow disc
		var glow := Color(unit_color.r, unit_color.g, unit_color.b, 0.22)
		draw_circle(center, r - 4.0, glow)
		# Solid core diamond
		var s: float = r - 8.0
		var pts := PackedVector2Array([
			center + Vector2(0, -s),
			center + Vector2(s, 0),
			center + Vector2(0, s),
			center + Vector2(-s, 0),
		])
		draw_colored_polygon(pts, unit_color)

	func _draw_ring(c: Vector2, radius: float, color: Color, width: float) -> void:
		var nb := 32
		var pts := PackedVector2Array()
		for i in nb + 1:
			var a := i * TAU / nb
			pts.append(c + Vector2.from_angle(a) * radius)
		for i in nb:
			draw_line(pts[i], pts[i + 1], color, width, true)


# ── Bottom button bar ──────────────────────────────────────

func _build_button_bar() -> void:
	var bar_panel := PanelContainer.new()
	bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_panel.offset_top = -90
	bar_panel.offset_bottom = 0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	bar_style.border_color = Color(0.45, 0.38, 0.20, 0.5)
	bar_style.border_width_top = 1
	bar_style.set_content_margin_all(0)
	bar_style.content_margin_top = 20
	bar_style.content_margin_bottom = 20
	bar_style.content_margin_left = 40
	bar_style.content_margin_right = 40
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	ui_root.add_child(bar_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	bar_panel.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "Back to Lobby"
	back_btn.custom_minimum_size = Vector2(160, 48)
	back_btn.pressed.connect(_on_back_pressed)
	_style_button(back_btn)
	hbox.add_child(back_btn)

	enter_button = Button.new()
	enter_button.text = "Enter the Dungeon"
	enter_button.custom_minimum_size = Vector2(220, 48)
	enter_button.disabled = true
	enter_button.pressed.connect(_on_enter_pressed)
	_style_button(enter_button)
	hbox.add_child(enter_button)


# ── Button styling ─────────────────────────────────────────

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.13, 0.18, 0.9)
	normal.border_color = Color(0.55, 0.50, 0.35, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.18, 0.25, 0.95)
	hover.border_color = Color(0.75, 0.65, 0.30, 0.8)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(8)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.10, 0.09, 0.14, 0.95)
	pressed.border_color = Color(0.75, 0.65, 0.30, 0.8)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(8)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.10, 0.10, 0.13, 0.7)
	disabled.border_color = Color(0.30, 0.27, 0.18, 0.4)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(4)
	disabled.set_content_margin_all(8)
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_color_override("font_color", Color(0.78, 0.74, 0.60))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.65))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.55))
	button.add_theme_color_override("font_disabled_color", Color(0.40, 0.38, 0.30, 0.6))
	button.add_theme_font_size_override("font_size", 17)

	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)


# ── Fade in ────────────────────────────────────────────────

func _animate_fade_in() -> void:
	ui_root.modulate.a = 0.0
	var tw := ui_root.create_tween()
	tw.tween_property(ui_root, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)


# ── Logic ──────────────────────────────────────────────────

func _get_unlock_cost(unit_type: String) -> int:
	match unit_type:
		"priest":
			var data := UpgradeData.get_upgrade_by_id("unlock_priest")
			return data.get("cost", 0)
		"mage":
			var data := UpgradeData.get_upgrade_by_id("unlock_mage")
			return data.get("cost", 0)
	return 0


func _on_plus_pressed(unit_type: String) -> void:
	var cost: int = UNIT_COSTS.get(unit_type, 0)
	if remaining_budget >= cost:
		counts[unit_type] += 1
		remaining_budget -= cost
		_pulse_count(unit_type)
		_update_display()


func _on_minus_pressed(unit_type: String) -> void:
	if counts.get(unit_type, 0) > 0:
		counts[unit_type] -= 1
		remaining_budget += UNIT_COSTS.get(unit_type, 0)
		_pulse_count(unit_type)
		_update_display()


func _pulse_count(unit_type: String) -> void:
	var lbl: Label = count_labels.get(unit_type)
	if lbl == null:
		return
	lbl.pivot_offset = lbl.size / 2.0
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.06)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.10)


func _update_display() -> void:
	budget_label.text = "%d / %d" % [remaining_budget, total_budget]
	if budget_bar:
		budget_bar.value = total_budget - remaining_budget
	for unit_type in counts:
		count_labels[unit_type].text = str(counts[unit_type])
		plus_buttons[unit_type].disabled = remaining_budget < UNIT_COSTS.get(unit_type, 999)
		minus_buttons[unit_type].disabled = counts[unit_type] <= 0
	var has_units: bool = false
	for unit_type in counts:
		if counts[unit_type] > 0:
			has_units = true
			break
	enter_button.disabled = not has_units

	var enter_normal: StyleBoxFlat = enter_button.get_theme_stylebox("normal") as StyleBoxFlat
	if enter_normal:
		if remaining_budget == 0 and has_units:
			enter_normal.bg_color = Color(0.18, 0.32, 0.16, 0.95)
			enter_normal.border_color = Color(0.85, 0.75, 0.35, 0.95)
		elif has_units:
			enter_normal.bg_color = Color(0.16, 0.16, 0.20, 0.95)
			enter_normal.border_color = Color(0.75, 0.65, 0.30, 0.7)
		else:
			enter_normal.bg_color = Color(0.14, 0.13, 0.18, 0.9)
			enter_normal.border_color = Color(0.55, 0.50, 0.35, 0.6)


func _on_back_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")


func _on_enter_pressed() -> void:
	var army: Dictionary = {}
	for unit_type in counts:
		if counts[unit_type] > 0:
			army[unit_type] = counts[unit_type]
	RunManager.set_drafted_army(army)
	SceneTransition.transition_to("res://scenes/ui/RunMapScreen.tscn")
