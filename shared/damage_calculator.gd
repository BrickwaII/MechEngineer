class_name DamageCalculator extends RefCounted

# Outgoing attack from a bot using a skill against a target.
static func calculate_attack(attacker: BotData, skill: SkillData, target) -> int:
	var base_damage: float = attacker.attack * skill.multiplier

	if attacker.charge_state.is_active():
		base_damage *= attacker.charge_state.get_multiplier()

	var final_damage := base_damage
	if not skill.armor_piercing:
		final_damage = maxf(0.0, base_damage - target.defense)

	return int(final_damage)

# Defense bonus a bot gains from using a Defend skill this round.
static func calculate_defend(bot: BotData, skill: SkillData) -> int:
	return int(bot.defense * skill.multiplier)

# Incoming damage from an enemy intent, reduced by target's assigned Defend skill.
static func calculate_incoming_damage(
		enemy: EnemyData,
		intent: IntentData,
		target_bot: BotData,
		target_skill: SkillData = null) -> int:
	var base: float = intent.value + enemy.temp_attack_bonus

	if target_skill != null and target_skill.command_type == "defend":
		var defend_bonus := calculate_defend(target_bot, target_skill)
		base = maxf(0.0, base - defend_bonus)

	return int(base)
