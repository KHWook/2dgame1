## An enemy, seen from above. Its row in Config.ENEMY_TYPES says what it goes for: the torch, to smother it; the
## player, to hurt them; or a log, to carry it off the field. It gets knocked back when hit. In the torch's light
## the warm glow slows it; out of it, a kind with dark_speed_mult hunts faster.
## A boss also has a pattern, always warned before it strikes (move says which part it is in): the slime king leaps
## at the player and shakes the ground where it lands, and every other time hops at them three times in a row; the
## shade lord circles in the dark, now and then rushes the torch, and now and then splits off decoys of itself. The
## world tells the screen "warn" { pos, at, enemy } when one is about to strike (at: where it will; for a split, where
## it stands), "landed" { pos, enemy, shock } when the slime king comes down (shock: how far round it it hurt), "decoy" { pos, enemy } where a decoy appears and
## "faded" { pos, enemy } where one breaks or fades.
## A charger (the boar) has a pattern too: it stops and paws the ground with its line drawn, charges straight along
## it, and stands dazed where the charge ends. It tells "warn" as well, at: the end of its line. The boar chief, a
## boss, hunts the keeper with sets of such charges across the field, ploughing aside the logs on its line, and
## stands winded after each set.
## A moth flies to the flame and burns up in it, taking fuel ("burned" { pos, enemy, tier }). A spitter stops short of
## the keeper, puffs up ("warn", at: the end of its line) and spits a blob along the line ("spat" { pos, enemy }). A
## drummer stands at the edge of the light and beats ("beat" { pos, enemy }); what hears it walks faster.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const E := Config.ENEMY
const KNOCK_KEEP: float = pow(E.knock_decay, Config.STEP) # share of its knockback a body keeps from one step to the next
## The patterns a row can give (a kind has at most one), each with the key of the time it first waits (move_t).
const PATTERNS := { "leap": "every", "lunge": "every", "charge": "every", "spit": "every", "drum": "beat" }

var kind: String
var tier := 1 # how strong it is, from 1 (Config.TIERS); T is its kind's row made that strong
var T: Dictionary
var pos: Vector2
var vel := Vector2.ZERO
var hp: int
var full_hp: int # its hp when it came: its row's, or a boss's made stronger or gentler for the night (World._boss)
var knock := Vector2.ZERO
var flash := 0.0
var dead := false
var gone := false # left the field with a log: it is removed, but that is not a kill
var at_torch := false # a smotherer that has reached the torch
var carrying := false # a thief holding a log
var summon_t := 0.0 # time until it next calls its kind (a boss with summon in its row)
var summons := 0 # how many it calls each time: its row's count, or a boss's made stronger or gentler for the night
var splits := 0 # how many it breaks into when it dies: its row's split_count, or a boss's made so for the night
var hops_left := 0 # the slime king's hops still to come in a run of hops, the one under way included; 0 for a leap
var leaps := 0 # leaps (and runs of hops) started so far
var split_t := 0.0 # the shade lord: time until it next splits, or, while it splits, until the decoys appear
var decoy := false # a decoy of a boss (split): it hurts nothing, smothers nothing and breaks at a blow, for no score
var lord = null # a decoy's boss: when it is gone, so are its decoys
var life_t := 0.0 # time a decoy has left
var move := "" # a pattern: "" (walking), "warn" (about to strike), "air" (the king's leap), "lunge", "stay" (the lord's rush and its time at the torch), "split" (the lord flickering before its decoys appear), "charge", "rest" (a charger's run and its daze after)
var move_t := 0.0 # time left in this part of the pattern, or, walking, until the next strike
var move_from := Vector2.ZERO # where the leap took off
var move_to := Vector2.ZERO # where it lands, or where the rush goes, or where a charge would end
var pattern := "" # which pattern its row gives it (PATTERNS), "" for none
var aim := Vector2.ZERO # the way a charger charges or a spitter spits, fixed when it starts to warn
var run := 0.0 # how far the charge lined up or under way goes: charge.dist, or less where the torch is in the way
var runs_left := 0 # a charger's charges still to come in this set, the one under way included
var drum = null # the drummer whose beat it last heard, while that beat carries it
var drum_t := 0.0 # time that beat still carries it


static var _rows := {} # "kind~tier" -> row(), made once


func _init(kind_: String, pos_: Vector2, tier_: int = 1) -> void:
	kind = kind_
	tier = tier_
	T = row(kind, tier)
	pos = pos_
	hp = T.hp
	full_hp = hp
	splits = T.get("split_count", 0)
	if T.has("summon"):
		summon_t = T.summon.every
		summons = T.summon.count
	if T.has("split"):
		split_t = T.split.first
	for key in PATTERNS:
		if T.has(key):
			pattern = key
			move_t = T[key][PATTERNS[key]]


