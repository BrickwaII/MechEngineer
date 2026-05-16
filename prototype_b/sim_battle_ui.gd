extends Control

enum UIMode { IDLE, SELECTING_TARGET, RESOLVING, BATTLE_OVER }
var ui_mode: UIMode = UIMode.IDLE

var _sim: SimBattle

var _bot_cards: Dictionary = {}    # bot_id (String) → BotCard
var _enemy_cards: Dictionary = {}  # enemy_id (String) → EnemyCard
var _cat_buttons: Dictionary = {}    # bot_id (String) → { cat_key (String) → Button }
var _skill_sublists: Dictionary = {} # bot_id (String) → { cat_key (String) → VBoxContainer }

var _selected_bot: BotData = null
var _pending_skill: SkillData = null
var _stand_by_skill: SkillData

var _header_label: Label
var _bot_row: HBoxContainer
var _enemy_row: HBoxContainer
var _arrow_layer: ArrowLayer
var _attack_arrow: AttackArrow
var _log: RichTextLabel
var _undo_btn: Button
var _execute_btn: Button
var _status_label: Label

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
	s.description = "Do nothing this round. Free action."
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
	_sim.attack_flashed.connect(_on_attack_flashed)

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
	atlas.id = "atlas"

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
	wren.id = "wren"

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
	corvus.id = "corvus"

	return [atlas, wren, corvus]

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
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

	_header_label = Label.new()
	_header_label.text = "PROTOTYPE B — Simultaneous Resolution"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	root.add_child(_header_label)

	# Battle area
	var battle_area := VBoxContainer.new()
	battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_area.size_flags_stretch_ratio = 3.0
	battle_area.add_theme_constant_override("separation", 8)
	root.add_child(battle_area)

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

	# Controls row
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

	var menu_btn := Button.new()
	menu_btn.text = "◀ MENU"
	menu_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://menu/main_menu.tscn")
	)
	ctrl_row.add_child(menu_btn)

	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 80)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.size_flags_stretch_ratio = 1.0
	_log.fit_content = false
	_log.scroll_active = true
	root.add_child(_log)

	# Arrow overlay (must be a direct child of self to cover full screen)
	_arrow_layer = ArrowLayer.new()
	_arrow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_layer)

	# Attack flash arrow (on top of everything)
	_attack_arrow = AttackArrow.new()
	_attack_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attack_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_attack_arrow)


func _build_cards(bots: Array, enemies: Array) -> void:
	for child in _bot_row.get_children():
		child.queue_free()
	for child in _enemy_row.get_children():
		child.queue_free()
	_bot_cards.clear()
	_enemy_cards.clear()
	_cat_buttons.clear()
	_skill_sublists.clear()

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

		_build_cat_buttons(bot, col)

	for e: EnemyData in enemies:
		var card := EnemyCard.new()
		_enemy_row.add_child(card)
		card.setup(e)
		card.card_clicked.connect(_on_enemy_card_clicked)
		_enemy_cards[e.id] = card

func _build_cat_buttons(bot: BotData, parent: VBoxContainer) -> void:
	var btn_map: Dictionary = {}
	var sublist_map: Dictionary = {}
	var cats: Array = [
		["ATTACK",   "attack",   Color(0.90, 0.22, 0.18)],
		["DEFEND",   "defend",   Color(0.18, 0.42, 0.92)],
		["SUPPORT",  "support",  Color(0.18, 0.80, 0.32)],
		["CHARGE",   "charge",   Color(0.92, 0.70, 0.10)],
		["STAND BY", "stand_by", Color(0.55, 0.55, 0.55)],
	]
	for row in cats:
		var label: String = row[0] as String
		var cat: String   = row[1] as String
		var col: Color    = row[2] as Color

		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 2)
		parent.add_child(section)

		var btn := Button.new()
		btn.text = label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size   = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", col)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var captured_cat: String = cat
		btn.pressed.connect(func() -> void: _on_cat_button_pressed(bot, captured_cat))
		section.add_child(btn)
		btn_map[cat] = btn

		if cat == "stand_by":
			continue

		var raw_slots: Variant = bot.skill_slots.get(cat, [])
		var skills: Array = raw_slots as Array

		var skill_list := VBoxContainer.new()
		skill_list.add_theme_constant_override("separation", 2)
		skill_list.visible = false
		section.add_child(skill_list)
		sublist_map[cat] = skill_list

		for skill: SkillData in skills:
			var sbtn := Button.new()
			var cost_str: String = "free" if skill.energy_cost == 0 else "%d⚡" % skill.energy_cost
			sbtn.text = "  %s [%s]" % [skill.skill_name, cost_str]
			sbtn.tooltip_text = skill.description
			sbtn.add_theme_color_override("font_color", col)
			sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sbtn.custom_minimum_size   = Vector2(0, 28)
			sbtn.add_theme_font_size_override("font_size", 10)
			var s: SkillData = skill
			sbtn.pressed.connect(func() -> void:
				SFX.select()
				_select_skill_for(bot, s)
			)
			skill_list.add_child(sbtn)

	_cat_buttons[bot.id] = btn_map
	_skill_sublists[bot.id] = sublist_map

