## The simulation: keeping the torch alive night after night. Pure data (S1): no nodes, no engine input, no clock.
## Same seed + same inputs = same game, step for step (tools/replay_test.gd holds us to it).
##
## Phases: "pick" (time stands still while you choose a torch upgrade: at every dusk, and at set hours of the
## night), "night", and the two endings, "out" (the torch died) and "dead" (you did). Reaching dawn starts the next
## night. R restarts from an ending.
##
## events is how the world tells whoever shows it what happened in the last step. The rules only add to it and
## never read it. Kinds: "hit" and "kill" { pos, dir (away from the blow), enemy (its kind), tier }; "passed", the same
## for a blow that went through an enemy the dark protects; "banished", the same for an enemy the dawn clears
## away; "fed" { pos } for a log put on the torch; "healed" { pos } for a berry eaten or a blade that drank enough;
## "dawn" { night } for the night that just ended; "shot" { pos } for a spark the torch fired; "cast" { pos } for an
## ember the keeper fired (a character whose attack is "shoot"); "boss" { enemy, pos }
## for a boss that came out of the dark; "coming" { enemy, pos } Config.BOSS.warn seconds before it does, from
## there; "warn" { pos, at, enemy } for a boss about to strike (at: where), "landed" { pos, enemy } for the slime
## king coming down from a leap or a hop, "decoy" { pos, enemy } where the shade lord's decoy appears and "faded"
## { pos, enemy } where one breaks or fades (src/sim/enemy.gd).
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Player := preload("res://src/sim/player.gd")
const Enemy := preload("res://src/sim/enemy.gd")
const T := Config.TORCH
const N := Config.NIGHT

var seed_value: int
var character := "knight" # who keeps the torch this run (Config.CHARACTERS); choose() changes it
var stats: Dictionary # Config.PLAYER with the character's stats over it: the player's numbers
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
var bolts: Array = [] # embers the keeper fired: { pos, dir, left (pixels it still flies), radius, pierce, hit (enemies it went through) }
var bosses_due: Array = [] # tonight's bosses still to come, first first: { kind, at (night time), from }; from is
						 # where it comes from once its warning is given (Config.BOSS.warn before at), null until then
var blade_kills := 0 # kills by the sword toward the next heal from the vampire upgrade
var events: Array = [] # what happened in the last step; see the top of this file
var _mods := {} # what mod() looks up: key -> the values the picks set it to (see _remod)
var _mods_for = null # the picks array _mods was worked out for (picks only ever grows, or is replaced)
var _mods_count := -1 # and how many it held then
var _light := 0.0 # light_radius() at _light_fuel
var _light_fuel := NAN


func _init(seed_value_: int = 1, character_: String = "knight") -> void:
	seed_value = seed_value_
	character = character_
	reset()


## Start the run again with another keeper (Config.CHARACTERS): the same seed, so the same night, but the offers
## are drawn again for it. Only before the run's first step, or from an ending.
func choose(id: String) -> void:
	character = id
	reset()


## Config.PLAYER with a character's stats merged over it.
static func character_stats(id: String) -> Dictionary:
	var out: Dictionary = Config.PLAYER.duplicate()
	out.merge(Config.CHARACTERS[id].get("stats", {}), true)
	return out


## One of the keeper's numbers this run (stats), as the upgrades have it now: the times of its attack
## (Config.ATTACK_TIMES) shortened by attack_mult.
func stat(key: String):
	if Config.ATTACK_TIMES.has(key):
		return stats[key] * mod("attack_mult", 1.0)
	return stats[key]


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
	bolts = []
	blade_kills = 0
	bosses_due = _plan_bosses()
	stats = character_stats(character)
	player = Player.new(stats)
	_offer()


## Start at the dusk of night n instead of the first, as if every night before it had been kept: the offers those
## nights would have made are drawn and the one in slot is taken each time (the last slot when fewer are offered),
## the keeper is rested and the torch topped up. For looking at and measuring late nights (the balance tool's
## --late, main.gd's --night=N); a normal run never calls it.
func begin_at(n: int, slot: int) -> void:
	for i in (n - 1) * (1 + N.picks_at.size()):
		if offer.is_empty():
			break
		_take(offer[mini(slot, offer.size()) - 1])
		night = 1 + (i + 1) / (1 + N.picks_at.size()) # the night this next offer is made on (an upgrade's from_night)
		_offer()
	night = n
	bosses_due = _plan_bosses()
	player.invuln_for = keeper_invuln()
	player.hp = max_hp()
	fuel = maxf(fuel, T.start_fuel * max_fuel() / T.max_fuel)


