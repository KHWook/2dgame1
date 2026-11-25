## How the world looks. It reads the world and paints it with the sprites; it never writes to the world (D4).
## main.gd calls paint() from its _draw, which the night and the torch light then shade, and paint_overlay() from a
## node on a layer above that nothing shades: things that glow by themselves, and the HUD pictures.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const Sprites := preload("res://src/art/sprites.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Effects := preload("res://src/art/effects.gd")
const Looks := preload("res://src/art/looks.gd")
const T := Config.TORCH

const VIEW: Vector2 = Config.VIEW
const GROUND := Color("#33523b")
const NIGHT := Color("#8580b8")
const DAWN := Color("#ffe9cf")
const DAWN_FROM := 0.85 # the sky starts to lighten at this share of the night
const DUSK_TIME := 2.5 # seconds the day takes to fade once a night begins

## Anchors: the pixel of a sprite that lands on its simulation position. Enemies have theirs in looks.gd.
const BODY := Vector2(8.0, 10.0) # the keeper
const TORCH_ANCHOR := Vector2(8.0, 3.0) # the middle of the bowl
const LOG_ANCHOR := Vector2(7.0, 4.0)
const BERRY_ANCHOR := Vector2(4.0, 6.0)
const CARRY := Vector2(0.0, -13.0) # a carried log rides above the keeper's head
const THIEF_CARRY := Vector2(0.0, -9.0) # and on a thief's back
const SHADOW := Vector2(-6.0, 1.0) # where the keeper's shadow's top-left sits, from the keeper's position
const HAND := Vector2(0.0, -2.0) # the sword turns around this point of the keeper
const GHOST := 0.45 # how solid an enemy looks while the dark protects it from blows

## Simulation steps per animation frame. Enemies have theirs in looks.gd.
const WALK_STEPS := 8
const FLAME_STEPS := 6
const FLAME_SIZES := [[0.6, "l"], [0.25, "m"], [0.0, "s"]] # the flame is this big from this share of fuel up

## Small things on the ground, laid out once per seed: one roll per cell, [sprite, share of cells that get it].
const SCENERY_CELL := Vector2(20.0, 18.0)
const SCENERY := [["tuft_a", 0.3], ["tuft_b", 0.26], ["flower_a", 0.05], ["flower_b", 0.04], ["pebble", 0.05], ["mushroom", 0.02]]
const CLEARING := Vector2i(60, 38) # the bare earth around the torch
const CLEARING_DROP := Vector2(0.0, 5.0)
const HEDGE_SIDES := { "top": 0, "right": 1, "bottom": 2, "left": 3 } # quarter turns from the sprite, which faces down
const HEDGE_DEPTH := 9

## The swing's trail: arcs just inside the reach, each [pixels inside the reach, share of the sweep it trails, colour].
const SLASH := [[0.0, 1.0, Color("#fff6c0")], [1.0, 0.7, Color("#fff6c0")], [2.0, 0.45, Color("#ffc94a")], [3.0, 0.25, Color("#f58230")]]

const HUD_HEARTS := Vector2(4.0, 4.0)
const HUD_HEART_STEP := 10.0
const HUD_FUEL := Rect2(13.0, 16.0, 50.0, 4.0)
const HUD_LOW := 0.25 # the fuel bar turns red and blinks below this share
const HUD_BLINK_STEPS := 10
const HUD_PICKS := Vector2(4.0, 25.0) # the upgrades you hold, in the order you took them
const HUD_PICK_STEP := 11.0

## How upgrades show in the world. The rest show only as their icon.
const WARMED := Color(1.0, 0.74, 0.5) # tint of an enemy the warm glow is slowing
const EMBERS := 14 # embers in the ember ring
const EMBER_TURN := 0.4 # radians per second the ring drifts round
const EMBER_PULSE := 0.2 # seconds the embers flare after the ring burns what is inside it

var effects # short-lived pictures that answer what happens in the world
var scenery: Array = [] # [texture, top-left]
var clearing: Texture2D
var hedges := {} # side -> texture: the treetops along each screen edge


