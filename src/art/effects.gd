## Short-lived pictures that answer what just happened in the world (world.events): pixels that fly off an enemy
## that is hit, a puff where one dies, sparks, a ring of embers and a brighter torch when it is fed, and hearts
## rising off a keeper who ate a berry.
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
	"heal": { "count": 9, "fan": 1.0, "speed": [20.0, 55.0], "life": [0.4, 0.8], "keep": 0.15 }, # rise off the keeper
}
## PALETTE keys of flying pixels that are not an enemy's own (those are in looks.gd).
const FIRE := ["f", "F", "x"]
const HEAL := ["i", "W", "I"]
const HEAD := Vector2(0.0, -8.0) # from the keeper's position
const BIG_UNTIL := 0.5 # a flying pixel is 2x2 for this share of its life, then 1x1
const POOF := ["poof_a", "poof_b", "poof_c", "poof_d"]
const POOF_STEPS := 4 # simulation steps per poof frame
const POOF_ANCHOR := Vector2(8.0, 9.0)
const FLAME_MOUTH := Vector2(0.0, -6.0) # sparks leave from here, measured from the torch position
const FLARE_TIME := 0.5 # seconds the fed torch burns brighter

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
			"kill", "banished":
				_burst(BURSTS.kill, ev.pos, ev.dir, Looks.enemy(ev.enemy).bits)
				poofs.append({ "pos": ev.pos, "age": 0 })
			"fed":
				_burst(BURSTS.sparks, ev.pos + FLAME_MOUTH, Vector2.UP, FIRE)
				_burst(BURSTS.wave, ev.pos, Vector2.UP, FIRE)
				flare = 1.0
			"healed":
				_burst(BURSTS.heal, ev.pos + HEAD, Vector2.UP, HEAL)
	for b in bits:
		b.pos += b.vel * Config.STEP
		b.vel *= pow(b.keep, Config.STEP)
		b.age += Config.STEP
	bits = bits.filter(func(b): return b.age < b.life)
	for p in poofs:
		p.age += 1
	poofs = poofs.filter(func(p): return p.age < POOF.size() * POOF_STEPS)
	flare = maxf(0.0, flare - Config.STEP / FLARE_TIME)


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
