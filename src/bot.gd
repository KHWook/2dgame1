## A simple deterministic player for the replay test, balance runs and `--bot` demo runs: fights what is close, otherwise hauls logs.
## It reads the world and returns the InputFrame a player would produce; it never changes the world.
extends RefCounted

const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")

const FIGHT_RANGE := 26.0
const SWING_EVERY := 12 # steps between swing presses
const DEADZONE := 2.0
const KEEP := 2.0 # how far outside a foe's touch the bot stands while it fights it
const DASH_FROM := 60.0 # with the dash upgrade, the bot dashes toward a goal at least this far away
const HUNGRY := 2 # the bot goes for a berry at this hp or less; above it, hauling logs matters more

var pick := 1 # which offer slot this bot always takes


func _init(pick_slot: int = 1) -> void:
	pick = pick_slot


func frame(w) -> InputFrame:
	var f := InputFrame.new()
	if w.phase == "pick":
		f.pressed["pick_%d" % mini(pick, w.offer.size())] = true # the last few offers have fewer slots than its usual one
		return f
	if w.phase != "night":
		return f
	var p = w.player
	var goal: Vector2 = Config.TORCH.pos
	var foe = _nearest(p.pos, w.enemies)
	var smotherer = _nearest(p.pos, w.enemies.filter(func(e): return e.at_torch))
	if foe != null and p.pos.distance_to(foe.pos) < FIGHT_RANGE and foe.T.get("dark_proof", false) and not w.in_light(foe.pos):
		pass # blows pass through it out here: walk back to the torch (the goal already) and fight it in the light
	elif foe != null and p.pos.distance_to(foe.pos) < FIGHT_RANGE:
		var away: Vector2 = (p.pos - foe.pos).normalized()
		goal = foe.pos + away * (foe.T.radius + Config.PLAYER.radius + KEEP) # stand off instead of walking into it
		if p.carrying:
			f.pressed["attack"] = true # drop the log to fight
		elif w.steps % SWING_EVERY == 0:
			f.pressed["attack"] = true
	elif smotherer != null:
		goal = smotherer.pos # something is on the torch: that comes before logs and berries
	elif not p.carrying and p.hp <= HUNGRY and not w.berries.is_empty():
		goal = _nearest_point(p.pos, w.berries)
	elif not p.carrying and not w.logs.is_empty():
		goal = _nearest_point(p.pos, w.logs)
		if goal == p.dropped:
			goal += Vector2(Config.PLAYER.grab * 2.0, 0.0) # still standing on the log it put down: step off, then come back for it
	elif not p.carrying and foe != null:
		goal = foe.pos
	var d: Vector2 = goal - p.pos
	var clear: bool = foe == null or p.pos.distance_to(foe.pos) > FIGHT_RANGE * 2.0
	if w.mod("dash_every", 0.0) > 0.0 and clear and d.length() > DASH_FROM:
		f.pressed["dash"] = true # a long way to go and nothing close: dash (it waits for the dash to be ready)
	if d.x > DEADZONE: f.held["right"] = true
	if d.x < -DEADZONE: f.held["left"] = true
	if d.y > DEADZONE: f.held["down"] = true
	if d.y < -DEADZONE: f.held["up"] = true
	return f


static func _nearest(from: Vector2, enemies: Array):
	var best = null
	for e in enemies:
		if best == null or from.distance_to(e.pos) < from.distance_to(best.pos):
			best = e
	return best


static func _nearest_point(from: Vector2, points: Array) -> Vector2:
	var best: Vector2 = points[0]
	for q in points:
		if from.distance_to(q) < from.distance_to(best):
			best = q
	return best