## The ground is laid out from the night's seed with its own generator, so it never draws from world.rng.
func _init(seed_value: int) -> void:
	effects = Effects.new(seed_value)
	clearing = ImageTexture.create_from_image(_clearing_image())
	for side in HEDGE_SIDES:
		var img: Image = Sprites.image("hedge")
		for turn in HEDGE_SIDES[side]:
			img.rotate_90(CLOCKWISE)
		hedges[side] = ImageTexture.create_from_image(img)
	var rng := SimRng.new(seed_value)
	var cells := Vector2i((VIEW / SCENERY_CELL).ceil())
	for cy in cells.y:
		for cx in cells.x:
			var roll: float = rng.next()
			var at := (Vector2(cx, cy) + Vector2(rng.next(), rng.next())) * SCENERY_CELL
			var from_clearing := (at - T.pos - CLEARING_DROP) / (Vector2(CLEARING) / 2.0)
			for s in SCENERY:
				roll -= s[1]
				if roll < 0.0:
					if from_clearing.length() > 1.0:
						scenery.append([Sprites.texture(s[0]), at.round()])
					break


func icon(upgrade: String) -> Texture2D:
	return Sprites.texture(Looks.ICON % upgrade)


## Call once after each world.step(), so the effects can answer what the step did.
func step(w) -> void:
	effects.step(w)


## How much brighter the torch burns right now because it was just fed, 1 fading to 0. main.gd adds it to the light.
func flare() -> float:
	return effects.flare


## How far the night has turned to day, 0 to 1. main.gd tints the sky and dims the lights with it.
func daylight(w) -> float:
	if w.phase == "pick" and w.time == 0.0:
		return 1.0 # dusk: it is still day while the torch makes its offer for the night
	return maxf(1.0 - smoothstep(0.0, DUSK_TIME, w.time), smoothstep(DAWN_FROM, 1.0, w.time / Config.NIGHT.length))


func sky(w) -> Color:
	return NIGHT.lerp(DAWN, daylight(w))


func paint(c: CanvasItem, w) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, VIEW), GROUND)
	c.draw_texture(clearing, (T.pos + CLEARING_DROP - Vector2(CLEARING) / 2.0).round())
	for s in scenery:
		c.draw_texture(s[0], s[1])
	_ember_ring(c, w)
	_shadows(c, w)
	var standing := _standing(w)
	standing.sort_custom(func(a, b): return a[0] < b[0])
	for s in standing:
		c.draw_texture(s[1], s[2], s[3])
	_sword(c, w)
	_fliers(c, w)
	for x in range(0, int(VIEW.x), 16):
		c.draw_texture(hedges.top, Vector2(x, 0.0))
		c.draw_texture(hedges.bottom, Vector2(x, VIEW.y - HEDGE_DEPTH))
	for y in range(0, int(VIEW.y), 16):
		c.draw_texture(hedges.left, Vector2(0.0, y))
		c.draw_texture(hedges.right, Vector2(VIEW.x - HEDGE_DEPTH, y))


func paint_overlay(c: CanvasItem, w) -> void:
	effects.paint(c)
	_slash(c, w)
	for e in w.enemies:
		var look := Looks.enemy(e.kind)
		if look.glow != "":
			c.draw_texture(Sprites.texture(look.glow), (e.pos - look.anchor).round())
	for i in w.max_hp():
		c.draw_texture(Sprites.texture("heart" if i < w.player.hp else "heart_empty"), HUD_HEARTS + Vector2(i * HUD_HEART_STEP, 0.0))
	var share := clampf(w.fuel / T.max_fuel, 0.0, 1.0)
	var low: bool = share < HUD_LOW
	c.draw_texture(Sprites.texture("flame_s_a"), Vector2(HUD_HEARTS.x, HUD_FUEL.position.y - 2.0))
	c.draw_rect(HUD_FUEL.grow(1.0), Sprites.PALETTE["k"])
	c.draw_rect(HUD_FUEL, Sprites.PALETTE["K"])
	if not (low and (w.steps / HUD_BLINK_STEPS) % 2 == 0):
		var fill := Rect2(HUD_FUEL.position, Vector2(ceilf(HUD_FUEL.size.x * share), HUD_FUEL.size.y))
		c.draw_rect(fill, Sprites.PALETTE["X" if low else "x"])
		c.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.0)), Sprites.PALETTE["x" if low else "F"])
	for i in w.picks.size():
		c.draw_texture(icon(w.picks[i]), HUD_PICKS + Vector2(i * HUD_PICK_STEP, 0.0))


