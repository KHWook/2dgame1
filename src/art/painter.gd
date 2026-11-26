## How the world looks. It reads the world and paints it with the sprites; it never writes to the world (D4).
## main.gd calls paint() from its _draw, which the night and the torch light then shade, and paint_overlay() from a
## node on a layer above that nothing shades: things that glow by themselves, and the HUD pictures.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const Sprites := preload("res://src/art/sprites.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Effects := preload("res://src/art/effects.gd")
const Looks := preload("res://src/art/looks.gd")
const Juice := preload("res://src/art/juice.gd")
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
const CARRY := Vector2(0.0, -11.0) # a carried log rides on the keeper's raised hands, over the hair
const THIEF_CARRY := Vector2(0.0, -9.0) # and on a thief's back
const SHADOW := Vector2(-6.0, 1.0) # where the keeper's shadow's top-left sits, from the keeper's position
const SLASH_AT := Vector2(0.0, -2.0) # the middle of the swing's trail, from the keeper's position
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

## The sword. The swing sweeps the arc the simulation hits (world.arc()), always turning the same way, and the
## picture runs through four stages, as shares of Config.PLAYER.attack_time: it winds up past the start of the arc,
## strikes across it (the blow lands at PLAYER.attack_hit_at, in the middle of this), holds at the end while the
## trail fades, and goes back to rest in the hand.
const SWING_WIND := 0.18
const SWING_STRIKE := 0.46
const SWING_HOLD := 0.64
const WIND_BACK := 0.5 # radians the blade is pulled back past the start of the arc
const OVERSHOOT := 0.25 # radians it flies past the end before it settles
const LUNGE := 1.0 # pixels the keeper leans into the blow while it strikes and holds
const SHOULDER := Vector2(0.0, 0.5) # the sword hand turns around this point of the keeper
const ARM := 5.0 # pixels from the shoulder to the hand while swinging
const GRIP := Vector2(1.5, 2.5) # the pixel of the sword sprite held in the hand: the middle of the fist
## At rest the sword hangs from the hand on the side the swing starts from, pointing down and a little ahead.
const REST_HAND := Vector2(3.5, 1.0) # where that hand is, along the side and down from it
const REST_DROP := Vector2(0.0, 2.5)
const REST_LENGTH := 0.7 # how long the sword looks at rest, hanging toward the viewer, against its length out
const REST_POINT := [0.7, 0.7, 0.8] # the rest direction: this much of the hand side, the facing, and down
const BEHIND := -0.25 # the sword is painted behind the keeper while it points up more than this (sine of its angle)

## The swing's trail: arcs just inside the reach, each [pixels inside the reach, share of the sweep it trails, colour].
## Each line is [share of the sweep it trails, PALETTE key], outermost first. The upgrades that change the swing
## show in it: the fire blade, where it does its extra damage (in the light), burns the trail and the blade; the
## long blade adds a cold gleam outside the reach; the wide swing draws every line twice as thick.
const SLASH := [[1.0, "W"], [0.7, "a"], [0.4, "A"]]
const SLASH_FIRE := [[1.0, "f"], [0.85, "F"], [0.65, "F"], [0.45, "x"], [0.25, "X"]]
const SLASH_GLEAM := [0.6, "l"] # outside the reach, with the long blade
const WIDE_LINE := 2.0 # pixels per trail line with the wide swing
const SWORD := "sword%s%s" # + "_long" with the long blade, + "_fire" while the fire blade burns
const SWORD_FLAMES := 4 # flames shed along the trail of a burning blade
const FLAME_RISE := 7.0 # pixels they rise while the swing holds
const FLAME_STEPS_FAST := 3 # simulation steps per frame of the flames on the blade