## For measuring crowds (main.gd's --crowd=K): bring the field up to k enemies of tonight's kinds, from the edges,
## heal the keeper and fill the torch, and keep the night from reaching dawn. A normal run never calls it.
func crowd(k: int) -> void:
	if phase != "night":
		return
	while enemies.size() < k:
		enemies.append(Enemy.new(_who(_night_row().who), _edge_point(), _tier()))
	player.hp = max_hp()
	fuel = max_fuel()
	if time > N.length * 0.9:
		time = N.length * 0.6


## Run fn after delay night seconds. Never use engine timers in the simulation.
func later(delay: float, fn: Callable) -> void:
	schedule.append({ "at": time + delay, "fn": fn })


## The value an upgrade sets for key, at the level you have it, or fallback when no picked upgrade sets it.
## Multipliers from different upgrades stack by product.
## Every enemy asks this every step (its light, its speed), so what the picks set is worked out once per change of
## picks (_mods) and only looked up here; the product is taken in the same order as ever, so it is the same float.
func mod(key: String, fallback):
	if not is_same(picks, _mods_for) or picks.size() != _mods_count:
		_remod()
	var set_by = _mods.get(key)
	if set_by == null:
		return fallback
	if not (key.ends_with("_mult") or key == "glow_slow"):
		return set_by[-1]
	var v = fallback
	for f in set_by:
		v = v * f
	return v


## For every key a picked upgrade sets: the values it is set to, in the order of Config.UPGRADES.
func _remod() -> void:
	_mods_for = picks
	_mods_count = picks.size()
	_mods = {}
	for id in Config.UPGRADES:
		var n := level(id)
		if n == 0:
			continue
		var u := upgrade(id, n, character)
		for key in u:
			if not _mods.has(key):
				_mods[key] = []
			_mods[key].append(u[key])


## How many times you have taken this upgrade: its level, 0 when you do not have it.
func level(id: String) -> int:
	return picks.count(id)


## An upgrade's row at a level from 1, as it reads for a character: the row (with the character's as merged over it)
## with its levels merged over it up to that one.
static func upgrade(id: String, at_level: int, who: String = "knight") -> Dictionary:
	var u := upgrade_row(id, who)
	var levels: Array = u.get("levels", [])
	for i in mini(at_level - 1, levels.size()):
		_merge(u, levels[i])
	return u


## An upgrade's row as a character has it: its as for that character merged over it (null takes a key out; levels
## are merged one by one), without the as itself.
static func upgrade_row(id: String, who: String = "knight") -> Dictionary:
	var u: Dictionary = Config.UPGRADES[id].duplicate()
	var over: Dictionary = u.get("as", {}).get(who, {})
	u.erase("as")
	for key in over:
		if key == "levels":
			var levels: Array = u.get("levels", []).duplicate()
			for i in over.levels.size():
				var l: Dictionary = levels[i].duplicate()
				_merge(l, over.levels[i])
				levels[i] = l
			u.levels = levels
		else:
			_merge(u, { key: over[key] })
	return u


## Merges from over into, a key set to null taking it out of into.
static func _merge(into: Dictionary, from: Dictionary) -> void:
	for key in from:
		if from[key] == null:
			into.erase(key)
		else:
			into[key] = from[key]


## Whether the torch may offer this upgrade on night n (its row's from_night, the first night when it has none).
static func offered_on(id: String, n: int) -> bool:
	return n >= Config.UPGRADES[id].get("from_night", 1)


static func max_level(id: String) -> int:
	return 1 + Config.UPGRADES[id].get("levels", []).size()


## How much fuel the torch holds.
func max_fuel() -> float:
	return T.max_fuel + mod("fuel_bonus", 0.0)


## Every enemy asks in_light() every step, so the radius is kept until the fuel or the picks change.
func light_radius() -> float:
	if fuel != _light_fuel or not is_same(picks, _mods_for) or picks.size() != _mods_count:
		# A big torch's extra fuel is a reserve: the light is as bright as it gets at the usual full tank.
		_light = lerpf(T.light_min, T.light_max, clampf(fuel / T.max_fuel, 0.0, 1.0)) * mod("light_mult", 1.0)
		_light_fuel = fuel
	return _light


func in_light(p: Vector2) -> bool:
	return p.distance_to(T.pos) <= light_radius()


func max_hp() -> int:
	return stats.hp + mod("hp_bonus", 0) + hardened_hp()


