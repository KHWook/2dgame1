## Short-lived pictures that answer what just happened in the world (world.events): pixels that fly off an enemy
## that is hit (and fire, from a blade that burns), a puff where one dies, sparks, a ring of embers and a brighter torch when it is fed, and hearts
## rising off a keeper who ate a berry, and dust where the slime king lands.
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
}
## PALETTE keys of flying pixels that are not an enemy's own (those are in looks.gd).
const FIRE := ["f", "F", "x"]
const HEAL := ["i", "W", "I"]
const DUST := ["m", "M", "c"] # thrown up off the ground
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

var rng # its own generator, so effects never draw from world.rng
var bits: Array = [] # flying pixels: { pos, vel, keep, age, life, colour }
var poofs: Array = [] # { pos, age in steps }
var flare := 0.0 # 1 the moment the torch is fed, fading to 0: how much brighter it burns


func _init(seed_value: int) -> void:
	rng = SimRng.new(seed_value)


## Call once after each world.step(): start what the step's events ask for, and move what is already showing.
func step(w) -> void:
	for ev in w.events:
		match ev.kind:
			"hit", "passed":
				_burst(BURSTS[ev.kind], ev.pos, ev.dir, Looks.enemy(ev.enemy).bits)
				if ev.kind == "hit" and _burning(w):
					_burst(BURSTS.burn, ev.pos, ev.dir, FIRE)
			"kill", "banished":
				if ev.kind == "kill" and _burning(w):
					_burst(BURSTS.burn, ev.pos, ev.dir, FIRE)
				_burst(BURSTS.kill, ev.pos, ev.dir, Looks.enemy(ev.enemy).bits)
				poofs.append({ "pos": ev.pos, "age": 0 })
			"fed":
				_burst(BURSTS.sparks, ev.pos + FLAME_MOUTH, Vector2.UP, FIRE)
				_burst(BURSTS.wave, ev.pos, Vector2.UP, FIRE)
				flare = 1.0
			"shot":
				_burst(BURSTS.shot, ev.pos, Vector2.UP, FIRE)
			"boss":
				_burst(BURSTS.arrive, ev.pos, Vector2.UP, Looks.enemy(ev.enemy).bits)
				poofs.append({ "pos": ev.pos, "age": 0 })
			"landed":
				_burst(BURSTS.landed, ev.pos, Vector2.UP, DUST + Looks.enemy(ev.enemy).bits)
				poofs.append({ "pos": ev.pos, "age": 0 })
			"healed":
				_burst(BURSTS.heal, ev.pos + HEAD, Vector2.UP, HEAL)
	if bits.size() > MAX_BITS:
		bits = bits.slice(bits.size() - MAX_BITS)
	if poofs.size() > MAX_POOFS:
		poofs = poofs.slice(poofs.size() - MAX_POOFS)
	var kept := 0
	for b in bits:
		b.pos += b.vel * Config.STEP
		b.vel *= pow(b.keep, Config.STEP)
		b.age += Config.STEP
		if b.age < b.life:
			bits[kept] = b
			kept += 1
	bits.resize(kept)
	kept = 0
	for p in poofs:
		p.age += 1
		if p.age < POOF.size() * POOF_STEPS:
			poofs[kept] = p
			kept += 1
	poofs.resize(kept)
	flare = maxf(0.0, flare - Config.STEP / FLARE_TIME)


## True while a blow does the fire blade's extra damage: it is held and the keeper stands in the light, as
## world.melee() decides it.
func _burning(w) -> bool:
	return w.mod("lit_damage", 0) > 0 and w.in_light(w.player.pos)


func paint(c: CanvasItem) -> void:
	for p in poofs:
		c.draw_texture(Sprites.texture(POOF[p.age / POOF_STEPS]), (p.pos - POOF_ANCHOR).round())
	for b in bits:
		var size := 2.0 if b.age < b.life * BIG_UNTIL else 1.0
		c.draw_rect(Rect2((b.pos - Vector2(size, size) / 2.0).round(), Vector2(size, size)), b.colour)


func _burst(b: Dictionary, at: Vector2, dir: Vector2, colours: Array) -> void:
	for i in b.count:
		var angle: float = dir.angle() + rng.range_f(-b.fan, b.fan)
		bits.append({
			"pos": at, "vel": Vector2.from_angle(angle) * rng.range_f(b.speed[0], b.speed[1]), "keep": b.keep,
			"age": 0.0, "life": rng.range_f(b.life[0], b.life[1]), "colour": Sprites.PALETTE[colours[rng.index(colours.size())]],
		})
