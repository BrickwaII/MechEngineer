extends Resource
class_name IntentData

var intent_type: String = "attack"
	# "attack" | "defend" | "power_up" | "buff_ally" | "recover" | "attack_weakest"
var value: int = 0                       # damage, defense gained, HP healed, ATK bonus, etc.
var target_resolution: String = "random" # "fixed" | "weakest" | "random" | "self"
var display_label: String = ""

static func make(type: String, val: int, res: String = "random") -> IntentData:
	var d := IntentData.new()
	d.intent_type = type
	d.value = val
	d.target_resolution = res
	d.display_label = _label_for(type, val)
	return d

static func _label_for(type: String, val: int) -> String:
	match type:
		"attack":         return "⚔ %d" % val
		"attack_weakest": return "⚔ %d (weakest)" % val
		"defend":         return "🛡 +%d DEF" % val
		"power_up":       return "▲ +%d ATK" % val
		"buff_ally":      return "↑ ally +%d ATK" % val
		"recover":        return "♥ +%d HP" % val
	return type
