extends Control

# ── Sub-states within PLANNING ───────────────────────────────────────────────
enum UIMode { IDLE, SELECTING_TARGET, RESOLVING, BATTLE_OVER }

var ui_mode: UIMode = UIMode.IDLE

var _sim: SimBattle

# Bot ID → BotCard
var _bot_cards: Dictionary = {}
# EnemyData.id → EnemyCard
var _enemy_cards: Dictionary = {}

var _selected_bot: BotData = null
var _pending_skill: SkillData = null

# Bot ID (String) → Dictionary of { skill_name (String) → Button }
var _skill_buttons: Dictionary = {}

# Stand-by skill (free, no energy cost)
var _stand_by_skill: SkillData

# ── UI elements ──────────────────────────────────────────────────────────────
var _header_label: Label
var _bot_row: HBoxContainer
var _enemy_row: HBoxContainer
var _arrow_layer: ArrowLayer
var _log: RichTextLabel
var _undo_btn: Button
var _execute_btn: Button
var _status_label: Label

# ── Boot ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stand_by_skill = _make_stand_by_skill()
	_build_ui()
	_start_battle()
	get_viewport().size_changed.connect(func() -> void: call_deferred("_redraw_arrows"))

func _make_stand_by_skill() -> SkillData:
	var s := SkillData.new()
	s.skill_name = "Stand By"
	s.command_type = "defend"
	s.energy_cost = 0
	s.multiplier = 0.0
	s.target_type = "self"
	s.effect_type = "buff"
	s.effect_value = 0.0
	return s

func _start_battle() -> void:
	var bots := _create_bots()
	var enemies := [EnemyFactory.bruiser(), EnemyFactory.tactician(), EnemyFactory.berserker()]

	_sim = SimBattle.new()
	add_child(_sim)
	_sim.planning_started.connect(_on_planning_started)
	_sim.assignment_changed.connect(_on_assignment_changed)
	_sim.resolution_started.connect(_on_resolution_started)
	_sim.action_executed.connect(_on_action_executed)
	_sim.round_ended.connect(_on_round_ended)
	_sim.battle_over.connect(_on_battle_over)

	_build_cards(bots, enemies)
	_sim.setup(bots, enemies)