## A kind's row in Config.ENEMY_TYPES at a tier: the row itself at tier 1, made stronger by Config.TIERS above it.
static func row(kind_: String, tier_: int) -> Dictionary:
	var base: Dictionary = Config.ENEMY_TYPES[kind_]
	if tier_ <= 1:
		return base
	var key := "%s~%d" % [kind_, tier_]
	if not _rows.has(key):
		var up: Dictionary = Config.TIERS[tier_ - 2]
		var r: Dictionary = base.duplicate()
		r.hp = ceili(base.hp * up.hp)
		r.speed = base.speed * up.speed
		r.smother = base.get("smother", 1.0) * up.smother
		r.score = ceili(base.get("score", Config.SCORE.kill) * up.score)
		if up.has("heavy"):
			r.heavy = base.get("heavy", 1.0) * up.heavy
		_rows[key] = r
	return _rows[key]


func step(world) -> void:
	flash = maxf(0.0, flash - Config.STEP)
	if decoy:
		life_t -= Config.STEP
		if life_t <= 0.0 or lord.dead or lord.gone:
			fade(world)
			return
	var flying := move == "air" # through the step it lands on, too
	if pattern != "":
		match pattern:
			"leap": _leap(world)
			"lunge": _lunge(world)
			"charge": _charge(world)
			"spit": _spit(world)
			"drum": _drum(world)
	if flying:
		at_torch = false
		knock = Vector2.ZERO
		if summons > 0:
			_summon(world)
		return
	var stop: float = Config.TORCH.reach + T.radius if T.target == "torch" else 0.0
	at_torch = T.target == "torch" and (Config.TORCH.pos - pos).length() <= stop
	if decoy and at_torch: # a decoy that reaches the torch is only smoke there
		at_torch = false
		fade(world)
		return
	if move == "lunge" and at_torch:
		move = "stay"
		move_t = T.lunge.stay
	if at_torch and T.has("burns"): # burning up is no kill: gone, not dead
		at_torch = false
		gone = true
		world.fuel -= T.burns * T.get("smother", 1.0)
		world.events.append({ "kind": "burned", "pos": pos, "enemy": kind, "tier": tier })
		return
	var goal: Vector2 = _goal(world)
	var to: Vector2 = (goal - pos).normalized()
	var speed: float = T.speed * (world.mod("glow_slow", 1.0) if world.in_light(pos) else T.get("dark_speed_mult", 1.0))
	if drum != null:
		drum_t -= Config.STEP
		if drum_t <= 0.0 or drum.dead or drum.gone:
			drum = null
		else:
			speed *= drum.T.drum.speed_mult
	if move == "lunge":
		speed = T.lunge.speed
	if move == "charge": # nothing turns a charge aside, blows neither
		speed = T.charge.speed
		to = aim
		knock = Vector2.ZERO
	# Most smotherers stop at the torch; the shade lord stops only while it warns and while it stays, so it can leave.
	var halt: bool = move in ["warn", "stay", "rest", "split"] or (at_torch and pattern != "lunge")
	if pattern == "spit":
		halt = halt or spits_from_here(world)
	elif pattern == "drum":
		halt = halt or pos.distance_to(goal) < E.drum_slack
	vel = knock if knock != Vector2.ZERO else (Vector2.ZERO if halt else to * speed)
	knock *= KNOCK_KEEP
	if knock.length() < E.knock_stop:
		knock = Vector2.ZERO
	pos += vel * Config.STEP
	if move == "charge" and T.charge.has("plough"):
		_plough(world)
	if move == "charge" and not Config.FIELD.has_point(pos): # it runs into the trees at the edge and stops there
		pos = pos.clamp(Config.FIELD.position, Config.FIELD.end)
		_daze()
	if T.target == "log":
		_thieve(world)
	if summons > 0:
		_summon(world)


## A boss calls its kind around itself every so often. They join the fight at the end of the step.
func _summon(world) -> void:
	summon_t -= Config.STEP
	if summon_t > 0.0:
		return
	summon_t += T.summon.every
	for i in summons:
		var around: Vector2 = Vector2.from_angle(TAU * i / summons + world.time) * (T.radius + E.summon_gap)
		world.born.append(get_script().new(T.summon.kind, pos + around))


