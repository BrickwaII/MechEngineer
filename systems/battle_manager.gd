extends Node
class_name BattleManager

signal attack_performed(attacker: BotData, target: BotData)

var allies: Array[BotData] = []
var enemies: Array[BotData] = []

var combat_log: RichTextLabel
var _log_entries: Array[String] = []

var ally_energy:  float = 0.0
var enemy_energy: float = 0.0

# Per-team regen boost: stacks increase multiplier, shared timer resets on each new stack
var ally_regen_count:  int   = 0
var ally_regen_timer:  float = 0.0
var enemy_regen_count: int   = 0
var enemy_regen_timer: float = 0.0

var _battle_over_logged: bool = false

# ── Energy ───────────────────────────────────────────────────────────────────

func ally_max_energy() -> float:
	var total := 0
	for bot: BotData in allies:
		if not bot.is_dead:
			total += bot.energy_capacity
	return float(total)

func enemy_max_energy() -> float:
	var total := 0
	for bot: BotData in enemies:
		if not bot.is_dead:
			total += bot.energy_capacity
	return float(total)

func clamp_energy_to_max() -> void:
	ally_energy  = minf(ally_energy,  ally_max_energy())
	enemy_energy = minf(enemy_energy, enemy_max_energy())

func add_regen_boost(bot: BotData) -> void:
	if allies.has(bot):
		ally_regen_count += 1
		ally_regen_timer  = 3.0
	else:
		enemy_regen_count += 1
		enemy_regen_timer  = 3.0

func tick_regen_stacks(delta: float) -> void:
	if ally_regen_timer > 0.0:
		ally_regen_timer -= delta
		if ally_regen_timer <= 0.0:
			ally_regen_timer = 0.0
			ally_regen_count = 0
	if enemy_regen_timer > 0.0:
		enemy_regen_timer -= delta
		if enemy_regen_timer <= 0.0:
			enemy_regen_timer = 0.0
			enemy_regen_count = 0

func ally_regen_multiplier() -> float:
	return 1.0 + ally_regen_count * 0.25

func enemy_regen_multiplier() -> float:
	return 1.0 + enemy_regen_count * 0.25

func tick(delta: float) -> void:
	tick_regen_stacks(delta)
	var base_regen := 0.5 * delta
	ally_energy  = minf(ally_max_energy(),  ally_energy  + base_regen * ally_regen_multiplier())
	enemy_energy = minf(enemy_max_energy(), enemy_energy + base_regen * enemy_regen_multiplier())

func get_team_energy(bot: BotData) -> float:
	return ally_energy if allies.has(bot) else enemy_energy

func spend_energy(bot: BotData, cost: int) -> void:
	if allies.has(bot):
		ally_energy  = maxf(0.0, ally_energy  - float(cost))
	else:
		enemy_energy = maxf(0.0, enemy_energy - float(cost))

func min_energy_cost(bot: BotData) -> int:
	var min_cost := 999
	for arr: Array in bot.skill_slots.values():
		for skill: SkillData in arr:
			min_cost = mini(min_cost, skill.energy_cost)
	return 1 if min_cost == 999 else min_cost

func can_act_energy_wise(bot: BotData) -> bool:
	return get_team_energy(bot) >= float(min_energy_cost(bot))

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup_battle(log_ui: RichTextLabel) -> void:
	combat_log = log_ui
	_create_bots()
	ally_energy  = ally_max_energy()
	enemy_energy = enemy_max_energy()

func _create_bots() -> void:
	allies.clear()
	enemies.clear()
	allies.append_array([
		BotFactory.ally_alpha(),
		BotFactory.ally_beta(),
		BotFactory.ally_gamma(),
		BotFactory.ally_delta(),
	])
	enemies.append_array([
		BotFactory.enemy_x(),
		BotFactory.enemy_y(),
		BotFactory.enemy_z(),
	])

# ── Skill resolution ──────────────────────────────────────────────────────────

