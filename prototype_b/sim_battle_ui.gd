extends Control

# ── Sub-states within PLANNING ───────────────────────────────────────────────
enum UIMode { IDLE, SELECTING_SKILL, SELECTING_TARGET, RESOLVING, BATTLE_OVER }

var ui_mode: UIMode = UIMode.IDLE

var _sim: SimBattle

# Bot ID → BotCard
var _bot_cards: Dictionary = {}
# EnemyData.id → EnemyCard
var _enemy_cards: Dictionary = {}

var _selected_bot: BotData = null
var _pending_skill: SkillData = null

# ── UI elements ──────────────────────────────────────────────────────────────
var _header_label: Label
var _bot_row: HBoxContainer
var _enemy_row: HBoxContainer
var _arrow_layer: ArrowLayer
var _skill_panel: SkillPanel
var _queue_ui: AssignmentQueueUI
var _log: RichTextLabel
var _undo_btn: Button
var _execute_btn: Button
var _status_label: Label

# ── Boot ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_battle()
	get_viewport().size_changed.connect(func() -> void: call_deferred("_redraw_arrows"))

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
	var lib := SkillLibrary.make()

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

	# ── Middle area: skill panel + queue ────────────────────────────────────
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	root.add_child(mid)

	_skill_panel = SkillPanel.new()
	_skill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_panel.visible = false
	_skill_panel.skill_chosen.connect(_on_skill_chosen)
	mid.add_child(_skill_panel)

	_queue_ui = AssignmentQueueUI.new()
	_queue_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_queue_ui)

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
	_undo_btn.text = "UNDO LAST"
	_undo_btn.pressed.connect(_on_undo_pressed)
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

	for bot: BotData in bots:
		var card := BotCard.new()
		_bot_row.add_child(card)
		card.setup(bot, 60, false)
		card.card_clicked.connect(_on_bot_card_clicked)
		_bot_cards[bot.id] = card

	for e: EnemyData in enemies:
		var card := EnemyCard.new()
		_enemy_row.add_child(card)
		card.setup(e)
		card.card_clicked.connect(_on_enemy_card_clicked)
		_enemy_cards[e.id] = card

# ── Event handlers from SimBattle ────────────────────────────────────────────

func _on_planning_started(round: int) -> void:
	ui_mode = UIMode.IDLE
	_selected_bot = null
	_pending_skill = null
	_skill_panel.visible = false
	_update_header()
	_refresh_all_cards()
	call_deferred("_redraw_arrows")  # defer so layout is settled
	_update_controls()
	_queue_ui.refresh(_sim.bots, {})

func _on_assignment_changed() -> void:
	_update_header()
	_update_controls()
	_refresh_all_cards()
	_update_previews()
	_redraw_arrows()
	var updated_assignments := _assignments_with_previews()
	_queue_ui.refresh(_sim.bots, updated_assignments)

func _on_resolution_started() -> void:
	ui_mode = UIMode.RESOLVING
	_skill_panel.visible = false
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
	_skill_panel.visible = false
	_update_controls()
	var msg := "\n★ VICTORY — enemies eliminated ★\n" if player_won \
		else "\n✕ DEFEAT — all bots destroyed ✕\n"
	_log.append_text(msg)

# ── Bot / enemy card click handlers ──────────────────────────────────────────

func _on_bot_card_clicked(bot: BotData) -> void:
	match ui_mode:
		UIMode.IDLE, UIMode.SELECTING_SKILL:
			if _sim.assignments.has(bot.id):
				return  # already assigned
			_selected_bot = bot
			ui_mode = UIMode.SELECTING_SKILL
			_skill_panel.populate(bot, _sim.energy_remaining)
			_skill_panel.visible = true
			_set_all_highlights(false)
			_highlight_card(bot, true)
			_update_status("Select a skill for %s" % bot.bot_name)

		UIMode.SELECTING_TARGET:
			# Selecting an ally as target
			if _pending_skill != null and \
					_pending_skill.target_type in ["single_ally", "single_enemy"]:
				if _pending_skill.target_type == "single_ally":
					_confirm_assignment(_selected_bot, _pending_skill, bot)