## The slime king's leap. Walking, it counts down to the next one, which it starts only with the player in range: it
## marks where the player stands and crouches; then it flies there, and where it lands it hurts a player too close.
## Every leap.hops.each-th time it hops instead: the same, hops.count times in a row, each a short hop (hop()) at the
## player marked afresh as the one before lands.
func _leap(world) -> void:
	var L: Dictionary = T.leap
	var p = world.player
	match move:
		"":
			move_t = maxf(0.0, move_t - Config.STEP)
			if move_t <= 0.0 and not p.dead and pos.distance_to(p.pos) <= L.range:
				leaps += 1
				hops_left = L.hops.count if L.has("hops") and leaps % L.hops.each == 0 else 0
				_mark(world)
		"warn":
			move_t -= Config.STEP
			move_from = pos
			if move_t <= 0.0:
				move = "air"
				move_t = hop().air
		"air":
			move_t -= Config.STEP
			pos = move_from.lerp(move_to, clampf(1.0 - move_t / hop().air, 0.0, 1.0))
			if move_t <= 0.0:
				pos = move_to
				world.events.append({ "kind": "landed", "pos": pos, "enemy": kind, "shock": hop().shock })
				if pos.distance_to(p.pos) < hop().shock + Config.PLAYER.radius:
					p.hurt(pos)
				if hops_left > 1 and not p.dead:
					hops_left -= 1
					_mark(world)
				else:
					hops_left = 0
					move = ""
					move_t = L.every


## The leap or hop under way, or about to be: its warn, air and shock (Config: leap, or leap.hops while it hops).
func hop() -> Dictionary:
	return T.leap.hops if hops_left > 0 else T.leap


## Marks where the leap (or the next hop) lands, crouches, and says so. A hop goes at the player but no further than
## hops.reach.
func _mark(world) -> void:
	var p = world.player
	var at: Vector2 = p.pos
	if hops_left > 0:
		at = pos + (p.pos - pos).limit_length(T.leap.hops.reach)
	move = "warn"
	move_t = hop().warn
	move_from = pos
	move_to = _off_torch(at, T.leap.torch_gap)
	world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })


## Where the king may land: never on the torch. A mark closer than gap pixels beyond where it would start smothering
## is pushed straight out from the torch to that distance, so the leap is an attack on the player, not a way in: a
## player guarding the torch would otherwise bring the king onto it in one leap, and the torch went out seconds later.
func _off_torch(at: Vector2, gap: float) -> Vector2:
	var keep: float = Config.TORCH.reach + T.radius + gap
	var away: Vector2 = at - Config.TORCH.pos
	if away.length() >= keep:
		return at
	if away.length() < 0.001:
		away = pos - Config.TORCH.pos
	return Config.TORCH.pos + away.normalized() * keep


## The shade lord's rush. Circling, it counts down to the next one; then it stops and looks at the torch, rushes it,
## stays a while smothering it (step() turns the rush into the stay when it gets there), and goes back out.
func _lunge(world) -> void:
	var L: Dictionary = T.lunge
	match move:
		"":
			move_t -= Config.STEP
			if T.has("split") and not decoy:
				split_t -= Config.STEP
			if move_t <= 0.0:
				move = "warn"
				move_t = L.warn
				move_to = Config.TORCH.pos
				world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })
			elif T.has("split") and not decoy and split_t <= 0.0:
				move = "split"
				split_t = T.split.warn
				world.events.append({ "kind": "warn", "pos": pos, "at": pos, "enemy": kind })
		"split": # it stands flickering; the rush's count waits meanwhile, so its decoys rush with it
			split_t -= Config.STEP
			if split_t <= 0.0:
				move = ""
				split_t = T.split.every
				_split(world)
		"warn":
			move_t -= Config.STEP
			if move_t <= 0.0:
				move = "lunge"
		"stay":
			move_t -= Config.STEP
			if move_t <= 0.0:
				move = ""
				move_t = L.every


## The shade lord's decoys: split.count of them round its ring (evenly spaced from it, about the torch), each counting
## down to the same rush as it, so they rush the torch together.
func _split(world) -> void:
	var S: Dictionary = T.split
	for i in S.count:
		var at: Vector2 = Config.TORCH.pos + (pos - Config.TORCH.pos).rotated(TAU * (i + 1) / (S.count + 1))
		var d = get_script().new(kind, at)
		d.decoy = true
		d.lord = self
		d.hp = 1
		d.full_hp = 1
		d.life_t = S.life
		d.move_t = move_t
		d.summon_t = INF
		d.split_t = INF
		world.born.append(d)
		world.events.append({ "kind": "decoy", "pos": at, "enemy": kind })


## A decoy breaks or fades: it is gone (not killed: it is worth nothing), and the screen hears where.
func fade(world) -> void:
	gone = true
	world.events.append({ "kind": "faded", "pos": pos, "enemy": kind })


