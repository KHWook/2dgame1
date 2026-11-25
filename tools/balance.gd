## Plays the bot over many seeds and each offer slot, and prints how far it gets. A tuning aid, not a gate:
## ./verify --balance
extends RefCounted

const Replay := preload("res://tools/replay_test.gd")
const SEEDS := 20
const STEPS := 60 * 600 # a bot still standing after this long is counted where it stands


static func run() -> String:
	var lines := []
	for slot in [1, 2, 3]:
		var fell := {} # night -> how many runs ended on it
		var ends := {}
		var nights := 0
		var score := 0
		for seed_value in range(1, SEEDS + 1):
			var m: Dictionary = Replay.play(seed_value, slot, STEPS).summary
			fell[m.night] = fell.get(m.night, 0) + 1
			ends[m.phase] = ends.get(m.phase, 0) + 1
			nights += m.night
			score += m.score
		var by_night := []
		for night in range(1, fell.keys().max() + 1):
			by_night.append("%d: %d" % [night, fell.get(night, 0)])
		lines.append("balance: bot taking slot %d over %d seeds: fell on night { %s }, mean night %.2f, ends %s, mean score %d" % [slot, SEEDS, ", ".join(by_night), float(nights) / SEEDS, ends, score / SEEDS])
	return "\n".join(lines)
