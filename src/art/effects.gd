## Short-lived pictures that answer what just happened in the world (world.events): pixels that fly off an enemy
## that is hit (and fire, from a blade that burns), a puff where one dies, sparks, a ring of embers and a brighter torch when it is fed, and hearts
## rising off a keeper who ate a berry, and dust where the slime king lands with a ring of debris thrown out to the
## shock's edge, and rings of smoke where a boss breaks out of the dark and where a decoy appears or breaks; and where
## the keeper's own blow lands, each character's mark (STRIKES): the sword's ring, the axe's bite with flying chips,
## the ember's pop, a spark trail behind each ember in flight and a fizzle where one flies out its range unspent.
## View only (D4): it reads the world and never writes to it. It runs on simulation steps with its own seeded
## generator, so the same night always shows the same effects.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const Sprites := preload("res://src/art/sprites.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Looks := preload("res://src/art/looks.gd")

## The pixels each event throws out: how many, how wide a fan around the event's direction (radians to each side),
## speed (px/s) and life (s) ranges, and the share of its speed a pixel keeps after one second.
const BURSTS := {
	"hit": { "count": 4, "fan": 0.9, "speed": [40.0, 100.0], "life": [0.12, 0.25], "keep": 0.01 },
	"kill": { "count": 10, "fan": PI, "speed": [30.0, 120.0], "life": [0.2, 0.45], "keep": 0.01 },
	"sparks": { "count": 14, "fan": 0.8, "speed": [20.0, 70.0], "life": [0.4, 0.9], "keep": 0.15 }, # rise off the fed flame
	"wave": { "count": 24, "fan": PI, "speed": [130.0, 150.0], "life": [0.3, 0.4], "keep": 0.1 }, # embers ringing out from it
	"passed": { "count": 3, "fan": 0.5, "speed": [40.0, 80.0], "life": [0.15, 0.3], "keep": 0.05 }, # a blow went through
	"shot": { "count": 5, "fan": 0.7, "speed": [20.0, 60.0], "life": [0.15, 0.3], "keep": 0.05 }, # the torch fires a spark
	"arrive": { "count": 24, "fan": PI, "speed": [40.0, 140.0], "life": [0.3, 0.7], "keep": 0.02 }, # a boss comes
	"burn": { "count": 8, "fan": 1.2, "speed": [30.0, 90.0], "life": [0.25, 0.5], "keep": 0.05 }, # a fire blade's blow
	"landed": { "count": 28, "fan": PI, "speed": [60.0, 130.0], "life": [0.25, 0.45], "keep": 0.02 }, # the slime king comes down
	"heal": { "count": 9, "fan": 1.0, "speed": [20.0, 55.0], "life": [0.4, 0.8], "keep": 0.15 }, # rise off the keeper
	# the keeper's own blows (STRIKES); "streak" draws a pixel as a short line along its flight, "fall" pulls it down (px/s²)
	"clang": { "count": 4, "fan": 0.55, "speed": [90.0, 150.0], "life": [0.06, 0.12], "keep": 0.01, "streak": true },
	"chop": { "count": 7, "fan": 1.1, "speed": [50.0, 110.0], "life": [0.25, 0.45], "keep": 0.05, "fall": 260.0 },
	"ground": { "count": 8, "fan": PI, "speed": [30.0, 70.0], "life": [0.2, 0.35], "keep": 0.05, "fall": 200.0 }, # chips and dirt off a chop's landing
	"pop": { "count": 8, "fan": PI, "speed": [40.0, 90.0], "life": [0.12, 0.25], "keep": 0.02 },
	"fizzle": { "count": 3, "fan": 0.6, "speed": [8.0, 20.0], "life": [0.3, 0.5], "keep": 0.3 }, # smoke rising off a spent ember
	"cast": { "count": 4, "fan": 0.45, "speed": [40.0, 90.0], "life": [0.08, 0.16], "keep": 0.02 }, # out of the mage's hand
	"cast_fan": { "count": 9, "fan": 0.85, "speed": [50.0, 100.0], "life": [0.1, 0.2], "keep": 0.02 }, # three at once
	"trail": { "count": 1, "fan": 0.7, "speed": [10.0, 30.0], "life": [0.08, 0.18], "keep": 0.05 }, # shed by an ember in flight
}
## Where one of the keeper's own blows lands, per character: a picture played frame by frame (steps per frame) and
## a burst of BURSTS in colours (PALETTE keys). A blade's blow is a hit told while its swing lands (blow()), an ember's
## where it touched (the embers are followed from step to step: _follow); FIZZLE plays where an ember ran out of range.
const STRIKES := {
	"knight": { "frames": ["clang_a", "clang_b"], "steps": 3, "burst": "clang", "colours": ["W", "a", "A"] },
	"woodcutter": { "frames": ["chop_a", "chop_b"], "steps": 4, "burst": "chop", "colours": ["o", "O", "y", "A", "M"] },
	"mage": { "frames": ["pop_a", "pop_b", "pop_c"], "steps": 3, "burst": "pop", "colours": ["f", "F", "x"] },
}
const FIZZLE := { "frames": ["fizzle_a", "fizzle_b", "fizzle_c"], "steps": 4, "burst": "fizzle", "colours": ["K", "z", "X"] }
const TRAIL := ["F", "x", "X"] # an ember's sparks; one more each step while it flies in the light, where it burns harder
const MUZZLE := 5.0 # pixels ahead of the mage the cast's sparks leave from
const STREAK := 0.025 # seconds of flight a streaking pixel is drawn long
## PALETTE keys of flying pixels that are not an enemy's own (those are in looks.gd).
const FIRE := ["f", "F", "x"]
const HEAL := ["i", "W", "I"]
const DUST := ["m", "M", "c"] # thrown up off the ground
const SPLAT := [Color("#9be8ff"), Color("#3f8fd0"), Color.WHITE] # a spitter's blob (painter.gd's SPIT), burst
const HEAD := Vector2(0.0, -8.0) # from the keeper's position
const BIG_UNTIL := 0.5 # a flying pixel is 2x2 for this share of its life, then 1x1
const POOF := ["poof_a", "poof_b", "poof_c", "poof_d"]
const POOF_STEPS := 4 # simulation steps per poof frame
const POOF_ANCHOR := Vector2(8.0, 9.0)
const FLAME_MOUTH := Vector2(0.0, -6.0) # sparks leave from here, measured from the torch position
const FLARE_TIME := 0.5 # seconds the fed torch burns brighter
## The most flying pixels and puffs on screen at once. A crowd mown down by the ember ring throws out hundreds a
## second; past these the oldest go first, so a big fight costs no more to show than a busy one.
const MAX_BITS := 320
const MAX_POOFS := 40
const MAX_RINGS := 12
const MAX_FLASHES := 24
## Rings thrown out from a spot: debris chunks out to a landing's shock (its "landed" event's shock: as far as it
## hurt), or smoke puffs round a boss breaking in or a decoy. kind -> [steps it lasts, pieces round it, radius it
## ends at (0: the event's shock)].
## A burst: an ember bursting on the enemy it stopped in, out to its "burst" event's radius (World.in_splash: what
## the ring is seen to cover, it burns).
## Dust: a chop coming down, out to the edge of the round it strikes (world.chop_radius(), about world.chop_centre()).
const RINGS := { "debris": [18, 16, 0.0], "smoke": [16, 6, 14.0], "wisp": [16, 4, 8.0], "burst": [12, 14, 0.0], "dust": [14, 14, 0.0] }
const DEBRIS := ["m", "M", "t", "T", "c"]
const DEBRIS_HOP := 3.0 # pixels a chunk rises on its way out

