extends VBoxContainer
class_name AssignmentQueueUI

func refresh(bots: Array, assignments: Dictionary) -> void:
	for child in get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "ASSIGNMENT QUEUE"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	add_child(header)

	for bot: BotData in bots:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 10)

		if assignments.has(bot.id):
			var a: Dictionary = assignments[bot.id]
			var skill: SkillData = a["skill"]
			var target = a.get("target", null)
			var target_name := _target_name(target)
			var preview_str := ""
			if a.has("preview_dmg") and a["preview_dmg"] > 0:
				preview_str = " (proj. %d dmg)" % a["preview_dmg"]
			row.text = "✓ %s → %s%s%s" % [
				bot.bot_name, skill.skill_name,
				(" → " + target_name) if target_name != "" else "",
				preview_str
			]
			row.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			row.text = "_ %s (unassigned)" % bot.bot_name
			row.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		add_child(row)

static func _target_name(target) -> String:
	if target == null:
		return ""
	if target is BotData:
		return target.bot_name
	if target is EnemyData:
		return target.enemy_name
	return ""
