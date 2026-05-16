extends Control

var battle_manager: BattleManager
var bot_to_card: Dictionary = {}

var _combat_log: RichTextLabel
var _reset_btn: Button
var _arrow_layer: AttackArrow
var _intent_arrows: ArrowLayer
var _ally_column: VBoxContainer
var _enemy_column: VBoxContainer
var _queue_box: VBoxContainer
var _active_card: BotCard = null
var _status_label: Label

var _battle_gen: int = 0
var _awaiting_target: bool = false

signal _target_clicked(bot: BotData)

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

	# Ally column
	_ally_column = VBoxContainer.new()
	_ally_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ally_column.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_ally_column.add_theme_constant_override("separation", 6)
	hbox.add_child(_ally_column)

	# Center column
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
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_status_label)

	_combat_log = RichTextLabel.new()
	_combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_log.fit_content = false
	_combat_log.scroll_active = true
	_combat_log.add_theme_font_size_override("normal_font_size", 11)
	center.add_child(_combat_log)

	# Enemy column
	_enemy_column = VBoxContainer.new()
	_enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_column.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_enemy_column.add_theme_constant_override("separation", 6)
	hbox.add_child(_enemy_column)

	# Attack flash arrow
	_arrow_layer = AttackArrow.new()
	_arrow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_layer)

	# Persistent intent arrows (on top)
	_intent_arrows = ArrowLayer.new()
	_intent_arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intent_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intent_arrows)

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
		card.setup(ally, 40, true)
		card.card_clicked.connect(_on_card_clicked)
		bot_to_card[ally] = card

	for enemy: BotData in battle_manager.enemies:
		var card := BotCard.new()
		_enemy_column.add_child(card)
		card.setup(enemy, 36, false)
		card.card_clicked.connect(_on_card_clicked)
		bot_to_card[enemy] = card

func _clear_bot_cards() -> void:
	for card in bot_to_card.values():
		(card as BotCard).queue_free()
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

# ── Enemy intent arrows ───────────────────────────────────────────────────────

func _draw_enemy_intents() -> void:
	_intent_arrows.clear_all()
	var alive_allies := battle_manager.get_alive_allies()
	if alive_allies.is_empty():
		return
	var weakest: BotData = alive_allies[0]
	for b: BotData in alive_allies:
		if b.current_hp < weakest.current_hp:
			weakest = b
	var to_card: BotCard = bot_to_card.get(weakest)
	if to_card == null:
		return
	var to_pt := to_card.get_global_rect().get_center()
	for enemy: BotData in battle_manager.enemies:
		if enemy.is_dead:
			continue
		var from_card: BotCard = bot_to_card.get(enemy)
		if from_card == null:
			continue
		_intent_arrows.add_arrow(
			from_card.get_global_rect().get_center(), to_pt,
			Color(1.0, 0.25, 0.25, 0.55), "?")

func _clear_enemy_intents() -> void:
	_intent_arrows.clear_all()

# ── Async battle loop ─────────────────────────────────────────────────────────

func _run_battle() -> void:
	var gen := _battle_gen
	while true:
		var actor := battle_manager.advance_to_next()
		if actor == null or _battle_gen != gen:
			break

		if battle_manager.allies.has(actor):
			_draw_enemy_intents()
			await _handle_ally_turn(actor, gen)
			_clear_enemy_intents()
			if _battle_gen != gen:
				break
		else:
			_clear_enemy_intents()
			_update_status("%s is acting..." % actor.bot_name)
			SFX.enemy_act()
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