# ── Category selection ────────────────────────────────────────────────────────

func _on_cat_button_pressed(bot: BotData, cat: String) -> void:
	if ui_mode == UIMode.RESOLVING or ui_mode == UIMode.BATTLE_OVER:
		return

	SFX.click()
	_set_all_highlights(false)
	ui_mode = UIMode.IDLE
	_selected_bot = null
	_pending_skill = null
	_update_status("")

	# Toggle off if same category is already assigned
	if _sim.assignments.has(bot.id):
		var a: Dictionary = _sim.assignments[bot.id]
		var assigned: SkillData = a["skill"] as SkillData
		var assigned_cat: String = "stand_by" if assigned.skill_name == "Stand By" \
				else assigned.command_type
		if assigned_cat == cat:
			_sim.undo_assignment(bot.id)
			_collapse_all_skill_lists(bot.id)
			return

	# Stand By assigns directly
	if cat == "stand_by":
		_sim.make_assignment(bot, _stand_by_skill, null)
		_collapse_all_skill_lists(bot.id)
		return

	var raw_slots: Variant = bot.skill_slots.get(cat, [])
	var skills: Array = raw_slots as Array
	if skills.is_empty():
		_collapse_all_skill_lists(bot.id)
		return

	if skills.size() == 1:
		_select_skill_for(bot, skills[0] as SkillData)
		_collapse_all_skill_lists(bot.id)
		return

	# Collapse all other categories, toggle this one
	var sublists: Dictionary = _skill_sublists.get(bot.id, {})
	for k in sublists:
		if k != cat:
			(sublists[k] as VBoxContainer).visible = false
	var skill_list: VBoxContainer = sublists.get(cat) as VBoxContainer
	if skill_list != null:
		skill_list.visible = not skill_list.visible

func _collapse_all_skill_lists(bot_id: String) -> void:
	var sublists: Dictionary = _skill_sublists.get(bot_id, {})
	for k in sublists:
		(sublists[k] as VBoxContainer).visible = false

func _select_skill_for(bot: BotData, skill: SkillData) -> void:
	_selected_bot  = bot
	_pending_skill = skill

	match skill.target_type:
		"self", "all_enemies", "all_allies", "random_enemy":
			_confirm_assignment(bot, skill, null)
		"single_enemy":
			_collapse_all_skill_lists(bot.id)
			ui_mode = UIMode.SELECTING_TARGET
			_highlight_all_enemies(true)
			_update_status("Select a target for %s" % skill.skill_name)
		"single_ally":
			_collapse_all_skill_lists(bot.id)
			ui_mode = UIMode.SELECTING_TARGET
			_highlight_all_bots(true)
			_update_status("Select an ally for %s" % skill.skill_name)