## The HUD sits on three dark panels so it reads over grass, light and day alike: top left (hearts, fuel, upgrades),
## top middle (the clock until dawn, which main.gd writes, over the night's progress) and top right (the night and the
## score, written by main.gd, which tells the painter how wide its words are).
const HUD_PANEL := Color(0.08, 0.06, 0.12, 0.62)
const HUD_PAD := 3.0 # panel edge to what it holds
const HUD_HEARTS := Vector2(5.0, 5.0)
const HUD_HEART_STEP := 10.0
const HUD_FUEL := Rect2(15.0, 17.0, 60.0, 6.0) # main.gd writes how long the fuel lasts just past its end
const HUD_FUEL_TEXT := 4.0 # from the end of the fuel bar to those words
const HUD_LOW := 0.25 # the fuel bar turns red and blinks below this share
const HUD_LOW_SECONDS := 10.0 # ... or when it would go out within this many seconds
const HUD_BLINK_STEPS := 10
const HUD_PICKS := Vector2(5.0, 28.0) # the upgrades you hold, in the order you first took them
const HUD_PICK_STEP := Vector2(12.0, 14.0) # icon to icon along a row, row to row
const HUD_PICKS_PER_ROW := 8
const ICON_SIZE := 9.0 # upgrade icons are 9x9
const HUD_LEVEL := Vector2(0.0, 10.0) # under an icon, a pip per level, this far from its top-left
const HUD_LEVEL_PIP := Vector2(2.0, 2.0)
const HUD_LEVEL_STEP := 3.0
## The night's progress towards dawn, under the clock that main.gd writes at the top in the middle.
const NIGHT_BAR := Rect2(195.0, 18.0, 90.0, 3.0)
const CLOCK_PANEL := Rect2(185.0, 1.0, 110.0, 23.0)
const BOSS_BAR := Rect2(140.0, 254.0, 200.0, 5.0) # a boss's health, along the bottom; main.gd writes its name above
const BOSS_BAR_COLOUR := "i"

## The dash: copies of the keeper trail behind while it dashes, fading, this far apart along the dash.
const DASH_GHOSTS := 3
const DASH_GHOST_GAP := 6.0
const DASH_GHOST := Color(0.65, 0.85, 1.0, 0.45)
const SPARK_TAIL := [[0.012, "F"], [0.024, "x"], [0.036, "X"]] # pixels behind a spark: [seconds back along its flight, colour]

## An enemy faster in the dark (looks.gd's dark_glow) streaks its burning eyes behind it: this many copies, this many
## pixels apart, the nearest this solid.
const DARK_STREAK := 3
const DARK_STREAK_GAP := 3.0
const DARK_STREAK_FADE := 0.7

## How upgrades show in the world. The rest show only as their icon.
const WARMED := Color(1.0, 0.74, 0.5) # tint of an enemy the warm glow is slowing
const EMBERS := 14 # embers in the ember ring
const EMBER_TURN := 0.4 # radians per second the ring drifts round
const EMBER_PULSE := 0.2 # seconds the embers flare after the ring burns what is inside it

var fuel_text_width := 0.0 # set by main.gd: the words after the fuel bar, 0 when they are hidden
var score_text_width := 0.0 # set by main.gd: the night and the score, top right
var effects # short-lived pictures that answer what happens in the world
var scenery: Array = [] # [texture, top-left]
var clearing: Texture2D
var hedges := {} # side -> texture: the treetops along each screen edge
var shake := Vector2.ZERO # set by main.gd: how far the field is drawn off its place right now (src/art/juice.gd)


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
	c.draw_rect(Rect2(Vector2.ZERO, VIEW).grow(Juice.MARGIN), Sprites.PALETTE["u"]) # the hedge goes on past the view, for a shake
	c.draw_rect(Rect2(Vector2.ZERO, VIEW), GROUND)
	c.draw_texture(clearing, (T.pos + CLEARING_DROP - Vector2(CLEARING) / 2.0).round())
	for s in scenery:
		c.draw_texture(s[0], s[1])
	_ember_ring(c, w)
	_shadows(c, w)
	var standing := _standing(w)
	standing.sort_custom(func(a, b): return a[0] < b[0])
	for s in standing:
		if s[1] == null:
			_sword(c, w)
		else:
			c.draw_texture(s[1], s[2], s[3])
	_fliers(c, w)
	for x in range(0, int(VIEW.x), 16):
		c.draw_texture(hedges.top, Vector2(x, 0.0))
		c.draw_texture(hedges.bottom, Vector2(x, VIEW.y - HEDGE_DEPTH))
	for y in range(0, int(VIEW.y), 16):
		c.draw_texture(hedges.left, Vector2(0.0, y))
		c.draw_texture(hedges.right, Vector2(VIEW.x - HEDGE_DEPTH, y))