## The hearts the keeper has gained by tonight (Config.HARDEN): hp_first on night from and one every hp_every nights after.
func hardened_hp() -> int:
	var H: Dictionary = Config.HARDEN
	if night < H.from:
		return 0
	return mini(H.hp_most, H.hp_first + (night - H.from) / H.hp_every)


## How long a hit keeps the keeper from the next tonight (Config.HARDEN): longer night by night from from.
func keeper_invuln() -> float:
	var H: Dictionary = Config.HARDEN
	return minf(H.invuln_most, stats.invuln + H.invuln_grow * maxi(0, night - H.from + 1))


## How far the swing reaches, and how wide it is: arc() is the cosine of the angle each side of the facing it sweeps.
func reach() -> float:
	return stats.reach + mod("reach_bonus", 0.0)


func arc() -> float:
	return stats.arc + mod("arc_bonus", 0.0)


## How far the keeper's ember flies (a shooter: Config.CHARACTERS' bolt), and how big it is.
func bolt_range() -> float:
	return stats.bolt.range + mod("range_bonus", 0.0)


func bolt_radius() -> float:
	return stats.bolt.radius + mod("bolt_bonus", 0.0)


## How far an attack reaches, for aiming: the swing's reach, or how far the ember flies.
func attack_range() -> float:
	return bolt_range() if stats.attack == "shoot" else reach()


## The arc of the swing under way: all the way round for a spin.
func blow_arc() -> float:
	return -1.01 if player.spin else arc()


## The angle each side of the facing the swing under way sweeps, in radians (PI for a spin).
func swing_half() -> float:
	return acos(clampf(blow_arc(), -1.0, 1.0))


## Whether the swing under way reaches a body of radius r at at: the body touches the keeper's own (what presses
## against you is cut, behind you too), or some of it is inside the swept sector, reach() from the keeper and
## swing_half() each side of the facing, allowing for the body's size. The painter draws the trail inside this
## sector (src/art/painter.gd), so whatever the trail passes over is struck.
func in_swing(at: Vector2, r: float) -> bool:
	var to: Vector2 = at - player.pos
	var d := to.length()
	if d < r + stats.radius:
		return true
	if d >= reach() + r:
		return false
	return absf(to.angle_to(player.face)) <= swing_half() + asin(minf(1.0, r / d))


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
	if not schedule.is_empty():
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
	_bolts()
	_sweep()
	_spawns()
	_end_or_offer()


## Drop the enemies that died or left this step and add the ones born in it, in place: a crowd of hundreds would
## otherwise make two new arrays every step.
func _sweep() -> void:
	var kept := 0
	for e in enemies:
		if not e.dead and not e.gone:
			enemies[kept] = e
			kept += 1
	enemies.resize(kept)
	if not born.is_empty():
		enemies.append_array(born)
		born.clear()


## Put three upgrades on the table, ones you don't have yet or the next level of ones you do (and that may come
## tonight: from_night), and stop the clock.
func _offer() -> void:
	var pool: Array = Config.UPGRADES.keys().filter(func(id): return level(id) < max_level(id) and offered_on(id, night))
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


## The night is over. The sun clears the field, you rest (fully, from Config.HARDEN.from: with the hearts that night
## gives), the torch is topped up, and the next night begins with the torch's offer.
func _dawn() -> void:
	score += Config.SCORE.dawn
	events.append({ "kind": "dawn", "night": night })
	for e in enemies + born:
		events.append({ "kind": "banished", "pos": e.pos, "dir": Vector2.UP, "enemy": e.kind, "tier": e.tier })
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
	bolts = []
	bosses_due = _plan_bosses()
	player.invuln_for = keeper_invuln()
	var heal: int = max_hp() if night >= Config.HARDEN.from else Config.DAWN.heal
	player.hp = mini(max_hp(), player.hp + heal)
	fuel = maxf(fuel, T.start_fuel * max_fuel() / T.max_fuel)
	_offer()


func _haul() -> void:
	var p = player
	if p.dead:
		return
	if p.dropped != null and p.pos.distance_to(p.dropped) >= stats.grab:
		p.dropped = null
	if p.carrying and p.pos.distance_to(T.pos) < T.reach + stats.radius:
		for i in p.held: # every log held goes on the fire, each counted
			fuel = minf(max_fuel(), fuel + T.log_fuel + mod("log_bonus", 0.0) + stats.log_bonus)
			score += Config.SCORE.log
			events.append({ "kind": "fed", "pos": T.pos })
		p.held = 0
		p.carrying = false
	elif p.held < stats.carry:
		for i in logs.size():
			# You pick a log up by walking onto it, so the one you just put down stays down until you step off it.
			# One a step, until the arms are full.
			if logs[i] != p.dropped and p.pos.distance_to(logs[i]) < stats.grab:
				logs.remove_at(i)
				p.take_log()
				break


