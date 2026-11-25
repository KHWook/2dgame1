## The simulation: keeping the torch alive night after night. Pure data (S1): no nodes, no engine input, no clock.
## Same seed + same inputs = same game, step for step (tools/replay_test.gd holds us to it).
##
## Phases: "pick" (time stands still while you choose a torch upgrade: at every dusk, and at set hours of the
## night), "night", and the two endings, "out" (the torch died) and "dead" (you did). Reaching dawn starts the next
## night. R restarts from an ending.
##
## events is how the world tells whoever shows it what happened in the last step. The rules only add to it and
## never read it. Kinds: "hit" and "kill" { pos, dir (away from the blow), enemy (its kind) }; "passed", the same
## for a blow that went through an enemy the dark protects; "banished", the same for an enemy the dawn clears
## away; "fed" { pos } for a log put on the torch; "healed" { pos } for a berry eaten or a blade that drank enough;
## "dawn" { night } for the night that just ended; "shot" { pos } for a spark the torch fired; "boss" { enemy, pos }
## for a boss that came out of the dark.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Player := preload("res://src/sim/player.gd")
const Enemy := preload("res://src/sim/enemy.gd")
const T := Config.TORCH
const N := Config.NIGHT

var seed_value: int
var rng
var phase := "pick"
var night := 1 # which night this is, from 1
var time := 0.0 # seconds into this night; stands still while picking
var steps := 0
var schedule: Array = [] # [{ "at": night time, "fn": Callable }]: things that happen later (D3)
var player
var enemies: Array = []
var born: Array = [] # enemies that appeared during this step (a big slime's halves); they join enemies at its end
var logs: Array = [] # Vector2 positions on the ground
var berries: Array = [] # Vector2 positions on the ground
var fuel := 0.0
var score := 0
var picks: Array = [] # upgrade ids chosen so far, in order
var offer: Array = [] # upgrade ids on the table while phase == "pick"
var picks_done := 0 # how many of NIGHT.picks_at have been offered
var next_spawn := 0.0
var next_wood := 0.0
var next_berry := 0.0
var next_ember := 0.0
var next_spark := 0.0
var next_thorn := 0.0
var sparks: Array = [] # embers the torch fired: { pos, vel, life }
var boss_due := false # a boss is still to come tonight
var blade_kills := 0 # kills by the sword toward the next heal from the vampire upgrade
var events: Array = [] # what happened in the last step; see the top of this file


func _init(seed_value_: int = 1) -> void:
	seed_value = seed_value_
	reset()


func reset() -> void:
	rng = SimRng.new(seed_value)
	events = []
	night = 1
	time = 0.0
	steps = 0
	schedule = []
	enemies = []
	born = []
	logs = []
	berries = []
	fuel = T.start_fuel
	score = 0
	picks = []
	picks_done = 0
	next_spawn = N.first_spawn
	next_wood = Config.WOOD.first
	next_berry = Config.BERRY.first
	next_ember = 0.0
	next_spark = 0.0
	next_thorn = 0.0
	sparks = []
	blade_kills = 0
	boss_due = _boss_night()
	player = Player.new()
	_offer()


## Run fn after delay night seconds. Never use engine timers in the simulation.
func later(delay: float, fn: Callable) -> void:
	schedule.append({ "at": time + delay, "fn": fn })


## The value an upgrade sets for key, at the level you have it, or fallback when no picked upgrade sets it.
## Multipliers from different upgrades stack by product.
func mod(key: String, fallback):
	var v = fallback
	for id in Config.UPGRADES:
		var n := level(id)
		if n == 0:
			continue
		var u := upgrade(id, n)
		if not u.has(key):
			continue
		v = v * u[key] if key.ends_with("_mult") or key == "glow_slow" else u[key]
	return v


## How many times you have taken this upgrade: its level, 0 when you do not have it.
func level(id: String) -> int:
	return picks.count(id)


## An upgrade's row at a level from 1: the row with its levels merged over it up to that one.
static func upgrade(id: String, at_level: int) -> Dictionary:
	var u: Dictionary = Config.UPGRADES[id].duplicate()
	var levels: Array = u.get("levels", [])
	for i in mini(at_level - 1, levels.size()):
		u.merge(levels[i], true)
	return u


static func max_level(id: String) -> int:
	return 1 + Config.UPGRADES[id].get("levels", []).size()


## How much fuel the torch holds.
func max_fuel() -> float:
	return T.max_fuel + mod("fuel_bonus", 0.0)