func paint_overlay(c: CanvasItem, w) -> void:
	c.draw_set_transform(shake) # what glows in the field shakes with it (main.gd moves the field); the HUD does not
	effects.paint(c)
	_slash(c, w)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var look := Looks.enemy(e.kind)
		var at: Vector2 = e.pos + _bob(w, i, look) - look.anchor
		if look.glow != "":
			c.draw_texture(Sprites.texture(look.glow), at.round())
		if look.dark_glow != "" and not w.in_light(e.pos):
			_dark_glow(c, e, Sprites.texture(look.dark_glow), at)
	c.draw_set_transform(Vector2.ZERO)
	_hud_panels(c, w)
	for i in w.max_hp():
		c.draw_texture(Sprites.texture("heart" if i < w.player.hp else "heart_empty"), HUD_HEARTS + Vector2(i * HUD_HEART_STEP, 0.0))
	var share := clampf(w.fuel / w.max_fuel(), 0.0, 1.0)
	var low: bool = fuel_low(w)
	var bar := fuel_bar(w)
	c.draw_texture(Sprites.texture("flame_s_a"), Vector2(HUD_HEARTS.x, HUD_FUEL.position.y - 1.0))
	c.draw_rect(bar.grow(1.0), Sprites.PALETTE["k"])
	c.draw_rect(bar, Sprites.PALETTE["K"])
	if not (low and (w.steps / HUD_BLINK_STEPS) % 2 == 0):
		var fill := Rect2(bar.position, Vector2(ceilf(bar.size.x * share), bar.size.y))
		c.draw_rect(fill, Sprites.PALETTE["X" if low else "x"])
		c.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.0)), Sprites.PALETTE["x" if low else "F"])
	var ids := held(w)
	for i in ids.size():
		var at := _pick_at(i)
		c.draw_texture(icon(ids[i]), at)
		var n: int = w.level(ids[i])
		for d in n if n > 1 else 0: # one pip per level once there is more than one
			c.draw_rect(Rect2(at + HUD_LEVEL + Vector2(d * HUD_LEVEL_STEP, 0.0), HUD_LEVEL_PIP), Sprites.PALETTE["Y"])
	_sparks(c, w)
	_boss_bar(c, w)
	_night_bar(c, w)


## The upgrades held, each once, in the order first taken.
static func held(w) -> Array:
	var out := []
	for id in w.picks:
		if not out.has(id):
			out.append(id)
	return out


static func _pick_at(i: int) -> Vector2:
	return HUD_PICKS + Vector2(i % HUD_PICKS_PER_ROW * HUD_PICK_STEP.x, i / HUD_PICKS_PER_ROW * HUD_PICK_STEP.y)


## The dark panels behind the HUD. The words' widths come from main.gd, which writes them.
func _hud_panels(c: CanvasItem, w) -> void:
	var right := fuel_bar(w).end.x + (HUD_FUEL_TEXT + fuel_text_width if fuel_text_width > 0.0 else 0.0)
	right = maxf(right, HUD_HEARTS.x + w.max_hp() * HUD_HEART_STEP - 1.0)
	var bottom := fuel_bar(w).end.y
	var n := held(w).size()
	if n > 0:
		right = maxf(right, _pick_at(mini(n, HUD_PICKS_PER_ROW) - 1).x + ICON_SIZE)
		bottom = _pick_at(n - 1).y + HUD_LEVEL.y + HUD_LEVEL_PIP.y
	c.draw_rect(Rect2(Vector2(HUD_HEARTS.x - HUD_PAD, 1.0), Vector2(right - HUD_HEARTS.x + 2.0 * HUD_PAD, bottom + HUD_PAD - 1.0)), HUD_PANEL)
	if w.phase == "night":
		c.draw_rect(CLOCK_PANEL, HUD_PANEL)
	if score_text_width > 0.0:
		c.draw_rect(Rect2(VIEW.x - score_text_width - 4.0 - HUD_PAD * 2.0, 1.0, score_text_width + HUD_PAD * 2.0 + 2.0, 14.0), HUD_PANEL)


## Whether anything is smothering the torch right now, so its fuel runs out faster.
static func smothered(w) -> bool:
	for e in w.enemies:
		if e.at_torch and not e.dead:
			return true
	return false


## Where the fuel bar is: a big torch has a longer one.
static func fuel_bar(w) -> Rect2:
	return Rect2(HUD_FUEL.position, Vector2(roundf(HUD_FUEL.size.x * w.max_fuel() / T.max_fuel), HUD_FUEL.size.y))


