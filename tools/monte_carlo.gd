class_name MonteCarlo extends RefCounted
# Runs HeadlessBattle N times per strategy and returns a formatted report.

const STRATEGIES: Array[String] = ["random", "aggressive", "smart"]

static func run(bot_templates: Array, enemy_templates: Array,
		runs: int = 1000) -> String:
	var t0 := Time.get_ticks_msec()

	var all_stats: Dictionary = {}
	for strat in STRATEGIES:
		all_stats[strat] = _empty_stats(bot_templates)

	for strat: String in STRATEGIES:
		var stats: Dictionary = all_stats[strat]
		for _i in range(runs):
			var r: HeadlessBattle.Result = HeadlessBattle.run(
				bot_templates, enemy_templates, strat)
			_accumulate(stats, r, bot_templates)

	var elapsed_ms := Time.get_ticks_msec() - t0
	return _format(all_stats, bot_templates, enemy_templates, runs, elapsed_ms)

# ── Stats accumulation ────────────────────────────────────────────────────────

static func _empty_stats(bot_templates: Array) -> Dictionary:
	var s := {
		"wins": 0, "losses": 0, "timeouts": 0,
		"total_rounds": 0,
		"win_rounds": 0,   "win_player_hp": 0,
		"loss_rounds": 0,  "loss_enemy_hp": 0,
		"bot_survived": {},
		"first_kill_counts": {},
	}
	for t: BotData in bot_templates:
		s["bot_survived"][t.id] = 0
	return s

static func _accumulate(stats: Dictionary, r: HeadlessBattle.Result,
		bot_templates: Array) -> void:
	stats["total_rounds"] += r.rounds
	if r.timed_out:
		stats["timeouts"] += 1
		stats["losses"]   += 1
		return
	if r.won:
		stats["wins"]          += 1
		stats["win_rounds"]    += r.rounds
		stats["win_player_hp"] += r.player_hp_left
	else:
		stats["losses"]         += 1
		stats["loss_rounds"]    += r.rounds
		stats["loss_enemy_hp"]  += r.enemy_hp_left

	for t: BotData in bot_templates:
		if r.bot_survived.get(t.id, false):
			stats["bot_survived"][t.id] += 1

	if r.first_enemy_killed != "":
		var fk: Dictionary = stats["first_kill_counts"]
		fk[r.first_enemy_killed] = fk.get(r.first_enemy_killed, 0) + 1

# ── Report formatting ─────────────────────────────────────────────────────────

static func _format(all_stats: Dictionary, bot_tpls: Array, enemy_tpls: Array,
		runs: int, elapsed_ms: int) -> String:
	var b := PackedStringArray()
	b.append("╔══ Monte Carlo Balance Report ══════════════════════════╗")
	b.append("  %d runs × %d strategies  |  %.2f ms total  (%.2f ms/run)" % [
		runs, STRATEGIES.size(), elapsed_ms,
		float(elapsed_ms) / (runs * STRATEGIES.size())])
	b.append("  Encounter: [%s] vs [%s]" % [
		", ".join(bot_tpls.map(func(t: BotData)  -> String: return t.bot_name)),
		", ".join(enemy_tpls.map(func(t: EnemyData) -> String: return t.enemy_name))])
	b.append("╚════════════════════════════════════════════════════════╝")

	var smart_win_rate := 0.0
	for strat: String in STRATEGIES:
		var s: Dictionary = all_stats[strat]
		var wins:   int = s["wins"]
		var losses: int = s["losses"]
		var total:  int = wins + losses
		var win_pct := float(wins) / total * 100.0 if total > 0 else 0.0

		if strat == "smart": smart_win_rate = win_pct

		b.append("")
		b.append("── %s ─────────────────────────────────────────────────" % strat.to_upper())
		b.append("  Win rate: %.1f%%  (%d W / %d L)" % [win_pct, wins, losses])
		if s["timeouts"] > 0:
			b.append("  Timeouts (>%d rounds): %d" % [HeadlessBattle.MAX_ROUNDS, s["timeouts"]])

		var avg_all := float(s["total_rounds"]) / total if total > 0 else 0.0
		var avg_win := float(s["win_rounds"])   / wins   if wins   > 0 else 0.0
		var avg_los := float(s["loss_rounds"])  / losses if losses > 0 else 0.0
		b.append("  Avg rounds: %.1f  (wins %.1f  |  losses %.1f)" % [avg_all, avg_win, avg_los])

		if wins > 0:
			b.append("  Avg player HP remaining on win: %.1f" % [
				float(s["win_player_hp"]) / wins])
		if losses > 0:
			b.append("  Avg enemy HP remaining on loss: %.1f" % [
				float(s["loss_enemy_hp"]) / losses])

		b.append("  Bot survival rates:")
		for t: BotData in bot_tpls:
			var pct := float(s["bot_survived"].get(t.id, 0)) / total * 100.0
			b.append("    %-10s  %.1f%%" % [t.bot_name, pct])

		var fk: Dictionary = s["first_kill_counts"]
		if not fk.is_empty():
			b.append("  First enemy eliminated:")
			for eid in fk:
				var ename := _enemy_name(eid, enemy_tpls)
				b.append("    %-10s  %.1f%% of battles" % [
					ename, float(fk[eid]) / total * 100.0])

	b.append("")
	b.append("── ASSESSMENT ─────────────────────────────────────────────")
	b.append("  " + _assess(smart_win_rate))
	b.append("")
	return "\n".join(b)

static func _assess(smart_win_rate: float) -> String:
	if smart_win_rate >= 80.0:
		return "VERY PLAYER-FAVORABLE (smart AI wins %.0f%%) — enemies need more HP or damage." % smart_win_rate
	elif smart_win_rate >= 60.0:
		return "PLAYER-FAVORABLE (smart AI wins %.0f%%) — slight player advantage, consider tuning." % smart_win_rate
	elif smart_win_rate >= 40.0:
		return "ROUGHLY BALANCED (smart AI wins %.0f%%) — within acceptable range for a first fight." % smart_win_rate
	elif smart_win_rate >= 20.0:
		return "ENEMY-FAVORABLE (smart AI wins %.0f%%) — fight may feel punishing early; consider easing." % smart_win_rate
	else:
		return "VERY ENEMY-FAVORABLE (smart AI wins %.0f%%) — tuning strongly recommended." % smart_win_rate

static func _enemy_name(id: String, enemy_tpls: Array) -> String:
	for e: EnemyData in enemy_tpls:
		if e.id == id: return e.enemy_name
	return id
