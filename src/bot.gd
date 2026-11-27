## A simple deterministic player for the replay test, balance runs and `--bot` demo runs: fights what is close, otherwise hauls logs.
## It plays every character (Config.CHARACTERS): a swinger stands off and swings; a shooter keeps its distance and
## shoots; one that can carry several logs picks up more on the way when the torch can wait.
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
const CLEAR_OF := 6.0 # how far past a marked landing's shock, or a charge's lane, the bot steps to be out of it
const SHOOT_FROM := 70.0 # a shooter fights what comes this close
const KITE := 46.0 # and backs off to keep it this far away
const KITE_HOME := 0.6 # backing off leans this much toward the torch, so it does not back into a corner
const SHOOT_DROP := 22.0 # a shooter carrying logs drops them to fight only what comes this close
const SHOOT_HUNGRY := 0.75 # below this share of a full tank, with logs about, it does not stop to fight: it shoots on its way to the wood
const STACK_NEAR := 60.0 # one that can carry more goes for another log this close, on its way to the torch
const STACK_FUEL := 0.45 # while the torch holds at least this share of a full tank

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
	var real: Array = w.enemies.filter(func(e): return not e.decoy) # a decoy hurts nothing: leave it be
	var foe = _nearest(p.pos, real)
	var smotherer = _nearest(p.pos, real.filter(func(e): return e.at_torch))
	var landing = _landing(w, p.pos)
	var lane = _lane(w, p.pos)
	var rush: bool = real.any(func(e): return e.T.has("lunge") and e.move in ["warn", "lunge"])
	var shooter: bool = w.stats.attack == "shoot"
	if landing != null:
		# a leap is marked on it: step out of the shock sideways to the leap, on the torch's side (not into a fence)
		var side: Vector2 = (landing.move_to - landing.pos).normalized().orthogonal()
		if side == Vector2.ZERO:
			side = Vector2.DOWN
		if side.dot(Config.TORCH.pos - landing.move_to) < 0.0:
			side = -side
		var out: Vector2 = p.pos - landing.move_to
		if out.length() < 1.0:
			out = side
		goal = landing.move_to + out.normalized() * (landing.hop().shock + Config.PLAYER.radius + CLEAR_OF)
	elif lane != null:
		# a charge is lined up at it: step out of the lane sideways, on the side it already leans to (the torch's
		# side when it stands right on the line)
		var on: Vector2 = lane.pos + lane.aim * maxf(0.0, (p.pos - lane.pos).dot(lane.aim))
		var out: Vector2 = p.pos - on
		if out.length() < 1.0:
			out = lane.aim.orthogonal()
			if out.dot(Config.TORCH.pos - p.pos) < 0.0:
				out = -out
		goal = on + out.normalized() * (_lane_width(lane) + CLEAR_OF)
	elif shooter and foe != null and not _hungry_fire(w) and p.pos.distance_to(foe.pos) < (SHOOT_DROP if p.carrying else SHOOT_FROM):
		goal = _kite(w, p, foe, f)
	elif foe != null and p.pos.distance_to(foe.pos) < FIGHT_RANGE and foe.T.get("dark_proof", false) and not w.in_light(foe.pos):
		pass # blows pass through it out here: walk back to the torch (the goal already) and fight it in the light
	elif not shooter and foe != null and p.pos.distance_to(foe.pos) < FIGHT_RANGE:
		var away: Vector2 = (p.pos - foe.pos).normalized()
		goal = foe.pos + away * (foe.T.radius + Config.PLAYER.radius + KEEP) # stand off instead of walking into it
		if p.carrying:
			f.pressed["attack"] = true # drop the log to fight
		elif w.steps % SWING_EVERY == 0:
			f.pressed["attack"] = true
	elif smotherer != null and shooter and not p.carrying:
		goal = _kite(w, p, smotherer, f) # shoot it off the torch from a step away
	elif smotherer != null:
		goal = smotherer.pos # something is on the torch: that comes before logs and berries
	elif rush:
		pass # the shade lord is about to rush the torch, where it can be cut: be there (the goal already)
	elif not p.carrying and p.hp <= HUNGRY and not w.berries.is_empty():
		goal = _nearest_point(p.pos, w.berries)
	elif p.held < w.stats.carry and not w.logs.is_empty() and (not p.carrying or _stack_more(w, p)):
		goal = _nearest_point(p.pos, w.logs)
		if goal == p.dropped:
			goal += Vector2(Config.PLAYER.grab * 2.0, 0.0) # still standing on the log it put down: step off, then come back for it
	elif not p.carrying and foe != null:
		goal = foe.pos
	if shooter and not p.carrying and foe != null and p.pos.distance_to(foe.pos) < SHOOT_FROM:
		f.pressed["attack"] = true # a shooter shoots on its way, whatever it is doing (never while carrying: that drops the logs)
	var d: Vector2 = goal - p.pos
	var clear: bool = foe == null or p.pos.distance_to(foe.pos) > FIGHT_RANGE * 2.0
	if w.mod("dash_every", 0.0) > 0.0 and clear and d.length() > DASH_FROM:
		f.pressed["dash"] = true # a long way to go and nothing close: dash (it waits for the dash to be ready)
	if d.x > DEADZONE: f.held["right"] = true
	if d.x < -DEADZONE: f.held["left"] = true
	if d.y > DEADZONE: f.held["down"] = true
	if d.y < -DEADZONE: f.held["up"] = true
	return f


## A shooter's fight with foe: shoot at it (World.aim turns the shot to the nearest), dropping what it carries first,
## and keep KITE away, backing off toward the torch. Returns where to go.
static func _kite(w, p, foe, f: InputFrame) -> Vector2:
	var away: Vector2 = p.pos - foe.pos
	var d := away.length()
	f.pressed["attack"] = true # pressed while a shot is under way, it does nothing
	if d >= KITE:
		return p.pos if not p.carrying else Config.TORCH.pos
	var home: Vector2 = (Config.TORCH.pos - p.pos).normalized() * KITE_HOME
	return p.pos + ((away / maxf(d, 0.01)) + home).normalized() * (KITE - d + CLEAR_OF)


## Whether the torch wants wood more than a shooter wants to stand and shoot: low, with logs on the ground.
static func _hungry_fire(w) -> bool:
	return not w.logs.is_empty() and w.fuel < SHOOT_HUNGRY * w.max_fuel()


## Whether one already carrying a log should pick up another (a nearby one, while the torch can wait).
static func _stack_more(w, p) -> bool:
	return p.pos.distance_to(_nearest_point(p.pos, w.logs)) < STACK_NEAR and w.fuel >= STACK_FUEL * w.max_fuel()


## A boss's marked landing (a leap's or a hop's) whose shock would reach the bot where it stands, or null.
static func _landing(w, at: Vector2):
	for e in w.enemies:
		if e.T.has("leap") and e.move in ["warn", "air"] and at.distance_to(e.move_to) < e.hop().shock + Config.PLAYER.radius + CLEAR_OF:
			return e
	return null


## A charger lined up at the bot or charging, whose lane (its body's width along the rest of its line) the bot stands
## in, or null.
static func _lane(w, at: Vector2):
	for e in w.enemies:
		if not (e.T.has("charge") and e.move in ["warn", "charge"]):
			continue
		var along: float = (at - e.pos).dot(e.aim)
		if along < -e.T.radius or along > e.pos.distance_to(e.move_to) + e.T.radius:
			continue
		if absf((at - e.pos).dot(e.aim.orthogonal())) < _lane_width(e):
			return e
	return null


static func _lane_width(e) -> float:
	return e.lane_half() + 2.0


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