## Seconds until the torch goes out at the rate it burns right now (smothering included).
static func fuel_left(w) -> float:
	var rate: float = w.burn_rate()
	return w.fuel / rate if rate > 0.0 else INF


## Whether the fuel is low enough to warn about: under a quarter of the tank, or out before ten seconds pass.
static func fuel_low(w) -> bool:
	return w.fuel / w.max_fuel() < HUD_LOW or fuel_left(w) < HUD_LOW_SECONDS


func _night_bar(c: CanvasItem, w) -> void:
	if w.phase != "night":
		return
	var share := clampf(w.time / Config.NIGHT.length, 0.0, 1.0)
	c.draw_rect(NIGHT_BAR.grow(1.0), Sprites.PALETTE["k"])
	c.draw_rect(NIGHT_BAR, Sprites.PALETTE["K"])
	c.draw_rect(Rect2(NIGHT_BAR.position, Vector2(ceilf(NIGHT_BAR.size.x * share), NIGHT_BAR.size.y)), Sprites.PALETTE["Y"])


## The embers the spark upgrade fires: they glow, so they are painted where the night does not dim them.
func _sparks(c: CanvasItem, w) -> void:
	var tex := Sprites.texture("spark")
	for sp in w.sparks:
		for t in SPARK_TAIL:
			c.draw_rect(Rect2((sp.pos - sp.vel * t[0]).round(), Vector2.ONE), Sprites.PALETTE[t[1]])
		c.draw_texture(tex, (sp.pos - tex.get_size() / 2.0).round())


## The first boss on the field, or null.
static func boss(w):
	for e in w.enemies:
		if e.T.get("boss", false) and not e.dead:
			return e
	return null


func _boss_bar(c: CanvasItem, w) -> void:
	var b = boss(w)
	if b == null:
		return
	c.draw_rect(BOSS_BAR.grow(2.0), HUD_PANEL)
	c.draw_rect(BOSS_BAR.grow(1.0), Sprites.PALETTE["k"])
	c.draw_rect(BOSS_BAR, Sprites.PALETTE["K"])
	c.draw_rect(Rect2(BOSS_BAR.position, Vector2(ceilf(BOSS_BAR.size.x * float(b.hp) / b.T.hp), BOSS_BAR.size.y)), Sprites.PALETTE[BOSS_BAR_COLOUR])


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
		for g in DASH_GHOSTS if p.dash_t > 0.0 else 0:
			var ghost := DASH_GHOST
			ghost.a *= 1.0 - float(g) / DASH_GHOSTS
			_put(out, p.pos.y + 4.8, look[0], p.pos - p.dash_dir * DASH_GHOST_GAP * (g + 1), BODY, look[1], true, ghost)
		_put(out, p.pos.y + 5.0, look[0], p.pos + _lean(w), BODY, look[1], p.hurt_t > 0.0)
		if w.mod("thorns", 0) > 0: # the thorn cloak: behind the keeper, except seen from behind
			_put(out, p.pos.y + (5.05 if look[2] == "up" else 4.95), "thorns_%s" % look[2], p.pos + _lean(w), BODY, look[1], p.hurt_t > 0.0)
		if p.carrying:
			_put(out, p.pos.y + 5.1, "log", p.pos + CARRY, LOG_ANCHOR)
		else:
			var behind: bool = sin(_blade(w)[1]) < BEHIND
			out.append([p.pos.y + (4.9 if behind else 5.2), null]) # the sword: paint() draws it at this depth
	return out


## What flies is painted above everything that stands, bobbing.
func _fliers(c: CanvasItem, w) -> void:
	var warms := _warms(w)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var look := Looks.enemy(e.kind)
		if look.flies:
			var tex := Sprites.texture(Looks.frame(e.kind, w.steps, i), false, e.flash > 0.0)
			c.draw_texture(tex, (e.pos + _bob(w, i, look) - look.anchor).round(), _tint(w, e, warms))


## How far a flier is lifted off its place on this step; nothing for what stands.
static func _bob(w, i: int, look: Dictionary) -> Vector2:
	return Vector2(0.0, roundf(sin((w.steps + i * 9) * 0.2))) if look.flies else Vector2.ZERO


