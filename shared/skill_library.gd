class_name CombatSkillLibrary extends Object

# Returns a Dictionary[String, SkillData] of all 14 prototype skills.
static func make() -> Dictionary:
	var d: Dictionary = {
		# ── Attack ──────────────────────────────────────────────────────────
		"standard_attack":  _atk("Standard Attack",  1, 1.00, "single_enemy",
				[], 1, 1),
		"power_shot":       _atk("Power Shot",        2, 1.50, "single_enemy",
				["methodical"], 1, 1),
		"spread_shot":      _atk("Spread Shot",       2, 0.75, "all_enemies",
				[], 1, 1),
		"frenzy":           _frenzy(),
		"crippling_shot":   _crippling_shot(),

		# ── Defend ──────────────────────────────────────────────────────────
		"standard_defend":  _def("Standard Defend",   1, 1.0, "self",  []),
		"counter_stance":   _def("Counter Stance",    2, 1.0, "self",
				["responding-to-threat"]),
		"bulwark":          _def("Bulwark",            2, 1.0, "self",
				["buffing-ally"]),

		# ── Support ─────────────────────────────────────────────────────────
		"standard_support": _sup("Standard Support",  1, "all_allies",   2.0, "buff",
				[]),
		"battle_cry":       _sup("Battle Cry",         2, "single_ally",  4.0, "buff",
				[]),
		"medic_protocol":   _sup("Medic Protocol",     2, "single_ally",  6.0, "heal",
				["responding-to-threat"]),

		# ── Charge ──────────────────────────────────────────────────────────
		"standard_charge":  _chg("Standard Charge",   1, 2.0, false),
		"overload":         _chg("Overload",           2, 3.0, true),
		"team_charge":      _team_charge(),
	}
	# Add descriptions
	(d["standard_attack"]  as SkillData).description = "Strike one enemy for ATK × 1.0 dmg."
	(d["power_shot"]       as SkillData).description = "Focused shot: ATK × 1.5 dmg to one enemy."
	(d["spread_shot"]      as SkillData).description = "Fire at all enemies for ATK × 0.75 dmg each."
	(d["frenzy"]           as SkillData).description = "2 rapid strikes at a random enemy, each at full ATK."
	(d["crippling_shot"]   as SkillData).description = "Attack one enemy and reduce their ATK by 2 this round."
	(d["standard_defend"]  as SkillData).description = "Gain DEF × 1.0 defense bonus this round."
	(d["counter_stance"]   as SkillData).description = "Gain DEF × 1.0 bonus; doubles when responding to a threat."
	(d["bulwark"]          as SkillData).description = "Gain DEF × 1.0 bonus and share half with your weakest ally."
	(d["standard_support"] as SkillData).description = "Give all allies +2 ATK and +2 DEF this round."
	(d["battle_cry"]       as SkillData).description = "Surge one ally with +4 ATK this round."
	(d["medic_protocol"]   as SkillData).description = "Restore 6 HP to a damaged ally."
	(d["standard_charge"]  as SkillData).description = "Charge up: next ATK or DEF is × 2."
	(d["overload"]         as SkillData).description = "Extreme charge (× 3 next ATK) at cost of 3 self-damage."
	(d["team_charge"]      as SkillData).description = "Charge self and grant +2 ATK to one ally."
	return d

# ── Private helpers ──────────────────────────────────────────────────────────

static func _s(name: String, cmd: String, cost: int, mult: float,
		eff: String, val: float, tgt: String, tags: Array[String]) -> SkillData:
	var s := SkillData.new()
	s.skill_name = name
	s.command_type = cmd
	s.energy_cost = cost
	s.multiplier = mult
	s.effect_type = eff
	s.effect_value = val
	s.target_type = tgt
	s.tags = ["dealing-damage"] + tags if cmd == "attack" else tags
	return s

static func _atk(name: String, cost: int, mult: float, tgt: String,
		extra_tags: Array[String], hit_min: int, hit_max: int) -> SkillData:
	var s := _s(name, "attack", cost, mult, "damage", 0.0, tgt, extra_tags)
	s.hit_count_min = hit_min
	s.hit_count_max = hit_max
	return s

static func _def(name: String, cost: int, mult: float, tgt: String,
		extra_tags: Array[String]) -> SkillData:
	var s := SkillData.new()
	s.skill_name = name
	s.command_type = "defend"
	s.energy_cost = cost
	s.multiplier = mult
	s.effect_type = "defend"
	s.target_type = tgt
	s.tags = ["absorbing-damage"] + extra_tags
	return s

static func _sup(name: String, cost: int, tgt: String, val: float,
		eff: String, extra_tags: Array[String]) -> SkillData:
	var s := SkillData.new()
	s.skill_name = name
	s.command_type = "support"
	s.energy_cost = cost
	s.effect_type = eff
	s.effect_value = val
	s.target_type = tgt
	s.tags = ["buffing-ally"] + extra_tags
	return s

static func _chg(name: String, cost: int, charge_mult: float,
		is_overload: bool) -> SkillData:
	var s := SkillData.new()
	s.skill_name = name
	s.command_type = "charge"
	s.energy_cost = cost
	s.effect_type = "charge"
	s.effect_value = charge_mult
	s.target_type = "self"
	s.tags = ["planning-ahead"]
	if is_overload:
		s.tags.append("reckless")
	return s

static func _frenzy() -> SkillData:
	var s := _atk("Frenzy", 2, 1.0, "random_enemy", ["reckless"], 2, 2)
	return s

static func _crippling_shot() -> SkillData:
	# effect_value = -2 means apply -2 attack debuff to target next round
	return _s("Crippling Shot", "attack", 2, 1.0, "damage", -2.0, "single_enemy",
			["methodical"])

static func _team_charge() -> SkillData:
	# Charges self AND gives +2 ATK to one ally
	var s := SkillData.new()
	s.skill_name = "Team Charge"
	s.command_type = "charge"
	s.energy_cost = 2
	s.effect_type = "charge"
	s.effect_value = 2.0  # charge multiplier for self
	s.target_type = "single_ally"  # the ally who gets +2 ATK
	s.tags = ["planning-ahead", "buffing-ally"]
	return s
