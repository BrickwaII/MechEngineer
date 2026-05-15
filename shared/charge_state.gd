extends RefCounted
class_name ChargeState

var is_charged: bool = false
var is_overloaded: bool = false

func get_multiplier() -> float:
	if is_overloaded:
		return 3.0
	if is_charged:
		return 2.0
	return 1.0

func is_active() -> bool:
	return is_charged or is_overloaded

func reset() -> void:
	is_charged = false
	is_overloaded = false