func drop_log(at: Vector2) -> void:
	logs.append(at)


## A hurt player who walks over a berry eats it. At full health it stays where it is.
func _forage() -> void:
	var p = player
	if p.dead or p.hp >= max_hp():
		return
	for i in berries.size():
		if p.pos.distance_to(berries[i]) < stats.grab:
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
	var reach: float = stats.radius + mod("thorn_reach", 0.0)
	for e in enemies:
		if not e.dead and e.pos.distance_to(player.pos) < e.T.radius + reach:
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


## Whether a living enemy's body comes within attack_range() of from: what the auto_attack upgrade attacks.
func foe_in_reach(from: Vector2) -> bool:
	var r: float = attack_range()
	for e in enemies:
		if not e.dead and from.distance_to(e.pos) - e.T.radius < r:
			return true
	return false


## A swing turns toward the nearest enemy within aim range, so backing off and swinging works. Otherwise it keeps face.
func aim(from: Vector2, face: Vector2) -> Vector2:
	var best = null
	var aim_range: float = attack_range() + stats.aim_slack
	for e in enemies:
		var d: float = from.distance_to(e.pos) - e.T.radius
		if d < aim_range and (best == null or d < from.distance_to(best.pos) - best.T.radius):
			best = e
	return face if best == null else (best.pos - from).normalized()


## The player's swing lands, on every step from PLAYER.attack_hit_at to attack_hit_until: hit everything in it
## (in_swing) that this swing has not hit yet.
func melee(p) -> void:
	var dmg: int = stats.damage + (mod("lit_damage", 0) if in_light(p.pos) else 0)
	for e in enemies:
		if not e.dead and not p.struck.has(e) and in_swing(e.pos, e.T.radius):
			p.struck.append(e)
			_damage(e, dmg, p.pos, true, stats.push)


## A shooter's attack lets go (at PLAYER.attack_hit_at into it): one ember along the facing (World.aim turned it), or
## with the spin upgrade as a shooter has it, every few shots a fan of three, Config.CHARACTERS' bolt.spread apart.
func shoot(p) -> void:
	var every: int = mod("spread_every", 0)
	var fan: Array = [0.0]
	if every > 0 and p.swings % every == 0:
		fan = [-stats.bolt.spread, 0.0, stats.bolt.spread]
	for turn in fan:
		bolts.append({ "pos": p.pos, "dir": p.face.rotated(turn), "left": bolt_range(), "radius": bolt_radius(),
			"pierce": stats.bolt.pierce, "hit": [] })
	events.append({ "kind": "cast", "pos": p.pos })


## Whether an ember that flies from a to b this step touches a body of radius r at at: the body comes within the
## ember's radius of the stretch it flew. The painter draws the ember as a disc of that radius (src/art/painter.gd),
## so whatever it is seen to touch, it hits.
static func in_bolt(a: Vector2, b: Vector2, radius: float, at: Vector2, r: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) < radius + r


## The keeper's embers fly straight for their range and burn what they touch: more in the light (bolt.lit_bonus,
## and the fire blade as a shooter has it); one goes through pierce enemies (lit_pierce more where the one it burns
## stands in the light), and stops at the next.
func _bolts() -> void:
	if bolts.is_empty():
		return
	var B: Dictionary = stats.bolt
	for b in bolts:
		var go: float = minf(B.speed * Config.STEP, b.left)
		var from: Vector2 = b.pos
		b.pos = from + b.dir * go
		b.left -= go
		for e in enemies:
			if e.dead or b.hit.has(e) or not in_bolt(from, b.pos, b.radius, e.pos, e.T.radius):
				continue
			b.hit.append(e)
			var lit: bool = in_light(e.pos)
			_damage(e, B.damage + ((B.lit_bonus + mod("lit_damage", 0)) if lit else 0), e.pos - b.dir, true, B.push)
			if b.hit.size() > b.pierce + (B.lit_pierce if lit else 0):
				b.left = 0.0
				_splash(e) # it bursts where it stops: on the last enemy it burns, not on those it goes through
				break
	bolts = bolts.filter(func(b): return b.left > 0.0)