func _shadows(c: CanvasItem, w) -> void:
	for e in w.enemies:
		var look := Looks.enemy(e.kind)
		c.draw_texture(Sprites.texture(look.shadow), (e.pos + look.shadow_at).round())
	if _keeper_shows(w) and not w.player.dead:
		c.draw_texture(Sprites.texture("shadow"), (w.player.pos + SHADOW).round())


## The ember ring upgrade: embers on the ground around the torch at the distance it burns, flaring each time it does.
func _ember_ring(c: CanvasItem, w) -> void:
	var radius: float = w.mod("ember_radius", 0.0)
	if radius <= 0.0 or w.fuel <= 0.0:
		return
	var since_burn: float = w.mod("ember_every", 1.0) - (w.next_ember - w.time)
	var ember := Sprites.texture("ember_hot" if since_burn < EMBER_PULSE else "ember")
	for i in EMBERS:
		var at: Vector2 = T.pos + Vector2.from_angle(TAU * i / EMBERS + w.time * EMBER_TURN) * radius
		c.draw_texture(ember, (at - ember.get_size() / 2.0).round())


## True while the warm glow upgrade is held: enemies inside the torch's light are slowed, and shown warmed.
func _warms(w) -> bool:
	return w.mod("glow_slow", 1.0) < 1.0


## How an enemy is tinted: warmed while the warm glow slows it, half there while the dark protects it from blows.
func _tint(w, e, warms: bool) -> Color:
	var lit: bool = w.in_light(e.pos)
	var tint := WARMED if warms and lit else Color.WHITE
	if e.T.get("dark_proof", false) and not lit:
		tint.a = GHOST
	return tint


## Everything that stands on the ground, as [depth, texture, top-left, tint]. paint() draws it back to front, so
## what is nearer the bottom of the screen covers what is behind it.
func _standing(w) -> Array:
	var out := []
	var p = w.player
	var warms := _warms(w)
	_put(out, T.pos.y + 7.0, "torch" if w.fuel > 0.0 else "torch_out", T.pos, TORCH_ANCHOR)
	if w.fuel > 0.0:
		var share: float = w.fuel / T.max_fuel
		var size: String = FLAME_SIZES.filter(func(s): return share >= s[0])[0][1]
		var beat: int = (w.steps / FLAME_STEPS) % 4 # a, b, then both mirrored
		var flame := "flame_%s_%s" % [size, "a" if beat % 2 == 0 else "b"]
		var tex := Sprites.texture(flame)
		_put(out, T.pos.y + 7.1, flame, T.pos, Vector2(tex.get_width() / 2.0, tex.get_height()), beat >= 2)
	for l in w.logs:
		_put(out, l.y + 2.0, "log", l, LOG_ANCHOR)
	for b in w.berries:
		_put(out, b.y + 2.0, "berry", b, BERRY_ANCHOR)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var look := Looks.enemy(e.kind)
		if look.flies:
			continue
		_put(out, e.pos.y + 4.0, Looks.frame(e.kind, w.steps, i), e.pos, look.anchor, look.turns and e.vel.x < 0.0, e.flash > 0.0, _tint(w, e, warms))
		if e.carrying:
			_put(out, e.pos.y + 4.1, "log", e.pos + THIEF_CARRY, LOG_ANCHOR)
	if p.dead:
		_put(out, p.pos.y + 5.0, "keeper_dead", p.pos, BODY)
	elif _keeper_shows(w):
		var look := _keeper(w)
		_put(out, p.pos.y + 5.0, look[0], p.pos, BODY, look[1], p.hurt_t > 0.0)
		if p.carrying:
			_put(out, p.pos.y + 5.1, "log", p.pos + CARRY, LOG_ANCHOR)
	return out