## An enemy that hunts faster in the dark: its eyes burn while it is out there, streaking behind it as it moves.
func _dark_glow(c: CanvasItem, e, eyes: Texture2D, at: Vector2) -> void:
	var back: Vector2 = -e.vel.normalized() if e.vel != Vector2.ZERO else Vector2.ZERO
	for g in range(DARK_STREAK, 0, -1):
		c.draw_texture(eyes, (at + back * DARK_STREAK_GAP * g).round(), Color(1.0, 1.0, 1.0, DARK_STREAK_FADE * (1.0 - float(g) / (DARK_STREAK + 1))))
	c.draw_texture(eyes, at.round())


## False on the frames a just-hurt keeper blinks away.
func _keeper_shows(w) -> bool:
	var p = w.player
	return p.dead or not (p.invuln > 0.0 and int(p.invuln * 16.0) % 2 == 0)


## Which keeper sprite to show, whether to mirror it, and which way it faces: [sprite, flip, "down"/"up"/"side"].
func _keeper(w) -> Array:
	var p = w.player
	var dir := "down"
	if absf(p.face.x) >= absf(p.face.y):
		dir = "side"
	elif p.face.y < 0.0:
		dir = "up"
	if _swinging(w):
		return ["keeper_%s_atk" % dir, dir == "side" and p.face.x < 0.0, dir]
	var walking: bool = p.vel.length() > 1.0 and p.hurt_t <= 0.0
	var beat: int = (w.steps / WALK_STEPS) % 4 if walking else 0 # stand, step, stand, other step
	var frame := "b" if beat % 2 == 1 else "a"
	var flip: bool = p.face.x < 0.0 if dir == "side" else beat == 3
	return ["keeper_%s%s_%s" % [dir, "_lift" if p.carrying else "", frame], flip, dir]


func _swinging(w) -> bool:
	return w.player.attack_t >= 0.0 and not w.player.dead


## How far into the swing it is, 0 to 1, or -1 when the keeper is not swinging.
func _swing_share(w) -> float:
	return clampf(w.player.attack_t / Config.PLAYER.attack_time, 0.0, 1.0) if _swinging(w) else -1.0


## Where along a stage of the swing k is, 0 to 1.
func _stage(k: float, from: float, to: float) -> float:
	return clampf((k - from) / (to - from), 0.0, 1.0)


## How far the keeper leans into the blow: a pixel toward the facing while the swing strikes and holds.
func _lean(w) -> Vector2:
	var k := _swing_share(w)
	if k < SWING_WIND or k >= SWING_HOLD:
		return Vector2.ZERO
	return (w.player.face * LUNGE).round()


## The angles of the swing: [start of the arc, end of the arc, wound up]. The sweep turns counter-clockwise on the
## screen and starts on the hand side, the side the facing turned a quarter clockwise points to.
func _arc(w) -> Array:
	var half := acos(clampf(w.blow_arc(), -1.0, 1.0)) # a spin goes all the way round
	var start: float = w.player.face.angle() + half
	return [start, start - 2.0 * half, start + WIND_BACK]


## Where the sword rests: [hand position, angle], the angle unwound to lie near near_angle.
func _rest(w, near_angle: float) -> Array:
	var p = w.player
	var side: Vector2 = p.face.rotated(PI / 2.0)
	var point: Vector2 = side * REST_POINT[0] + p.face * REST_POINT[1] + Vector2.DOWN * REST_POINT[2]
	var hand: Vector2 = p.pos + REST_DROP + side * REST_HAND
	return [hand, near_angle + wrapf(point.angle() - near_angle, -PI, PI)]


## Where the sword is now: [hand position, angle, how far the hand is out from rest, 0 to 1]. The hand goes from its resting place out to ARM from the
## shoulder while winding up, and back while recovering.
func _blade(w) -> Array:
	var p = w.player
	var k := _swing_share(w)
	var arc := _arc(w)
	if k < 0.0:
		return _rest(w, arc[0]) + [0.0]
	var shoulder: Vector2 = p.pos + _lean(w) + SHOULDER
	var a: float
	var out := 1.0 # how far the hand is from rest toward the arm's length out
	if k < SWING_WIND:
		var rest := _rest(w, arc[2])
		out = ease(_stage(k, 0.0, SWING_WIND), 0.4)
		a = lerpf(rest[1], arc[2], out)
	elif k < SWING_STRIKE:
		a = lerpf(arc[2], arc[1] - OVERSHOOT, smoothstep(0.0, 1.0, _stage(k, SWING_WIND, SWING_STRIKE)))
	elif k < SWING_HOLD:
		a = lerpf(arc[1] - OVERSHOOT, arc[1], ease(_stage(k, SWING_STRIKE, SWING_HOLD), 0.5))
	else:
		var rest := _rest(w, arc[1])
		out = 1.0 - smoothstep(0.0, 1.0, _stage(k, SWING_HOLD, 1.0))
		a = lerpf(rest[1], arc[1], out)
	var rest_hand: Vector2 = _rest(w, a)[0]
	return [rest_hand.lerp(shoulder + Vector2.from_angle(a) * ARM, out), a, out]


