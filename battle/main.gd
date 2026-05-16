extends Control

var battle_manager: BattleManager
var bot_to_card: Dictionary = {}  # BotData -> BotCard

var _combat_log: RichTextLabel
var _reset_btn: Button
var _arrow_layer: AttackArrow
var _ally_column: VBoxContainer
var _enemy_column: VBoxContainer
var _queue_box: VBoxContainer
var _status_label: Label
var _active_card: BotCard = null

var _battle_gen: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left",  10)
	margin.add_theme_constant_override("margin_right", 10)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# ── Ally column (left) — expands to fill ────────────────────────────────
	_ally_column = VBoxContainer.new()
	_ally_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ally_column.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_ally_column.add_theme_constant_override("separation", 8)
	hbox.add_child(_ally_column)

	# ── Center column — fixed width, does not expand ────────────────────────
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.custom_minimum_size   = Vector2(240, 0)
	center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	hbox.add_child(center)

	var header := Label.new()
	header.text = "PROTOTYPE A — Active Time Battle"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	center.add_child(header)

	_reset_btn = Button.new()
	_reset_btn.text = "↺  Reset Battle"
	center.add_child(_reset_btn)

	var menu_btn := Button.new()
	menu_btn.text = "◀ Menu"
	menu_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://menu/main_menu.tscn")
	)
	center.add_child(menu_btn)

	var sep := HSeparator.new()
	center.add_child(sep)

	var queue_header := Label.new()
	queue_header.text = "TURN ORDER"
	queue_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_header.add_theme_font_size_override("font_size", 10)
	queue_header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	center.add_child(queue_header)

	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 2)
	center.add_child(_queue_box)

	var sep2 := HSeparator.new()
	center.add_child(sep2)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_status_label)

	_combat_log = RichTextLabel.new()
	_combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_log.fit_content = false
	_combat_log.scroll_active = true
	_combat_log.add_theme_font_size_override("normal_font_size", 11)
	center.add_child(_combat_log)

	# ── Enemy column (right) — expands to fill ──────────────────────────────
	_enemy_column = VBoxContainer.new()
	_enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_column.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_enemy_column.add_theme_constant_override("separation", 8)
	hbox.add_child(_enemy_column)

	# ── Arrow overlay (last child so it renders on top) ─────────────────────
	_arrow_layer = AttackArrow.new()
	_arrow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_layer)

	# ── Battle manager ──────────────────────────────────────────────────────
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.attack_performed.connect(_on_attack_performed)
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.setup_battle(_combat_log, null)

	_build_bot_cards()
	_refresh_queue()

	_reset_btn.pressed.connect(_on_reset_pressed)

	call_deferred("_run_battle")

# ── Card building ─────────────────────────────────────────────────────────────

func _build_bot_cards() -> void:
	for ally: BotData in battle_manager.allies:
		var card := BotCard.new()
		_ally_column.add_child(card)
		card.setup(ally, 60, true)
		bot_to_card[ally] = card

	for enemy: BotData in battle_manager.enemies:
		var card := BotCard.new()
		_enemy_column.add_child(card)
		card.setup(enemy, 50, false)
		bot_to_card[enemy] = card

func _clear_bot_cards() -> void:
	for card in bot_to_card.values():
		card.queue_free()
	bot_to_card.clear()
	_active_card = null

func _refresh_all_cards() -> void:
	for bot: BotData in bot_to_card:
		(bot_to_card[bot] as BotCard).update_display()

# ── Turn queue display ────────────────────────────────────────────────────────

func _refresh_queue() -> void:
	for child in _queue_box.get_children():
		child.queue_free()

	var order := battle_manager.turn_order
	var idx   := battle_manager.current_turn_index
	var shown := 0
	for i in range(order.size()):
		var bot: BotData = order[i]
		if bot.is_dead:
			continue
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		if i == idx:
			lbl.text = "▶ " + bot.bot_name
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			lbl.text = "  " + bot.bot_name
			lbl.add_theme_color_override("font_color", bot.color)
		_queue_box.add_child(lbl)
		shown += 1
		if shown >= 8:
			break

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_turn_started(acting: BotData) -> void:
	if _active_card:
		_active_card.set_active(false)
	_active_card = bot_to_card.get(acting) as BotCard
	if _active_card:
		_active_card.set_active(true)
	_refresh_queue()

func _on_attack_performed(attacker: BotData, target: BotData) -> void:
	var from_card: BotCard = bot_to_card.get(attacker)
	var to_card:   BotCard = bot_to_card.get(target)
	if from_card and to_card:
		_arrow_layer.show_attack(
			from_card.get_global_rect().get_center(),
			to_card.get_global_rect().get_center()
		)
	_refresh_all_cards()

# ── Async battle loop ─────────────────────────────────────────────────────────

func _run_battle() -> void:
	var gen := _battle_gen
	while true:
		var actor := battle_manager.advance_to_next()
		if actor == null or _battle_gen != gen:
			break

		if battle_manager.allies.has(actor):
			_update_status("YOUR TURN: %s — choose an action" % actor.bot_name)
			var card := bot_to_card.get(actor) as BotCard
			var cmd := BotData.Command.ATTACK
			if card:
				card.show_actions()
				cmd = await card.action_chosen
				if _battle_gen != gen:
					card.hide_actions()
					break
				card.hide_actions()
			battle_manager.resolve_current(cmd)
		else:
			_update_status("%s is acting..." % actor.bot_name)
			await get_tree().create_timer(0.7).timeout
			if _battle_gen != gen:
				break
			battle_manager.resolve_current(BotData.Command.ATTACK)
			await get_tree().create_timer(0.35).timeout
			if _battle_gen != gen:
				break

		_refresh_all_cards()
		_refresh_queue()

	_update_status("")

func _update_status(msg: String) -> void:
	_status_label.text = msg

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_reset_pressed() -> void:
	_battle_gen += 1
	for card in bot_to_card.values():
		(card as BotCard).cancel_action()
	if _active_card:
		_active_card.set_active(false)
		_active_card = null
	_clear_bot_cards()
	battle_manager.reset_battle()
	_build_bot_cards()
	_refresh_queue()
	_update_status("")
	call_deferred("_run_battle")
