extends Resource
class_name EnemyData

var id: String = ""
var enemy_name: String = ""
var personality_archetype: String = ""
var hp: int = 20
var max_hp: int = 20
var attack: int = 5
var defense: int = 0
var speed: int = 5
var intent_loop: Array = []          # Array[IntentData]
var current_intent_index: int = 0
var current_intent: IntentData = null

# Per-round transient state
var temp_attack_bonus: int = 0
var temp_defense_bonus: int = 0
var is_dead: bool:
	get: return hp <= 0

func initialize() -> void:
	hp = max_hp
	temp_attack_bonus = 0
	temp_defense_bonus = 0
	current_intent_index = 0
	current_intent = intent_loop[0] if intent_loop.size() > 0 else null

func advance_intent() -> void:
	if intent_loop.is_empty():
		return
	current_intent_index = (current_intent_index + 1) % intent_loop.size()
	current_intent = intent_loop[current_intent_index]

# Raw HP reduction — callers apply defense before calling this.
func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
