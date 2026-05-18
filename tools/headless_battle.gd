class_name HeadlessBattle extends RefCounted
# Synchronous, signal-free battle simulation used by MonteCarlo.
# Mirrors SimBattle resolution exactly: defend → attack (speed desc) → enemies.

const MAX_ROUNDS: int = 30

class Result:
	var won: bool = false
	var rounds: int = 0
	var timed_out: bool = false
	var player_hp_left: int = 0   # sum of surviving bots' HP
	var enemy_hp_left: int = 0    # sum of surviving enemies' HP
	var bot_survived: Dictionary = {}  # bot.id -> bool
	var first_enemy_killed: String = ""

static func run(bot_tpls: Array, enemy_tpls: Array,
		strategy: String, energy_budget: int = 4) -> Result:
	var bots: Array    = bot_tpls.map(func(t): return _copy_bot(t))
	var enemies: Array = enemy_tpls.map(func(t): return _copy_enemy(t))
	var res := Result.new()
	var battle_ended := false

	for round in range(MAX_ROUNDS):
		res.rounds = round + 1

		for b: BotData in bots:    b.reset_round_bonuses()
		for e: EnemyData in enemies: e.temp_attack_bonus = 0

		var alive_b := _alive(bots)
		var alive_e := _alive(enemies)
		if alive_b.is_empty() or alive_e.is_empty():
			battle_ended = true
			break

		var asgn: Dictionary = AIStrategies.assign(alive_b, alive_e, energy_budget, strategy)

		# Phase A: defenders first
		for bot: BotData in alive_b:
			if asgn.has(bot.id) and _cmd(asgn, bot.id) == "defend":
				_exec_bot(bot, asgn[bot.id], bots, enemies)

		# Phase B: attackers/support/charge in speed order
		var others := alive_b.filter(func(b: BotData) -> bool:
			return asgn.has(b.id) and _cmd(asgn, b.id) != "defend")
		others.sort_custom(func(a: BotData, b: BotData) -> bool: return a.speed > b.speed)
		for bot: BotData in others:
			_exec_bot(bot, asgn[bot.id], bots, enemies)

		if _alive(enemies).is_empty():
			res.won = true
			battle_ended = true
			break
		if _alive(bots).is_empty():
			battle_ended = true
			break

		# Phase C: enemy intents in speed order
		var sorted_e := _alive(enemies)
		sorted_e.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.speed > b.speed)
		for e: EnemyData in sorted_e:
			_exec_enemy(e, bots, enemies)

		if res.first_enemy_killed == "":
			for e: EnemyData in enemies:
				if e.is_dead: res.first_enemy_killed = e.id; break

		if _alive(bots).is_empty():
			battle_ended = true
			break

		for e: EnemyData in enemies:
			if not e.is_dead: e.advance_intent()

	if not battle_ended:
		res.timed_out = true

	res.player_hp_left = bots.reduce(
		func(s: int, b: BotData) -> int: return s + (b.current_hp if not b.is_dead else 0), 0)
	res.enemy_hp_left = enemies.reduce(
		func(s: int, e: EnemyData) -> int: return s + (e.hp if not e.is_dead else 0), 0)
	for b: BotData in bots:
		res.bot_survived[b.id] = not b.is_dead
	return res

# ── Action execution ─────────────────────────────────────────────────────────

static func _exec_bot(bot: BotData, a: Dictionary, bots: Array, enemies: Array) -> void:
	if bot.is_dead: return
	var skill: SkillData = a["skill"]
	var target: Variant  = a.get("target", null)
	match skill.command_type:
		"attack":  _do_attack(bot, skill, target, enemies)
		"defend":  _do_defend(bot, skill, bots)
		"support": _do_support(bot, skill, target, bots)
		"charge":  _do_charge(bot, skill, target, bots)

static func _do_attack(bot: BotData, skill: SkillData, target, enemies: Array) -> void:
	match skill.target_type:
		"single_enemy":
			if target is EnemyData and not target.is_dead:
				var dmg := DamageCalculator.calculate_attack(bot, skill, target)
				target.take_damage(dmg)
				if skill.skill_name == "Crippling Shot":
					target.temp_attack_bonus += int(skill.effect_value)
		"all_enemies":
			for e: EnemyData in enemies:
				if not e.is_dead:
					e.take_damage(DamageCalculator.calculate_attack(bot, skill, e))
		"random_enemy":
			var alive := _alive(enemies)
			if not alive.is_empty():
				var hits := randi_range(skill.hit_count_min, skill.hit_count_max)
				for _i in range(hits):
					var t: EnemyData = alive[randi() % alive.size()] as EnemyData
					t.take_damage(DamageCalculator.calculate_attack(bot, skill, t))
	bot.charge_state.reset()

