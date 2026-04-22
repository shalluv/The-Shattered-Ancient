extends Control

const MysticBackground = preload("res://scenes/ui/MysticBackground.gd")

const GOLD := Color(0.85, 0.7, 0.3, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.65, 1.0)
const GOLD_SOFT := Color(0.78, 0.74, 0.60, 1.0)
const PARCHMENT := Color(0.94, 0.92, 0.84, 1.0)
const PANEL_DARK := Color(0.03, 0.04, 0.06, 0.98)
const CARD_BG := Color(0.06, 0.07, 0.10, 1.0)
const CARD_BORDER := Color(0.45, 0.38, 0.22, 0.7)
const CARD_OWNED_BG := Color(0.20, 0.15, 0.05, 1.0)
const CARD_OWNED_BORDER := Color(1.00, 0.82, 0.32, 1.00)
const CARD_LOCKED_BG := Color(0.04, 0.04, 0.06, 1.0)
const CARD_LOCKED_BORDER := Color(0.30, 0.27, 0.20, 0.6)

const CATEGORIES: Array = [
	{"id": "unit_unlock", "name": "Recruits", "color": Color(0.85, 0.65, 0.25)},
	{"id": "budget", "name": "Draft Budget", "color": Color(0.35, 0.55, 0.78)},
	{"id": "hero_unlock", "name": "Heroes", "color": Color(0.70, 0.35, 0.62)},
	{"id": "room_unlock", "name": "Chambers", "color": Color(0.40, 0.65, 0.45)},
	{"id": "stat_boost", "name": "Combat", "color": Color(0.78, 0.32, 0.30)},
]

var shard_label: Label = null
var sections_container: VBoxContainer = null
var card_panels: Dictionary = {}
var info_name_label: Label = null
var info_desc_label: Label = null
var ui_root: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if SelectionManager:
		SelectionManager.set_process_input(false)
	tree_exiting.connect(_on_tree_exiting)

	var bg := MysticBackground.new()
	bg.show_rune_circle = false
	add_child(bg)

	_build_ui()
	_animate_fade_in()
	MetaProgress.shards_changed.connect(_on_shards_changed)


func _on_tree_exiting() -> void:
	if SelectionManager:
		SelectionManager.set_process_input(true)


# ── Layout ────────────────────────────────────────────────

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	_build_title()
	_build_shard_badge()
	_build_grid_panel()
	_build_button_bar()


func _build_title() -> void:
	var title_container := VBoxContainer.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_container.offset_left = -400
	title_container.offset_right = 400
	title_container.offset_top = 30
	title_container.offset_bottom = 140
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	title_container.add_theme_constant_override("separation", 4)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(title_container)

	var kicker := Label.new()
	kicker.text = "— S A N C T U M —"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", Color(0.7, 0.65, 0.50, 0.7))
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(kicker)

	var title := Label.new()
	title.text = "ETERNAL UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 40)
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