var rng # its own generator, so effects never draw from world.rng
var bits: Array = [] # flying pixels: { pos, vel, keep, age, life, colour }
var poofs: Array = [] # { pos, age in steps }
var rings: Array = [] # { pos, age in steps, kind (RINGS), radius it ends at }
var flashes: Array = [] # a blow's mark or a fizzle: { pos, age in steps, kind ("strike"/"fizzle"), frames, steps }
var _flying: Array = [] # the embers in flight after the last step: [bolt, enemies it had hit, where it was]
var flare := 0.0 # 1 the moment the torch is fed, fading to 0: how much brighter it burns
var _was_t := -1.0 # the keeper's attack_t after the last step: a chop lands on the step it passes attack_hit_at


func _init(seed_value: int) -> void:
	rng = SimRng.new(seed_value)


## Call once after each world.step(): start what the step's events ask for, and move what is already showing.
func step(w) -> void:
	var cast := false
	for ev in w.events:
		if ev.kind == "cast":
			cast = true
		if (ev.kind == "hit" or ev.kind == "kill") and blow(w, ev):
			_strike(STRIKES.get(w.character, STRIKES.knight), ev.pos, ev.dir)
		elif (ev.kind == "hit" or ev.kind == "kill") and cast and _point_blank(w, ev):
			_strike(STRIKES.get(w.character, STRIKES.knight), ev.pos - ev.dir * Config.ENEMY_TYPES[ev.enemy].radius, ev.dir)
		match ev.kind:
			"cast":
				var fan: bool = w.bolts.filter(func(x): return not _flying.any(func(f): return is_same(f[0], x))).size() >= 3
				_burst(BURSTS.cast_fan if fan else BURSTS.cast, ev.pos + w.player.face * MUZZLE, w.player.face, _keys(FIRE))
			"hit", "passed":
				_burst(BURSTS[ev.kind], ev.pos, ev.dir, Looks.bit_colours(ev.enemy, ev.tier))
				if ev.kind == "hit" and _burning(w):
					_burst(BURSTS.burn, ev.pos, ev.dir, _keys(FIRE))
			"kill", "banished":
				if ev.kind == "kill" and _burning(w):
					_burst(BURSTS.burn, ev.pos, ev.dir, _keys(FIRE))
				_burst(BURSTS.kill, ev.pos, ev.dir, Looks.bit_colours(ev.enemy, ev.tier))
				poofs.append({ "pos": ev.pos, "age": 0 })
			"fed":
				_burst(BURSTS.sparks, ev.pos + FLAME_MOUTH, Vector2.UP, _keys(FIRE))
				_burst(BURSTS.wave, ev.pos, Vector2.UP, _keys(FIRE))
				flare = 1.0
			"shot":
				_burst(BURSTS.shot, ev.pos, Vector2.UP, _keys(FIRE))
			"boss":
				var at: Vector2 = ev.pos.clamp(Config.FIELD.position, Config.FIELD.end) # where it breaks in: on screen
				_burst(BURSTS.arrive, at, Vector2.UP, Looks.bit_colours(ev.enemy, 1))
				poofs.append({ "pos": at, "age": 0 })
				_ring("smoke", at)
			"decoy", "faded": # a decoy of a boss appears, or breaks into smoke
				_burst(BURSTS.kill, ev.pos, Vector2.UP, Looks.bit_colours(ev.enemy, 1))
				poofs.append({ "pos": ev.pos, "age": 0 })
				_ring("wisp", ev.pos)
			"landed":
				_burst(BURSTS.landed, ev.pos, Vector2.UP, _keys(DUST) + Looks.bit_colours(ev.enemy, 1))
				poofs.append({ "pos": ev.pos, "age": 0 })
				_ring("debris", ev.pos, ev.get("shock", 0.0))
			"healed":
				_burst(BURSTS.heal, ev.pos + HEAD, Vector2.UP, _keys(HEAL))
			"burst":
				_ring("burst", ev.pos, ev.radius)
			"wave":
				_ring(ev.ring, ev.pos, ev.radius)
			"burned": # a moth in the flame: its wings go up with a spurt of the fire it took
				_burst(BURSTS.kill, ev.pos, Vector2.UP, Looks.bit_colours(ev.enemy, ev.tier))
				_burst(BURSTS.sparks, Config.TORCH.pos + FLAME_MOUTH, Vector2.UP, _keys(FIRE))
				poofs.append({ "pos": ev.pos, "age": 0 })
			"splat": # a spitter's blob bursts
				_burst(BURSTS.pop, ev.pos, Vector2.UP, SPLAT)
	_follow(w)
	if landed(w, _was_t):
		var at: Vector2 = w.chop_centre(w.player.pos, w.player.face)
		_ring("dust", at, w.chop_radius())
		_burst(BURSTS.ground, at, Vector2.UP, _keys(STRIKES.woodcutter.colours + DUST))
	_was_t = w.player.attack_t
	if bits.size() > MAX_BITS:
		bits = bits.slice(bits.size() - MAX_BITS)
	if poofs.size() > MAX_POOFS:
		poofs = poofs.slice(poofs.size() - MAX_POOFS)
	if rings.size() > MAX_RINGS:
		rings = rings.slice(rings.size() - MAX_RINGS)
	var kept := 0
	for b in bits:
		b.pos += b.vel * Config.STEP
		b.vel *= pow(b.keep, Config.STEP)
		b.vel.y += b.fall * Config.STEP
		b.age += Config.STEP
		if b.age < b.life:
			bits[kept] = b
			kept += 1
	bits.resize(kept)
	if flashes.size() > MAX_FLASHES:
		flashes = flashes.slice(flashes.size() - MAX_FLASHES)
	kept = 0
	for f in flashes:
		f.age += 1
		if f.age < f.frames.size() * f.steps:
			flashes[kept] = f
			kept += 1
	flashes.resize(kept)
	kept = 0
	for p in poofs:
		p.age += 1
		if p.age < POOF.size() * POOF_STEPS:
			poofs[kept] = p
			kept += 1
	poofs.resize(kept)
	kept = 0
	for r in rings:
		r.age += 1
		if r.age < RINGS[r.kind][0]:
			rings[kept] = r
			kept += 1
	rings.resize(kept)
	flare = maxf(0.0, flare - Config.STEP / FLARE_TIME)


