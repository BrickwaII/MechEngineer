class_name SimBattle extends Node

enum State { PLANNING, RESOLVING, ROUND_END, BATTLE_OVER }

signal planning_started(round: int)
signal assignment_changed                  # planning state updated
signal resolution_started
signal action_executed(msg: String)
signal round_ended(round: int)
signal battle_over(player_won: bool)

const ENERGY_BUDGET: int = 4

var state: State = State.PLANNING
var bots: Array = []     # Array[BotData]
var enemies: Array = []  # Array[EnemyData]

# assignments[bot_id] = { skill, target, preview_dmg }
var assignments: Dictionary = {}
var energy_remaining: int = ENERGY_BUDGET
var current_round: int = 0

func setup(p_bots: Array, p_enemies: Array) -> void:
	bots = p_bots
	enemies = p_enemies
	start_round()

func start_round() -> void:
	current_round += 1
	assignments.clear()
	energy_remaining = ENERGY_BUDGET
	for bot: BotData in bots:
		bot.assigned_skill = null
		bot.assigned_target = null
		bot.reset_round_bonuses()
	for e: EnemyData in enemies:
		e.temp_attack_bonus = 0

	state = State.PLANNING
	emit_signal("planning_started", current_round)
	emit_signal("assignment_changed")

func make_assignment(bot: BotData, skill: SkillData, target = null) -> bool:
	if state != State.PLANNING:
		return false
	if skill.energy_cost > energy_remaining:
		return false
	if assignments.has(bot.id):
		return false

	bot.assigned_skill = skill
	bot.assigned_target = target
	assignments[bot.id] = { "skill": skill, "target": target, "preview_dmg": 0 }
	energy_remaining -= skill.energy_cost

	emit_signal("assignment_changed")
	return true

func undo_last_assignment() -> void:
	if state != State.PLANNING or assignments.is_empty():
		return

	var last_id: String = assignments.keys()[-1]
	var a: Dictionary = assignments[last_id]
	energy_remaining += (a["skill"] as SkillData).energy_cost
	assignments.erase(last_id)

	for bot: BotData in bots:
		if bot.id == last_id:
			bot.assigned_skill = null
			bot.assigned_target = null
			break

	emit_signal("assignment_changed")

func confirm_assignments() -> void:
	if state != State.PLANNING:
		return
	state = State.RESOLVING
	emit_signal("resolution_started")
	_resolve_simultaneously()

# ── Resolution ───────────────────────────────────────────────────────────────

func _resolve_simultaneously() -> void:
	# Phase A: Defend bots act first (gain defense)
	for bot: BotData in _bots_with_command("defend"):
		_execute_bot_action(bot)

	# Phase B: remaining bots sorted by Speed desc
	var others := bots.filter(func(b: BotData) -> bool:
		return not b.is_dead and assignments.has(b.id) \
		and (b.assigned_skill as SkillData).command_type != "defend"
	)
	others.sort_custom(func(a: BotData, b: BotData) -> bool: return a.speed > b.speed)
	for bot: BotData in others:
		_execute_bot_action(bot)

	if _check_battle_over():
		return

	# Phase C: enemy intents resolve in speed order
	var alive_enemies: Array = enemies.filter(func(e: EnemyData) -> bool: return not e.is_dead)
	alive_enemies.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.speed > b.speed)
	for e: EnemyData in alive_enemies:
		_execute_enemy_intent(e)

	if _check_battle_over():
		return

	# Phase D: advance enemy intents and start next round
	for e: EnemyData in enemies:
		if not e.is_dead:
			e.advance_intent()

	state = State.ROUND_END
	emit_signal("round_ended", current_round)
	start_round()

func _bots_with_command(cmd: String) -> Array:
	return bots.filter(func(b: BotData) -> bool:
		return not b.is_dead and assignments.has(b.id) \
		and (b.assigned_skill as SkillData).command_type == cmd
	)

func _execute_bot_action(bot: BotData) -> void:
	if bot.is_dead or not assignments.has(bot.id):
		return
	var skill: SkillData = bot.assigned_skill
	var target = bot.assigned_target

	match skill.command_type:
		"attack":  _resolve_attack(bot, skill, target)
		"defend":  _resolve_defend(bot, skill)
		"support": _resolve_support(bot, skill, target)
		"charge":  _resolve_charge(bot, skill, target)