func light_radius() -> float:
	# A big torch's extra fuel is a reserve: the light is as bright as it gets at the usual full tank.
	return lerpf(T.light_min, T.light_max, clampf(fuel / T.max_fuel, 0.0, 1.0)) * mod("light_mult", 1.0)


func in_light(p: Vector2) -> bool:
	return p.distance_to(T.pos) <= light_radius()


func max_hp() -> int:
	return Config.PLAYER.hp + mod("hp_bonus", 0)


## How far the swing reaches, and how wide it is: a blow lands when the direction to the enemy, dotted with the
## facing, is above arc().
func reach() -> float:
	return Config.PLAYER.reach + mod("reach_bonus", 0.0)


func arc() -> float:
	return Config.PLAYER.arc + mod("arc_bonus", 0.0)


## The arc of the swing under way: all the way round for a spin.
func blow_arc() -> float:
	return -1.01 if player.spin else arc()


func step(inp) -> void:
	steps += 1
	events = []
	if phase in ["out", "dead"]:
		if inp.is_pressed("restart"):
			reset()
		return
	if phase == "pick":
		for i in offer.size():
			if inp.is_pressed("pick_%d" % (i + 1)):
				_take(offer[i])
				break
		return
	time += Config.STEP
	var due := schedule.filter(func(s): return s.at <= time)
	schedule = schedule.filter(func(s): return s.at > time)
	for s in due:
		s.fn.call()
	player.step(self, inp)
	_haul()
	_forage()
	for e in enemies:
		if e.dead:
			continue
		e.step(self)
		if not e.T.get("harmless", false) and e.touches(player) and player.hurt(e.pos):
			var thorns: int = mod("thorns", 0)
			if thorns > 0:
				_damage(e, thorns, player.pos)
	_prickle()
	_torch()
	_sparks()
	enemies = enemies.filter(func(e): return not e.dead and not e.gone) + born
	born = []
	_spawns()
	_end_or_offer()


## Put three upgrades on the table, ones you don't have yet or the next level of ones you do, and stop the clock.
func _offer() -> void:
	var pool: Array = Config.UPGRADES.keys().filter(func(id): return level(id) < max_level(id))
	offer = []
	while offer.size() < N.offer_size and not pool.is_empty():
		offer.append(pool.pop_at(rng.index(pool.size())))
	phase = "pick" if not offer.is_empty() else "night"


## Take an offered upgrade. Most only change what mod() answers; hp_bonus also heals by as much as it grew, now.
func _take(id: String) -> void:
	var before: int = upgrade(id, level(id)).get("hp_bonus", 0) if level(id) > 0 else 0
	picks.append(id)
	offer = []
	phase = "night"
	player.hp += upgrade(id, level(id)).get("hp_bonus", 0) - before


func _end_or_offer() -> void:
	if player.dead:
		phase = "dead"
	elif fuel <= 0.0:
		phase = "out"
	elif time >= N.length:
		_dawn()
	elif picks_done < N.picks_at.size() and time >= N.length * N.picks_at[picks_done]:
		picks_done += 1
		_offer()


## The night is over. The sun clears the field, you rest, the torch is topped up, and the next night begins with
## the torch's offer.
func _dawn() -> void:
	score += Config.SCORE.dawn
	events.append({ "kind": "dawn", "night": night })
	for e in enemies + born:
		events.append({ "kind": "banished", "pos": e.pos, "dir": Vector2.UP, "enemy": e.kind })
		if e.carrying:
			logs.append(e.pos.clamp(Config.FIELD.position, Config.FIELD.end))
	enemies = []
	born = []
	schedule = []
	night += 1
	time = 0.0
	picks_done = 0
	next_spawn = N.first_spawn
	next_wood = Config.WOOD.first
	next_berry = Config.BERRY.first
	next_ember = 0.0
	next_spark = 0.0
	next_thorn = 0.0
	sparks = []
	boss_due = _boss_night()
	player.hp = mini(max_hp(), player.hp + Config.DAWN.heal)
	fuel = maxf(fuel, T.start_fuel * max_fuel() / T.max_fuel)
	_offer()


func _haul() -> void:
	var p = player
	if p.dead:
		return
	if p.dropped != null and p.pos.distance_to(p.dropped) >= Config.PLAYER.grab:
		p.dropped = null
	if not p.carrying:
		for i in logs.size():
			# You pick a log up by walking onto it, so the one you just put down stays down until you step off it.
			if logs[i] != p.dropped and p.pos.distance_to(logs[i]) < Config.PLAYER.grab:
				logs.remove_at(i)
				p.carrying = true
				break
	elif p.pos.distance_to(T.pos) < T.reach + Config.PLAYER.radius:
		p.carrying = false
		fuel = minf(max_fuel(), fuel + T.log_fuel + mod("log_bonus", 0.0))
		score += Config.SCORE.log
		events.append({ "kind": "fed", "pos": T.pos })