func _update_category_buttons() -> void:
	for bot: BotData in _sim.bots:
		var btn_map: Dictionary = _cat_buttons.get(bot.id, {})
		var assigned_skill: SkillData = null
		var assigned_cat: String = ""
		if _sim.assignments.has(bot.id):
			var a: Dictionary = _sim.assignments[bot.id]
			assigned_skill = a["skill"] as SkillData
			if assigned_skill.skill_name == "Stand By":
				assigned_cat = "stand_by"
			else:
				assigned_cat = assigned_skill.command_type

		var cat_defs: Array = [
			["ATTACK",   "attack"],
			["DEFEND",   "defend"],
			["SUPPORT",  "support"],
			["CHARGE",   "charge"],
			["STAND BY", "stand_by"],
		]
		for row in cat_defs:
			var label: String = row[0] as String
			var cat: String   = row[1] as String
			var btn: Button   = btn_map.get(cat) as Button
			if btn == null:
				continue
			if cat == assigned_cat and assigned_skill != null:
				var cost_str: String = "" if assigned_skill.energy_cost == 0 \
						else " [%d⚡]" % assigned_skill.energy_cost
				btn.text = label + "\n" + assigned_skill.skill_name + cost_str
				btn.modulate = Color(0.3, 1.0, 0.5)
			else:
				btn.text = label
				btn.modulate = Color.WHITE

# ── Event handlers from SimBattle ─────────────────────────────────────────────

func _on_planning_started(_round: int) -> void:
	ui_mode = UIMode.IDLE
	_selected_bot = null
	_pending_skill = null
	for bot_id in _skill_sublists:
		_collapse_all_skill_lists(bot_id)
	_update_header()
	_refresh_all_cards()
	call_deferred("_redraw_arrows")
	_update_controls()
	_update_category_buttons()

func _on_assignment_changed() -> void:
	_update_header()
	_update_controls()
	_refresh_all_cards()
	_update_previews()
	_redraw_arrows()
	_update_category_buttons()

func _on_resolution_started() -> void:
	ui_mode = UIMode.RESOLVING
	for bot_id in _skill_sublists:
		_collapse_all_skill_lists(bot_id)
	_set_all_highlights(false)
	_update_controls()

func _on_attack_flashed(attacker_id: String, attacker_is_enemy: bool, target_id: String, target_is_enemy: bool) -> void:
	var from_pt := Vector2.ZERO
	var to_pt := Vector2.ZERO
	if attacker_is_enemy:
		var card: EnemyCard = _enemy_cards.get(attacker_id) as EnemyCard
		if card:
			from_pt = card.get_global_rect().get_center()
	else:
		var card: BotCard = _bot_cards.get(attacker_id) as BotCard
		if card:
			from_pt = card.get_global_rect().get_center()
	if target_is_enemy:
		var card: EnemyCard = _enemy_cards.get(target_id) as EnemyCard
		if card:
			to_pt = card.get_global_rect().get_center()
	else:
		var card: BotCard = _bot_cards.get(target_id) as BotCard
		if card:
			to_pt = card.get_global_rect().get_center()
	if from_pt != Vector2.ZERO and to_pt != Vector2.ZERO:
		_attack_arrow.show_attack(from_pt, to_pt)

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
	var msg: String = "\n★ VICTORY — enemies eliminated ★\n" if player_won \
		else "\n✕ DEFEAT — all bots destroyed ✕\n"
	_log.append_text(msg)

# ── Bot / enemy card click handlers ──────────────────────────────────────────

func _on_bot_card_clicked(bot: BotData) -> void:
	if ui_mode == UIMode.SELECTING_TARGET:
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
	_collapse_all_skill_lists(bot.id)

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_clear_all_pressed() -> void:
	SFX.cancel_sfx()
	_sim.clear_assignments()
	_selected_bot = null
	_pending_skill = null
	ui_mode = UIMode.IDLE
	for bot_id in _skill_sublists:
		_collapse_all_skill_lists(bot_id)
	_set_all_highlights(false)
	_update_status("")

func _on_execute_pressed() -> void:
	if ui_mode == UIMode.BATTLE_OVER:
		return
	SFX.confirm()
	_sim.confirm_assignments()

func _on_restart_pressed() -> void:
	_log.clear()
	for child in _bot_row.get_children():
		child.queue_free()
	for child in _enemy_row.get_children():
		child.queue_free()
	_bot_cards.clear()
	_enemy_cards.clear()
	_cat_buttons.clear()
	_skill_sublists.clear()
	if _sim:
		_sim.queue_free()
	_start_battle()