func _process_turn_with_skill(bot: BotData) -> void:
	if bot.assigned_skill == null:
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
				add_log("  %s destroyed!" % tgt.bot_name)
	elif target is BotData and not (target as BotData).is_dead:
		var tgt: BotData = target as BotData
		var dmg := DamageCalculator.calculate_attack(attacker, skill, tgt)
		var actual := tgt.take_damage(dmg)
		attack_performed.emit(attacker, tgt)
		add_log("%s%s: %s → %s [%d dmg]" % [attacker.bot_name, charge_tag, skill.skill_name, tgt.bot_name, actual])
		if tgt.is_dead:
			add_log("  %s destroyed!" % tgt.bot_name)
		if skill.skill_name == "Crippling Shot":
			tgt.temp_attack_bonus += int(skill.effect_value)
			add_log("  ↳ Crippling Shot: %s ATK reduced by %d" % [tgt.bot_name, -int(skill.effect_value)])
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
				add_log("  %s destroyed!" % tgt.bot_name)
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
	if skill.skill_name == "Bulwark":
		var weakest := _get_weakest_ally(bot)
		if weakest != null:
			var share := bonus / 2
			weakest.temp_defense_bonus += share
			add_log("  ↳ Bulwark shares +%d DEF → %s" % [share, weakest.bot_name])

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
			bot.charge_state.tier = ChargeState.Tier.OVERLOADED
			bot.take_damage(3)
			add_log("%s: Overload [OVERLOADED ×3, took 3 self-dmg]" % bot.bot_name)
		"Team Charge":
			bot.charge_state.tier = ChargeState.Tier.CHARGED
			if target is BotData and not (target as BotData).is_dead:
				var tgt: BotData = target as BotData
				tgt.temp_attack_bonus += 2
				add_log("%s: Team Charge [CHARGED, +2 ATK → %s]" % [bot.bot_name, tgt.bot_name])
			else:
				add_log("%s: Team Charge [CHARGED]" % bot.bot_name)
		_:
			bot.charge_state.tier = ChargeState.Tier.CHARGED
			add_log("%s: %s [CHARGED ×2]" % [bot.bot_name, skill.skill_name])

# ── Command resolution (used by enemies and legacy callers) ───────────────────

func resolve_for_bot(bot: BotData, cmd: BotData.Command) -> void:
	match cmd:
		BotData.Command.ATTACK:  _do_attack(bot)
		BotData.Command.DEFEND:  _do_defend(bot)
		BotData.Command.SUPPORT: _do_support(bot)
		BotData.Command.CHARGE:  _do_charge(bot)

func resolve_for_bot_with_skill(bot: BotData, skill: SkillData, target: Variant) -> void:
	bot.assigned_skill = skill
	bot.assigned_target = target
	_process_turn_with_skill(bot)

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
	bot.charge_state.tier = ChargeState.Tier.CHARGED
	add_log("%s charges up! (next ATK ×2 or next DEF ×2)" % bot.bot_name)

# ── Helpers ───────────────────────────────────────────────────────────────────

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

func _get_weakest_ally(exclude: BotData) -> BotData:
	var team := allies if allies.has(exclude) else enemies
	var alive: Array[BotData] = []
	for b: BotData in team:
		if b != exclude and not b.is_dead:
			alive.append(b)
	if alive.is_empty():
		return null
	var w: BotData = alive[0]
	for b: BotData in alive:
		if b.current_hp < w.current_hp:
			w = b
	return w

# Executes one hit of a random-target multi-hit skill. Returns {target, actual}.
# Charge state is NOT reset here — caller resets it after all hits.
func execute_single_hit(attacker: BotData, skill: SkillData) -> Dictionary:
	var pool := get_alive_enemies() if allies.has(attacker) else get_alive_allies()
	if pool.is_empty():
		return {}
	var tgt: BotData = pool.pick_random()
	var dmg  := DamageCalculator.calculate_attack(attacker, skill, tgt)
	var actual := tgt.take_damage(dmg)
	if tgt.is_dead:
		add_log("  %s destroyed!" % tgt.bot_name)
	return {"target": tgt, "actual": actual}

func add_log(text: String) -> void:
	_log_entries.insert(0, text)
	combat_log.clear()
	combat_log.append_text("\n".join(_log_entries))

func check_battle_over() -> bool:
	if get_alive_allies().is_empty():
		if not _battle_over_logged:
			_battle_over_logged = true
			add_log("★ ENEMIES WIN ★")
		return true
	if get_alive_enemies().is_empty():
		if not _battle_over_logged:
			_battle_over_logged = true
			add_log("★ ALLIES WIN ★")
		return true
	return false

func reset_battle() -> void:
	combat_log.clear()
	_log_entries.clear()
	_battle_over_logged = false
	ally_regen_count  = 0
	ally_regen_timer  = 0.0
	enemy_regen_count = 0
	enemy_regen_timer = 0.0
	_create_bots()
	ally_energy  = ally_max_energy()
	enemy_energy = enemy_max_energy()
	add_log("Battle Reset")