func _build_shard_badge() -> void:
	var badge := PanelContainer.new()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -260
	badge.offset_right = -40
	badge.offset_top = 40
	badge.offset_bottom = 84

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	style.border_color = Color(0.55, 0.50, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	badge.add_theme_stylebox_override("panel", style)
	ui_root.add_child(badge)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	badge.add_child(hbox)

	var shard_icon := ShardIconDrawer.new()
	shard_icon.custom_minimum_size = Vector2(18, 18)
	hbox.add_child(shard_icon)

	shard_label = Label.new()
	shard_label.text = "%d Radiant Shards" % MetaProgress.radiant_ore_shards
	shard_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	shard_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(shard_label)

	shard_label.pivot_offset = Vector2(100, 12)
	var pulse := shard_label.create_tween()
	pulse.set_loops()
	pulse.tween_property(shard_label, "scale", Vector2(1.03, 1.03), 1.2)
	pulse.tween_property(shard_label, "scale", Vector2.ONE, 1.2)


class ShardIconDrawer extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var s: float = min(size.x, size.y) / 2.0 - 1.0
		var gold := Color(1.0, 0.92, 0.65, 1.0)
		var dim := Color(0.85, 0.7, 0.3, 0.6)
		# Diamond / shard
		var pts := PackedVector2Array([
			c + Vector2(0, -s),
			c + Vector2(s * 0.7, 0),
			c + Vector2(0, s),
			c + Vector2(-s * 0.7, 0),
		])
		draw_colored_polygon(pts, gold)
		# Outline
		for i in 4:
			draw_line(pts[i], pts[(i + 1) % 4], dim, 1.0, true)


func _build_grid_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 170
	panel.offset_bottom = -110

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_DARK
	panel_style.border_color = Color(0.55, 0.50, 0.35, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_build_info_bar(vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	sections_container = VBoxContainer.new()
	sections_container.add_theme_constant_override("separation", 18)
	sections_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections_container)

	_build_upgrade_sections()


func _build_info_bar(parent: VBoxContainer) -> void:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 64)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.clip_contents = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	style.border_color = Color(0.55, 0.50, 0.35, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", style)
	parent.add_child(bar)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	bar.add_child(info_vbox)

	info_name_label = Label.new()
	info_name_label.text = "Hover an upgrade"
	info_name_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	info_name_label.add_theme_font_size_override("font_size", 16)
	info_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_name_label.clip_text = true
	info_vbox.add_child(info_name_label)

	info_desc_label = Label.new()
	info_desc_label.text = "See its effects and requirements here."
	info_desc_label.add_theme_color_override("font_color", Color(0.70, 0.66, 0.55, 0.95))
	info_desc_label.add_theme_font_size_override("font_size", 13)
	info_desc_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_desc_label.clip_text = true
	info_vbox.add_child(info_desc_label)


func _set_info(upgrade: Dictionary) -> void:
	if info_name_label == null:
		return
	if upgrade.is_empty():
		info_name_label.text = "Hover an upgrade"
		info_desc_label.text = "See its effects and requirements here."
		return
	info_name_label.text = upgrade["name"]
	var parts: Array[String] = [upgrade["description"]]
	var prereq: String = upgrade.get("prerequisite", "")
	if prereq != "" and not MetaProgress.has_upgrade(prereq):
		var pdata := UpgradeData.get_upgrade_by_id(prereq)
		parts.append("Requires %s." % pdata.get("name", prereq))
	if MetaProgress.has_upgrade(upgrade["id"]):
		parts.append("Already attuned.")
	info_desc_label.text = "  ·  ".join(parts)


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
	back_btn.text = "Back to Camp"
	back_btn.custom_minimum_size = Vector2(180, 48)
	back_btn.pressed.connect(_on_back_pressed)
	_style_button(back_btn)
	hbox.add_child(back_btn)


# ── Sections + Compact Cards ───────────────────────────────

func _build_upgrade_sections() -> void:
	for child in sections_container.get_children():
		child.queue_free()
	card_panels.clear()

	for cat in CATEGORIES:
		var upgrades_in_cat: Array = []
		for u in UpgradeData.get_all_upgrades():
			if u.get("category", "") == cat["id"]:
				upgrades_in_cat.append(u)
		if upgrades_in_cat.is_empty():
			continue
		_build_section(cat, upgrades_in_cat)


func _build_section(cat: Dictionary, upgrades: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections_container.add_child(section)

	# Header row: colored diamond + name + thin gold rule
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	section.add_child(header_row)

	var diamond := DiamondMarkDrawer.new()
	diamond.custom_minimum_size = Vector2(10, 10)
	diamond.color = cat["color"]
	header_row.add_child(diamond)

	var header_label := Label.new()
	header_label.text = String(cat["name"]).to_upper()
	header_label.add_theme_color_override("font_color", GOLD_SOFT)
	header_label.add_theme_font_size_override("font_size", 14)
	header_row.add_child(header_label)

	var rule := DividerDrawer.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.custom_minimum_size = Vector2(0, 12)
	header_row.add_child(rule)

	# Card grid: 2 columns of compact one-row cards
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(grid)

	for upgrade in upgrades:
		var card := _create_compact_card(upgrade, cat["color"])
		grid.add_child(card)
		card_panels[upgrade["id"]] = card


func _create_compact_card(upgrade: Dictionary, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 44)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var id: String = upgrade["id"]
	var owned: bool = MetaProgress.has_upgrade(id)
	var prereq: String = upgrade.get("prerequisite", "")
	var prereq_met: bool = prereq == "" or MetaProgress.has_upgrade(prereq)
	var affordable: bool = MetaProgress.radiant_ore_shards >= upgrade["cost"]

	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	if owned:
		style.bg_color = CARD_OWNED_BG
		style.border_color = CARD_OWNED_BORDER
		style.set_border_width_all(2)
		style.border_width_left = 4
		style.shadow_color = Color(1.00, 0.78, 0.30, 0.35)
		style.shadow_size = 6
	elif not prereq_met:
		style.bg_color = CARD_LOCKED_BG
		style.border_color = CARD_LOCKED_BORDER
	else:
		style.bg_color = CARD_BG
		style.border_color = CARD_BORDER

	# Left edge accent always uses category color (dimmed if locked)
	var accent_used := accent
	if not prereq_met and not owned:
		accent_used = Color(accent.r, accent.g, accent.b, 0.35)
	style.set("border_color", style.border_color) # no-op to keep flow
	# Override left border via a separate stylebox? StyleBoxFlat has only one
	# border color; we approximate the accent stripe by using a custom drawer.
	panel.add_theme_stylebox_override("panel", style)

	var stripe := AccentStripeDrawer.new()
	stripe.color = accent_used
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 3
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stripe)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# Name
	var name_label := Label.new()
	name_label.text = upgrade["name"]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if owned:
		name_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	elif not prereq_met:
		name_label.add_theme_color_override("font_color", Color(0.50, 0.48, 0.42, 1.0))
	else:
		name_label.add_theme_color_override("font_color", PARCHMENT)
	hbox.add_child(name_label)

	# Right side: cost + button OR owned pill
	if owned:
		var pill := PanelContainer.new()
		var pill_style := StyleBoxFlat.new()
		pill_style.bg_color = Color(1.00, 0.82, 0.32, 1.00)
		pill_style.border_color = Color(1.00, 0.92, 0.55, 1.00)
		pill_style.set_border_width_all(1)
		pill_style.set_corner_radius_all(3)
		pill_style.content_margin_left = 10
		pill_style.content_margin_right = 10
		pill_style.content_margin_top = 3
		pill_style.content_margin_bottom = 3
		pill.add_theme_stylebox_override("panel", pill_style)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var pill_label := Label.new()
		pill_label.text = "✦ OWNED"
		pill_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.04, 1.0))
		pill_label.add_theme_font_size_override("font_size", 12)
		pill.add_child(pill_label)

		hbox.add_child(pill)
	elif not prereq_met:
		var lock := Label.new()
		lock.text = "🔒"
		lock.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40, 0.8))
		lock.add_theme_font_size_override("font_size", 14)
		lock.custom_minimum_size = Vector2(36, 0)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lock)
	else:
		var cost_label := Label.new()
		cost_label.text = str(upgrade["cost"])
		cost_label.add_theme_font_size_override("font_size", 16)
		cost_label.custom_minimum_size = Vector2(28, 0)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if affordable:
			cost_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		else:
			cost_label.add_theme_color_override("font_color", Color(0.65, 0.40, 0.35, 1.0))
		hbox.add_child(cost_label)

		var buy_btn := Button.new()
		buy_btn.text = "Unlock"
		buy_btn.custom_minimum_size = Vector2(72, 28)
		buy_btn.disabled = not affordable
		buy_btn.pressed.connect(_on_purchase.bind(id))
		_style_button(buy_btn)
		hbox.add_child(buy_btn)

	# Hover: update info bar + brighten border
	panel.mouse_entered.connect(func() -> void:
		_set_info(upgrade)
		var hovered_border := Color(accent.r, accent.g, accent.b, 0.85)
		if owned:
			hovered_border = CARD_OWNED_BORDER
		style.border_color = hovered_border
		panel.queue_redraw()
	)
	panel.mouse_exited.connect(func() -> void:
		_set_info({})
		if owned:
			style.border_color = CARD_OWNED_BORDER
		elif not prereq_met:
			style.border_color = CARD_LOCKED_BORDER
		else:
			style.border_color = CARD_BORDER
		panel.queue_redraw()
	)

	return panel


