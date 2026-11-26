## An enemy, seen from above. Its row in Config.ENEMY_TYPES says what it goes for: the torch, to smother it; the
## player, to hurt them; or a log, to carry it off the field. It gets knocked back when hit. In the torch's light
## the warm glow slows it; out of it, a kind with dark_speed_mult hunts faster.
## A boss also has a pattern, always warned before it strikes (move says which part it is in): the slime king leaps
## at the player and shakes the ground where it lands; the shade lord circles in the dark and now and then rushes
## the torch. The world tells the screen "warn" { pos, at, enemy } when one is about to strike (at: where it will) and
## "landed" { pos, enemy } when the slime king comes down.
## A charger (the boar) has a pattern too: it stops and paws the ground with its line drawn, charges straight along
## it, and stands dazed where the charge ends. It tells "warn" as well, at: the end of its line.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const E := Config.ENEMY

var kind: String
var T: Dictionary
var pos: Vector2
var vel := Vector2.ZERO
var hp: int
var knock := Vector2.ZERO
var flash := 0.0
var dead := false
var gone := false # left the field with a log: it is removed, but that is not a kill
var at_torch := false # a smotherer that has reached the torch
var carrying := false # a thief holding a log
var summon_t := 0.0 # time until it next calls its kind (a boss with summon in its row)
var move := "" # a pattern: "" (walking), "warn" (about to strike), "air" (the king's leap), "lunge", "stay" (the lord's rush and its time at the torch), "charge", "rest" (a charger's run and its daze after)
var move_t := 0.0 # time left in this part of the pattern, or, walking, until the next strike
var move_from := Vector2.ZERO # where the leap took off
var move_to := Vector2.ZERO # where it lands, or where the rush goes, or where a charge would end
var aim := Vector2.ZERO # the way a charger charges, fixed when it starts to warn


func _init(kind_: String, pos_: Vector2) -> void:
	kind = kind_
	T = Config.ENEMY_TYPES[kind]
	pos = pos_
	hp = T.hp
	if T.has("summon"):
		summon_t = T.summon.every
	if T.has("leap"):
		move_t = T.leap.every
	if T.has("lunge"):
		move_t = T.lunge.every
	if T.has("charge"):
		move_t = T.charge.every


func step(world) -> void:
	flash = maxf(0.0, flash - Config.STEP)
	var flying := move == "air" # through the step it lands on, too
	if T.has("leap"):
		_leap(world)
	if T.has("lunge"):
		_lunge(world)
	if T.has("charge"):
		_charge(world)
	if flying:
		at_torch = false
		knock = Vector2.ZERO
		if T.has("summon"):
			_summon(world)
		return
	var stop: float = Config.TORCH.reach + T.radius if T.target == "torch" else 0.0
	at_torch = T.target == "torch" and (Config.TORCH.pos - pos).length() <= stop
	if move == "lunge" and at_torch:
		move = "stay"
		move_t = T.lunge.stay
	var to: Vector2 = (_goal(world) - pos).normalized()
	var speed: float = T.speed * (world.mod("glow_slow", 1.0) if world.in_light(pos) else T.get("dark_speed_mult", 1.0))
	if move == "lunge":
		speed = T.lunge.speed
	if move == "charge": # nothing turns a charge aside, blows neither
		speed = T.charge.speed
		to = aim
		knock = Vector2.ZERO
	# Most smotherers stop at the torch; the shade lord stops only while it warns and while it stays, so it can leave.
	var halt: bool = move in ["warn", "stay", "rest"] or (at_torch and not T.has("lunge"))
	vel = knock if knock != Vector2.ZERO else (Vector2.ZERO if halt else to * speed)
	knock *= pow(E.knock_decay, Config.STEP)
	if knock.length() < E.knock_stop:
		knock = Vector2.ZERO
	pos += vel * Config.STEP
	if move == "charge" and not Config.FIELD.has_point(pos): # it runs into the trees at the edge and stops there
		pos = pos.clamp(Config.FIELD.position, Config.FIELD.end)
		_daze()
	if T.target == "log":
		_thieve(world)
	if T.has("summon"):
		_summon(world)