func _resolve_attack(bot: BotData, skill: SkillData, target) -> void:
	var was_charged := bot.charge_state.is_active()

	match skill.target_type:
		"single_enemy":
			if target is EnemyData and not target.is_dead:
				var dmg := DamageCalculator.calculate_attack(bot, skill, target)
				target.take_damage(dmg)
				var suffix := " [CRIPPLED -2 ATK]" if skill.skill_name == "Crippling Shot" else ""
				if skill.skill_name == "Crippling Shot":
					target.temp_attack_bonus -= int(skill.effect_value)
				var charge_tag := " (CHARGED)" if was_charged else ""
				emit_signal("action_executed",
					"%s%s: %s → %s [%d dmg]%s" % [
					bot.bot_name, charge_tag, skill.skill_name,
					target.enemy_name, dmg, suffix])

		"all_enemies":
			var total := 0
			for e: EnemyData in enemies:
				if e.is_dead:
					continue
				var dmg := DamageCalculator.calculate_attack(bot, skill, e)
				e.take_damage(dmg)
				total += dmg
			emit_signal("action_executed",
				"%s: %s → all enemies [%d dmg each]" % [
				bot.bot_name, skill.skill_name, total / maxi(1, enemies.size())])

		"random_enemy":
			var alive := enemies.filter(func(e: EnemyData) -> bool: return not e.is_dead)
			if alive.is_empty():
				return
			var hits := randi_range(skill.hit_count_min, skill.hit_count_max)
			var total := 0
			for _i in range(hits):
				var t: EnemyData = alive[randi() % alive.size()]
				var dmg := DamageCalculator.calculate_attack(bot, skill, t)
				t.take_damage(dmg)
				total += dmg
			emit_signal("action_executed",
				"%s: %s → %d hits [%d total dmg]" % [
				bot.bot_name, skill.skill_name, hits, total])

	bot.charge_state.reset()

func _resolve_defend(bot: BotData, skill: SkillData) -> void:
	var bonus := DamageCalculator.calculate_defend(bot, skill)
	if bot.charge_state.is_active():
		bonus = int(bonus * bot.charge_state.get_multiplier())
		bot.charge_state.reset()
	bot.temp_defense_bonus += bonus
	emit_signal("action_executed",
		"%s: %s [+%d DEF this round]" % [bot.bot_name, skill.skill_name, bonus])

	# Bulwark shares half with weakest ally
	if skill.skill_name == "Bulwark":
		var weakest := _weakest_bot(bot)
		if weakest:
			var share := bonus / 2
			weakest.temp_defense_bonus += share
			emit_signal("action_executed",
				"  ↳ Bulwark shares +%d DEF → %s" % [share, weakest.bot_name])

func _resolve_support(bot: BotData, skill: SkillData, target) -> void:
	var val := int(skill.effect_value)
	match skill.effect_type:
		"buff":
			if skill.target_type == "all_allies":
				for b: BotData in bots:
					if b != bot and not b.is_dead:
						b.temp_attack_bonus += val
						b.temp_defense_bonus += val
				emit_signal("action_executed",
					"%s: %s [+%d ATK/DEF → all allies]" % [bot.bot_name, skill.skill_name, val])
			elif target is BotData and not target.is_dead:
				target.temp_attack_bonus += val
				emit_signal("action_executed",
					"%s: %s [+%d ATK → %s]" % [bot.bot_name, skill.skill_name, val, target.bot_name])
		"heal":
			if target is BotData and not target.is_dead:
				target.current_hp = mini(target.current_hp + val, target.max_hp)
				emit_signal("action_executed",
					"%s: %s [+%d HP → %s]" % [bot.bot_name, skill.skill_name, val, target.bot_name])

