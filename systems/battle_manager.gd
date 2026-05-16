extends Node
class_name BattleManager

signal attack_performed(attacker: BotData, target: BotData)
signal turn_started(acting_bot: BotData)

var allies: Array[BotData] = []
var enemies: Array[BotData] = []

var turn_order: Array[BotData] = []
var current_turn_index := 0

var combat_log: RichTextLabel
var turn_label: Label
var _log_entries: Array[String] = []

var _acting: BotData = null

func setup_battle(log_ui: RichTextLabel, label_ui: Label) -> void:
	combat_log = log_ui
	turn_label = label_ui
	create_test_bots()
	build_turn_order()
	update_turn_label()

# ── Bot creation ─────────────────────────────────────────────────────────────

func create_test_bots() -> void:
	allies.clear()
	enemies.clear()

	var lib := CombatSkillLibrary.make()

	var ally_1 := BotData.new()
	ally_1.bot_name = "ALLY_ALPHA"
	ally_1.max_hp = randi_range(22, 38)
	ally_1.attack  = randi_range(4, 8)
	ally_1.defense = randi_range(0, 3)
	ally_1.speed   = randi_range(5, 9)
	ally_1.color = Color(0.25, 0.55, 1.0)
	ally_1.initialize()
	ally_1.skill_slots["attack"]  = [lib["standard_attack"], lib["power_shot"]]
	ally_1.skill_slots["defend"]  = [lib["standard_defend"]]
	ally_1.skill_slots["support"] = [lib["standard_support"]]
	ally_1.skill_slots["charge"]  = [lib["standard_charge"]]

	var ally_2 := BotData.new()
	ally_2.bot_name = "ALLY_BETA"
	ally_2.max_hp = randi_range(16, 28)
	ally_2.attack  = randi_range(6, 10)
	ally_2.defense = randi_range(0, 2)
	ally_2.speed   = randi_range(3, 7)
	ally_2.color = Color(0.25, 0.85, 0.45)
	ally_2.initialize()
	ally_2.skill_slots["attack"]  = [lib["standard_attack"], lib["frenzy"]]
	ally_2.skill_slots["defend"]  = [lib["standard_defend"]]
	ally_2.skill_slots["support"] = [lib["battle_cry"]]
	ally_2.skill_slots["charge"]  = [lib["standard_charge"]]

	var ally_3 := BotData.new()
	ally_3.bot_name = "ALLY_GAMMA"
	ally_3.max_hp = randi_range(20, 32)
	ally_3.attack  = randi_range(4, 8)
	ally_3.defense = randi_range(1, 3)
	ally_3.speed   = randi_range(3, 7)
	ally_3.color = Color(0.8, 0.3, 1.0)
	ally_3.initialize()
	ally_3.skill_slots["attack"]  = [lib["standard_attack"], lib["crippling_shot"]]
	ally_3.skill_slots["defend"]  = [lib["standard_defend"], lib["bulwark"]]
	ally_3.skill_slots["support"] = [lib["medic_protocol"]]
	ally_3.skill_slots["charge"]  = [lib["standard_charge"]]

	var ally_4 := BotData.new()
	ally_4.bot_name = "ALLY_DELTA"
	ally_4.max_hp = randi_range(28, 42)
	ally_4.attack  = randi_range(2, 5)
	ally_4.defense = randi_range(2, 5)
	ally_4.speed   = randi_range(2, 5)
	ally_4.color = Color(0.15, 0.85, 0.85)
	ally_4.initialize()
	ally_4.skill_slots["attack"]  = [lib["standard_attack"], lib["spread_shot"]]
	ally_4.skill_slots["defend"]  = [lib["standard_defend"], lib["bulwark"]]
	ally_4.skill_slots["support"] = [lib["standard_support"]]
	ally_4.skill_slots["charge"]  = [lib["standard_charge"], lib["team_charge"]]

	var enemy_1 := BotData.new()
	enemy_1.bot_name = "ENEMY_X"
	enemy_1.max_hp = randi_range(18, 30)
	enemy_1.attack = randi_range(3, 6)
	enemy_1.speed  = randi_range(4, 8)
	enemy_1.color = Color(1.0, 0.3, 0.2)
	enemy_1.initialize()

	var enemy_2 := BotData.new()
	enemy_2.bot_name = "ENEMY_Y"
	enemy_2.max_hp = randi_range(14, 24)
	enemy_2.attack = randi_range(4, 7)
	enemy_2.speed  = randi_range(3, 7)
	enemy_2.color = Color(1.0, 0.65, 0.1)
	enemy_2.initialize()

	var enemy_3 := BotData.new()
	enemy_3.bot_name = "ENEMY_Z"
	enemy_3.max_hp = randi_range(18, 28)
	enemy_3.attack = randi_range(5, 9)
	enemy_3.speed  = randi_range(5, 9)
	enemy_3.color = Color(0.9, 0.2, 0.7)
	enemy_3.initialize()

	allies.append_array([ally_1, ally_2, ally_3, ally_4])
	enemies.append_array([enemy_1, enemy_2, enemy_3])

# ── Turn order ───────────────────────────────────────────────────────────────