# ── Display helpers ───────────────────────────────────────────────────────────

func _update_header() -> void:
	var over_budget := _sim.energy_remaining < 0
	var energy_color: Color = Color(1.0, 0.3, 0.3) if over_budget else Color(0.9, 0.8, 0.5)
	_header_label.add_theme_color_override("font_color", energy_color)
	var budget_tag: String = " [OVER BUDGET]" if over_budget else ""
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
		var card: BotCard = _bot_cards.get(bot.id) as BotCard
		if card:
			card.update_display()
	for e: EnemyData in _sim.enemies:
		var card: EnemyCard = _enemy_cards.get(e.id) as EnemyCard
		if card:
			card.update_display()

func _update_previews() -> void:
	for e: EnemyData in _sim.enemies:
		var card: EnemyCard = _enemy_cards.get(e.id) as EnemyCard
		if card:
			card.clear_preview()

	var result := LivePreviewSystem.compute(_sim.bots, _sim.enemies, _sim.assignments)
	var outgoing: Dictionary = result["outgoing"]

	for e: EnemyData in _sim.enemies:
		var dmg: int = int(outgoing.get(e.id, 0))
		var card: EnemyCard = _enemy_cards.get(e.id) as EnemyCard
		if card:
			card.show_outgoing_preview(dmg)

func _redraw_arrows() -> void:
	_arrow_layer.clear_all()
	if _sim.state != SimBattle.State.PLANNING:
		return

	# Red dashed arrows: enemy intents → predicted targets
	for e: EnemyData in _sim.enemies:
		if e.is_dead or e.current_intent == null:
			continue
		var intent: IntentData = e.current_intent
		if intent.intent_type not in ["attack", "attack_weakest"]:
			continue
		var from_card: EnemyCard = _enemy_cards.get(e.id) as EnemyCard
		if from_card == null:
			continue
		var target_bot: BotData = _intent_display_target(intent)
		if target_bot == null:
			continue
		var to_card: BotCard = _bot_cards.get(target_bot.id) as BotCard
		if to_card == null:
			continue
		var from_pt := from_card.global_position + from_card.size * Vector2(0.5, 1.0)
		var to_pt := to_card.global_position + to_card.size * Vector2(0.5, 0.0)
		_arrow_layer.add_arrow(from_pt, to_pt, Color(1.0, 0.25, 0.25, 0.75))

	# Colored arrows: player assignments
	for bot: BotData in _sim.bots:
		if not _sim.assignments.has(bot.id):
			continue
		var a: Dictionary = _sim.assignments[bot.id]
		var skill: SkillData = a["skill"] as SkillData
		var target: Variant = a.get("target", null)
		if target == null:
			continue
		var from_card: BotCard = _bot_cards.get(bot.id) as BotCard
		if from_card == null:
			continue
		var to_pos := Vector2.ZERO
		var color := Color(0.3, 1.0, 0.3, 0.85)
		if target is EnemyData:
			var to_card: EnemyCard = _enemy_cards.get(target.id) as EnemyCard
			if to_card == null:
				continue
			to_pos = to_card.global_position + to_card.size * Vector2(0.5, 1.0)
			color = Color(1.0, 0.3, 0.3, 0.85)
		elif target is BotData:
			var to_card: BotCard = _bot_cards.get(target.id) as BotCard
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
	return alive[0] as BotData

func _set_all_highlights(on: bool) -> void:
	for card in _bot_cards.values():
		(card as BotCard).set_highlight(on)
	for card in _enemy_cards.values():
		(card as EnemyCard).set_highlight(on)

func _highlight_all_enemies(on: bool) -> void:
	for e: EnemyData in _sim.enemies:
		if not e.is_dead:
			var card: EnemyCard = _enemy_cards.get(e.id) as EnemyCard
			if card:
				card.set_highlight(on)

func _highlight_all_bots(on: bool) -> void:
	for bot: BotData in _sim.bots:
		if not bot.is_dead:
			var card: BotCard = _bot_cards.get(bot.id) as BotCard
			if card:
				card.set_highlight(on)