func _handle_ally_turn(actor: BotData, gen: int) -> void:
	var card := bot_to_card.get(actor) as BotCard
	if card == null:
		battle_manager.resolve_current(BotData.Command.ATTACK)
		return

	var chosen_skill: SkillData = null
	var chosen_target: Variant = null

	while true:
		if _battle_gen != gen:
			return

		_update_status("YOUR TURN: %s — choose action" % actor.bot_name)
		card.show_skill_accordion(actor.skill_slots)
		chosen_skill = await card.skill_chosen
		if _battle_gen != gen or chosen_skill == null:
			card.hide_action_ui()
			return

		# Target selection (if needed)
		chosen_target = null
		var need_enemy := chosen_skill.target_type in ["single_enemy", "random_enemy"]
		var need_ally  := chosen_skill.target_type == "single_ally"
		if need_enemy:
			_update_status("Choose target for %s" % chosen_skill.skill_name)
			_set_card_highlights(battle_manager.enemies, true)
			_awaiting_target = true
			var clicked: BotData = await _target_clicked
			_awaiting_target = false
			_set_card_highlights(battle_manager.enemies, false)
			if _battle_gen != gen or clicked == null:
				card.hide_action_ui()
				return
			chosen_target = clicked
		elif need_ally:
			_update_status("Choose ally for %s" % chosen_skill.skill_name)
			var valid_allies: Array[BotData] = []
			for b: BotData in battle_manager.allies:
				if b != actor and not b.is_dead:
					valid_allies.append(b)
			_set_card_highlights(valid_allies, true)
			_awaiting_target = true
			var clicked: BotData = await _target_clicked
			_awaiting_target = false
			_set_card_highlights(valid_allies, false)
			if _battle_gen != gen or clicked == null:
				card.hide_action_ui()
				return
			chosen_target = clicked

		# Preview + confirm
		var preview := _compute_preview(actor, chosen_skill, chosen_target)
		card.show_preview(preview)
		_update_status("Confirm or go back")
		var confirmed: bool = await card.preview_result
		if _battle_gen != gen:
			card.hide_action_ui()
			return
		if not confirmed:
			continue

		break

	card.hide_action_ui()
	battle_manager.resolve_current_with_skill(chosen_skill, chosen_target)

func _compute_preview(bot: BotData, skill: SkillData, target: Variant) -> String:
	match skill.command_type:
		"attack":
			if skill.target_type == "all_enemies":
				return "%s → all enemies" % skill.skill_name
			elif target is BotData:
				var tgt: BotData = target as BotData
				var dmg := DamageCalculator.calculate_attack(bot, skill, tgt)
				return "%s: %s → %s\n~%d damage" % [bot.bot_name, skill.skill_name, tgt.bot_name, dmg]
			else:
				return "%s (random target)" % skill.skill_name
		"defend":
			var bonus := DamageCalculator.calculate_defend(bot, skill)
			return "%s: %s\n+%d DEF this round" % [bot.bot_name, skill.skill_name, bonus]
		"support":
			if skill.target_type == "all_allies":
				return "%s: %s\n+%d ATK & DEF to all allies" % [bot.bot_name, skill.skill_name, int(skill.effect_value)]
			elif target is BotData:
				var tgt: BotData = target as BotData
				return "%s: %s → %s" % [bot.bot_name, skill.skill_name, tgt.bot_name]
			else:
				return "%s: %s" % [bot.bot_name, skill.skill_name]
		"charge":
			return "%s: %s\nCHARGED — next attack ×%.0f" % [bot.bot_name, skill.skill_name, skill.multiplier]
	return "%s: %s" % [bot.bot_name, skill.skill_name]

func _set_card_highlights(bots: Array, on: bool) -> void:
	for bot: BotData in bots:
		var card: BotCard = bot_to_card.get(bot)
		if card:
			card.set_highlight(on)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_card_clicked(bot: BotData) -> void:
	if _awaiting_target and not bot.is_dead:
		_target_clicked.emit(bot)

func _on_turn_started(acting: BotData) -> void:
	if _active_card:
		_active_card.set_active(false)
	_active_card = bot_to_card.get(acting) as BotCard
	if _active_card:
		_active_card.set_active(true)
	_refresh_queue()

func _on_attack_performed(attacker: BotData, target: BotData) -> void:
	SFX.attack()
	var from_card: BotCard = bot_to_card.get(attacker)
	var to_card:   BotCard = bot_to_card.get(target)
	if from_card and to_card:
		_arrow_layer.show_attack(
			from_card.get_global_rect().get_center(),
			to_card.get_global_rect().get_center()
		)
	_refresh_all_cards()

func _update_status(msg: String) -> void:
	_status_label.text = msg

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_reset_pressed() -> void:
	_battle_gen += 1
	_awaiting_target = false
	_target_clicked.emit(null)  # unblock any pending target await
	for card in bot_to_card.values():
		(card as BotCard).cancel_action()
	_clear_enemy_intents()
	if _active_card:
		_active_card.set_active(false)
		_active_card = null
	_clear_bot_cards()
	battle_manager.reset_battle()
	_build_bot_cards()
	_refresh_queue()
	_update_status("")
	call_deferred("_run_battle")
