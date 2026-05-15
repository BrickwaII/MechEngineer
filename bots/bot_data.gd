extends Resource
class_name BotData

enum Command { ATTACK, DEFEND, SUPPORT, CHARGE }

@export var id: String = ""
@export var bot_name: String = "Bot"
@export var max_hp: int = 20
@export var attack: int = 5
@export var defense: int = 2
@export var speed: int = 5
@export var elasticity: float = 1.0
@export var efficiency: float = 1.0
@export var generation: int = 1

var color: Color = Color.WHITE
var current_hp: int
var is_dead: bool = false

var personality: PersonalityData
var charge_state: ChargeState

# Prototype B — skills available per command type and current assignment
var skill_slots: Dictionary = {}  # String -> Array[SkillData]
var assigned_skill: SkillData = null
var assigned_target = null  # BotData | EnemyData | null

# Per-round transient bonuses
var temp_attack_bonus: int = 0
var temp_defense_bonus: int = 0

# Prototype A backward-compat
var command: Command = Command.ATTACK

# Per-battle tag accumulator
var action_log: Array = []

func initialize() -> void:
	current_hp = max_hp
	is_dead = false
	charge_state = ChargeState.new()
	personality = PersonalityData.new()
	personality.active_scales = generation
	temp_attack_bonus = 0
	temp_defense_bonus = 0
	assigned_skill = null
	assigned_target = null
	action_log.clear()
	_populate_default_skills()

func _populate_default_skills() -> void:
	var lib := SkillLibrary.make()
	skill_slots["attack"]  = [lib["standard_attack"], lib["power_shot"], lib["spread_shot"]]
	skill_slots["defend"]  = [lib["standard_defend"], lib["counter_stance"]]
	skill_slots["support"] = [lib["standard_support"], lib["battle_cry"], lib["medic_protocol"]]
	skill_slots["charge"]  = [lib["standard_charge"], lib["overload"]]

func get_all_skills() -> Array:
	var result: Array = []
	for arr in skill_slots.values():
		result.append_array(arr)
	return result

# Raw HP reduction — caller is responsible for applying defense via DamageCalculator.
func take_damage(amount: int) -> int:
	var actual := maxi(0, amount)
	current_hp -= actual
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
	return actual

func reset_round_bonuses() -> void:
	temp_attack_bonus = 0
	temp_defense_bonus = 0