## What flies is painted above everything that stands, bobbing.
func _fliers(c: CanvasItem, w) -> void:
	var warms := _warms(w)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var look := Looks.enemy(e.kind)
		if look.flies:
			var bob := roundf(sin((w.steps + i * 9) * 0.2))
			var tex := Sprites.texture(Looks.frame(e.kind, w.steps, i), false, e.flash > 0.0)
			c.draw_texture(tex, (e.pos + Vector2(0.0, bob) - look.anchor).round(), _tint(w, e, warms))


## False on the frames a just-hurt keeper blinks away.
func _keeper_shows(w) -> bool:
	var p = w.player
	return p.dead or not (p.invuln > 0.0 and int(p.invuln * 16.0) % 2 == 0)


## Which keeper sprite to show and whether to mirror it: [sprite, flip].
func _keeper(w) -> Array:
	var p = w.player
	var dir := "down"
	if absf(p.face.x) >= absf(p.face.y):
		dir = "side"
	elif p.face.y < 0.0:
		dir = "up"
	var walking: bool = p.vel.length() > 1.0 and p.hurt_t <= 0.0
	var beat: int = (w.steps / WALK_STEPS) % 4 if walking else 0 # stand, step, stand, other step
	var frame := "b" if beat % 2 == 1 else "a"
	var flip: bool = p.face.x < 0.0 if dir == "side" else beat == 3
	return ["keeper_%s_%s" % [dir, frame], flip]


## Where the swing is: [hand position, reach, angle it started at, angle it is at now, share of the swing done].
## The sweep is the arc the simulation hits (world.arc() and world.reach()), so the picture shows the real reach.
func _sweep(w) -> Array:
	var p = w.player
	var k := clampf(p.attack_t / Config.PLAYER.attack_time, 0.0, 1.0)
	var half := acos(clampf(w.arc(), -1.0, 1.0))
	var from: float = p.face.angle() - half
	return [(p.pos + HAND).round(), w.reach(), from, from + 2.0 * half * (1.0 - pow(1.0 - k, 3.0)), k]


func _swinging(w) -> bool:
	return w.player.attack_t >= 0.0 and not w.player.dead


func _sword(c: CanvasItem, w) -> void:
	if not _swinging(w):
		return
	var sweep := _sweep(w)
	var sword := Sprites.texture("sword")
	c.draw_set_transform(sweep[0], sweep[3], Vector2(sweep[1] / Config.PLAYER.reach, 1.0)) # a longer reach stretches the blade
	c.draw_texture(sword, Vector2(3.0, -sword.get_height() / 2.0))
	c.draw_set_transform(Vector2.ZERO)


func _slash(c: CanvasItem, w) -> void:
	if not _swinging(w):
		return
	var sweep := _sweep(w)
	for arc in SLASH:
		var tail: float = lerpf(sweep[3], sweep[2], arc[1])
		c.draw_arc(sweep[0], sweep[1] - arc[0], tail, sweep[3], 12, Color(arc[2], 1.0 - sweep[4] * sweep[4]), 1.0)


func _put(list: Array, depth: float, sprite: String, at: Vector2, anchor: Vector2, flip := false, white := false, tint := Color.WHITE) -> void:
	list.append([depth, Sprites.texture(sprite, flip, white), (at - anchor).round(), tint])


## Bare earth with a wobbly edge and a few specks, made from the dirt colours. The same picture every time.
static func _clearing_image() -> Image:
	var img := Image.create_empty(CLEARING.x, CLEARING.y, false, Image.FORMAT_RGBA8)
	var mid := Vector2(CLEARING) / 2.0
	for y in CLEARING.y:
		for x in CLEARING.x:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - mid) / mid
			var a := d.angle()
			var edge := 0.86 + 0.07 * sin(a * 3.0 + 0.6) + 0.05 * sin(a * 7.0 + 2.1)
			if d.length() > edge:
				continue
			var speck := _hash(x, y) % 100
			var colour := "M"
			if d.length() > edge - 0.1:
				colour = "N"
			elif speck < 5:
				colour = "m"
			elif speck < 9:
				colour = "N"
			img.set_pixel(x, y, Sprites.PALETTE[colour])
	return img


static func _hash(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)