func _resolve_charge(bot: BotData, skill: SkillData, target) -> void:
	if skill.skill_name == "Overload":
		bot.charge_state.is_overloaded = true
		bot.charge_state.is_charged = false
		bot.take_damage(3)
		emit_signal("action_executed",
			"%s: Overload [OVERLOADED ×3, took 3 self-dmg]" % bot.bot_name)
	elif skill.skill_name == "Team Charge":
		bot.charge_state.is_charged = true
		if target is BotData and not target.is_dead:
			target.temp_attack_bonus += 2
			emit_signal("action_executed",
				"%s: Team Charge [CHARGED, +2 ATK → %s]" % [bot.bot_name, target.bot_name])
		else:
			emit_signal("action_executed",
				"%s: Team Charge [CHARGED]" % bot.bot_name)
	else:
		bot.charge_state.is_charged = true
		emit_signal("action_executed",
			"%s: %s [CHARGED ×2]" % [bot.bot_name, skill.skill_name])

func _execute_enemy_intent(e: EnemyData) -> void:
	if e.current_intent == null:
		return
	var intent: IntentData = e.current_intent

	match intent.intent_type:
		"attack", "attack_weakest":
			var target := _resolve_intent_target(intent)
			if target == null:
				return
			# Apply enemy power-up, then reduce by target's defense + round defend bonus
			var raw := intent.value + e.temp_attack_bonus
			var net := max(0, raw - target.defense - target.temp_defense_bonus)
			var actual := target.take_damage(net)
			var adj_tag := " [POWER-UP]" if e.temp_attack_bonus > 0 else ""
			var def_tag := " (blocked %d)" % (raw - net) if net < raw else ""
			emit_signal("action_executed",
				"%s%s attacks %s [%d dmg%s]" % [e.enemy_name, adj_tag, target.bot_name, actual, def_tag])

		"defend":
			# Enemies don't use DamageCalculator for their own defense boost
			# — just note it; their `defense` stat is always active
			emit_signal("action_executed",
				"%s braces for impact [+%d DEF next round]" % [e.enemy_name, intent.value])

		"power_up":
			e.temp_attack_bonus += intent.value
			emit_signal("action_executed",
				"%s powers up! [+%d ATK next attacks]" % [e.enemy_name, intent.value])

		"buff_ally":
			var alive := enemies.filter(func(x: EnemyData) -> bool: return not x.is_dead and x != e)
			if not alive.is_empty():
				var ally: EnemyData = alive[randi() % alive.size()]
				ally.temp_attack_bonus += intent.value
				emit_signal("action_executed",
					"%s buffs %s [+%d ATK]" % [e.enemy_name, ally.enemy_name, intent.value])

		"recover":
			e.hp = mini(e.hp + intent.value, e.max_hp)
			emit_signal("action_executed",
				"%s recovers [+%d HP]" % [e.enemy_name, intent.value])

func _resolve_intent_target(intent: IntentData) -> BotData:
	var alive: Array = bots.filter(func(b: BotData) -> bool: return not b.is_dead)
	if alive.is_empty():
		return null
	match intent.target_resolution:
		"weakest":
			var w: BotData = alive[0]
			for b: BotData in alive:
				if b.current_hp < w.current_hp:
					w = b
			return w
		_:
			return alive[randi() % alive.size()]

func _weakest_bot(exclude: BotData) -> BotData:
	var alive: Array = bots.filter(func(b: BotData) -> bool: return not b.is_dead and b != exclude)
	if alive.is_empty():
		return null
	var w: BotData = alive[0]
	for b: BotData in alive:
		if b.current_hp < w.current_hp:
			w = b
	return w

func _check_battle_over() -> bool:
	var all_bots_dead := bots.all(func(b: BotData) -> bool: return b.is_dead)
	var all_enemies_dead := enemies.all(func(e: EnemyData) -> bool: return e.is_dead)
	if all_bots_dead:
		state = State.BATTLE_OVER
		emit_signal("battle_over", false)
		return true
	if all_enemies_dead:
		state = State.BATTLE_OVER
		emit_signal("battle_over", true)
		return true
	return false

func alive_bots() -> Array:
	return bots.filter(func(b: BotData) -> bool: return not b.is_dead)

func alive_enemies() -> Array:
	return enemies.filter(func(e: EnemyData) -> bool: return not e.is_dead)
