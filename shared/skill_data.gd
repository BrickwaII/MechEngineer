extends Resource
class_name SkillData

var skill_name: String = ""
var command_type: String = ""       # "attack" | "defend" | "support" | "charge"
var energy_cost: int = 1
var multiplier: float = 1.0
var effect_type: String = "damage"  # "damage" | "defend" | "buff" | "charge" | "heal"
var effect_value: float = 0.0       # secondary effect magnitude (debuff, buff amount, etc.)
var target_type: String = "single_enemy"
	# "single_enemy" | "all_enemies" | "random_enemy"
	# "self" | "single_ally" | "all_allies"
var hit_count_min: int = 1
var hit_count_max: int = 1
var armor_piercing: bool = false
var level: int = 1
var max_level: int = 5
var tags: Array = []