func _on_enemy_card_clicked(enemy: EnemyData) -> void:
	if ui_mode == UIMode.SELECTING_TARGET and _pending_skill != null:
		if _pending_skill.target_type in ["single_enemy", "random_enemy"]:
			_confirm_assignment(_selected_bot, _pending_skill, enemy)

func _on_skill_chosen(skill: SkillData) -> void:
	if _selected_bot == null:
		return
	_pending_skill = skill

	match skill.target_type:
		"self", "all_enemies", "all_allies":
			_confirm_assignment(_selected_bot, skill, null)

		"single_enemy":
			ui_mode = UIMode.SELECTING_TARGET
			_skill_panel.visible = false
			_set_all_highlights(false)
			_highlight_all_enemies(true)
			_update_status("Select a target for %s" % skill.skill_name)

		"single_ally":
			ui_mode = UIMode.SELECTING_TARGET
			_skill_panel.visible = false
			_set_all_highlights(false)
			_highlight_all_bots(true)
			_update_status("Select an ally for %s" % skill.skill_name)

		"random_enemy":
			# Auto-confirm, target resolved at resolution time
			_confirm_assignment(_selected_bot, skill, null)

func _confirm_assignment(bot: BotData, skill: SkillData, target) -> void:
	var ok := _sim.make_assignment(bot, skill, target)
	if ok:
		_selected_bot = null
		_pending_skill = null
		ui_mode = UIMode.IDLE
		_skill_panel.visible = false
		_set_all_highlights(false)
		_update_status("")
	else:
		_update_status("Cannot assign — check energy or already assigned")

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_undo_pressed() -> void:
	_sim.undo_last_assignment()
	_selected_bot = null
	_pending_skill = null
	ui_mode = UIMode.IDLE
	_skill_panel.visible = false
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
	if _sim:
		_sim.queue_free()
	_start_battle()

# ── Display helpers ───────────────────────────────────────────────────────────

func _update_header() -> void:
	_header_label.text = "ROUND %d — ENERGY: %d / %d" % [
		_sim.current_round, _sim.energy_remaining, SimBattle.ENERGY_BUDGET]

func _update_controls() -> void:
	var is_planning := _sim.state == SimBattle.State.PLANNING
	var is_over := ui_mode == UIMode.BATTLE_OVER
	_undo_btn.disabled = not is_planning or _sim.assignments.is_empty()
	_execute_btn.disabled = not is_planning or is_over
	_execute_btn.text = "EXECUTE ORDERS ▶" if is_planning else "RESOLVING..."

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
	var incoming: Dictionary = result["incoming"]

	for e: EnemyData in _sim.enemies:
		var dmg: int = outgoing.get(e.id, 0)
		var card: EnemyCard = _enemy_cards.get(e.id)
		if card:
			card.show_outgoing_preview(dmg)

	# Show incoming on bot cards via their assignment label area
	for bot: BotData in _sim.bots:
		var dmg: int = incoming.get(bot.id, 0)
		var card: BotCard = _bot_cards.get(bot.id)
		if card and dmg > 0:
			# Reuse the assignment label slot temporarily
			# (only shown if bot has no skill assignment)
			pass  # Incoming preview visible in log; full bar overlay is phase 4

func _assignments_with_previews() -> Dictionary:
	var result := LivePreviewSystem.compute(_sim.bots, _sim.enemies, _sim.assignments)
	var previews: Dictionary = result["assignment_previews"]
	var out := _sim.assignments.duplicate()
	for bot_id in previews:
		if out.has(bot_id):
			out[bot_id]["preview_dmg"] = previews[bot_id]
	return out

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
		var skill: SkillData = a["skill"]
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
		var w: BotData = alive[0]
		for b: BotData in alive:
			if b.current_hp < w.current_hp:
				w = b
		return w
	# For random intents show first alive as placeholder
	return alive[0]

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