func drop_log(at: Vector2) -> void:
	logs.append(at)


## A hurt player who walks over a berry eats it. At full health it stays where it is.
func _forage() -> void:
	var p = player
	if p.dead or p.hp >= max_hp():
		return
	for i in berries.size():
		if p.pos.distance_to(berries[i]) < Config.PLAYER.grab:
			berries.remove_at(i)
			p.hp = mini(max_hp(), p.hp + Config.BERRY.heal)
			events.append({ "kind": "healed", "pos": p.pos })
			break


## Fuel the torch uses per second right now: tonight's burn with upgrades, plus whatever is smothering it (less
## with the ember ring: an enemy at the torch is always inside the ring).
func burn_rate() -> float:
	var smothering := 0.0
	for e in enemies:
		if e.at_torch and not e.dead:
			smothering += e.T.get("smother", 1.0)
	return burn() * mod("burn_mult", 1.0) + T.smother * smothering * mod("smother_mult", 1.0)


func _torch() -> void:
	fuel -= burn_rate() * Config.STEP
	var ring: float = mod("ember_radius", 0.0)
	if ring > 0.0 and time >= next_ember:
		next_ember = time + mod("ember_every", 1.0)
		for e in enemies:
			# The ring scorches but never kills: the last point is left for you to strike.
			if e.hp > 1 and e.pos.distance_to(T.pos) <= ring:
				_damage(e, 1, T.pos)
	var every: float = mod("spark_every", 0.0)
	if every > 0.0 and time >= next_spark:
		var target = null # the nearest enemy in the light
		for e in enemies:
			if not e.dead and in_light(e.pos) and (target == null or e.pos.distance_to(T.pos) < target.pos.distance_to(T.pos)):
				target = e
		if target != null:
			next_spark = time + every
			var from: Vector2 = T.pos + Config.SPARK.mouth
			sparks.append({ "pos": from, "vel": (target.pos - from).normalized() * Config.SPARK.speed, "life": Config.SPARK.life })
			events.append({ "kind": "shot", "pos": from })


## The thorn cloak pricks every enemy pressed up against you every so often, besides hurting the ones that hit you.
func _prickle() -> void:
	var every: float = mod("thorn_every", 0.0)
	if every <= 0.0 or time < next_thorn or player.dead:
		return
	next_thorn = time + every
	for e in enemies:
		if not e.dead and e.pos.distance_to(player.pos) < e.T.radius + Config.PLAYER.radius + mod("thorn_reach", 0.0):
			_damage(e, 1, player.pos)


## Sparks fly straight and burn the first enemy they touch.
func _sparks() -> void:
	for sp in sparks:
		sp.pos += sp.vel * Config.STEP
		sp.life -= Config.STEP
		for e in enemies:
			if not e.dead and sp.pos.distance_to(e.pos) < e.T.radius + Config.SPARK.radius:
				_damage(e, Config.SPARK.damage, sp.pos - sp.vel * Config.STEP)
				sp.life = 0.0
				break
	sparks = sparks.filter(func(sp): return sp.life > 0.0)


## A swing turns toward the nearest enemy within aim range, so backing off and swinging works. Otherwise it keeps face.
func aim(from: Vector2, face: Vector2) -> Vector2:
	var best = null
	var aim_range: float = reach() + Config.PLAYER.aim_slack
	for e in enemies:
		var d: float = from.distance_to(e.pos) - e.T.radius
		if d < aim_range and (best == null or d < from.distance_to(best.pos) - best.T.radius):
			best = e
	return face if best == null else (best.pos - from).normalized()


## The player's swing lands: hit everything in the facing arc within reach.
func melee(p) -> void:
	var dmg: int = 1 + (mod("lit_damage", 0) if in_light(p.pos) else 0)
	for e in enemies:
		var to: Vector2 = e.pos - p.pos
		if to.length() < reach() + e.T.radius and to.normalized().dot(p.face) > blow_arc():
			_damage(e, dmg, p.pos, true)


