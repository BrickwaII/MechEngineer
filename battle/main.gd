extends Control

enum ATBState { TICKING, RESOLVING, OVER }

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
var _in_ally_action: bool = false
var _awaiting_ally_select: bool = false
var _atb_state: ATBState = ATBState.TICKING
var _atb_display_timer: float = 0.0

signal _target_clicked(bot: BotData)
signal _turn_input(value: Variant)

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
	queue_header.text = "ATB STATUS"
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

	# Attack flash arrow overlay
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
	battle_manager.setup_battle(_combat_log, null)

	_build_bot_cards()
	_refresh_atb_queue()
	_reset_btn.pressed.connect(_on_reset_pressed)

# ── ATB tick ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _atb_state != ATBState.TICKING or battle_manager == null:
		return

	var tick_rate := 4.0
	var ready_allies: Array[BotData] = []
	var ready_enemies: Array[BotData] = []

	for bot: BotData in battle_manager.allies:
		if bot.is_dead:
			continue
		bot.atb_cooldown = maxf(0.0, bot.atb_cooldown - delta * tick_rate)
		if bot.atb_cooldown <= 0.0:
			ready_allies.append(bot)

	for bot: BotData in battle_manager.enemies:
		if bot.is_dead:
			continue
		bot.atb_cooldown = maxf(0.0, bot.atb_cooldown - delta * tick_rate)
		if bot.atb_cooldown <= 0.0:
			ready_enemies.append(bot)

	_refresh_all_atb()

	_atb_display_timer += delta
	if _atb_display_timer >= 0.15:
		_atb_display_timer = 0.0
		_refresh_atb_queue()

	if not ready_allies.is_empty():
		_atb_state = ATBState.RESOLVING
		_do_ally_atb_turn(ready_allies)
	elif not ready_enemies.is_empty():
		_atb_state = ATBState.RESOLVING
		_do_enemy_atb_turn(ready_enemies[0])

# ── ATB turn coroutines ───────────────────────────────────────────────────────

func _do_ally_atb_turn(ready: Array[BotData]) -> void:
	var gen := _battle_gen
	var actor: BotData

	if ready.size() == 1:
		actor = ready[0]
	else:
		_update_status("%d bots READY — click one to act first!" % ready.size())
		_set_card_highlights(ready, true)
		_awaiting_ally_select = true
		var clicked: BotData = await _target_clicked
		_awaiting_ally_select = false
		_set_card_highlights(ready, false)
		if _battle_gen != gen or clicked == null:
			_atb_state = ATBState.TICKING
			return
		actor = clicked if ready.has(clicked) else ready[0]

	if _battle_gen != gen:
		_atb_state = ATBState.TICKING
		return

	if _active_card:
		_active_card.set_active(false)
	_active_card = bot_to_card.get(actor) as BotCard
	if _active_card:
		_active_card.set_active(true)

	_draw_enemy_intents()
	var success := await _do_ally_action(actor)
	_clear_enemy_intents()

	if _battle_gen != gen:
		_atb_state = ATBState.TICKING
		return

	if success:
		actor.atb_cooldown = actor.atb_max

	if _active_card:
		_active_card.set_active(false)
		_active_card = null

	_refresh_all_cards()

	if battle_manager.check_battle_over():
		_atb_state = ATBState.OVER
	else:
		_atb_state = ATBState.TICKING

func _do_enemy_atb_turn(enemy: BotData) -> void:
	var gen := _battle_gen

	if _active_card:
		_active_card.set_active(false)
	_active_card = bot_to_card.get(enemy) as BotCard
	if _active_card:
		_active_card.set_active(true)

	_update_status("%s is acting..." % enemy.bot_name)
	SFX.enemy_act()
	await get_tree().create_timer(0.7).timeout

	if _battle_gen != gen:
		_atb_state = ATBState.TICKING
		return

	enemy.reset_round_bonuses()
	battle_manager.resolve_for_bot(enemy, BotData.Command.ATTACK)
	enemy.atb_cooldown = enemy.atb_max

	await get_tree().create_timer(0.35).timeout

	if _battle_gen != gen:
		_atb_state = ATBState.TICKING
		return

	if _active_card:
		_active_card.set_active(false)
		_active_card = null

	_update_status("")
	_refresh_all_cards()

	if battle_manager.check_battle_over():
		_atb_state = ATBState.OVER
	else:
		_atb_state = ATBState.TICKING