## Whether a hit (or kill) told this step is the keeper's own blade landing: it swings a weapon, the blow is landing
## now (attack_hit_at to attack_hit_until) and what was struck is in the blow (world.in_blow). Thorns or the torch's
## sparks that happen to strike during a swing count too; it only chooses a picture.
static func blow(w, ev) -> bool:
	if Looks.character(w.character).weapon == "" or w.player.attack_t < 0.0:
		return false
	var t: float = w.player.attack_t
	if t < w.stat("attack_hit_at") - Config.STEP or t > w.stat("attack_hit_until") + Config.STEP:
		return false
	return w.in_blow(ev.pos, Config.ENEMY_TYPES[ev.enemy].radius + 2.0)


## Whether a chop came down on the last step (it was at was before it): the keeper chops (a spin goes round
## instead) and its attack passed attack_hit_at, whether or not anything was there to strike.
static func landed(w, was: float) -> bool:
	if w.stats.attack != "chop" or w.player.spin or w.player.dead:
		return false
	var hit_at: float = w.stat("attack_hit_at")
	return w.player.attack_t >= hit_at and was < hit_at


## A hit on the step an ember was cast, close enough for that ember to have reached it already: an ember that burns
## what it touches on its first step and stops is gone before _follow() ever sees it fly.
func _point_blank(w, ev) -> bool:
	if not w.stats.has("bolt"):
		return false
	var B: Dictionary = w.stats.bolt
	return ev.pos.distance_to(w.player.pos) <= B.speed * Config.STEP + w.bolt_radius() + Config.ENEMY_TYPES[ev.enemy].radius + 1.0