## A charger's run. Walking, it counts down to the next one, which it starts only on the field with the player in
## range: it fixes its line at the player and paws the ground; then it charges along the line for charge.dist (step()
## moves it and stops it at the field's edge) and stands dazed for charge.rest, when it is easy to hit.
## A charger with charge.count (the boar chief) charges that many times in a row, charge.rest between them and each
## lined up afresh, and after the last stands winded for charge.winded. Its line stops short of the torch (_run()),
## and a line the torch leaves too short to be a charge (shorter than lane_half()) is not started.
func _charge(world) -> void:
	var C: Dictionary = T.charge
	var p = world.player
	match move:
		"":
			move_t = maxf(0.0, move_t - Config.STEP)
			var at: Vector2 = (p.pos - pos).normalized() if p.pos != pos else Vector2.RIGHT
			if move_t <= 0.0 and not p.dead and pos.distance_to(p.pos) <= C.range and Config.FIELD.has_point(pos) and _run(at) >= lane_half():
				if runs_left <= 0:
					runs_left = C.get("count", 1)
				move = "warn"
				move_t = C.warn
				aim = at
				run = _run(aim)
				move_to = pos + aim * run
				world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })
		"warn":
			move_t -= Config.STEP
			run = _run(aim)
			move_to = pos + aim * run # a blow can push it while it paws; the line goes with it
			if move_t <= 0.0:
				move = "charge"
				move_t = run / C.speed
		"charge":
			move_t -= Config.STEP
			if move_t <= 0.0:
				_daze()
		"rest":
			move_t -= Config.STEP
			if move_t <= 0.0:
				move = ""
				move_t = C.every if runs_left <= 0 else 0.0


## How far a charge along dir from here goes: charge.dist, or, for a charger with charge.torch_gap, only up to
## where its body would come within that gap of touching the torch. Nothing, when it stands inside that already and
## dir leads further in.
func _run(dir: Vector2) -> float:
	var C: Dictionary = T.charge
	if not C.has("torch_gap"):
		return C.dist
	var keep: float = Config.TORCH.reach + T.radius + C.torch_gap
	var to: Vector2 = Config.TORCH.pos - pos
	var along: float = to.dot(dir)
	var off2: float = to.length_squared() - along * along
	if along <= 0.0 or off2 >= keep * keep:
		return C.dist
	return clampf(along - sqrt(keep * keep - off2), 0.0, C.dist)


## The charge is over: it stands for rest_time().
func _daze() -> void:
	runs_left -= 1
	move = "rest"
	move_t = rest_time()


## How long the stop after the charge just made lasts: charge.rest, or charge.winded after the last of a set.
func rest_time() -> float:
	return T.charge.winded if runs_left <= 0 and T.charge.has("winded") else T.charge.rest


## Standing still after the last charge of a set: dazed (the boar) or winded (the chief), the time to cut it.
func spent() -> bool:
	return move == "rest" and runs_left <= 0


## A charging chief ploughs the logs it runs into: each within charge.plough of its body is pushed out to that
## distance, ahead and aside, and stays on the field.
func _plough(world) -> void:
	var reach: float = T.radius + T.charge.plough
	for i in world.logs.size():
		var off: Vector2 = world.logs[i] - pos
		if off.length() < reach:
			world.logs[i] = (pos + (off if off != Vector2.ZERO else aim).normalized() * reach).clamp(Config.FIELD.position, Config.FIELD.end)


## Whether a spitter spits from where it stands: on the field, the keeper no further than spit.range.
func spits_from_here(world) -> bool:
	return Config.FIELD.has_point(pos) and pos.distance_to(world.player.pos) <= T.spit.range


## A spitter's spit. Standing off, it counts down to the next one; then it fixes its line at the keeper and puffs up
## for spit.warn, and lets a blob go along the line (World.blobs: the world flies it).
func _spit(world) -> void:
	var S: Dictionary = T.spit
	var p = world.player
	if move == "":
		move_t = maxf(0.0, move_t - Config.STEP)
		if move_t <= 0.0 and not p.dead and spits_from_here(world):
			move = "warn"
			move_t = S.warn
			aim = (p.pos - pos).normalized() if p.pos != pos else Vector2.RIGHT
			move_to = pos + aim * S.reach
			world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })
	elif move == "warn":
		move_t -= Config.STEP
		move_to = pos + aim * S.reach # a blow can push it while it puffs; the line goes with it
		if move_t <= 0.0:
			move = ""
			move_t = S.every
			world.blobs.append({ "pos": pos, "dir": aim, "left": S.reach, "radius": S.radius, "speed": S.speed })
			world.events.append({ "kind": "spat", "pos": pos, "enemy": kind })