func build_turn_order() -> void:
	turn_order.clear()
	for ally in allies:
		if not ally.is_dead:
			turn_order.append(ally)
	for enemy in enemies:
		if not enemy.is_dead:
			turn_order.append(enemy)
	turn_order.sort_custom(func(a: BotData, b: BotData) -> bool: return a.speed > b.speed)

func advance_to_next() -> BotData:
	for _guard in range(30):
		if check_battle_over():
			return null
		if turn_order.is_empty():
			build_turn_order()
		if current_turn_index >= turn_order.size():
			_end_round()
			current_turn_index = 0
			build_turn_order()
			continue
		var bot: BotData = turn_order[current_turn_index]
		if bot.is_dead:
			current_turn_index += 1
			continue
		_acting = bot
		turn_started.emit(_acting)
		update_turn_label()
		return _acting
	return null

func resolve_current(cmd: BotData.Command) -> void:
	if _acting == null:
		return
	_acting.command = cmd
	_process_turn(_acting)
	current_turn_index += 1
	_acting = null

func resolve_current_with_skill(skill: SkillData, target: Variant) -> void:
	if _acting == null:
		return
	_acting.assigned_skill = skill
	_acting.assigned_target = target
	_process_turn_with_skill(_acting)
	current_turn_index += 1
	_acting = null

func _process_turn_with_skill(bot: BotData) -> void:
	if bot.assigned_skill == null:
		_process_turn(bot)
		return
	var skill: SkillData = bot.assigned_skill
	match skill.command_type:
		"attack":  _do_attack_with_skill(bot, skill, bot.assigned_target)
		"defend":  _do_defend_with_skill(bot, skill)
		"support": _do_support_with_skill(bot, skill, bot.assigned_target)
		"charge":  _do_charge_with_skill(bot, skill, bot.assigned_target)
	bot.assigned_skill = null
	bot.assigned_target = null

func _do_attack_with_skill(attacker: BotData, skill: SkillData, target: Variant) -> void:
	var charged := attacker.charge_state.is_active()
	var charge_tag := " [CHARGED]" if charged else ""

	if skill.target_type == "all_enemies":
		var pool := get_alive_enemies() if allies.has(attacker) else get_alive_allies()
		for tgt: BotData in pool:
			var dmg := DamageCalculator.calculate_attack(attacker, skill, tgt)
			var actual := tgt.take_damage(dmg)
			attack_performed.emit(attacker, tgt)
			add_log("%s%s: %s → %s [%d dmg]" % [attacker.bot_name, charge_tag, skill.skill_name, tgt.bot_name, actual])
			if tgt.is_dead:
				add_log("%s destroyed!" % tgt.bot_name)
	elif target is BotData and not (target as BotData).is_dead:
		var tgt: BotData = target as BotData
		var dmg := DamageCalculator.calculate_attack(attacker, skill, tgt)
		var actual := tgt.take_damage(dmg)
		attack_performed.emit(attacker, tgt)
		add_log("%s%s: %s → %s [%d dmg]" % [attacker.bot_name, charge_tag, skill.skill_name, tgt.bot_name, actual])
		if tgt.is_dead:
			add_log("%s destroyed!" % tgt.bot_name)
	else:
		var hits := randi_range(skill.hit_count_min, skill.hit_count_max)
		var total := 0
		for _i in range(hits):
			var hit_pool := get_alive_enemies() if allies.has(attacker) else get_alive_allies()
			if hit_pool.is_empty():
				break
			var tgt: BotData = hit_pool.pick_random()
			var dmg := DamageCalculator.calculate_attack(attacker, skill, tgt)
			var actual := tgt.take_damage(dmg)
			total += actual
			attack_performed.emit(attacker, tgt)
			if tgt.is_dead:
				add_log("%s destroyed!" % tgt.bot_name)
		add_log("%s%s: %s → %d hits [%d total dmg]" % [
				attacker.bot_name, charge_tag, skill.skill_name, hits, total])
	attacker.charge_state.reset()

func _do_defend_with_skill(bot: BotData, skill: SkillData) -> void:
	var bonus := DamageCalculator.calculate_defend(bot, skill)
	if bot.charge_state.is_active():
		bonus = int(bonus * bot.charge_state.get_multiplier())
		bot.charge_state.reset()
	bot.temp_defense_bonus += bonus
	add_log("%s: %s [+%d DEF this round]" % [bot.bot_name, skill.skill_name, bonus])

func _do_support_with_skill(bot: BotData, skill: SkillData, target: Variant) -> void:
	var val := int(skill.effect_value)
	match skill.effect_type:
		"buff":
			if skill.target_type == "all_allies":
				var team := allies if allies.has(bot) else enemies
				for ally: BotData in team:
					if ally != bot and not ally.is_dead:
						ally.temp_attack_bonus  += val
						ally.temp_defense_bonus += val
				add_log("%s: %s [+%d ATK/DEF → all allies]" % [bot.bot_name, skill.skill_name, val])
			elif target is BotData and not (target as BotData).is_dead:
				var tgt: BotData = target as BotData
				tgt.temp_attack_bonus += val
				add_log("%s: %s [+%d ATK → %s]" % [bot.bot_name, skill.skill_name, val, tgt.bot_name])
		"heal":
			if target is BotData and not (target as BotData).is_dead:
				var tgt: BotData = target as BotData
				tgt.current_hp = mini(tgt.current_hp + val, tgt.max_hp)
				add_log("%s: %s [+%d HP → %s]" % [bot.bot_name, skill.skill_name, val, tgt.bot_name])