## The embers from step to step: one that touched another enemy pops where it touched it (the point of the stretch it
## flew closest to that enemy, inside its radius, as world.in_bolt() hits); one gone without touching anything flew
## its whole range (world._bolts() stops it exactly there) and fizzles where it ended. Each ember in flight sheds sparks.
func _follow(w) -> void:
	for f in _flying:
		var b: Dictionary = f[0]
		var gone: bool = not w.bolts.any(func(x): return is_same(x, b))
		if b.hit.size() > f[1]:
			for e in b.hit.slice(f[1]):
				var touch: Vector2 = Geometry2D.get_closest_point_to_segment(e.pos, f[2], b.pos)
				_strike(STRIKES.mage, touch, b.dir)
		elif gone and b.left <= 0.0:
			_strike(FIZZLE, b.pos, Vector2.UP)
	for b in w.bolts:
		for i in 2 if w.in_light(b.pos) else 1:
			_burst(BURSTS.trail, b.pos - b.dir * 2.0, -b.dir, _keys(TRAIL))
	_flying = w.bolts.map(func(b): return [b, b.hit.size(), b.pos])


func _strike(s: Dictionary, at: Vector2, dir: Vector2) -> void:
	flashes.append({ "pos": at, "age": 0, "kind": "fizzle" if s == FIZZLE else "strike", "frames": s.frames, "steps": s.steps })
	_burst(BURSTS[s.burst], at, dir, _keys(s.colours))


## True while a blow does the fire blade's extra damage: it is held and the keeper stands in the light, as
## world.melee() decides it.
func _burning(w) -> bool:
	return w.mod("lit_damage", 0) > 0 and w.in_light(w.player.pos)


