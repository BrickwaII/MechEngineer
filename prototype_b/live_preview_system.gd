class_name LivePreviewSystem extends RefCounted

# Recalculates all damage previews and returns structured results.
# Returns { "outgoing": { enemy_id -> int }, "incoming": { bot_id -> int },
#           "assignment_previews": { bot_id -> int } }
static func compute(bots: Array, enemies: Array, assignments: Dictionary) -> Dictionary:
	var out_dmg: Dictionary = {}   # enemy_id -> total incoming damage this round
	var in_dmg: Dictionary = {}    # bot_id   -> total incoming damage from enemies

	_compute_outgoing(bots, enemies, assignments, out_dmg)
	_compute_incoming(bots, enemies, assignments, in_dmg)

	# Build per-assignment preview damage (used by queue UI)
	var assign_prev: Dictionary = {}
	for bot_id in assignments:
		var a: Dictionary = assignments[bot_id]
		var skill: SkillData = a["skill"]
		if skill.effect_type == "damage":
			var target = a.get("target", null)
			if target is EnemyData:
				assign_prev[bot_id] = out_dmg.get(target.id, 0)

	return {
		"outgoing":            out_dmg,
		"incoming":            in_dmg,
		"assignment_previews": assign_prev,
	}

static func _compute_outgoing(bots: Array, enemies: Array,
		assignments: Dictionary, out_dmg: Dictionary) -> void:
	for bot: BotData in bots:
		if not assignments.has(bot.id):
			continue
		var a: Dictionary = assignments[bot.id]
		var skill: SkillData = a["skill"]
		if skill.effect_type != "damage":
			continue

		match skill.target_type:
			"all_enemies":
				for e: EnemyData in enemies:
					if e.is_dead:
						continue
					var dmg := DamageCalculator.calculate_attack(bot, skill, e)
					out_dmg[e.id] = out_dmg.get(e.id, 0) + dmg

			"random_enemy":
				# Show average expected damage across living enemies
				var alive_enemies := enemies.filter(func(e: EnemyData) -> bool: return not e.is_dead)
				if alive_enemies.is_empty():
					continue
				var hit_avg := (skill.hit_count_min + skill.hit_count_max) * 0.5
				var dmg_per_hit := DamageCalculator.calculate_attack(bot, skill, alive_enemies[0])
				var total := int(dmg_per_hit * hit_avg)
				# Distribute evenly for preview
				for e: EnemyData in alive_enemies:
					out_dmg[e.id] = out_dmg.get(e.id, 0) + int(total / alive_enemies.size())

			"single_enemy":
				var target = a.get("target", null)
				if target is EnemyData and not target.is_dead:
					var dmg := DamageCalculator.calculate_attack(bot, skill, target)
					out_dmg[target.id] = out_dmg.get(target.id, 0) + dmg

static func _compute_incoming(bots: Array, enemies: Array,
		assignments: Dictionary, in_dmg: Dictionary) -> void:
	for e: EnemyData in enemies:
		if e.is_dead or e.current_intent == null:
			continue
		var intent: IntentData = e.current_intent
		if intent.intent_type not in ["attack", "attack_weakest"]:
			continue

		var target_bot: BotData = _resolve_target(intent, bots)
		if target_bot == null:
			continue

		var target_assignment: Dictionary = assignments.get(target_bot.id, {})
		var target_skill: SkillData = target_assignment.get("skill", null)

		var dmg := DamageCalculator.calculate_incoming_damage(e, intent, target_bot, target_skill)
		in_dmg[target_bot.id] = in_dmg.get(target_bot.id, 0) + dmg

static func _resolve_target(intent: IntentData, bots: Array) -> BotData:
	var alive: Array = bots.filter(func(b: BotData) -> bool: return not b.is_dead)
	if alive.is_empty():
		return null

	match intent.target_resolution:
		"weakest":
			var weakest: BotData = alive[0]
			for b: BotData in alive:
				if b.current_hp < weakest.current_hp:
					weakest = b
			return weakest
		_:
			return alive[randi() % alive.size()]
