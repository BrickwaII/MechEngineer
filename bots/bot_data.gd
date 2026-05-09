extends Resource
class_name BotData

enum Command { ATTACK, DEFEND, SUPPORT, CHARGE }

@export var bot_name: String = "Bot"
@export var max_hp: int = 20
@export var power: int = 5
@export var speed: int = 5

var color: Color = Color.WHITE
var current_hp: int
var is_dead: bool = false

var command: Command = Command.ATTACK
var is_charged: bool = false
var temp_attack_bonus: int = 0  # granted by an allied Support this round
var defend_bonus: int = 0       # damage resistance set when this bot uses Defend

func initialize() -> void:
	current_hp = max_hp
	is_dead = false
	is_charged = false
	temp_attack_bonus = 0
	defend_bonus = 0

# Returns the actual damage dealt after applying defend_bonus.
func take_damage(amount: int) -> int:
	var actual := maxi(0, amount - defend_bonus)
	current_hp -= actual
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
	return actual