func _do_charge_with_skill(bot: BotData, skill: SkillData, target: Variant) -> void:
	match skill.skill_name:
		"Overload":
			bot.charge_state.is_overloaded = true
			bot.charge_state.is_charged    = false
			bot.take_damage(3)
			add_log("%s: Overload [OVERLOADED ×3, took 3 self-dmg]" % bot.bot_name)
		"Team Charge":
			bot.charge_state.is_charged = true
			if target is BotData and not (target as BotData).is_dead:
				var tgt: BotData = target as BotData
				tgt.temp_attack_bonus += 2
				add_log("%s: Team Charge [CHARGED, +2 ATK → %s]" % [bot.bot_name, tgt.bot_name])
			else:
				add_log("%s: Team Charge [CHARGED]" % bot.bot_name)
		_:
			bot.charge_state.is_charged = true
			add_log("%s: %s [CHARGED ×2]" % [bot.bot_name, skill.skill_name])

# ── Round end ────────────────────────────────────────────────────────────────

func _end_round() -> void:
	for bot in allies + enemies:
		bot.reset_round_bonuses()
	add_log("─── Round End ───")

# ── Command resolution ───────────────────────────────────────────────────────

func _process_turn(bot: BotData) -> void:
	match bot.command:
		BotData.Command.ATTACK:  _do_attack(bot)
		BotData.Command.DEFEND:  _do_defend(bot)
		BotData.Command.SUPPORT: _do_support(bot)
		BotData.Command.CHARGE:  _do_charge(bot)

func _do_attack(attacker: BotData) -> void:
	var pool := get_alive_enemies() if allies.has(attacker) else get_alive_allies()
	if pool.is_empty():
		return

	var target: BotData = pool.pick_random()
	var damage := attacker.attack + attacker.temp_attack_bonus
	var charged := attacker.charge_state.is_active()

	if charged:
		damage = int(damage * attacker.charge_state.get_multiplier())
		attacker.charge_state.reset()

	var net_damage := maxi(0, damage - target.defense - target.temp_defense_bonus)
	var actual := target.take_damage(net_damage)
	attack_performed.emit(attacker, target)

	var prefix := "[CHARGED] " if charged else ""
	if actual == 0:
		add_log("%s%s attacks %s — blocked! (defense absorbs all damage)" \
				% [prefix, attacker.bot_name, target.bot_name])
	else:
		add_log("%s%s attacks %s for %d damage. (%d HP remaining)" \
				% [prefix, attacker.bot_name, target.bot_name, actual, target.current_hp])

	if target.is_dead:
		add_log("%s was destroyed!" % target.bot_name)

func _do_defend(bot: BotData) -> void:
	var bonus := 4 if bot.charge_state.is_active() else 2
	bot.charge_state.reset()
	bot.temp_defense_bonus = bonus
	add_log("%s takes a defensive stance (-%d incoming damage this round)." \
			% [bot.bot_name, bonus])

func _do_support(bot: BotData) -> void:
	var team := allies if allies.has(bot) else enemies
	for ally in team:
		if ally != bot and not ally.is_dead:
			ally.temp_attack_bonus += 2
			ally.temp_defense_bonus += 2
	add_log("%s supports allies! (+2 ATK, +2 DEF to all other allies this round)" % bot.bot_name)

func _do_charge(bot: BotData) -> void:
	bot.charge_state.is_charged = true
	add_log("%s charges up! (next ATK ×2 or next DEF ×2)" % bot.bot_name)

# ── Helpers ──────────────────────────────────────────────────────────────────

func get_alive_allies() -> Array[BotData]:
	var alive: Array[BotData] = []
	for bot in allies:
		if not bot.is_dead:
			alive.append(bot)
	return alive

func get_alive_enemies() -> Array[BotData]:
	var alive: Array[BotData] = []
	for bot in enemies:
		if not bot.is_dead:
			alive.append(bot)
	return alive

func add_log(text: String) -> void:
	_log_entries.insert(0, text)
	combat_log.clear()
	combat_log.append_text("\n".join(_log_entries))

func update_turn_label() -> void:
	if turn_label == null or current_turn_index >= turn_order.size():
		return
	var bot := turn_order[current_turn_index]
	turn_label.text = "Current Turn: %s" % bot.bot_name

func check_battle_over() -> bool:
	if get_alive_allies().is_empty():
		add_log("★ ENEMIES WIN ★")
		return true
	if get_alive_enemies().is_empty():
		add_log("★ ALLIES WIN ★")
		return true
	return false

func reset_battle() -> void:
	combat_log.clear()
	_log_entries.clear()
	_acting = null
	current_turn_index = 0
	create_test_bots()
	build_turn_order()
	update_turn_label()
	add_log("Battle Reset")
