extends Control

var battle_manager: BattleManager
var bot_to_card: Dictionary = {}  # BotData -> BotCard

var _turn_label: Label
var _combat_log: RichTextLabel
var _next_turn_btn: Button
var _reset_btn: Button
var _arrow_layer: AttackArrow
var _ally_column: VBoxContainer
var _enemy_column: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	# ── Ally column (left) ──────────────────────────────────────────────────
	_ally_column = VBoxContainer.new()
	_ally_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ally_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ally_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_ally_column.add_theme_constant_override("separation", 14)
	hbox.add_child(_ally_column)

	# ── Center column ───────────────────────────────────────────────────────
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	center.add_theme_constant_override("separation", 8)
	hbox.add_child(center)

	_turn_label = Label.new()
	_turn_label.text = "Battle Start"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_turn_label)

	_next_turn_btn = Button.new()
	_next_turn_btn.text = "Next Turn"
	center.add_child(_next_turn_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "Reset Battle"
	center.add_child(_reset_btn)

	_combat_log = RichTextLabel.new()
	_combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_log.custom_minimum_size = Vector2(0, 200)
	_combat_log.fit_content = false
	_combat_log.scroll_active = true
	center.add_child(_combat_log)

	# ── Enemy column (right) ────────────────────────────────────────────────
	_enemy_column = VBoxContainer.new()
	_enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_column.add_theme_constant_override("separation", 10)
	hbox.add_child(_enemy_column)

	# ── Arrow overlay (must be last child so it renders on top) ─────────────
	_arrow_layer = AttackArrow.new()
	_arrow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_layer)

	# ── Battle manager ──────────────────────────────────────────────────────
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.attack_performed.connect(_on_attack_performed)
	battle_manager.setup_battle(_combat_log, _turn_label)

	_build_bot_cards()

	_next_turn_btn.pressed.connect(_on_next_turn_pressed)
	_reset_btn.pressed.connect(_on_reset_pressed)

# ── Card building ────────────────────────────────────────────────────────────

func _build_bot_cards() -> void:
	for ally in battle_manager.allies:
		var card := BotCard.new()
		_ally_column.add_child(card)
		card.setup(ally, 80, true)   # interactive: player controls these
		bot_to_card[ally] = card

	for enemy in battle_manager.enemies:
		var card := BotCard.new()
		_enemy_column.add_child(card)
		card.setup(enemy, 50, false)
		bot_to_card[enemy] = card

func _clear_bot_cards() -> void:
	for card in bot_to_card.values():
		card.queue_free()
	bot_to_card.clear()

func _refresh_all_cards() -> void:
	for bot: BotData in bot_to_card:
		(bot_to_card[bot] as BotCard).update_display()

# ── Button handlers ──────────────────────────────────────────────────────────

func _on_next_turn_pressed() -> void:
	battle_manager.next_turn()

func _on_reset_pressed() -> void:
	_clear_bot_cards()
	battle_manager.reset_battle()
	_build_bot_cards()

# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_attack_performed(attacker: BotData, target: BotData) -> void:
	var from_card: BotCard = bot_to_card.get(attacker)
	var to_card: BotCard = bot_to_card.get(target)
	if from_card and to_card:
		_arrow_layer.show_attack(
			from_card.get_global_rect().get_center(),
			to_card.get_global_rect().get_center()
		)
	_refresh_all_cards()
