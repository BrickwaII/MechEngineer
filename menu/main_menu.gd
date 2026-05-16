extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	# ── Background ───────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.09)
	add_child(bg)

	# ── Root layout — centered column ────────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	# ── Title block ──────────────────────────────────────────────────────────
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	col.add_child(title_box)

	var title := Label.new()
	title.text = "MECH ENGINEER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "AI Commander  ·  Combat Prototype v0.1"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	title_box.add_child(subtitle)

	_add_rule(col)

	# ── Mode select label ────────────────────────────────────────────────────
	var pick := Label.new()
	pick.text = "SELECT COMBAT PROTOTYPE"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_size_override("font_size", 14)
	pick.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	col.add_child(pick)

	# ── Prototype cards ──────────────────────────────────────────────────────
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 24)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards_row)

	_build_mode_card(cards_row,
		"PROTOTYPE A",
		"Active Time Battle",
		Color(0.88, 0.68, 0.14),
		[
			"Speed-driven bars fill in real time",
			"A bot's bar fills → command it now",
			"Faster bots act more frequently",
			"Energy regenerates continuously",
		],
		"res://battle/main.tscn",
		false
	)

	_build_mode_card(cards_row,
		"PROTOTYPE B",
		"Simultaneous Resolution",
		Color(0.3, 0.7, 1.0),
		[
			"All enemy intents visible upfront",
			"Assign all commands in planning phase",
			"Everything resolves at once",
			"Energy budget per round · live preview",
		],
		"res://prototype_b/sim_battle.tscn",
		true
	)

	_add_rule(col)

	# ── Bottom links ─────────────────────────────────────────────────────────
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	col.add_child(bottom_row)

	var exit_btn := Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(130, 42)
	exit_btn.pressed.connect(func() -> void: get_tree().quit())
	bottom_row.add_child(exit_btn)

# ── Card builder ──────────────────────────────────────────────────────────────

func _build_mode_card(parent: Control, proto_label: String, title: String,
		accent: Color, bullets: Array, scene_path: String, active: bool) -> void:

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 340)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.10, 0.15) if active else Color(0.08, 0.08, 0.12)
	card_style.border_color = accent if active else Color(0.25, 0.25, 0.35)
	card_style.border_width_top    = 2 if active else 1
	card_style.border_width_right  = 2 if active else 1
	card_style.border_width_bottom = 2 if active else 1
	card_style.border_width_left   = 2 if active else 1
	card_style.corner_radius_top_left     = 8
	card_style.corner_radius_top_right    = 8
	card_style.corner_radius_bottom_left  = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_top    = 20
	card_style.content_margin_bottom = 20
	card_style.content_margin_left   = 20
	card_style.content_margin_right  = 20
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Proto tag
	var proto_tag := Label.new()
	proto_tag.text = proto_label + ("  ★" if active else "")
	proto_tag.add_theme_font_size_override("font_size", 13)
	proto_tag.add_theme_color_override("font_color", accent)
	proto_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(proto_tag)

	# Mode title
	var mode_title := Label.new()
	mode_title.text = title
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.add_theme_font_size_override("font_size", 22)
	mode_title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	vbox.add_child(mode_title)

	# Divider
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = accent.darkened(0.4)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Bullet points
	var bullet_box := VBoxContainer.new()
	bullet_box.add_theme_constant_override("separation", 4)
	bullet_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(bullet_box)

	for b: String in bullets:
		var lbl := Label.new()
		lbl.text = "· " + b
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet_box.add_child(lbl)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "PLAY  ▶"
	play_btn.custom_minimum_size = Vector2(0, 48)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = accent.darkened(0.35)
	btn_style_normal.corner_radius_top_left     = 4
	btn_style_normal.corner_radius_top_right    = 4
	btn_style_normal.corner_radius_bottom_left  = 4
	btn_style_normal.corner_radius_bottom_right = 4
	play_btn.add_theme_stylebox_override("normal", btn_style_normal)

	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = accent.darkened(0.15)
	btn_style_hover.corner_radius_top_left     = 4
	btn_style_hover.corner_radius_top_right    = 4
	btn_style_hover.corner_radius_bottom_left  = 4
	btn_style_hover.corner_radius_bottom_right = 4
	play_btn.add_theme_stylebox_override("hover", btn_style_hover)

	var path := scene_path
	play_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(path)
	)
	vbox.add_child(play_btn)

	parent.add_child(card)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_rule(parent: Control) -> void:
	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(840, 1)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.2, 0.3)
	s.content_margin_top    = 1
	s.content_margin_bottom = 1
	rule.add_theme_stylebox_override("separator", s)
	parent.add_child(rule)
