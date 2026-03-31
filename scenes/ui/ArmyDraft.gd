extends Control

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

const ALL_UNIT_TYPES: Array[String] = ["swordsman", "archer", "priest", "mage"]

var counts: Dictionary = {}
var remaining_budget: int = 0
var total_budget: int = 0
var count_labels: Dictionary = {}
var plus_buttons: Dictionary = {}
var minus_buttons: Dictionary = {}
var budget_bar: ProgressBar = null

@onready var budget_label: Label = $VBoxContainer/BudgetLabel
@onready var enter_button: Button = $VBoxContainer/EnterButton
@onready var rows_container: VBoxContainer = $VBoxContainer/RowsContainer


func _ready() -> void:
	total_budget = MetaProgress.get_draft_budget()
	remaining_budget = total_budget
	enter_button.pressed.connect(_on_enter_pressed)
	_style_button(enter_button)
	_setup_budget_bar()
	_build_unit_rows()
	_update_display()


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.border_color = Color(0.3, 0.3, 0.4)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.35)
	hover.border_color = Color(0.5, 0.5, 0.6)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.25, 0.35)
	pressed.border_color = Color(0.5, 0.5, 0.6)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", pressed)

	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)


func _setup_budget_bar() -> void:
	budget_bar = ProgressBar.new()
	budget_bar.min_value = 0
	budget_bar.max_value = total_budget
	budget_bar.value = total_budget
	budget_bar.custom_minimum_size = Vector2(300, 10)
	budget_bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#FFD700")
	fill.set_corner_radius_all(2)
	budget_bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.set_corner_radius_all(2)
	budget_bar.add_theme_stylebox_override("background", bg)

	$VBoxContainer.add_child(budget_bar)
	$VBoxContainer.move_child(budget_bar, 1)


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
	var row_index: int = 0
	for unit_type in ALL_UNIT_TYPES:
		var available: bool = _is_unit_available(unit_type)

		if available:
			counts[unit_type] = 0

		if row_index > 0:
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(400, 1)
			sep.color = Color(0.5, 0.5, 0.5, 0.3)
			sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rows_container.add_child(sep)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)

		# TODO: Replace with unit art asset
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		if available:
			swatch.color = UNIT_COLORS.get(unit_type, Color.WHITE)
		else:
			swatch.color = Color(0.25, 0.25, 0.25, 1.0)
		row.add_child(swatch)

		var name_label := Label.new()
		if available:
			var cost: int = UNIT_COSTS.get(unit_type, 0)
			name_label.text = "%s (%d)" % [UNIT_NAMES.get(unit_type, unit_type), cost]
			name_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84, 1))
		else:
			var upgrade_cost: int = _get_unlock_cost(unit_type)
			name_label.text = "[LOCKED] %s - Unlock at Camp (%d shards)" % [UNIT_NAMES.get(unit_type, unit_type), upgrade_cost]
			name_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25, 1.0))
		name_label.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_label)

		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(40, 30)
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
		count_lbl.custom_minimum_size = Vector2(40, 0)
		if available:
			count_lbl.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0, 1.0))
		else:
			count_lbl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25, 1.0))
		count_lbl.add_theme_font_size_override("font_size", 24)
		row.add_child(count_lbl)
		count_labels[unit_type] = count_lbl

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(40, 30)
		_style_button(plus_btn)
		if available:
			plus_btn.pressed.connect(_on_plus_pressed.bind(unit_type))
		else:
			plus_btn.disabled = true
		row.add_child(plus_btn)
		plus_buttons[unit_type] = plus_btn

		rows_container.add_child(row)
		row_index += 1


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
		_update_display()


func _on_minus_pressed(unit_type: String) -> void:
	if counts.get(unit_type, 0) > 0:
		counts[unit_type] -= 1
		remaining_budget += UNIT_COSTS.get(unit_type, 0)
		_update_display()


func _update_display() -> void:
	budget_label.text = "Budget: %d / %d" % [remaining_budget, total_budget]
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
			enter_normal.bg_color = Color("#228B22")
			enter_normal.border_color = Color(0.3, 0.6, 0.3)
		else:
			enter_normal.bg_color = Color(0.15, 0.15, 0.2)
			enter_normal.border_color = Color(0.3, 0.3, 0.4)


func _on_enter_pressed() -> void:
	var army: Dictionary = {}
	for unit_type in counts:
		if counts[unit_type] > 0:
			army[unit_type] = counts[unit_type]
	RunManager.set_drafted_army(army)
	SceneTransition.transition_to("res://scenes/ui/RunMapScreen.tscn")
