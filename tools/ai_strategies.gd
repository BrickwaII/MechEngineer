class_name AIStrategies extends Object
# Three player-side strategies for Monte Carlo simulation.
# Each returns assignments: Dictionary  (bot.id -> { skill, target })

static func assign(bots: Array, enemies: Array,
		energy: int, strategy: String) -> Dictionary:
	match strategy:
		"aggressive": return _aggressive(bots, enemies, energy)
		"smart":      return _smart(bots, enemies, energy)
		_:            return _random(bots, enemies, energy)

# ── RANDOM — picks any affordable skill for each bot in random order ─────────

static func _random(bots: Array, enemies: Array, energy: int) -> Dictionary:
	var asgn  := {}
	var rem   := energy
	var order := bots.duplicate()
	order.shuffle()

	for bot: BotData in order:
		if rem <= 0: break
		var pool: Array = []
		for arr: Array in bot.skill_slots.values():
			for s: SkillData in arr:
				if s.energy_cost <= rem:
					pool.append(s)
		if pool.is_empty(): continue

		var skill: SkillData = pool[randi() % pool.size()]
		asgn[bot.id] = { "skill": skill, "target": _pick_target(skill, bot, bots, enemies) }
		rem -= skill.energy_cost

	return asgn

# ── AGGRESSIVE — attack only, highest-damage skill, lowest-HP target ─────────

static func _aggressive(bots: Array, enemies: Array, energy: int) -> Dictionary:
	var asgn := {}
	var rem  := energy
	var sorted_bots := bots.duplicate()
	sorted_bots.sort_custom(func(a: BotData, b: BotData) -> bool: return a.speed > b.speed)

	for bot: BotData in sorted_bots:
		if rem <= 0: break
		var best_skill: SkillData = null
		var best_dmg := 0.0
		var weakest := _weakest_enemy(enemies)
		if weakest == null: break

		for s: SkillData in bot.skill_slots.get("attack", []):
			if s.energy_cost > rem: continue
			var est := _estimate_damage(bot, s, weakest, enemies)
			if est > best_dmg:
				best_dmg  = est
				best_skill = s

		if best_skill == null: continue
		asgn[bot.id] = { "skill": best_skill, "target": weakest }
		rem -= best_skill.energy_cost

	return asgn

# ── SMART — contextual decisions: defend if near death, attack wisely ─────────

static func _smart(bots: Array, enemies: Array, energy: int) -> Dictionary:
	var asgn := {}
	var rem  := energy

	# First identify bots that should defend (< 30% HP and defend is available)
	for bot: BotData in bots:
		if rem <= 0: break
		var hp_pct := float(bot.current_hp) / float(bot.max_hp)
		if hp_pct >= 0.30: continue
		var s := _cheapest_in(bot.skill_slots.get("defend", []), rem)
		if s:
			asgn[bot.id] = { "skill": s, "target": null }
			rem -= s.energy_cost

	# Next, assign attacks / support for remaining bots
	var sorted := bots.duplicate()
	sorted.sort_custom(func(a: BotData, b: BotData) -> bool: return a.speed > b.speed)

	for bot: BotData in sorted:
		if asgn.has(bot.id) or rem <= 0: continue
		var weakest := _weakest_enemy(enemies)
		if weakest == null: break

		# If charged, use the strongest available attack
		var atk_skill: SkillData
		if bot.charge_state.is_active():
			atk_skill = _highest_mult_attack(bot, rem)
		else:
			# Prefer Power Shot → Standard Attack → any attack
			atk_skill = _named_skill(bot, "attack", "Power Shot", rem)
			if atk_skill == null:
				atk_skill = _named_skill(bot, "attack", "Standard Attack", rem)
			if atk_skill == null:
				atk_skill = _cheapest_in(bot.skill_slots.get("attack", []), rem)

		if atk_skill:
			asgn[bot.id] = { "skill": atk_skill, "target": weakest }
			rem -= atk_skill.energy_cost
			continue

		# No attack fits — try a cheap support
		var sup := _cheapest_in(bot.skill_slots.get("support", []), rem)
		if sup:
			var sup_target: Variant = _pick_target(sup, bot, bots, enemies)
			asgn[bot.id] = { "skill": sup, "target": sup_target }
			rem -= sup.energy_cost

	return asgn

# ── Shared helpers ────────────────────────────────────────────────────────────

static func _pick_target(skill: SkillData, self_bot: BotData,
		bots: Array, enemies: Array) -> Variant:
	match skill.target_type:
		"single_enemy":
			return _weakest_enemy(enemies)
		"single_ally":
			# Heals go to lowest-HP ally; buffs go to highest-ATK ally
			var alive := bots.filter(func(b: BotData) -> bool:
				return not b.is_dead and b != self_bot)
			if alive.is_empty(): return null
			if skill.effect_type == "heal":
				return alive.reduce(func(best: BotData, b: BotData) -> BotData:
					return b if b.current_hp < best.current_hp else best)
			return alive.reduce(func(best: BotData, b: BotData) -> BotData:
				return b if b.attack > best.attack else best)
		_:
			return null  # all_enemies / all_allies / self / random_enemy

static func _weakest_enemy(enemies: Array) -> EnemyData:
	var alive := enemies.filter(func(e: EnemyData) -> bool: return not e.is_dead)
	if alive.is_empty(): return null
	return alive.reduce(func(w: EnemyData, e: EnemyData) -> EnemyData:
		return e if e.hp < w.hp else w)

static func _cheapest_in(skills: Array, budget: int) -> SkillData:
	var best: SkillData = null
	for s: SkillData in skills:
		if s.energy_cost <= budget:
			if best == null or s.energy_cost < best.energy_cost:
				best = s
	return best

static func _named_skill(bot: BotData, cmd: String,
		name: String, budget: int) -> SkillData:
	for s: SkillData in bot.skill_slots.get(cmd, []):
		if s.skill_name == name and s.energy_cost <= budget:
			return s
	return null

static func _highest_mult_attack(bot: BotData, budget: int) -> SkillData:
	var best: SkillData = null
	for s: SkillData in bot.skill_slots.get("attack", []):
		if s.energy_cost > budget: continue
		if best == null or s.multiplier > best.multiplier:
			best = s
	return best

static func _estimate_damage(bot: BotData, skill: SkillData,
		primary_target: EnemyData, all_enemies: Array) -> float:
	match skill.target_type:
		"all_enemies":
			var total := 0.0
			for e: EnemyData in all_enemies:
				if not e.is_dead:
					total += DamageCalculator.calculate_attack(bot, skill, e)
			return total
		"random_enemy":
			var alive_count := all_enemies.filter(
				func(e: EnemyData) -> bool: return not e.is_dead).size()
			var dmg_each := float(DamageCalculator.calculate_attack(bot, skill, primary_target))
			var avg_hits := (skill.hit_count_min + skill.hit_count_max) * 0.5
			return dmg_each * avg_hits
		_:
			return float(DamageCalculator.calculate_attack(bot, skill, primary_target))