class AccentStripeDrawer extends Control:
	var color: Color = Color.WHITE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), color)


class DividerDrawer extends Control:
	func _draw() -> void:
		var gold := Color(0.55, 0.50, 0.35, 0.5)
		var cy: float = size.y / 2.0
		draw_line(Vector2(0, cy), Vector2(size.x, cy), gold, 1.0)


class DiamondMarkDrawer extends Control:
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
	button.add_theme_font_size_override("font_size", 16)

	button.button_down.connect(func() -> void:
		if not button.disabled: AudioManager.play_sfx("ui_click")
		button.pivot_offset = button.size / 2.0
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.05)
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled: AudioManager.play_sfx("ui_hover")
	)


# ── Fade in ────────────────────────────────────────────────

func _animate_fade_in() -> void:
	ui_root.modulate.a = 0.0
	var tw := ui_root.create_tween()
	tw.tween_property(ui_root, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)


# ── Logic ──────────────────────────────────────────────────

func _on_purchase(upgrade_id: String) -> void:
	if MetaProgress.purchase_upgrade(upgrade_id):
		_play_unlock_particles()
		_rebuild_cards()


func _rebuild_cards() -> void:
	_build_upgrade_sections()


func _play_unlock_particles() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.88, 0.45, 0.9)
	particles.process_material = mat
	particles.amount = 32
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.position = get_viewport_rect().size / 2.0
	add_child(particles)
	get_tree().create_timer(1.4).timeout.connect(particles.queue_free)


func _on_shards_changed(new_amount: int) -> void:
	if shard_label:
		shard_label.text = "%d Radiant Shards" % new_amount


func _on_back_pressed() -> void:
	SceneTransition.transition_to("res://scenes/lobby/Lobby.tscn")
