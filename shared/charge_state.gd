extends RefCounted
class_name ChargeState

enum Tier { NONE, CHARGED, OVERLOADED }

var tier: Tier = Tier.NONE

func is_active() -> bool:
	return tier != Tier.NONE

func get_multiplier() -> float:
	match tier:
		Tier.OVERLOADED: return 3.0
		Tier.CHARGED:    return 2.0
		_:               return 1.0

func reset() -> void:
	tier = Tier.NONE
