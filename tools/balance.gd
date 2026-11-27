## Plays the bot over many seeds and each offer slot, and prints how far it gets. A tuning aid, not a gate:
## ./verify --balance          from the first night, for at most STEPS (about the tenth night)
## ./verify --balance --late   from the dusk of night LATE_FROM (World.begin_at: the offers of the nights before it
##                             drawn and taken by the same slot), for at most LATE_STEPS, to see the late nights
extends RefCounted

const Replay := preload("res://tools/replay_test.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/bot.gd")
const SEEDS := 20
const STEPS := 60 * 600 # a bot still standing after this long is counted where it stands
const LATE_FROM := 10
const LATE_STEPS := 60 * 60 * 12 # twelve nights: past the twentieth


static func run(late := false) -> String:
	var lines := []
	var all_fell := {}
	for slot in [1, 2, 3]:
		var fell := {} # night -> how many runs ended on it
		var ends := {}
		var nights := 0
		var score := 0
		for seed_value in range(1, SEEDS + 1):
			var m: Dictionary = _late(seed_value, slot) if late else Replay.play(seed_value, slot, STEPS).summary
			fell[m.night] = fell.get(m.night, 0) + 1
			all_fell[m.night] = all_fell.get(m.night, 0) + 1
			ends[m.phase] = ends.get(m.phase, 0) + 1
			nights += m.night
			score += m.score
		var by_night := []
		for night in range(LATE_FROM if late else 1, fell.keys().max() + 1):
			by_night.append("%d: %d" % [night, fell.get(night, 0)])
		lines.append("balance%s: bot taking slot %d over %d seeds: fell on night { %s }, mean night %.2f, ends %s, mean score %d" % [" (late)" if late else "", slot, SEEDS, ", ".join(by_night), float(nights) / SEEDS, ends, score / SEEDS])
	var total := 0
	var count := 0
	for night in all_fell:
		total += night * all_fell[night]
		count += all_fell[night]
	lines.append("balance%s: all slots: mean night %.2f" % [" (late)" if late else "", float(total) / count])
	return "\n".join(lines)


## One run from the dusk of night LATE_FROM: how it ended.
static func _late(seed_value: int, slot: int) -> Dictionary:
	var w = World.new(seed_value)
	w.begin_at(LATE_FROM, slot)
	var bot = Bot.new(slot)
	for s in LATE_STEPS:
		w.step(bot.frame(w))
		if w.phase == "out" or w.phase == "dead":
			break
	return { "phase": w.phase, "night": w.night, "score": w.score }