## A blow of n lands on e, struck from from (by the sword when blade). The dark protects some enemies; a thief drops
## its log when it dies; a big slime breaks into smaller ones, which join the fight at the end of the step; with the
## vampire upgrade enough sword kills heal you.
func _damage(e, n: int, from: Vector2, blade := false) -> void:
	if e.dead:
		return
	var dir: Vector2 = (e.pos - from).normalized()
	if e.T.get("dark_proof", false) and not in_light(e.pos):
		events.append({ "kind": "passed", "pos": e.pos, "dir": dir, "enemy": e.kind })
		return
	e.hit(n, from)
	events.append({ "kind": "kill" if e.dead else "hit", "pos": e.pos, "dir": dir, "enemy": e.kind })
	if not e.dead:
		return
	score += e.T.get("score", Config.SCORE.kill)
	var thirst: int = mod("vamp_kills", 0)
	if blade and thirst > 0:
		blade_kills = mini(blade_kills + 1, thirst)
		if blade_kills >= thirst and player.hp < max_hp() and not player.dead:
			blade_kills = 0
			player.hp += 1
			events.append({ "kind": "healed", "pos": player.pos })
	if e.carrying:
		logs.append(e.pos)
	for i in e.T.get("split_count", 0):
		var side := -1.0 if i % 2 == 0 else 1.0
		var half = Enemy.new(e.T.splits_into, e.pos + Vector2(side * Config.ENEMY.split_spread, 0.0))
		half.knock = Vector2(side * Config.ENEMY.split_knock, 0.0)
		born.append(half)


func _spawns() -> void:
	if time >= next_spawn:
		var row := _night_row()
		var apart: float = lerpf(row.spawn[0], row.spawn[1], clampf(time / N.length, 0.0, 1.0))
		next_spawn = time + apart * pow(Config.LATER_NIGHTS.spawn, _nights_past()) * (Config.BOSS.spawn_mult if _boss_night() else 1.0)
		enemies.append(Enemy.new(_who(row.who), _edge_point()))
	if boss_due and time >= N.length * Config.BOSS.at:
		boss_due = false
		var boss = Enemy.new(boss_kind(), _edge_point())
		enemies.append(boss)
		events.append({ "kind": "boss", "enemy": boss.kind, "pos": boss.pos })
	if time >= next_wood:
		next_wood = time + Config.WOOD.every * mod("wood_mult", 1.0)
		if logs.size() < Config.WOOD.max_on_ground + mod("wood_extra", 0):
			var spot = _free_spot(Config.WOOD.keep_away)
			if spot != null:
				logs.append(spot)
	if time >= next_berry:
		next_berry = time + Config.BERRY.every
		if berries.size() < Config.BERRY.max_on_ground:
			var spot = _free_spot(Config.BERRY.keep_away)
			if spot != null:
				berries.append(spot)


## Whether a boss comes tonight.
func _boss_night() -> bool:
	return night % Config.BOSS.every == 0


## Which boss comes on this boss night: they take turns.
func boss_kind() -> String:
	var kinds: Array = Config.BOSS.kinds
	return kinds[(night / Config.BOSS.every - 1) % kinds.size()]


## This night's row of Config.NIGHTS; nights past the table use its last row.
func _night_row() -> Dictionary:
	return Config.NIGHTS[mini(night, Config.NIGHTS.size()) - 1]


## How many nights past the end of Config.NIGHTS this one is.
func _nights_past() -> int:
	return maxi(0, night - Config.NIGHTS.size())


## Fuel the torch uses per second tonight, before upgrades.
func burn() -> float:
	return _night_row().burn + Config.LATER_NIGHTS.burn * _nights_past()


## Which kind comes out of the dark: one roll over the shares in a night's row.
func _who(shares: Dictionary) -> String:
	var total := 0.0
	for kind in shares:
		total += shares[kind]
	var roll: float = rng.next() * total
	for kind in shares:
		roll -= shares[kind]
		if roll < 0.0:
			return kind
	return shares.keys()[-1]


## A point just outside a random screen edge.
func _edge_point() -> Vector2:
	var f := Config.FIELD.grow(Config.ENEMY.edge)
	var t: float = rng.next() * 2.0 * (f.size.x + f.size.y)
	if t < f.size.x:
		return Vector2(f.position.x + t, f.position.y)
	t -= f.size.x
	if t < f.size.y:
		return Vector2(f.end.x, f.position.y + t)
	t -= f.size.y
	if t < f.size.x:
		return Vector2(f.end.x - t, f.end.y)
	return Vector2(f.position.x, f.end.y - (t - f.size.x))


## A random spot on the field at least keep_away from the torch, or null when the tries run out.
func _free_spot(keep_away: float):
	var f := Config.FIELD.grow(-8.0)
	for i in Config.SPOT_TRIES:
		var p := Vector2(rng.range_f(f.position.x, f.end.x), rng.range_f(f.position.y, f.end.y))
		if p.distance_to(T.pos) >= keep_away:
			return p
	return null