## A drummer's beat, every drum.beat seconds once it is on the field: every other enemy within drum.radius of it
## (drummers and decoys excepted) hears it, and walks faster until the next beat (step() reads drum).
func _drum(world) -> void:
	move_t -= Config.STEP
	if move_t > 0.0 or not Config.FIELD.has_point(pos):
		return
	move_t = T.drum.beat
	world.events.append({ "kind": "beat", "pos": pos, "enemy": kind })
	for e in world.enemies:
		if not e.dead and not e.decoy and not e.T.has("drum") and pos.distance_to(e.pos) <= T.drum.radius:
			e.drum = self
			e.drum_t = T.drum.beat + Config.STEP


## How far from a charger's line its charge hurts: its body and the keeper's touch (touches()) all along the run.
## The painter's band is this wide each side of the line, so outside the band is out of reach.
func lane_half() -> float:
	return T.radius + Config.PLAYER.radius


## Where the charge lined up (or under way) ends: at move_to, charge.dist along its line, or sooner where the line
## leaves the field (step() stops it at the trees).
func charge_end() -> Vector2:
	var end: Vector2 = move_to
	if Config.FIELD.has_point(end):
		return end
	var f: Rect2 = Config.FIELD
	var t := 1.0
	for axis in 2:
		var d: float = end[axis] - pos[axis]
		if d > 0.0:
			t = minf(t, (f.end[axis] - pos[axis]) / d)
		elif d < 0.0:
			t = minf(t, (f.position[axis] - pos[axis]) / d)
	return pos.lerp(end, clampf(t, 0.0, 1.0))


## Where it is heading. A boss that circles the light aims a little ahead of itself on a ring outside it, unless it is
## rushing the torch. A thief goes for the nearest log, shadows the player when there is none, and once it has
## one runs straight away from the torch.
func _goal(world) -> Vector2:
	if pattern == "lunge" and move == "":
		var out: Vector2 = pos - Config.TORCH.pos
		var r: float = world.light_radius() + T.lunge.ring + T.radius
		# aiming at a point on the ring ahead would cut inside it; aiming this much further out keeps it on the ring.
		# Where the ring runs past the field (a big light) it goes along the edge instead, so it stays on screen and
		# out from under the HUD.
		var aim: Vector2 = Config.TORCH.pos + (out if out != Vector2.ZERO else Vector2.RIGHT).normalized().rotated(E.orbit_lead) * r / cos(E.orbit_lead)
		var inside := Config.FIELD.grow_individual(-T.radius, -E.orbit_top, -T.radius, -T.radius)
		return aim.clamp(inside.position, inside.end)
	if T.target == "torch":
		return Config.TORCH.pos
	if T.target == "light": # its place on the edge of the light, straight out from the torch through where it stands
		var out: Vector2 = pos - Config.TORCH.pos
		var at: Vector2 = Config.TORCH.pos + (out if out != Vector2.ZERO else Vector2.RIGHT).normalized() * (world.light_radius() + T.drum.gap + T.radius)
		return at.clamp(Config.FIELD.position + Vector2(T.radius, T.radius), Config.FIELD.end - Vector2(T.radius, T.radius))
	if T.target == "log":
		if carrying:
			var away: Vector2 = pos - Config.TORCH.pos
			return pos + (away if away != Vector2.ZERO else Vector2.RIGHT).normalized() * Config.FIELD.size.x
		var best = null
		for l in world.logs:
			if best == null or pos.distance_to(l) < pos.distance_to(best):
				best = l
		if best != null:
			return best
	return world.player.pos


## A thief takes a log it reaches, or one of those the player is carrying (one only: a woodcutter's stack loses its
## top log), and is gone once it is off the field with it.
func _thieve(world) -> void:
	if carrying:
		gone = not Config.FIELD.grow(E.edge).has_point(pos)
		return
	for i in world.logs.size():
		if pos.distance_to(world.logs[i]) < E.steal:
			world.logs.remove_at(i)
			carrying = true
			return
	var p = world.player
	if p.carrying and not p.dead and touches(p):
		p.lose_log()
		carrying = true


## Up in the air during a leap: it touches nothing until it lands. A decoy touches nothing at all.
func touches(p) -> bool:
	if move == "air" or decoy:
		return false
	return pos.distance_to(p.pos) < T.radius + Config.PLAYER.radius


func hit(dmg: int, from_pos: Vector2, push := 1.0) -> void:
	hp -= dmg
	flash = E.flash
	knock = (pos - from_pos).normalized() * E.knock * T.get("heavy", 1.0) * push
	if hp <= 0:
		dead = true