## A boss calls its kind around itself every so often. They join the fight at the end of the step.
func _summon(world) -> void:
	summon_t -= Config.STEP
	if summon_t > 0.0:
		return
	summon_t += T.summon.every
	for i in T.summon.count:
		var around: Vector2 = Vector2.from_angle(TAU * i / T.summon.count + world.time) * (T.radius + E.summon_gap)
		world.born.append(get_script().new(T.summon.kind, pos + around))


## The slime king's leap. Walking, it counts down to the next one, which it starts only with the player in range: it
## marks where the player stands and crouches; then it flies there, and where it lands it hurts a player too close.
func _leap(world) -> void:
	var L: Dictionary = T.leap
	var p = world.player
	match move:
		"":
			move_t = maxf(0.0, move_t - Config.STEP)
			if move_t <= 0.0 and not p.dead and pos.distance_to(p.pos) <= L.range:
				move = "warn"
				move_t = L.warn
				move_from = pos
				move_to = _off_torch(p.pos, L.torch_gap)
				world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })
		"warn":
			move_t -= Config.STEP
			move_from = pos
			if move_t <= 0.0:
				move = "air"
				move_t = L.air
		"air":
			move_t -= Config.STEP
			pos = move_from.lerp(move_to, clampf(1.0 - move_t / L.air, 0.0, 1.0))
			if move_t <= 0.0:
				pos = move_to
				move = ""
				move_t = L.every
				world.events.append({ "kind": "landed", "pos": pos, "enemy": kind })
				if pos.distance_to(p.pos) < L.shock + Config.PLAYER.radius:
					p.hurt(pos)


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
			if move_t <= 0.0:
				move = "warn"
				move_t = L.warn
				move_to = Config.TORCH.pos
				world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })
		"warn":
			move_t -= Config.STEP
			if move_t <= 0.0:
				move = "lunge"
		"stay":
			move_t -= Config.STEP
			if move_t <= 0.0:
				move = ""
				move_t = L.every


## A charger's run. Walking, it counts down to the next one, which it starts only on the field with the player in
## range: it fixes its line at the player and paws the ground; then it charges along the line for charge.dist (step()
## moves it and stops it at the field's edge) and stands dazed for charge.rest, when it is easy to hit.
func _charge(world) -> void:
	var C: Dictionary = T.charge
	var p = world.player
	match move:
		"":
			move_t = maxf(0.0, move_t - Config.STEP)
			if move_t <= 0.0 and not p.dead and pos.distance_to(p.pos) <= C.range and Config.FIELD.has_point(pos):
				move = "warn"
				move_t = C.warn
				aim = (p.pos - pos).normalized() if p.pos != pos else Vector2.RIGHT
				move_to = pos + aim * C.dist
				world.events.append({ "kind": "warn", "pos": pos, "at": move_to, "enemy": kind })
		"warn":
			move_t -= Config.STEP
			move_to = pos + aim * C.dist # a blow can push it while it paws; the line goes with it
			if move_t <= 0.0:
				move = "charge"
				move_t = C.dist / C.speed
		"charge":
			move_t -= Config.STEP
			if move_t <= 0.0:
				_daze()
		"rest":
			move_t -= Config.STEP
			if move_t <= 0.0:
				move = ""
				move_t = C.every


func _daze() -> void:
	move = "rest"
	move_t = T.charge.rest


## Where it is heading. A boss that circles the light aims a little ahead of itself on a ring outside it, unless it is
## rushing the torch. A thief goes for the nearest log, shadows the player when there is none, and once it has
## one runs straight away from the torch.
func _goal(world) -> Vector2:
	if T.has("lunge") and move == "":
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


## A thief takes a log it reaches, or the one the player is carrying, and is gone once it is off the field with it.
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
		p.carrying = false
		carrying = true


## Up in the air during a leap: it touches nothing until it lands.
func touches(p) -> bool:
	if move == "air":
		return false
	return pos.distance_to(p.pos) < T.radius + Config.PLAYER.radius


func hit(dmg: int, from_pos: Vector2) -> void:
	hp -= dmg
	flash = E.flash
	knock = (pos - from_pos).normalized() * E.knock * T.get("heavy", 1.0)
	if hp <= 0:
		dead = true
