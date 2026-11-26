## An enemy, seen from above. Its row in Config.ENEMY_TYPES says what it goes for: the torch, to smother it; the
## player, to hurt them; or a log, to carry it off the field. It gets knocked back when hit. In the torch's light
## the warm glow slows it; out of it, a kind with dark_speed_mult hunts faster.
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


func _init(kind_: String, pos_: Vector2) -> void:
	kind = kind_
	T = Config.ENEMY_TYPES[kind]
	pos = pos_
	hp = T.hp
	if T.has("summon"):
		summon_t = T.summon.every


func step(world) -> void:
	flash = maxf(0.0, flash - Config.STEP)
	var stop: float = Config.TORCH.reach + T.radius if T.target == "torch" else 0.0
	var to := _goal(world) - pos
	at_torch = T.target == "torch" and to.length() <= stop
	var speed: float = T.speed * (world.mod("glow_slow", 1.0) if world.in_light(pos) else T.get("dark_speed_mult", 1.0))
	vel = knock if knock != Vector2.ZERO else (Vector2.ZERO if at_torch else to.normalized() * speed)
	knock *= pow(E.knock_decay, Config.STEP)
	if knock.length() < E.knock_stop:
		knock = Vector2.ZERO
	pos += vel * Config.STEP
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


## Where it is heading. A thief goes for the nearest log, shadows the player when there is none, and once it has
## one runs straight away from the torch.
func _goal(world) -> Vector2:
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


func touches(p) -> bool:
	return pos.distance_to(p.pos) < T.radius + Config.PLAYER.radius


func hit(dmg: int, from_pos: Vector2) -> void:
	hp -= dmg
	flash = E.flash
	knock = (pos - from_pos).normalized() * E.knock * T.get("heavy", 1.0)
	if hp <= 0:
		dead = true