func _create_bots() -> Array:
	var lib := CombatSkillLibrary.make()

	var atlas := BotData.new()
	atlas.bot_name = "ATLAS"
	atlas.max_hp = 30
	atlas.attack = 8
	atlas.defense = 2
	atlas.speed = 6
	atlas.color = Color(0.3, 0.55, 1.0)
	atlas.initialize()
	atlas.skill_slots["attack"]  = [lib["standard_attack"], lib["power_shot"], lib["spread_shot"]]
	atlas.skill_slots["defend"]  = [lib["standard_defend"]]
	atlas.skill_slots["support"] = [lib["standard_support"]]
	atlas.skill_slots["charge"]  = [lib["standard_charge"]]

	var wren := BotData.new()
	wren.bot_name = "WREN"
	wren.max_hp = 25
	wren.attack = 5
	wren.defense = 3
	wren.speed = 9
	wren.color = Color(0.3, 0.85, 0.45)
	wren.initialize()
	wren.skill_slots["attack"]  = [lib["standard_attack"], lib["frenzy"]]
	wren.skill_slots["defend"]  = [lib["counter_stance"], lib["bulwark"]]
	wren.skill_slots["support"] = [lib["battle_cry"], lib["medic_protocol"]]
	wren.skill_slots["charge"]  = [lib["standard_charge"]]

	var corvus := BotData.new()
	corvus.bot_name = "CORVUS"
	corvus.max_hp = 35
	corvus.attack = 7
	corvus.defense = 4
	corvus.speed = 4
	corvus.color = Color(0.75, 0.3, 1.0)
	corvus.initialize()
	corvus.skill_slots["attack"]  = [lib["standard_attack"], lib["crippling_shot"]]
	corvus.skill_slots["defend"]  = [lib["standard_defend"], lib["bulwark"]]
	corvus.skill_slots["support"] = [lib["battle_cry"]]
	corvus.skill_slots["charge"]  = [lib["standard_charge"], lib["overload"], lib["team_charge"]]

	# Assign stable IDs
	atlas.id = "atlas"
	wren.id = "wren"
	corvus.id = "corvus"

	return [atlas, wren, corvus]

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Outermost padding wrapper ────────────────────────────────────────────
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left",  12)
	margin.add_theme_constant_override("margin_right", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# ── Header bar ──────────────────────────────────────────────────────────
	_header_label = Label.new()
	_header_label.text = "PROTOTYPE B — Simultaneous Resolution"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	root.add_child(_header_label)

	# ── Battle area (enemy row + bot row) ────────────────────────────────────
	# stretch_ratio 3 → claims 3× as much extra vertical space as the log (ratio 1)
	var battle_area := VBoxContainer.new()
	battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_area.size_flags_stretch_ratio = 3.0
	battle_area.add_theme_constant_override("separation", 8)
	root.add_child(battle_area)

	# Enemy row
	var enemy_section := VBoxContainer.new()
	enemy_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_section.add_theme_constant_override("separation", 4)
	battle_area.add_child(enemy_section)

	var enemy_header := Label.new()
	enemy_header.text = "ENEMIES"
	enemy_header.add_theme_font_size_override("font_size", 10)
	enemy_header.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_section.add_child(enemy_header)

	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_row.add_theme_constant_override("separation", 12)
	enemy_section.add_child(_enemy_row)

	# Bot row
	var bot_section := VBoxContainer.new()
	bot_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_section.add_theme_constant_override("separation", 4)
	battle_area.add_child(bot_section)

	var bot_header := Label.new()
	bot_header.text = "SQUAD"
	bot_header.add_theme_font_size_override("font_size", 10)
	bot_header.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	bot_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_section.add_child(bot_header)

	_bot_row = HBoxContainer.new()
	_bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bot_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bot_row.add_theme_constant_override("separation", 12)
	bot_section.add_child(_bot_row)

	# ── Status and controls row ──────────────────────────────────────────────
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 8)
	root.add_child(ctrl_row)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_row.add_child(_status_label)

	_undo_btn = Button.new()
	_undo_btn.text = "CLEAR ALL"
	_undo_btn.pressed.connect(_on_clear_all_pressed)
	ctrl_row.add_child(_undo_btn)

	_execute_btn = Button.new()
	_execute_btn.text = "EXECUTE ORDERS ▶"
	_execute_btn.pressed.connect(_on_execute_pressed)
	ctrl_row.add_child(_execute_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESTART"
	reset_btn.pressed.connect(_on_restart_pressed)
	ctrl_row.add_child(reset_btn)

	var balance_btn := Button.new()
	balance_btn.text = "BALANCE CHECK"
	balance_btn.pressed.connect(_on_balance_check_pressed)
	ctrl_row.add_child(balance_btn)

	var menu_btn := Button.new()
	menu_btn.text = "◀ MENU"
	menu_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://menu/main_menu.tscn")
	)
	ctrl_row.add_child(menu_btn)

	# ── Combat log ───────────────────────────────────────────────────────────
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 80)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.size_flags_stretch_ratio = 1.0
	_log.fit_content = false
	_log.scroll_active = true
	root.add_child(_log)

	# ── Arrow overlay (must be last so it renders above cards) ───────────────
	_arrow_layer = ArrowLayer.new()
	_arrow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_layer)

func _build_cards(bots: Array, enemies: Array) -> void:
	for child in _bot_row.get_children():
		child.queue_free()
	for child in _enemy_row.get_children():
		child.queue_free()
	_bot_cards.clear()
	_enemy_cards.clear()
	_skill_buttons.clear()

	for bot: BotData in bots:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		_bot_row.add_child(col)

		var card := BotCard.new()
		col.add_child(card)
		card.setup(bot, 40, false)
		card.card_clicked.connect(_on_bot_card_clicked)
		_bot_cards[bot.id] = card

		_build_skill_grid(bot, col)

	for e: EnemyData in enemies:
		var card := EnemyCard.new()
		_enemy_row.add_child(card)
		card.setup(e)
		card.card_clicked.connect(_on_enemy_card_clicked)
		_enemy_cards[e.id] = card