func paint(c: CanvasItem) -> void:
	for r in rings:
		_paint_ring(c, r)
	for p in poofs:
		c.draw_texture(Sprites.texture(POOF[p.age / POOF_STEPS]), (p.pos - POOF_ANCHOR).round())
	for f in flashes:
		var tex := Sprites.texture(f.frames[mini(f.frames.size() - 1, f.age / f.steps)])
		c.draw_texture(tex, (f.pos - tex.get_size() / 2.0).round())
	for b in bits:
		if b.streak:
			var from: Vector2 = b.pos.round()
			c.draw_line(from, (b.pos - b.vel * STREAK).round(), b.colour, 1.0)
			continue
		var size := 2.0 if b.age < b.life * BIG_UNTIL else 1.0
		c.draw_rect(Rect2((b.pos - Vector2(size, size) / 2.0).round(), Vector2(size, size)), b.colour)


func _ring(kind: String, at: Vector2, shock := 0.0) -> void:
	var to: float = RINGS[kind][2] if RINGS[kind][2] > 0.0 else shock
	rings.append({ "pos": at, "age": 0, "kind": kind, "radius": to })


## How far out a ring's pieces are at its age: fast at first, ending at its radius (a landing's: the shock).
static func ring_radius(r: Dictionary) -> float:
	var k := clampf(float(r.age) / (RINGS[r.kind][0] - 1), 0.0, 1.0)
	return r.radius * (1.0 - (1.0 - k) * (1.0 - k))


func _paint_ring(c: CanvasItem, r: Dictionary) -> void:
	var life: int = RINGS[r.kind][0]
	var n: int = RINGS[r.kind][1]
	var k := float(r.age) / life
	var out := ring_radius(r)
	for i in n:
		var a := TAU * (i + 0.37 * (i % 3)) / n
		var at: Vector2 = r.pos + Vector2.from_angle(a) * out
		if r.kind == "burst": # tongues of fire, white-hot at first, cooling as they reach the edge
			var size := 2.0 if k < 0.5 else 1.0
			var colour: Color = Sprites.PALETTE[FIRE[mini(FIRE.size() - 1, int(k * FIRE.size() + (i % 2) * 0.5))]]
			c.draw_rect(Rect2((at - Vector2(size, size) / 2.0).round(), Vector2(size, size)), Color(colour, 1.0 - k * k))
		elif r.kind == "dust": # dirt thrown out along the ground to the round's edge, thinning as it settles
			var size := 2.0 if k < 0.4 and i % 2 == 0 else 1.0
			var colour: Color = Sprites.PALETTE[DUST[i % DUST.size()]]
			var half := Vector2(size, size) / 2.0
			c.draw_rect(Rect2((at - Vector2.from_angle(a) * half.x - half).round(), Vector2(size, size)), Color(colour, 1.0 - k * k))
		elif r.kind == "debris":
			var size := 2.0 if k < 0.5 and i % 2 == 0 else 1.0
			var colour: Color = Sprites.PALETTE[DEBRIS[i % DEBRIS.size()]]
			at.y -= sin(k * PI) * DEBRIS_HOP
			c.draw_rect(Rect2((at - Vector2(size, size) / 2.0).round(), Vector2(size, size)), Color(colour, 1.0 - k * k))
		else:
			var frame: int = mini(POOF.size() - 1, r.age * POOF.size() / life)
			c.draw_texture(Sprites.texture(POOF[frame]), (at - POOF_ANCHOR).round(), Color(0.62, 0.58, 0.82, (0.8 if r.kind == "smoke" else 0.6) * (1.0 - k)))


## The colours of PALETTE keys.
static func _keys(keys: Array) -> Array:
	return keys.map(func(k): return Sprites.PALETTE[k])


## Throws out b's pixels, each in one of colours: an enemy's in its tier's (Looks.bit_colours).
func _burst(b: Dictionary, at: Vector2, dir: Vector2, colours: Array) -> void:
	for i in b.count:
		var angle: float = dir.angle() + rng.range_f(-b.fan, b.fan)
		bits.append({
			"pos": at, "vel": Vector2.from_angle(angle) * rng.range_f(b.speed[0], b.speed[1]), "keep": b.keep,
			"age": 0.0, "life": rng.range_f(b.life[0], b.life[1]), "colour": colours[rng.index(colours.size())],
			"streak": b.get("streak", false), "fall": b.get("fall", 0.0),
		})