static func _do_defend(bot: BotData, skill: SkillData, bots: Array) -> void:
	var bonus := DamageCalculator.calculate_defend(bot, skill)
	if bot.charge_state.is_active():
		bonus = int(bonus * bot.charge_state.get_multiplier())
		bot.charge_state.reset()
	bot.temp_defense_bonus += bonus
	if skill.skill_name == "Bulwark":
		var w := _weakest_excluding(bots, bot)
		if w: (w as BotData).temp_defense_bonus += bonus / 2

static func _do_support(bot: BotData, skill: SkillData, target, bots: Array) -> void:
	var val := int(skill.effect_value)
	match skill.effect_type:
		"buff":
			if skill.target_type == "all_allies":
				for b: BotData in bots:
					if b != bot and not b.is_dead:
						b.temp_attack_bonus  += val
						b.temp_defense_bonus += val
			elif target is BotData and not target.is_dead:
				target.temp_attack_bonus += val
		"heal":
			if target is BotData and not target.is_dead:
				target.current_hp = mini(target.current_hp + val, target.max_hp)

static func _do_charge(bot: BotData, skill: SkillData, target, bots: Array) -> void:
	match skill.skill_name:
		"Overload":
			bot.charge_state.tier = ChargeState.Tier.OVERLOADED
			bot.take_damage(3)
		"Team Charge":
			bot.charge_state.tier = ChargeState.Tier.CHARGED
			if target is BotData and not target.is_dead:
				target.temp_attack_bonus += 2
		_:
			bot.charge_state.tier = ChargeState.Tier.CHARGED

static func _exec_enemy(e: EnemyData, bots: Array, enemies: Array) -> void:
	if e.current_intent == null: return
	var intent: IntentData = e.current_intent
	match intent.intent_type:
		"attack", "attack_weakest":
			var target := _bot_target(intent, bots)
			if target:
				var raw := intent.value + e.temp_attack_bonus
				var net := maxi(0, raw - target.defense - target.temp_defense_bonus)
				target.take_damage(net)
		"power_up":
			e.temp_attack_bonus += intent.value
		"buff_ally":
			var others := enemies.filter(func(x: EnemyData) -> bool: return not x.is_dead and x != e)
			if not others.is_empty():
				(others[randi() % others.size()] as EnemyData).temp_attack_bonus += intent.value
		"recover":
			e.hp = mini(e.hp + intent.value, e.max_hp)

# ── Helpers ──────────────────────────────────────────────────────────────────

static func _alive(units: Array) -> Array:
	return units.filter(func(u) -> bool:
		return u is BotData and not (u as BotData).is_dead \
		    or u is EnemyData and not (u as EnemyData).is_dead)

static func _cmd(asgn: Dictionary, bot_id: String) -> String:
	return (asgn[bot_id]["skill"] as SkillData).command_type

static func _bot_target(intent: IntentData, bots: Array) -> BotData:
	var alive := _alive(bots)
	if alive.is_empty(): return null
	if intent.target_resolution == "weakest":
		var w: BotData = alive[0] as BotData
		for b: BotData in alive:
			if b.current_hp < w.current_hp: w = b
		return w
	return alive[randi() % alive.size()] as BotData

static func _weakest_excluding(units: Array, exclude: Object) -> Object:
	var alive := units.filter(func(u: Object) -> bool:
		if u is BotData: return not (u as BotData).is_dead and u != exclude
		if u is EnemyData: return not (u as EnemyData).is_dead and u != exclude
		return false)
	if alive.is_empty(): return null
	var w: Object = alive[0]
	for u: Object in alive:
		var uhp := (u as BotData).current_hp if u is BotData else (u as EnemyData).hp
		var whp := (w as BotData).current_hp if w is BotData else (w as EnemyData).hp
		if uhp < whp: w = u
	return w

static func _copy_bot(t: BotData) -> BotData:
	var b := BotData.new()
	b.id          = t.id
	b.bot_name    = t.bot_name
	b.max_hp      = t.max_hp
	b.attack      = t.attack
	b.defense     = t.defense
	b.speed       = t.speed
	b.color       = t.color
	b.generation  = t.generation
	b.skill_slots = t.skill_slots  # SkillData is immutable during battle
	b.initialize()
	return b

static func _copy_enemy(t: EnemyData) -> EnemyData:
	var e := EnemyData.new()
	e.id                    = t.id
	e.enemy_name            = t.enemy_name
	e.personality_archetype = t.personality_archetype
	e.max_hp      = t.max_hp
	e.attack      = t.attack
	e.defense     = t.defense
	e.speed       = t.speed
	e.intent_loop = t.intent_loop  # IntentData entries are read-only
	e.initialize()
	return e