func _build_skill_grid(bot: BotData, parent: VBoxContainer) -> void:
	var btn_map: Dictionary = {}

	# Stand By first (always free)
	var sb_btn := _make_skill_button(bot, _stand_by_skill)
	parent.add_child(sb_btn)
	btn_map[_stand_by_skill.skill_name] = sb_btn

	# Skills from skill_slots in order: attack, defend, support, charge
	var cmd_order: Array[String] = ["attack", "defend", "support", "charge"]
	for cmd_type in cmd_order:
		if not bot.skill_slots.has(cmd_type):
			continue
		var slots: Variant = bot.skill_slots[cmd_type]
		if not slots is Array:
			continue
		for skill: SkillData in (slots as Array):
			var btn := _make_skill_button(bot, skill)
			parent.add_child(btn)
			btn_map[skill.skill_name] = btn

	_skill_buttons[bot.id] = btn_map

func _make_skill_button(bot: BotData, skill: SkillData) -> Button:
	var btn := Button.new()
	if skill.energy_cost == 0:
		btn.text = "%s  [free]" % skill.skill_name
	else:
		btn.text = "%s  %d⚡" % [skill.skill_name, skill.energy_cost]
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(0, 24)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured_bot: BotData = bot
	var captured_skill: SkillData = skill
	btn.pressed.connect(func() -> void: _on_skill_button_pressed(captured_bot, captured_skill))
	return btn

func _on_skill_button_pressed(bot: BotData, skill: SkillData) -> void:
	if ui_mode == UIMode.RESOLVING or ui_mode == UIMode.BATTLE_OVER:
		return

	# If same skill already assigned to this bot, undo it
	if _sim.assignments.has(bot.id):
		var a: Dictionary = _sim.assignments[bot.id]
		var assigned_skill: SkillData = a["skill"] as SkillData
		if assigned_skill.skill_name == skill.skill_name:
			_sim.undo_assignment(bot.id)
			ui_mode = UIMode.IDLE
			_selected_bot = null
			_pending_skill = null
			_set_all_highlights(false)
			_update_status("")
			return

	# Cancel any active target selection
	_set_all_highlights(false)
	ui_mode = UIMode.IDLE
	_selected_bot = null
	_pending_skill = null

	_selected_bot = bot
	_pending_skill = skill

	match skill.target_type:
		"self", "all_enemies", "all_allies", "random_enemy":
			_confirm_assignment(bot, skill, null)
		"single_enemy":
			ui_mode = UIMode.SELECTING_TARGET
			_highlight_all_enemies(true)
			_update_status("Select a target for %s" % skill.skill_name)
		"single_ally":
			ui_mode = UIMode.SELECTING_TARGET
			_highlight_all_bots(true)
			_update_status("Select an ally for %s" % skill.skill_name)

func _update_skill_buttons() -> void:
	for bot: BotData in _sim.bots:
		if not _skill_buttons.has(bot.id):
			continue
		var btn_map: Dictionary = _skill_buttons[bot.id]
		var assigned_skill_name: String = ""
		if _sim.assignments.has(bot.id):
			var a: Dictionary = _sim.assignments[bot.id]
			assigned_skill_name = (a["skill"] as SkillData).skill_name

		for skill_name in btn_map:
			var btn: Button = btn_map[skill_name] as Button
			if skill_name == assigned_skill_name:
				btn.modulate = Color(0.2, 1.0, 0.45)
			else:
				btn.modulate = Color.WHITE

# ── Event handlers from SimBattle ────────────────────────────────────────────

func _on_planning_started(_round: int) -> void:
	ui_mode = UIMode.IDLE
	_selected_bot = null
	_pending_skill = null
	_update_header()
	_refresh_all_cards()
	call_deferred("_redraw_arrows")  # defer so layout is settled
	_update_controls()
	_update_skill_buttons()

func _on_assignment_changed() -> void:
	_update_header()
	_update_controls()
	_refresh_all_cards()
	_update_previews()
	_redraw_arrows()
	_update_skill_buttons()

func _on_resolution_started() -> void:
	ui_mode = UIMode.RESOLVING
	_set_all_highlights(false)
	_update_controls()

func _on_action_executed(msg: String) -> void:
	_log.append_text(msg + "\n")
	_log.scroll_to_line(_log.get_line_count() - 1)
	_refresh_all_cards()
	_arrow_layer.clear_all()

