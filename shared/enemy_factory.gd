class_name EnemyFactory extends Object

static func bruiser() -> EnemyData:
	var e := EnemyData.new()
	e.id = "bruiser"
	e.enemy_name = "BRUISER"
	e.personality_archetype = "bruiser"
	e.max_hp = 28
	e.attack = 8
	e.defense = 2
	e.speed = 5
	e.intent_loop = [
		IntentData.make("attack", 8, "random"),
		IntentData.make("attack", 8, "random"),
		IntentData.make("defend", 4, "self"),
	]
	e.initialize()
	return e

static func tactician() -> EnemyData:
	var e := EnemyData.new()
	e.id = "tactician"
	e.enemy_name = "TACTICIAN"
	e.personality_archetype = "tactician"
	e.max_hp = 22
	e.attack = 10
	e.defense = 4
	e.speed = 4
	e.intent_loop = [
		IntentData.make("defend",   5, "self"),
		IntentData.make("power_up", 4, "self"),   # +4 ATK next actions
		IntentData.make("attack",  10, "random"),
		IntentData.make("attack",  10, "random"),
	]
	e.initialize()
	return e

static func berserker() -> EnemyData:
	var e := EnemyData.new()
	e.id = "berserker"
	e.enemy_name = "BERSERKER"
	e.personality_archetype = "berserker"
	e.max_hp = 32
	e.attack = 12
	e.defense = 0
	e.speed = 7
	e.intent_loop = [
		IntentData.make("attack",  12, "random"),
		IntentData.make("attack",  12, "random"),
		IntentData.make("attack",  12, "random"),
		IntentData.make("recover",  8, "self"),
	]
	e.initialize()
	return e

static func supporter() -> EnemyData:
	var e := EnemyData.new()
	e.id = "supporter"
	e.enemy_name = "SUPPORTER"
	e.personality_archetype = "supporter"
	e.max_hp = 24
	e.attack = 7
	e.defense = 2
	e.speed = 5
	e.intent_loop = [
		IntentData.make("buff_ally", 3, "random"),
		IntentData.make("defend",    4, "self"),
		IntentData.make("attack",    7, "random"),
	]
	e.initialize()
	return e

static func predator() -> EnemyData:
	var e := EnemyData.new()
	e.id = "predator"
	e.enemy_name = "PREDATOR"
	e.personality_archetype = "predator"
	e.max_hp = 30
	e.attack = 9
	e.defense = 1
	e.speed = 6
	e.intent_loop = [
		IntentData.make("attack_weakest", 9, "weakest"),
		IntentData.make("attack_weakest", 9, "weakest"),
		IntentData.make("defend",         3, "self"),
	]
	e.initialize()
	return e
