extends Node
class_name BattleManager

signal attack_performed(attacker: BotData, target: BotData)

var allies: Array[BotData] = []
var enemies: Array[BotData] = []

var turn_order: Array[BotData] = []
var current_turn_index := 0
var is_battle_over: bool = false

var combat_log: RichTextLabel
var turn_label: Label
var _log_entries: Array[String] = []

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

	var ally_1 := BotData.new()
	ally_1.bot_name = "ALLY_ALPHA"
	ally_1.max_hp = 30
	ally_1.power = 5
	ally_1.speed = randi_range(5, 9)
	ally_1.color = Color(0.25, 0.55, 1.0)
	ally_1.initialize()

	var ally_2 := BotData.new()
	ally_2.bot_name = "ALLY_BETA"
	ally_2.max_hp = 20
	ally_2.power = 8
	ally_2.speed = randi_range(3, 7)
	ally_2.color = Color(0.25, 0.85, 0.45)
	ally_2.initialize()

	var ally_3 := BotData.new()
	ally_3.bot_name = "ALLY_GAMMA"
	ally_3.max_hp = 25
	ally_3.power = 6
	ally_3.speed = randi_range(4, 8)
	ally_3.color = Color(0.8, 0.3, 1.0)
	ally_3.initialize()

	var ally_4 := BotData.new()
	ally_4.bot_name = "ALLY_DELTA"
	ally_4.max_hp = 35
	ally_4.power = 3
	ally_4.speed = randi_range(2, 6)
	ally_4.color = Color(0.15, 0.85, 0.85)
	ally_4.initialize()

	var enemy_1 := BotData.new()
	enemy_1.bot_name = "ENEMY_X"
	enemy_1.max_hp = 25
	enemy_1.power = 4
	enemy_1.speed = randi_range(4, 8)
	enemy_1.color = Color(1.0, 0.3, 0.2)
	enemy_1.initialize()

	var enemy_2 := BotData.new()
	enemy_2.bot_name = "ENEMY_Y"
	enemy_2.max_hp = 18
	enemy_2.power = 6
	enemy_2.speed = randi_range(3, 7)
	enemy_2.color = Color(1.0, 0.65, 0.1)
	enemy_2.initialize()

	var enemy_3 := BotData.new()
	enemy_3.bot_name = "ENEMY_Z"
	enemy_3.max_hp = 22
	enemy_3.power = 7
	enemy_3.speed = randi_range(6, 10)
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
	turn_order.sort_custom(func(a: BotData, b: BotData) -> bool:
		var a_def: bool = a.command == BotData.Command.DEFEND
		var b_def: bool = b.command == BotData.Command.DEFEND
		if a_def != b_def:
			return a_def   # defenders always go first
		return a.speed > b.speed
	)

func next_turn() -> void:
	if check_battle_over():
		return

	if turn_order.is_empty():
		build_turn_order()

	var acting_bot := turn_order[current_turn_index]

	# Skip dead bots silently
	if acting_bot.is_dead:
		current_turn_index += 1
		if current_turn_index >= turn_order.size():
			_end_round()
			current_turn_index = 0
			build_turn_order()
		else:
			next_turn()
		return

	_process_turn(acting_bot)
	current_turn_index += 1

	# End the round immediately when the last bot has acted
	if current_turn_index >= turn_order.size():
		_end_round()
		current_turn_index = 0
		build_turn_order()

	update_turn_label()

# ── Round end ────────────────────────────────────────────────────────────────

func _end_round() -> void:
	for bot in allies + enemies:
		bot.temp_attack_bonus = 0
		bot.defend_bonus = 0
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
	var damage := attacker.power + attacker.temp_attack_bonus
	var charged := attacker.is_charged

	if charged:
		damage *= 2
		attacker.is_charged = false

	var actual := target.take_damage(damage)
	attack_performed.emit(attacker, target)

	var prefix := "[CHARGED] " if charged else ""
	if actual == 0:
		add_log("%s%s attacks %s — blocked! (defend absorbs all damage)" \
				% [prefix, attacker.bot_name, target.bot_name])
	else:
		add_log("%s%s attacks %s for %d damage. (%d HP remaining)" \
				% [prefix, attacker.bot_name, target.bot_name, actual, target.current_hp])

	if target.is_dead:
		add_log("%s was destroyed!" % target.bot_name)

func _do_defend(bot: BotData) -> void:
	var resistance := 4 if bot.is_charged else 2
	bot.is_charged = false
	bot.defend_bonus = resistance
	add_log("%s takes a defensive stance (-%d incoming damage this round)." \
			% [bot.bot_name, resistance])

func _do_support(bot: BotData) -> void:
	var team := allies if allies.has(bot) else enemies
	for ally in team:
		if ally != bot and not ally.is_dead:
			ally.temp_attack_bonus += 2
			ally.defend_bonus += 2
	add_log("%s supports allies! (+2 ATK, +2 DEF to all other allies this round)" % bot.bot_name)

func _do_charge(bot: BotData) -> void:
	bot.is_charged = true
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
	if current_turn_index >= turn_order.size():
		return
	var bot := turn_order[current_turn_index]
	turn_label.text = "Current Turn: %s" % bot.bot_name

func check_battle_over() -> bool:
	if get_alive_allies().is_empty():
		add_log("★ ENEMIES WIN ★")
		is_battle_over = true
		return true
	if get_alive_enemies().is_empty():
		add_log("★ ALLIES WIN ★")
		is_battle_over = true
		return true
	return false

func reset_battle() -> void:
	combat_log.clear()
	_log_entries.clear()
	current_turn_index = 0
	is_battle_over = false
	create_test_bots()
	build_turn_order()
	update_turn_label()
	add_log("Battle Reset")
