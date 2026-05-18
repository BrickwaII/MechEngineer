class_name BotFactory extends Object

static func ally_alpha() -> BotData:
	var lib := CombatSkillLibrary.make()
	var b := BotData.new()
	b.id       = "ally_alpha"
	b.bot_name = "ALLY_ALPHA"
	b.max_hp   = randi_range(22, 38)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(0.25, 0.55, 1.0)
	b.initialize()
	b.skill_slots["attack"]  = [lib["standard_attack"], lib["power_shot"]]
	b.skill_slots["defend"]  = [lib["standard_defend"]]
	b.skill_slots["support"] = [lib["standard_support"]]
	b.skill_slots["charge"]  = [lib["standard_charge"]]
	return b

static func ally_beta() -> BotData:
	var lib := CombatSkillLibrary.make()
	var b := BotData.new()
	b.id       = "ally_beta"
	b.bot_name = "ALLY_BETA"
	b.max_hp   = randi_range(16, 28)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(0.25, 0.85, 0.45)
	b.initialize()
	b.skill_slots["attack"]  = [lib["standard_attack"], lib["frenzy"]]
	b.skill_slots["defend"]  = [lib["standard_defend"]]
	b.skill_slots["support"] = [lib["battle_cry"]]
	b.skill_slots["charge"]  = [lib["standard_charge"]]
	return b

static func ally_gamma() -> BotData:
	var lib := CombatSkillLibrary.make()
	var b := BotData.new()
	b.id       = "ally_gamma"
	b.bot_name = "ALLY_GAMMA"
	b.max_hp   = randi_range(20, 32)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(0.8, 0.3, 1.0)
	b.initialize()
	b.skill_slots["attack"]  = [lib["standard_attack"], lib["crippling_shot"]]
	b.skill_slots["defend"]  = [lib["standard_defend"], lib["bulwark"]]
	b.skill_slots["support"] = [lib["medic_protocol"]]
	b.skill_slots["charge"]  = [lib["standard_charge"]]
	return b

static func ally_delta() -> BotData:
	var lib := CombatSkillLibrary.make()
	var b := BotData.new()
	b.id       = "ally_delta"
	b.bot_name = "ALLY_DELTA"
	b.max_hp   = randi_range(28, 42)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(0.15, 0.85, 0.85)
	b.initialize()
	b.skill_slots["attack"]  = [lib["standard_attack"], lib["spread_shot"]]
	b.skill_slots["defend"]  = [lib["standard_defend"], lib["bulwark"]]
	b.skill_slots["support"] = [lib["standard_support"]]
	b.skill_slots["charge"]  = [lib["standard_charge"], lib["team_charge"]]
	return b

static func enemy_x() -> BotData:
	var b := BotData.new()
	b.id       = "enemy_x"
	b.bot_name = "ENEMY_X"
	b.max_hp   = randi_range(18, 30)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(1.0, 0.3, 0.2)
	b.initialize()
	b.personality.personality_label = "Opportunist"
	return b

static func enemy_y() -> BotData:
	var b := BotData.new()
	b.id       = "enemy_y"
	b.bot_name = "ENEMY_Y"
	b.max_hp   = randi_range(14, 24)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(1.0, 0.65, 0.1)
	b.initialize()
	b.personality.personality_label = "Berserker"
	return b

static func enemy_z() -> BotData:
	var b := BotData.new()
	b.id       = "enemy_z"
	b.bot_name = "ENEMY_Z"
	b.max_hp   = randi_range(18, 28)
	b.attack   = randi_range(5, 10)
	b.defense  = randi_range(1, 4)
	b.speed    = randi_range(3, 8)
	b.color    = Color(0.9, 0.2, 0.7)
	b.initialize()
	b.personality.personality_label = "Predator"
	return b