func _do_ally_action(actor: BotData) -> bool:
	var gen := _battle_gen
	var card := bot_to_card.get(actor) as BotCard
	if card == null:
		return false

	var current_skill: SkillData = null
	var current_targets: Array[BotData] = []
	var chosen_target: Variant = null
	var executed := false

	var skill_fwd := func(s: SkillData) -> void: _turn_input.emit(s)
	card.skill_chosen.connect(skill_fwd)
	_in_ally_action = true
	card.show_skill_accordion(actor.skill_slots)
	_update_status("YOUR TURN: %s — choose action" % actor.bot_name)

	while _battle_gen == gen:
		var value = await _turn_input

		if _battle_gen != gen or value == null:
			break

		if value is SkillData:
			var skill := value as SkillData
			if not current_targets.is_empty():
				_set_card_highlights(current_targets, false)
				_clear_target_tooltips(current_targets)
				current_targets.clear()
			current_skill = skill

			var need_enemy := skill.target_type == "single_enemy"
			var need_ally  := skill.target_type == "single_ally"

			if not need_enemy and not need_ally:
				chosen_target = null
				executed = true
				break

			if need_enemy:
				current_targets = battle_manager.get_alive_enemies()
			else:
				current_targets = []
				for b: BotData in battle_manager.allies:
					if b != actor and not b.is_dead:
						current_targets.append(b)

			_set_card_highlights(current_targets, true)
			_set_target_tooltips(actor, skill, current_targets)
			_update_status("Click target  ·  or choose a different action")

		elif value is BotData:
			var target := value as BotData
			if current_skill != null and current_targets.has(target) and not target.is_dead:
				_set_card_highlights(current_targets, false)
				_clear_target_tooltips(current_targets)
				current_targets.clear()
				chosen_target = target
				executed = true
				break

	_in_ally_action = false
	if is_instance_valid(card) and card.skill_chosen.is_connected(skill_fwd):
		card.skill_chosen.disconnect(skill_fwd)
	if not current_targets.is_empty():
		_set_card_highlights(current_targets, false)
		_clear_target_tooltips(current_targets)
	if is_instance_valid(card):
		card.hide_action_ui()

	if not executed or _battle_gen != gen:
		return false

	actor.reset_round_bonuses()
	battle_manager.resolve_for_bot_with_skill(actor, current_skill, chosen_target)
	return true

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

func _refresh_all_atb() -> void:
	for bot: BotData in bot_to_card:
		if not bot.is_dead:
			(bot_to_card[bot] as BotCard).update_atb(bot.atb_cooldown, bot.atb_max)

# ── ATB status panel ──────────────────────────────────────────────────────────

func _refresh_atb_queue() -> void:
	for child in _queue_box.get_children():
		child.free()

	var all_bots: Array[BotData] = []
	for bot: BotData in battle_manager.allies:
		if not bot.is_dead:
			all_bots.append(bot)
	for bot: BotData in battle_manager.enemies:
		if not bot.is_dead:
			all_bots.append(bot)
	all_bots.sort_custom(func(a: BotData, b: BotData) -> bool:
		return a.atb_cooldown < b.atb_cooldown
	)

	for bot: BotData in all_bots:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 10)
		if bot.atb_cooldown <= 0.0:
			lbl.text = "▶ %s  READY!" % bot.bot_name
			lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
		else:
			lbl.text = "  %s  %.1f" % [bot.bot_name, bot.atb_cooldown]
			lbl.add_theme_color_override("font_color", bot.color)
		_queue_box.add_child(lbl)

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
		var raw: int = enemy.attack + enemy.temp_attack_bonus
		var net: int = maxi(0, raw - weakest.defense - weakest.temp_defense_bonus)
		_intent_arrows.add_arrow(
			from_card.get_global_rect().get_center(), to_pt,
			Color(1.0, 0.25, 0.25, 0.55), "~%d" % net)

func _clear_enemy_intents() -> void:
	_intent_arrows.clear_all()

# ── Target tooltips ───────────────────────────────────────────────────────────

func _set_target_tooltips(actor: BotData, skill: SkillData, targets: Array) -> void:
	for bot: BotData in targets:
		var card: BotCard = bot_to_card.get(bot)
		if card:
			card.tooltip_text = _compute_target_tooltip(actor, skill, bot)

func _clear_target_tooltips(targets: Array) -> void:
	for bot: BotData in targets:
		var card: BotCard = bot_to_card.get(bot)
		if card:
			card.tooltip_text = ""

func _compute_target_tooltip(actor: BotData, skill: SkillData, target: BotData) -> String:
	match skill.command_type:
		"attack":
			var dmg := DamageCalculator.calculate_attack(actor, skill, target)
			if skill.armor_piercing:
				return "%s\n%d damage (piercing)" % [skill.skill_name, dmg]
			return "%s\n~%d damage" % [skill.skill_name, dmg]
		"support":
			var val := int(skill.effect_value)
			match skill.effect_type:
				"heal":
					var healed := mini(target.current_hp + val, target.max_hp) - target.current_hp
					return "%s\n+%d HP" % [skill.skill_name, healed]
				"buff":
					return "%s\n+%d ATK" % [skill.skill_name, val]
	return skill.skill_name

func _set_card_highlights(bots: Array, on: bool) -> void:
	for bot: BotData in bots:
		var card: BotCard = bot_to_card.get(bot)
		if card:
			card.set_highlight(on)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_card_clicked(bot: BotData) -> void:
	if _in_ally_action and not bot.is_dead:
		_turn_input.emit(bot)
	elif _awaiting_ally_select and not bot.is_dead and battle_manager.allies.has(bot):
		_target_clicked.emit(bot)

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

# ── Reset ─────────────────────────────────────────────────────────────────────

func _on_reset_pressed() -> void:
	_battle_gen += 1
	_in_ally_action = false
	_awaiting_ally_select = false
	_target_clicked.emit(null)
	_turn_input.emit(null)
	for card in bot_to_card.values():
		(card as BotCard).cancel_action()
	_clear_enemy_intents()
	if _active_card:
		_active_card.set_active(false)
		_active_card = null
	_clear_bot_cards()
	battle_manager.reset_battle()
	_build_bot_cards()
	_refresh_atb_queue()
	_update_status("")
	_atb_state = ATBState.TICKING
