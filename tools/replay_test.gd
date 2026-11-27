## Plays the bot session in tests/replay_script.gd through the real World twice and checks: (D) both runs match step for step,
## (E1) the world told the view about every kill and every log fed, and (G2) the run matches tests/golden/replay.json.
## Marks are hashes of the world state once per second.
extends RefCounted

const World := preload("res://src/sim/world.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const ReplayScript := preload("res://tests/replay_script.gd")
const Bot := preload("res://src/bot.gd")
const Config := preload("res://src/sim/config.gd")
const Enemy := preload("res://src/sim/enemy.gd")
const GOLDEN := "res://tests/golden/replay.json"


static func digest(w) -> String:
	var p = w.player
	var nums := PackedFloat64Array([w.night, w.time, w.steps, w.fuel, w.score, w.picks.size(), w.offer.size(), w.schedule.size(),
		p.pos.x, p.pos.y, p.vel.x, p.vel.y, p.hp, p.face.x, p.face.y, p.attack_t, 1.0 if p.carrying else 0.0, 1.0 if p.dropped != null else 0.0, w.enemies.size(), w.logs.size(), w.berries.size(),
		w.sparks.size(), p.dash_t, w.blade_kills, w.rerolls, w.haste_until])
	for e in w.enemies:
		nums.append_array([e.pos.x, e.pos.y, e.hp, e.knock.x, e.knock.y, 1.0 if e.carrying else 0.0, e.tier])
	for l in w.logs + w.berries:
		nums.append_array([l.x, l.y])
	for b in w.blobs:
		nums.append_array([b.pos.x, b.pos.y, b.left])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(nums.to_byte_array())
	ctx.update(("%s|%s|%s" % [w.rng.state(), w.phase, ",".join(w.picks)]).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


static func play(seed_value: int = ReplayScript.SEED, pick_slot: int = ReplayScript.PICK_SLOT, steps: int = ReplayScript.STEPS, character: String = "knight") -> Dictionary:
	var w = World.new(seed_value, character)
	var bot = Bot.new(pick_slot)
	var marks := []
	var told := {} # how many events of each kind the world reported
	var kill_worth := 0 # what the kills told were worth: most score SCORE.kill, a boss its own score, a tier more
	var gifts := 0 # the score the cards told as taken gave by themselves (a filler's score)
	for s in steps:
		w.step(bot.frame(w))
		for ev in w.events:
			told[ev.kind] = told.get(ev.kind, 0) + 1
			if ev.kind == "kill":
				kill_worth += Enemy.row(ev.enemy, ev.tier).get("score", Config.SCORE.kill)
			if ev.kind == "took":
				gifts += Config.FILLERS.get(ev.id, {}).get("score", 0)
		if (s + 1) % 60 == 0:
			marks.append(digest(w))
	var p = w.player
	return { "seed": seed_value, "steps": steps, "summary": { "phase": w.phase, "night": w.night, "time": snappedf(w.time, 0.01), "score": w.score, "hp": p.hp, "fuel": roundi(w.fuel), "picks": w.picks }, "events": told, "kill_worth": kill_worth, "gifts": gifts, "marks": marks }


## E1: what is wrong with the events of a run, or "" when they are complete. The score counts kills, logs fed,
## dawns and the score a filler gives on its own, so the events must add up to it; if they don't, an effect (or later
## a sound) would go missing.
static func untold(run: Dictionary) -> String:
	var kills: int = run.events.get("kill", 0)
	var fed: int = run.events.get("fed", 0)
	var dawns: int = run.events.get("dawn", 0)
	var worth: int = run.kill_worth + fed * Config.SCORE.log + dawns * Config.SCORE.dawn + run.gifts
	if worth == run.summary.score:
		return ""
	return "events: world.events told of %d kills, %d logs fed, %d dawns and %d from cards taken, worth %d, but the score is %d. Fix: append to world.events wherever a kill, a fed log, a dawn or a card's score is scored (E1); if the score now counts something new, count its event here too." % [kills, fed, dawns, run.gifts, worth, run.summary.score]


## Returns [ok: bool, message: String].
static func run(update: bool) -> Array:
	var a := play()
	var b := play()
	for i in a.marks.size():
		if a.marks[i] != b.marks[i]:
			return [false, "replay: NOT deterministic, runs differ at second %d. Something read the clock, an unseeded random, or engine state (D1-D3, S1)." % (i + 1)]
	if untold(a) != "":
		return [false, untold(a)]
	var summary := _say(a.summary)
	if update:
		var f := FileAccess.open(GOLDEN, FileAccess.WRITE)
		f.store_string(JSON.stringify(a, "  ") + "\n")
		return [true, "replay: golden re-recorded (%s). Add a docs/DECISIONS.md entry saying what changed and why." % summary]
	if not FileAccess.file_exists(GOLDEN):
		return [false, "replay: no golden yet. Record it on purpose: ./verify --update-golden"]
	var g = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	for i in a.marks.size():
		if i >= g.marks.size() or a.marks[i] != g.marks[i]:
			return [false, "replay: deterministic, but differs from the golden at second %d (now: %s; golden: %s). If gameplay changed on purpose: ./verify --update-golden and a DECISIONS entry. Never edit the golden by hand." % [i + 1, summary, _say(g.summary)]]
	return [true, "replay: deterministic and matches golden (%s)" % summary]


static func _say(m: Dictionary) -> String:
	return "%s on night %d at %.1fs, score %d, hp %d, fuel %d, picks %s" % [m.phase, m.get("night", 1), m.time, m.score, m.hp, m.fuel, ",".join(m.picks)]