func _on_round_ended(_round: int) -> void:
	_log.append_text("─── Round End ───\n")

func _on_battle_over(player_won: bool) -> void:
	ui_mode = UIMode.BATTLE_OVER
	_update_controls()
	var msg := "\n★ VICTORY — enemies eliminated ★\n" if player_won \
		else "\n✕ DEFEAT — all bots destroyed ✕\n"
	_log.append_text(msg)

# ── Bot / enemy card click handlers ──────────────────────────────────────────

func _on_bot_card_clicked(bot: BotData) -> void:
	if ui_mode == UIMode.SELECTING_TARGET:
		# Selecting an ally as target
		if _pending_skill != null and _pending_skill.target_type == "single_ally":
			_confirm_assignment(_selected_bot, _pending_skill, bot)

func _on_enemy_card_clicked(enemy: EnemyData) -> void:
	if ui_mode == UIMode.SELECTING_TARGET and _pending_skill != null:
		if _pending_skill.target_type in ["single_enemy", "random_enemy"]:
			_confirm_assignment(_selected_bot, _pending_skill, enemy)

func _confirm_assignment(bot: BotData, skill: SkillData, target: Variant) -> void:
	_sim.make_assignment(bot, skill, target)
	_selected_bot = null
	_pending_skill = null
	ui_mode = UIMode.IDLE
	_set_all_highlights(false)
	_update_status("")

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_clear_all_pressed() -> void:
	_sim.clear_assignments()
	_selected_bot = null
	_pending_skill = null
	ui_mode = UIMode.IDLE
	_set_all_highlights(false)
	_update_status("")

func _on_execute_pressed() -> void:
	if ui_mode == UIMode.BATTLE_OVER:
		return
	_sim.confirm_assignments()

func _on_balance_check_pressed() -> void:
	_log.clear()
	_log.append_text("Running balance check (1000 runs × 3 strategies)...\n")
	# Build fresh templates matching the current encounter setup
	var bot_tpls: Array = _create_bots()
	var enemy_tpls: Array = [
		EnemyFactory.bruiser(), EnemyFactory.tactician(), EnemyFactory.berserker()
	]
	var report := MonteCarlo.run(bot_tpls, enemy_tpls, 1000)
	_log.clear()
	_log.append_text(report)

func _on_restart_pressed() -> void:
	_log.clear()
	for child in _bot_row.get_children():
		child.queue_free()
	for child in _enemy_row.get_children():
		child.queue_free()
	_bot_cards.clear()
	_enemy_cards.clear()
	_skill_buttons.clear()
	if _sim:
		_sim.queue_free()
	_start_battle()

# ── Display helpers ───────────────────────────────────────────────────────────

func _update_header() -> void:
	var energy_color: Color
	var over_budget := _sim.energy_remaining < 0
	if over_budget:
		energy_color = Color(1.0, 0.3, 0.3)
	else:
		energy_color = Color(0.9, 0.8, 0.5)
	_header_label.add_theme_color_override("font_color", energy_color)

	var budget_tag := " [OVER BUDGET]" if over_budget else ""
	_header_label.text = "ROUND %d — ENERGY: %d / %d%s" % [
		_sim.current_round, _sim.energy_remaining, SimBattle.ENERGY_BUDGET, budget_tag]

func _update_controls() -> void:
	var is_planning := _sim.state == SimBattle.State.PLANNING
	var is_over := ui_mode == UIMode.BATTLE_OVER
	var over_budget := _sim.energy_remaining < 0
	_undo_btn.disabled = not is_planning or _sim.assignments.is_empty()
	_execute_btn.disabled = not is_planning or is_over or over_budget
	if over_budget:
		_execute_btn.text = "OVER BUDGET"
	elif is_planning:
		_execute_btn.text = "EXECUTE ORDERS ▶"
	else:
		_execute_btn.text = "RESOLVING..."

func _update_status(msg: String) -> void:
	_status_label.text = msg

func _refresh_all_cards() -> void:
	for bot: BotData in _sim.bots:
		var card: BotCard = _bot_cards.get(bot.id)
		if card:
			card.update_display()
	for e: EnemyData in _sim.enemies:
		var card: EnemyCard = _enemy_cards.get(e.id)
		if card:
			card.update_display()

