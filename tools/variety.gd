## Prints how much one run differs from another: how alike two runs are, how alike their builds end up, how evenly
## enemies come through a night, and how much of the game a run meets. A tuning aid, not a gate:
## ./verify --variety
extends RefCounted

const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/bot.gd")
const Config := preload("res://src/sim/config.gd")
const SimRng := preload("res://src/sim/rng.gd")

const RUN_STEPS := 60 * 60 * 3 # three nights: enough to tell two runs apart
const BUILD_SEEDS := 300
const BUILD_PAIRS := 3000
const BUILD_NIGHTS := [5, 10, 15, 20]
const PACE_NIGHTS := [1, 3, 5, 7, 9]
const PACE_SEEDS := 5
const WINDOW := 5.0 # seconds: a burst is many arrivals inside one window
const MET_SEEDS := 10
const MET_STEPS := 60 * 600 # as the balance tool: a bot still standing after this long is counted where it stands


static func run() -> String:
	return "\n".join([_runs(), _builds(), _pacing(), _met()])


## Steps a bot's run until it ends, the night is no longer only (0: any night) or steps run out. Returns every enemy
## that came out of the dark, as { night, time, id ("kind tier place") }, and every enemy kind it met at all.
static func _play(w, bot, steps: int, only := 0) -> Dictionary:
	var seen := {}
	var arrivals := []
	var kinds := {}
	var tiers := 1
	for s in steps:
		w.step(bot.frame(w))
		if w.phase == "out" or w.phase == "dead" or (only > 0 and w.night != only):
			break
		for e in w.enemies:
			if seen.has(e):
				continue
			seen[e] = true
			kinds[e.kind] = true
			tiers = maxi(tiers, e.tier)
			if not Config.FIELD.has_point(e.pos):
				arrivals.append({ "night": w.night, "time": w.time, "id": "%s %d %.1f,%.1f" % [e.kind, e.tier, e.pos.x, e.pos.y] })
	return { "arrivals": arrivals, "kinds": kinds.keys(), "tiers": tiers, "world": w }


## How many of b's arrivals a has too: the same enemy from the same place at the same time of the same night.
static func _shared(a: Array, b: Array) -> int:
	var have := {}
	for x in a:
		have["%d %.2f %s" % [x.night, x.time, x.id]] = true
	var both := 0
	for x in b:
		if have.has("%d %.2f %s" % [x.night, x.time, x.id]):
			both += 1
	return both


static func _runs() -> String:
	var a: Array = _play(World.new(1), Bot.new(1), RUN_STEPS).arrivals
	var again: Array = _play(World.new(1), Bot.new(1), RUN_STEPS).arrivals
	var other: Array = _play(World.new(2), Bot.new(1), RUN_STEPS).arrivals
	return "variety: runs: one seed played twice shares %d of %d arrivals (same enemy, place and time); another seed shares %d of %d" % [
		_shared(a, again), again.size(), _shared(a, other), other.size()]


## Takes a random card at every offer up to the dusk of the last of BUILD_NIGHTS, as World.begin_at takes a fixed
## one, and compares what two keepers hold at the dusk of each of those nights.
static func _builds() -> String:
	var per_night: int = 1 + Config.NIGHT.picks_at.size()
	var held := {}
	for n in BUILD_NIGHTS:
		held[n] = []
	for seed_value in range(1, BUILD_SEEDS + 1):
		var w = World.new(seed_value)
		var rng = SimRng.new(seed_value + 1000)
		for i in per_night * (BUILD_NIGHTS[-1] - 1) + 1:
			if not w.offer.is_empty():
				w._take(w.offer[rng.index(w.offer.size())])
			for n in BUILD_NIGHTS:
				if i == per_night * (n - 1):
					held[n].append(w.picks.duplicate())
			w.night = 1 + (i + 1) / per_night
			w._offer()
	var rng = SimRng.new(7)
	var parts := []
	for n in BUILD_NIGHTS:
		var runs: Array = held[n]
		if runs.size() < 2:
			parts.append("night %d: no run gets a card there" % n)
			continue
		var pool := 0
		for id in Config.UPGRADES:
			if World.offered_on(id, n):
				pool += World.max_level(id)
		var share := 0.0
		for i in BUILD_PAIRS:
			var a: Array = runs[rng.index(runs.size())]
			var b: Array = runs[rng.index(runs.size())]
			var both := 0
			for id in Config.UPGRADES:
				both += mini(a.count(id), b.count(id))
			share += float(both) / maxi(1, a.size())
		var sizes: Array = runs.map(func(r): return r.size())
		sizes.sort()
		parts.append("night %d: %d of %d levels held, two keepers share %.0f%% of them" % [n, sizes[sizes.size() / 2], pool, 100.0 * share / BUILD_PAIRS])
	return "variety: builds at dusk, a random card at every offer over %d seeds: %s" % [BUILD_SEEDS, "; ".join(parts)]


## Whole nights the bot keeps, started at their dusk: how many enemies come out of the dark, and how many of them in
## the busiest WINDOW seconds, against what a night with evenly spaced arrivals would hold there.
static func _pacing() -> String:
	var parts := []
	for n in PACE_NIGHTS:
		var counts := []
		var busiest := []
		for seed_value in range(1, PACE_SEEDS + 1):
			var w = World.new(seed_value)
			w.begin_at(n, 1)
			var run := _play(w, Bot.new(1), int(Config.NIGHT.length * 70.0), n)
			if w.night == n:
				continue
			var times: Array = run.arrivals.map(func(x): return x.time)
			var most := 0
			for t in times:
				most = maxi(most, times.filter(func(u): return u >= t and u < t + WINDOW).size())
			counts.append(times.size())
			busiest.append(most)
		if counts.is_empty():
			parts.append("night %d: the bot kept none of %d" % [n, PACE_SEEDS])
			continue
		counts.sort()
		busiest.sort()
		var count: int = counts[counts.size() / 2]
		var even: float = count * WINDOW / (Config.NIGHT.length - Config.NIGHT.first_spawn)
		parts.append("night %d: %d arrivals, %d in the busiest %d s (even: %.1f)" % [n, count, busiest[busiest.size() / 2], int(WINDOW), even])
	return "variety: pacing, medians over the nights the bot keeps of %d seeds: %s" % [PACE_SEEDS, "; ".join(parts)]


## What a run meets before it ends: the night it falls on, the enemy kinds and bosses it sees, the upgrades it takes.
static func _met() -> String:
	var bosses: Array = Config.ENEMY_TYPES.keys().filter(func(k): return Config.ENEMY_TYPES[k].get("boss", false))
	var nights := []
	var kinds := []
	var boss_kinds := []
	var cards := []
	var stronger := 0
	for seed_value in range(1, MET_SEEDS + 1):
		var run := _play(World.new(seed_value), Bot.new(1), MET_STEPS)
		var w = run.world
		nights.append(w.night)
		kinds.append(run.kinds.filter(func(k): return not bosses.has(k)).size())
		boss_kinds.append(run.kinds.filter(func(k): return bosses.has(k)).size())
		cards.append(w.picks.size())
		if run.tiers > 1:
			stronger += 1
	for list in [nights, kinds, boss_kinds, cards]:
		list.sort()
	var mid: int = MET_SEEDS / 2
	return "variety: met, medians over %d runs of the bot: falls on night %d, meets %d of %d enemy kinds and %d of %d bosses, takes %d cards; %d of %d runs meet a stronger tier" % [
		MET_SEEDS, nights[mid], kinds[mid], Config.ENEMY_TYPES.size() - bosses.size(), boss_kinds[mid], bosses.size(), cards[mid], stronger, MET_SEEDS]