## Whether a body of radius r at at is inside an ember's burst centred on centre: its edge comes within splash pixels.
## The painter's burst ring ends at that radius (src/art/effects.gd), so what it is seen to cover, it burns.
static func in_splash(centre: Vector2, splash: float, at: Vector2, r: float) -> bool:
	return centre.distance_to(at) < splash + r


## An ember burst on e: splash_damage on every other enemy in it (in_splash), struck from e's middle. Taken before
## any of it lands, so the halves of a big slime it breaks are not burned by the same burst.
func _splash(e) -> void:
	var B: Dictionary = stats.bolt
	var centre: Vector2 = e.pos
	events.append({ "kind": "burst", "pos": centre, "radius": B.splash })
	var caught := enemies.filter(func(o): return o != e and not o.dead and in_splash(centre, B.splash, o.pos, o.T.radius))
	for o in caught:
		_damage(o, B.splash_damage, centre, true, B.splash_push)


## A blow of n lands on e, struck from from (by the sword when blade). The dark protects some enemies; a thief drops
## its log when it dies; a big slime breaks into smaller ones, which join the fight at the end of the step; with the
## vampire upgrade enough sword kills heal you (vamp_need(); kills made at full health wait for the next hurt).
func _damage(e, n: int, from: Vector2, blade := false, push := 1.0) -> void:
	if e.dead:
		return
	var dir: Vector2 = (e.pos - from).normalized()
	if e.T.get("dark_proof", false) and not in_light(e.pos):
		events.append({ "kind": "passed", "pos": e.pos, "dir": dir, "enemy": e.kind, "tier": e.tier })
		return
	if e.decoy: # only smoke: it breaks, and is worth nothing
		e.fade(self)
		return
	e.hit(n, from, push)
	events.append({ "kind": "kill" if e.dead else "hit", "pos": e.pos, "dir": dir, "enemy": e.kind, "tier": e.tier })
	if not e.dead:
		return
	score += e.T.get("score", Config.SCORE.kill)
	var thirst := vamp_need()
	if blade and thirst > 0:
		blade_kills = mini(blade_kills + 1, thirst)
		if blade_kills >= thirst and player.hp < max_hp() and not player.dead:
			blade_kills = 0
			player.hp += 1
			events.append({ "kind": "healed", "pos": player.pos })
	if e.carrying:
		logs.append(e.pos)
	for i in e.splits:
		var side := -1.0 if i % 2 == 0 else 1.0
		var half = Enemy.new(e.T.splits_into, e.pos + Vector2(side * Config.ENEMY.split_spread, 0.0), e.tier)
		half.knock = Vector2(side * Config.ENEMY.split_knock, 0.0)
		born.append(half)
		if player.attack_t >= 0.0:
			player.struck.append(half) # the swing that broke it does not also cut its halves


## How many sword kills the vampire blade wants for a heal tonight (0 without it): vamp_kills up to night vamp_from,
## and vamp_grow times as many on each night after it (rounded), so it keeps up with crowds that grow by a share
## every night: they give kills in plenty, and a want that grew by a fixed number would soon heal you every few
## seconds again.
func vamp_need() -> int:
	var first: int = mod("vamp_kills", 0)
	return 0 if first == 0 else roundi(first * pow(mod("vamp_grow", 1.0), maxi(0, night - mod("vamp_from", 0))))


func _spawns() -> void:
	if time >= next_spawn:
		var row := _night_row()
		next_spawn = time + spawn_gap()
		var kind := _who(row.who)
		var at := _edge_point()
		var tier := _tier()
		enemies.append(Enemy.new(kind, at, tier))
		var along := _along_edge(at)
		var company: Array = row.get("with", {}).get(kind, [])
		for i in company.size(): # beside it on the edge, one each side in turn
			enemies.append(Enemy.new(company[i], at + along * Config.ENEMY.with_gap * (i / 2 + 1) * (1.0 if i % 2 == 0 else -1.0), tier))
	for b in bosses_due:
		if b.from == null and time >= b.at - Config.BOSS.warn:
			b.from = _edge_point()
			events.append({ "kind": "coming", "enemy": b.kind, "pos": b.from })
	while not bosses_due.is_empty() and bosses_due[0].from != null and time >= bosses_due[0].at:
		var b: Dictionary = bosses_due.pop_front()
		var boss = _boss(b.kind, b.from)
		enemies.append(boss)
		events.append({ "kind": "boss", "enemy": boss.kind, "pos": boss.pos })
	if time >= next_wood:
		next_wood = time + Config.WOOD.every * minf(1.0, Config.WOOD.pace / burn()) * mod("wood_mult", 1.0)
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