func _update_previews() -> void:
	# Clear existing previews
	for e: EnemyData in _sim.enemies:
		var card: EnemyCard = _enemy_cards.get(e.id)
		if card:
			card.clear_preview()

	var result := LivePreviewSystem.compute(_sim.bots, _sim.enemies, _sim.assignments)
	var outgoing: Dictionary = result["outgoing"]

	for e: EnemyData in _sim.enemies:
		var dmg: int = outgoing.get(e.id, 0)
		var card: EnemyCard = _enemy_cards.get(e.id)
		if card:
			card.show_outgoing_preview(dmg)

func _redraw_arrows() -> void:
	_arrow_layer.clear_all()
	if _sim.state != SimBattle.State.PLANNING:
		return

	# Red dashed arrows: enemy intents → their likely targets
	for e: EnemyData in _sim.enemies:
		if e.is_dead or e.current_intent == null:
			continue
		var intent: IntentData = e.current_intent
		if intent.intent_type not in ["attack", "attack_weakest"]:
			continue

		var from_card: EnemyCard = _enemy_cards.get(e.id)
		if from_card == null:
			continue

		# Resolve target for arrow display
		var target_bot: BotData = _intent_display_target(intent)
		if target_bot == null:
			continue
		var to_card: BotCard = _bot_cards.get(target_bot.id)
		if to_card == null:
			continue

		var from_pt := from_card.global_position + from_card.size * Vector2(0.5, 1.0)
		var to_pt := to_card.global_position + to_card.size * Vector2(0.5, 0.0)
		_arrow_layer.add_arrow(from_pt, to_pt, Color(1.0, 0.25, 0.25, 0.75))

	# Green/red arrows: player assignments
	for bot: BotData in _sim.bots:
		if not _sim.assignments.has(bot.id):
			continue
		var a: Dictionary = _sim.assignments[bot.id]
		var skill: SkillData = a["skill"] as SkillData
		var target: Variant = a.get("target", null)
		if target == null:
			continue

		var from_card: BotCard = _bot_cards.get(bot.id)
		if from_card == null:
			continue

		var to_pos := Vector2.ZERO
		var color := Color(0.3, 1.0, 0.3, 0.85)

		if target is EnemyData:
			var to_card: EnemyCard = _enemy_cards.get(target.id)
			if to_card == null:
				continue
			to_pos = to_card.global_position + to_card.size * Vector2(0.5, 1.0)
			color = Color(1.0, 0.3, 0.3, 0.85)
		elif target is BotData:
			var to_card: BotCard = _bot_cards.get(target.id)
			if to_card == null:
				continue
			to_pos = to_card.global_position + to_card.size * Vector2(0.5, 0.5)

		var from_pt := from_card.global_position + from_card.size * Vector2(0.5, 0.0)
		_arrow_layer.add_arrow(from_pt, to_pos, color)

func _intent_display_target(intent: IntentData) -> BotData:
	var alive: Array = _sim.bots.filter(func(b: BotData) -> bool: return not b.is_dead)
	if alive.is_empty():
		return null
	if intent.target_resolution == "weakest":
		var w: BotData = alive[0] as BotData
		for b: BotData in alive:
			if b.current_hp < w.current_hp:
				w = b
		return w
	# For random intents show first alive as placeholder
	return alive[0] as BotData

func _set_all_highlights(on: bool) -> void:
	for card: BotCard in _bot_cards.values():
		card.set_highlight(on)
	for card: EnemyCard in _enemy_cards.values():
		card.set_highlight(on)

func _highlight_card(bot: BotData, on: bool) -> void:
	var card: BotCard = _bot_cards.get(bot.id)
	if card:
		card.set_highlight(on)

func _highlight_all_enemies(on: bool) -> void:
	for e: EnemyData in _sim.enemies:
		if not e.is_dead:
			var card: EnemyCard = _enemy_cards.get(e.id)
			if card:
				card.set_highlight(on)

func _highlight_all_bots(on: bool) -> void:
	for bot: BotData in _sim.bots:
		if not bot.is_dead:
			var card: BotCard = _bot_cards.get(bot.id)
			if card:
				card.set_highlight(on)