## True while the fire blade does its extra damage: it is held and the keeper stands in the light.
func _burning(w) -> bool:
	return w.mod("lit_damage", 0) > 0 and w.in_light(w.player.pos)


func _sword_texture(w) -> Texture2D:
	return Sprites.texture(SWORD % ["_long" if w.mod("reach_bonus", 0.0) > 0.0 else "", "_fire" if _burning(w) else ""])


## How much the sword sprite is stretched along its length, so that at full length its tip reaches as far past the
## base sword's as world.reach() goes past the base reach, and it looks shorter at rest.
func _stretch(w, sword: Texture2D, out: float) -> float:
	var base := Sprites.texture("sword").get_width() - GRIP.x
	var stretch: float = (w.reach() - Config.PLAYER.reach + base) / (sword.get_width() - GRIP.x)
	return stretch * lerpf(REST_LENGTH, 1.0, out)


func _sword(c: CanvasItem, w) -> void:
	var blade := _blade(w)
	var sword := _sword_texture(w)
	c.draw_set_transform(blade[0].round(), blade[1], Vector2(_stretch(w, sword, blade[2]), 1.0))
	c.draw_texture(sword, -GRIP)
	c.draw_set_transform(Vector2.ZERO)


## The trail follows the blade through the strike at the reach the simulation hits (world.reach()), then shrinks
## into the blade and fades while the swing holds. A burning blade sheds flames that rise off it.
func _slash(c: CanvasItem, w) -> void:
	var p = w.player
	if p.dead or p.carrying:
		return
	var burning := _burning(w)
	var blade := _blade(w)
	if burning: # a flame licks the tip whenever the blade burns, swinging or not
		var sword := _sword_texture(w)
		var tip: Vector2 = blade[0] + Vector2.from_angle(blade[1]) * (sword.get_width() - GRIP.x - 1.0) * _stretch(w, sword, blade[2])
		var lick := Sprites.texture("flame_s_%s" % ("a" if (w.steps / FLAME_STEPS_FAST) % 2 == 0 else "b"))
		c.draw_texture(lick, (tip - Vector2(3.0, 5.0)).round())
	var k := _swing_share(w)
	if k < SWING_WIND or k >= SWING_HOLD:
		return
	var arc := _arc(w)
	var a: float = blade[1]
	var hold := _stage(k, SWING_STRIKE, SWING_HOLD)
	var fade := Color(1.0, 1.0, 1.0, 1.0 - hold * hold)
	var at: Vector2 = (p.pos + _lean(w) + SLASH_AT).round()
	var lines: Array = (SLASH_FIRE if burning else SLASH).duplicate()
	var r: float = w.reach()
	if w.mod("reach_bonus", 0.0) > 0.0:
		lines.push_front(SLASH_GLEAM)
		r += 1.0
	var width: float = WIDE_LINE if w.mod("arc_bonus", 0.0) < 0.0 else 1.0
	for i in lines.size():
		var tail: float = lerpf(a, arc[2], lines[i][0] * (1.0 - hold))
		if absf(tail - a) > 0.05:
			c.draw_arc(at, r - (i + 0.5) * width + 0.5, tail, a, 12, Sprites.PALETTE[lines[i][1]] * fade, width)
	if burning:
		for j in SWORD_FLAMES:
			var share := (j + 1.0) / (SWORD_FLAMES + 1.0)
			var spot: float = lerpf(a, arc[2], share * (1.0 - hold * 0.5))
			var flame := Sprites.texture("flame_s_%s" % ("a" if (w.steps / FLAME_STEPS_FAST + j) % 2 == 0 else "b"))
			var rise := Vector2(0.0, -FLAME_RISE * hold - j)
			c.draw_texture(flame, (at + Vector2.from_angle(spot) * (r - 3.0) + rise - Vector2(3.0, 5.0)).round(), fade)


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