## Seconds from one enemy to the next at this point of tonight: the row's gap (from dusk to just before dawn),
## shorter on every night past the table, but never under LATER_NIGHTS.min_gap; on a boss night, further apart.
func spawn_gap() -> float:
	var row := _night_row()
	var apart: float = lerpf(row.spawn[0], row.spawn[1], clampf(time / N.length, 0.0, 1.0)) * pow(Config.LATER_NIGHTS.spawn, _nights_past())
	return maxf(apart, Config.LATER_NIGHTS.min_gap) * (Config.BOSS.spawn_mult if _boss_night() else 1.0)


## Whether bosses come tonight.
func _boss_night() -> bool:
	return night % Config.BOSS.every == 0


## Which bosses come tonight, in the order they come ([] on a night without): Config.BOSS.counts of them, the kinds
## taking turns from boss night to boss night and, on a night with several, from one boss to the next.
func boss_kinds() -> Array:
	if not _boss_night():
		return []
	var count := 0
	for r in Config.BOSS.counts:
		if night >= r.from:
			count = r.count
	var kinds: Array = Config.BOSS.kinds
	var out := []
	for i in count:
		out.append(kinds[(night / Config.BOSS.every - 1 + i) % kinds.size()])
	return out


## Tonight's bosses, each with the night time it comes: BOSS.at into the night, each next one BOSS.apart later.
func _plan_bosses() -> Array:
	var out := []
	var kinds := boss_kinds()
	for i in kinds.size():
		out.append({ "kind": kinds[i], "at": N.length * Config.BOSS.at + Config.BOSS.apart * i, "from": null })
	return out


## Bosses on their way that the screen has been told of: [{ kind, at, from }], from where each will come.
func bosses_coming() -> Array:
	return bosses_due.filter(func(b): return b.from != null)


## What a boss's hp and summons are multiplied by tonight (Config.BOSS.strength): gentle on the first boss night,
## stronger on each one after it, up to most.
func boss_strength() -> float:
	var S: Dictionary = Config.BOSS.strength
	return minf(S.most, S.first + S.grow * (night / Config.BOSS.every - 1))


## A boss of kind coming out of the dark at at, as strong as tonight makes it (boss_strength()): its hp rounded up,
## the enemies it calls and those it breaks into rounded, never under one. Its row, and so its score, stays as it is.
func _boss(kind: String, at: Vector2):
	var boss = Enemy.new(kind, at)
	var k := boss_strength()
	boss.full_hp = ceili(boss.T.hp * k)
	boss.hp = boss.full_hp
	if boss.T.has("summon"):
		boss.summons = maxi(1, roundi(boss.T.summon.count * k))
	if boss.splits > 0:
		boss.splits = maxi(1, roundi(boss.splits * k))
	return boss


## This night's row of Config.NIGHTS; nights past the table use its last row.
func _night_row() -> Dictionary:
	return Config.NIGHTS[mini(night, Config.NIGHTS.size()) - 1]


## How many nights past the end of Config.NIGHTS this one is.
func _nights_past() -> int:
	return maxi(0, night - Config.NIGHTS.size())


## Fuel the torch uses per second tonight, before upgrades.
func burn() -> float:
	return _night_row().burn + Config.LATER_NIGHTS.burn * _nights_past()


## Tonight's shares of each tier (Config.TIER_NIGHTS), or [] before the first row: then every enemy is tier 1.
func tier_shares() -> Array:
	var shares := []
	for r in Config.TIER_NIGHTS:
		if night >= r.from:
			shares = r.shares
	return shares


## How strong what comes out of the dark is: one roll over tonight's tier_shares(), none on a night without them.
func _tier() -> int:
	var shares := tier_shares()
	if shares.is_empty():
		return 1
	var roll: float = rng.next() * shares.reduce(func(a, b): return a + b, 0.0)
	for i in shares.size():
		roll -= shares[i]
		if roll < 0.0:
			return i + 1
	return shares.size()


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


## Which way a point from _edge_point() runs along its edge: across on the top and bottom, down on the sides.
func _along_edge(at: Vector2) -> Vector2:
	var f := Config.FIELD.grow(Config.ENEMY.edge)
	return Vector2.RIGHT if is_equal_approx(at.y, f.position.y) or is_equal_approx(at.y, f.end.y) else Vector2.DOWN


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
