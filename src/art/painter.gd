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
const NIGHT := Color("#15132a") # what the night leaves of every colour out of the light: next to nothing
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

## The sword. The swing sweeps the arc the simulation hits (world.swing_half()), always turning the same way, and the
## picture runs through four stages, as shares of the keeper's attack_time (World.stats): it winds up past the start of the arc,
## strikes across it (the blow starts landing at PLAYER.attack_hit_at, in the middle of this), holds at the end while
## the trail fades, and goes back to rest in the hand. The trail shows until the blow stops landing
## (attack_hit_until: _hold()), so while it is on screen, whatever it covers is struck. The woodcutter's axe chops
## instead (CHOP_* below; it sweeps like this only on a spin). Looks.CHARACTERS says which weapon a character holds;
## the mage holds none and shoots embers.
const SWING_WIND := 0.18
const SWING_STRIKE := 0.46
const WIND_BACK := 0.5 # radians the blade is pulled back past the start of the arc
const OVERSHOOT := 0.25 # radians it flies past the end before it settles
const LUNGE := 1.0 # pixels the keeper leans into the blow while it strikes and holds
const SHOULDER := Vector2(0.0, 0.5) # the sword hand turns around this point of the keeper
const ARM := 5.0 # pixels from the shoulder to the hand while swinging
## At rest the sword hangs from the hand on the side the swing starts from, pointing down and a little ahead.
const REST_HAND := Vector2(3.5, 1.0) # where that hand is, along the side and down from it
const REST_DROP := Vector2(0.0, 2.5)
const REST_LENGTH := 0.7 # how long the sword looks at rest, hanging toward the viewer, against its length out
const REST_POINT := [0.7, 0.7, 0.8] # the rest direction: this much of the hand side, the facing, and down
const BEHIND := -0.25 # the sword is painted behind the keeper while it points up more than this (sine of its angle)

## The swing's trail: arcs just inside the reach, each [pixels inside the reach, share of the sweep it trails, colour].
## Each line is [share of the sweep it trails, PALETTE key], outermost first. The upgrades that change the swing
## show in it: the fire blade, where it does its extra damage (in the light), burns the trail and the blade; the
## long blade adds a cold gleam at the reach; the wide swing draws every line twice as thick.
const SLASH := [[1.0, "W"], [0.7, "a"], [0.4, "A"]]
const SLASH_FIRE := [[1.0, "f"], [0.85, "F"], [0.65, "F"], [0.45, "x"], [0.25, "X"]]
const SLASH_GLEAM := [0.6, "l"] # the outermost line, at the reach, with the long blade
const WIDE_LINE := 2.0 # pixels per trail line with the wide swing
## Under the trail's lines, the smear: filled bands from the reach inward, widest at the blade and thinning to its
## tail, each [pixels wide at the blade, share of the sweep it trails, PALETTE key, alpha], widest first; steps: the
## facets along it (the axe's few and chunky, the sword's smooth). A burning blade's bands burn (SMEAR_FIRE keys in
## order); the wide swing widens them by SMEAR_WIDE. Like the lines, every band lies inside world.in_swing() and its
## outer edge is the reach (tools/rules_test.gd), so the smear shows exactly what the blow covers.
const SMEAR := {
	"sword": { "bands": [[6.0, 0.9, "A", 0.55], [4.0, 0.7, "a", 0.8], [2.0, 0.45, "W", 1.0]], "steps": 12 },
	"axe": { "bands": [[11.0, 1.0, "T", 0.85], [8.0, 0.85, "A", 0.95], [5.0, 0.6, "a", 1.0], [2.0, 0.35, "W", 1.0]], "steps": 5 },
}
const SMEAR_FIRE := ["X", "x", "F", "f"]
const SMEAR_WIDE := 1.4
const SMEAR_TAIL := 0.2 # a band's width at its tail, as a share of its width at the blade
const SMEAR_HEAD := 2.0 # the bright pixel square at the blade's end of the smear, while it strikes
const SWORD := "%s%s%s" # the weapon + "_long" with the long blade, + "_fire" while the fire blade burns
## A chop (World stats attack "chop", unless the swing is a spin): the axe turns in the upright plane of the facing,
## seen from above, so going up it shortens and climbs the screen. As shares of the time to the blow
## (attack_hit_at): it rises behind and over the head (CHOP_UP radians back from pointing ahead along the ground)
## until CHOP_RAISE, then falls, faster and faster, flat on the ground ahead by the blow, its head on the middle of the
## round the simulation strikes (world.chop_centre()). It stays bitten in, quivering a pixel for CHOP_QUIVER steps,
## while the blow lands, then goes back to rest. The keeper raises its arms (the _raise sprite) and leans back a
## pixel while the axe goes up, and lunges a pixel into the blow.
const CHOP_UP := 2.1
const CHOP_RAISE := 0.72
const CHOP_HEIGHT := 0.8 # how much of the axe's height above the ground shows as up on the screen
const CHOP_QUIVER := 3
const AXE_HEAD := 4.0 # pixels from the end of an axe sprite back to the middle of its head
## Where the chop comes down (chop_marks()): while the blow lands, a dent with cracks running out from the middle
## (CHOP_CRACKS of them, each of CRACK_JOINTS bends, reaching CRACK_REACH of the radius) and a ring of thrown dust whose
## outer edge is the round's edge, world.chop_radius(); both fade over the blow. Effects adds dust flying out to the
## same edge and chips. A burning axe's ring and cracks glow.
const CHOP_CRACKS := 5
const CRACK_JOINTS := 3
const CRACK_REACH := 0.85
const CRACK_BEND := 0.35 # radians a crack wanders at each bend
const CHOP_DENT := ["N", 0.45] # PALETTE key and alpha of the dent
const CHOP_RING := ["w", "F"] # the dust ring, and a burning axe's
const CHOP_RING_WIDE := 2.0 # pixels wide for the first half of the blow (its outer edge stays the radius)
const CHOP_CRACK := ["k", "x"]
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
## The upgrades you hold: each on a tile, one row per side (looks.gd's SIDES: the torch's, then the keeper's), in the
## order first taken. A tile's colour says the side; under the icon a pip per level it can reach, the reached ones
## gold; a tile at its last level gets a gold edge. main.gd's ui names them on the pause and end screens.
const HUD_PICKS := Vector2(5.0, 28.0) # the first tile's top-left
const TILE := Vector2(13.0, 15.0)
const TILE_STEP := Vector2(14.0, 17.0) # tile to tile along a row, row to row
const TILE_ICON := Vector2(2.0, 2.0) # the icon's top-left in its tile
const ICON_SIZE := 9.0 # upgrade icons are 9x9
const TILE_PIP := Vector2(3.0, 2.0) # a level pip, its row this far from the tile's top
const TILE_PIP_Y := 12.0
const TILE_BACK := { "torch": Color("#43281a"), "keeper": Color("#1f2d4a") }
const TILE_EDGE := { "torch": Color("#8a5430"), "keeper": Color("#46619a") }
const TILE_FULL := "Y" # PALETTE key of a reached pip, and of the edge of a tile at its last level
const TILE_EMPTY := "K"
const TILE_FLASH := 3.0 # pixels the white ring grows out from a tile that just got its upgrade
## Logs and berries keep a lit ring the night does not dim (Sprites.rim), stronger in the dark, breathing, with a glint
## now and then, so they read on the dark grass; a berry also bobs. Each thing has its own phase, from where it lies.
const LOG_RIM := "F"
const BERRY_RIM := "W"
const RIM_DARK := [0.45, 0.9] # its alpha out of the light, as it breathes
const RIM_LIT := [0.3, 0.55] # and in the light, where the thing shows anyway
const RIM_BREATH := 0.09 # radians per step
const SELF_LIT := 0.7 # out of the light the thing itself is also painted unlit, this much of the ring's alpha
const GLINT_EVERY := 150 # steps between two glints on one thing
const GLINT_STEPS := 14 # how long one lasts
const BERRY_BOB_STEPS := 20 # steps per half bob
## The dim over the field while a box asks something (main.gd's ui sets how strong).
const SCRIM := Color(0.03, 0.02, 0.07)
## The night's progress towards dawn, under the clock that main.gd writes at the top in the middle.
const NIGHT_BAR := Rect2(195.0, 18.0, 90.0, 3.0)
const CLOCK_PANEL := Rect2(185.0, 1.0, 110.0, 23.0)
const BOSS_BAR := Rect2(140.0, 254.0, 200.0, 5.0) # the first boss's health, along the bottom; the ui writes its name left of it
const BOSS_BAR_STEP := 10.0 # each next boss's bar is this much higher: they stack up from the bottom
const BOSS_BAR_COLOUR := "i"

## The dash: copies of the keeper trail behind while it dashes, fading, this far apart along the dash.
const DASH_GHOSTS := 3
const DASH_GHOST_GAP := 6.0
const DASH_GHOST := Color(0.65, 0.85, 1.0, 0.45)
const SPARK_TAIL := [[0.012, "F"], [0.024, "x"], [0.036, "X"]] # pixels behind a spark: [seconds back along its flight, colour]
## The keeper's embers (a shooter's bolts): a disc as big as what it hits (World.bolt_radius, World.in_bolt), brighter
## in the torch's light where it burns harder, with its core and a tail of [pixels back along its flight, colour].
const BOLT_DISC := Color("#f58230")
const BOLT_DISC_LIT := Color("#ffc94a")
const BOLT_TAIL := [[3.0, "F"], [5.0, "x"]] # effects.gd sheds the sparks further back
const BOLT_CORES := ["bolt", "bolt_c", "bolt_b", "bolt_c", "bolt", "bolt_b"] # the core's flicker, a frame a step
const BOLT_INNER := [0.55, 0.7, 0.5, 0.65] # the hot middle's radius as a share of the disc's, flickering
const BOLT_GLOW := 0.55 # how solid the disc (what it hits) is; the hot middle is solid
## The embers light the dark around them as they fly, and a burst flares where one stops, so the mage sees what it
## shoots at out past the torch. Only to see by, like the keeper's ember: the rules' light is the torch's alone
## (world.in_light), so the lit bonus and the shade's dark are not changed by it. main.gd puts a light at each.
const BOLT_LIGHT := 30.0 # pixels an ember in flight lights around it
const BOLT_LIGHT_ENERGY := [0.75, 0.95] # flickering between these
const BURST_LIGHT := 20.0 # pixels past the burst's radius its flare lights, fading as the ring goes out
const BURST_LIGHT_ENERGY := 1.2
const MAX_LIGHTS := 8 # main.gd keeps this many lights for embers and bursts; past it the newest are not lit
const STACK_STEP := Vector2(0.0, -3.0) # each more log a keeper carries sits this far above the one under it

## An enemy faster in the dark (looks.gd's dark_glow) streaks its burning eyes behind it: this many copies, this many
## pixels apart, the nearest this solid.
const DARK_STREAK := 3
const DARK_STREAK_GAP := 3.0
const DARK_STREAK_FADE := 0.7

## The torch's light, as main.gd's lights show it: full at the torch and falling away to nothing at the edge, which is
## exactly world.light_radius() out at its furthest. The edge is a ring of tongues, and two such rings turn against
## each other, so it wavers like a flame without ever reaching past the radius the rules use. The whole light also
## flickers a little.
const LIGHT_SIZE := 128 # pixels across the light's picture
const LIGHT_FALL := 2.0 # how late the light falls off toward its edge: 1 is a straight slope
const LIGHT_RINGS := [[5, 0.45], [7, -0.3]] # [tongues round the edge, radians per second the ring turns]
const LIGHT_LICK := 0.1 # how far in from the radius the edge dips between two tongues, as a share of it
const LIGHT_FLICKER := [[0.37, 0.04], [0.83, 0.03]] # [radians per step, share of the brightness] added up
## What stands in the light throws a long shadow away from the torch: its own shape laid on the ground from its
## feet, longer the further out it stands, gone at the edge of the light, where everything is dark anyway.
const CAST := Color(0.02, 0.01, 0.06, 0.5)
const CAST_LENGTH := [0.9, 2.4] # times the thing's height: at the torch, at the edge of the light
const CAST_FADE := [0.75, 1.1] # it fades out between these shares of the light's radius
const CAST_NEAR := 6.0 # pixels: closer to the torch than this the shadow has no direction, so none is thrown
## The keeper's ember: fire taken from the torch to see by. It catches only at the torch itself, as close as a log
## is fed from (world.gd), keeps what it has anywhere in the torch's light, and cools out of it, lighting less and
## less around the keeper and turning from gold to red. Walking back into the light does not bring it back: the
## keeper has to go and touch the torch. It is only for seeing: the rules' light is the torch's alone
## (world.in_light), so the ember is small and red where the torch's light is wide and warm.
const EMBER_COOL := 10.0 # seconds out of the torch's light until it has cooled all the way
const EMBER_KINDLE := 0.4 # seconds at the torch until it burns full again
const EMBER_REACH := [13.0, 46.0] # pixels it lights around the keeper: cooled, full
const EMBER_GLOW := [0.4, 0.85] # how bright that light is: cooled, full
const EMBER_COLOUR := ["X", "F"] # PALETTE keys of its light: cooled, full
const EMBER_AT := Vector2(6.0, -4.0) # where it floats: this far to the side away from the sword hand, and up
const EMBER_BOB_STEPS := 24 # steps per half bob
const EMBER_HOT := 0.6 # it is drawn as the big ember above this share, the small one below
const EMBER_DIM := 0.6 # how solid the ember itself looks when cooled
const EMBER_CATCH := 0.7 # reaching the torch cooler than this share, it flares as it catches
const EMBER_FLARE := 0.35 # seconds that flare lasts
const EMBER_FLARE_GLOW := 0.6 # how much brighter its light is at the start of the flare

## A boss's pattern, warned before it strikes (src/sim/enemy.gd). The slime king's marked landing (mark_radius(): the
## shock): the king's shadow grows on the ground from the middle to the shock as it falls, cracks run out through it,
## a dashed ring at the shock turns, and dust trickles down inside it; the king crouches and flashes while it waits
## and is lifted off its shadow in the air. The shade lord, about to rush, flashes and lays a dashed line from itself
## to the torch.
const MARK := "i" # PALETTE key of the marked landing and the rush line
const MARK_RING := Color("#ff7a5c") # the turning ring at the shock: warm, softer than the hearts' red
const MARK_SHADOW := Color("#0b0814") # the falling king's shadow
const MARK_SHADOW_MOST := 0.55 # how dark it is as the king lands
const MARK_SHADOW_FROM := 0.25 # share of the shock the shadow starts at
const MARK_DASHES := 12 # dashes round the ring
const MARK_TURN := 1.5 # radians per second the ring turns
const MARK_CRACKS := 6 # cracks running out from the middle
const MARK_CRACK_KINKS := 3 # bends in each
const MARK_CRACK := Color("#2a1e18")
const MARK_DUST := 5 # dust pixels trickling inside the ring
const MARK_BLINK_STEPS := 4
const LEAP_HEIGHT := 26.0 # pixels the king rises at the top of its leap
const RUSH_DASH := 4.0 # pixels per dash of the rush line, and per gap
## The shade lord about to split: it flashes inside a turning dashed ring, and as many wisps of smoke as it will have
## decoys (a little turning ring of smoke pixels each) slide round from it along its ring to where they will appear.
const SPLIT_SMOKE := "7"
const SPLIT_WISP := 8 # smoke pixels in each wisp
## A charger about to charge (Config.ENEMY_TYPES.boar.charge): it flashes and paws (shuffles a pixel to and fro,
## kicking up dust) on a soft warm band laid from itself to where the charge ends, as wide as the charge hurts
## (charge_band: Enemy.lane_half() each side of its line, round at the ends): outside the band is safe, and its edge
## line is the strongest part of it. The band fills from the boar toward its end as the wind-up runs out, chevrons
## slide along it toward the end (faster as the wind-up runs out: chevrons()), and stays under the charge, which
## leaves a trail of dust; where it stops it skids in a puff. Dazed after, stars turn over its head.
const LANE := Color("#e8956a") # a soft warm orange: a warning, not a wall of red
const LANE_FAINT := 0.06 # how solid the band is the moment it is drawn
const LANE_FULL := 0.15 # how solid the filled part is (and the whole band while it charges)
const LANE_EDGE := 0.6 # its outline, blinking down to 0.7 of this
const LANE_ROUND := 8 # points on each round end
const CHEVRON_GAP := 12.0 # pixels between chevrons along the band
const CHEVRON_SIZE := 3.0 # pixels from a chevron's tip back to its arms
const CHEVRON_SPEED := [12.0, 70.0] # pixels a second they slide: as the wind-up starts, as it ends
const CHEVRON := 0.55 # how solid they are
const PAW_DUST := 3 # dust pixels kicked up behind it while it paws
const TRAIL_DUST := 10 # dust pixels left along the way behind it while it charges
const TRAIL_LENGTH := 28.0 # pixels behind it the trail reaches
const DUST := ["m", "M", "c"] # PALETTE keys of dust thrown up off the ground
const PAW_STEPS := 3 # simulation steps per shuffle while it paws
const DAZED_AT := Vector2(-3.0, -13.0) # the stars' top-left, from the charger's position
const DAZED_STEPS := 8 # simulation steps per turn of the stars
## A boss on its way: Config.BOSS.warn seconds ahead, the edge it comes from glows and an arrow there points out at it.
const COMING_BAND := Vector2(70.0, 4.0) # along the edge, into the field
const COMING_ARROW := 7.0 # pixels from the arrow's tip to its back
const COMING_IN := 12.0 # from the edge to the arrow's tip
const COMING_SMOKE := 14 # smoke pixels curling in over the edge it comes from
const COMING_SMOKE_KEY := "A" # half of them pale, so they show on the black past the light
const COMING_BLINK_STEPS := 8
## An enemy coming in from beyond the field (under the treetops, or not yet on screen): a small arrow on that edge,
## inside the treetops, points out at it until it is on the field.
const EDGE_ARROW := 4.0 # pixels from the tip to the back
const EDGE_ARROW_IN := 11.0 # from the screen edge to the tip
const EDGE_ARROW_COLOUR := "W"
const EDGE_ARROW_ALPHA := 0.75

## The dash upgrade's cooldown: a bar under the keeper that fills while the dash is not ready, gone once it is; the
## dash icon in the HUD is shaded over the share still to wait.
const DASH_BAR := Rect2(-5.0, 8.0, 10.0, 2.0) # from the keeper's position: just under its feet
const DASH_BAR_COLOUR := "l"
const ICON_WAIT := Color(0.0, 0.0, 0.0, 0.6)

## How upgrades show in the world. The rest show only as their icon.
const WARMED := Color(1.0, 0.74, 0.5) # tint of an enemy the warm glow is slowing
const EMBERS := 14 # embers in the ember ring
const EMBER_TURN := 0.4 # radians per second the ring drifts round
const EMBER_PULSE := 0.2 # seconds the embers flare after the ring burns what is inside it

var fuel_text_width := 0.0 # set by main.gd: the words after the fuel bar, 0 when they are hidden
var effects # short-lived pictures that answer what happens in the world
var scenery: Array = [] # [texture, top-left]
var clearing: Texture2D
var hedges := {} # side -> texture: the treetops along each screen edge
var shake := Vector2.ZERO # set by main.gd: how far the field is drawn off its place right now (src/art/juice.gd)
var scrim := 0.0 # set by main.gd's ui: how dark the dim over the field is, 0 to 1
var hidden_pick := "" # set by the ui: an upgrade whose icon is still flying to its tile, drawn empty until it lands
var flash_pick := "" # set by the ui: the tile that just got its upgrade, ringed while flash runs from 1 to 0
var flash := 0.0
var ember := 1.0 # how much of the keeper's ember is left, 1 full to 0 cooled
var ember_flare := 0.0 # seconds left of the flare of an ember that just caught again
var ember_at_torch := true # whether the keeper touched the torch on the last step
var score_panel := Vector2.ZERO # set by the ui: the size of the night and score words, top right
var _kinds := {} # enemy kind -> its pictures, found once (see _kind): a crowd paints hundreds every frame
## What every pass over the enemies needs to know about each, worked out once per world step (_crowd): its kind's
## pictures, which walking frame it shows, whether it is drawn mirrored, whether it stands in the light.
var _crowd_for := []
var _picture: Array = []
var _frame := PackedInt32Array()
var _mirror := PackedInt32Array()
var _lit := PackedByteArray()


func _init(seed_value: int) -> void:
	effects = Effects.new(seed_value)
	# The clearing and the treetops go into the sprites' atlas too, and so do the eyes that show in the dark, so the
	# whole field is drawn from one texture (src/art/sprites.gd).
	var pictures := { "clearing": _clearing_image() }
	for side in HEDGE_SIDES:
		var img: Image = Sprites.image("hedge")
		for turn in HEDGE_SIDES[side]:
			img.rotate_90(CLOCKWISE)
		pictures["hedge_" + side] = img
	Sprites.pack(pictures)
	clearing = Sprites.picture("clearing")
	for side in HEDGE_SIDES:
		hedges[side] = Sprites.picture("hedge_" + side)
	var eyes := []
	for kind in Config.ENEMY_TYPES:
		var look := Looks.enemy(kind)
		if not look.in_dark.is_empty():
			for frame in Looks.FRAMES:
				for flip in [false, true]:
					eyes.append([frame % kind, look.in_dark[0], flip])
	Sprites.prepare_only(eyes)
	lay_ground(seed_value)


## Lays the ground's scenery out from a run's seed, in place of what lay there, with a generator of its own, so it
## never draws from world.rng.
func lay_ground(seed_value: int) -> void:
	scenery = []
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


func icon(upgrade: String, alone := false, who := "knight") -> Texture2D:
	var name := Looks.icon(upgrade, who)
	return Sprites.alone(name) if alone else Sprites.texture(name)


## Call once after each world.step(), so the effects can answer what the step did.
func step(w) -> void:
	effects.step(w)
	var at_torch: bool = w.fuel > 0.0 and w.player.pos.distance_to(T.pos) < T.reach + Config.PLAYER.radius
	if at_torch and not ember_at_torch and ember < EMBER_CATCH:
		ember_flare = EMBER_FLARE
	ember_at_torch = at_torch
	if at_torch:
		ember = minf(1.0, ember + Config.STEP / EMBER_KINDLE)
	elif not w.in_light(w.player.pos) or w.fuel <= 0.0:
		ember = maxf(0.0, ember - Config.STEP / EMBER_COOL)
	ember_flare = maxf(0.0, ember_flare - Config.STEP)


## How far the keeper's ember lights around them right now, in pixels. main.gd sizes the keeper's light with it.
func ember_reach() -> float:
	return lerpf(EMBER_REACH[0], EMBER_REACH[1], ember)


## How bright that light is, and its colour.
func ember_glow(w) -> float:
	if w.player.dead:
		return 0.0
	return lerpf(EMBER_GLOW[0], EMBER_GLOW[1], ember) + EMBER_FLARE_GLOW * ember_flare / EMBER_FLARE


func ember_colour() -> Color:
	return Sprites.PALETTE[EMBER_COLOUR[0]].lerp(Sprites.PALETTE[EMBER_COLOUR[1]], ember)


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


## The picture of a light: a round one, or with tongues round its edge that dip in by lick (a share of the radius).
static func light_image(tongues := 0, lick := 0.0) -> Image:
	var img := Image.create_empty(LIGHT_SIZE, LIGHT_SIZE, false, Image.FORMAT_RGBA8)
	var mid := Vector2(LIGHT_SIZE, LIGHT_SIZE) / 2.0
	for y in LIGHT_SIZE:
		for x in LIGHT_SIZE:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - mid) / mid
			var edge := 1.0 - lick * (0.5 + 0.5 * sin(d.angle() * tongues))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 - pow(minf(d.length() / edge, 1.0), LIGHT_FALL)))
	return img


## How far ring i of the torch's light has turned by now, in radians.
static func light_turn(w, i: int) -> float:
	return w.steps * Config.STEP * LIGHT_RINGS[i][1]


## How bright the flame is on this step, around 1.
static func flicker(w) -> float:
	var out := 1.0
	for f in LIGHT_FLICKER:
		out += sin(w.steps * f[0]) * f[1]
	return out


func paint(c: CanvasItem, w) -> void:
	_crowd(w)
	c.draw_rect(Rect2(Vector2.ZERO, VIEW).grow(Juice.MARGIN), Sprites.PALETTE["u"]) # the hedge goes on past the view, for a shake
	c.draw_rect(Rect2(Vector2.ZERO, VIEW), GROUND)
	c.draw_texture(clearing, (T.pos + CLEARING_DROP - Vector2(CLEARING) / 2.0).round())
	for s in scenery:
		c.draw_texture(s[0], s[1])
	_ember_ring(c, w)
	_shadows(c, w)
	_chop_ground(c, w)
	var standing := _standing(w)
	standing.sort()
	for s in standing:
		if s[2] == null:
			_sword(c, w)
		else:
			c.draw_texture(s[2], s[3], s[4])
	_fliers(c, w)
	for x in range(0, int(VIEW.x), 16):
		c.draw_texture(hedges.top, Vector2(x, 0.0))
		c.draw_texture(hedges.bottom, Vector2(x, VIEW.y - HEDGE_DEPTH))
	for y in range(0, int(VIEW.y), 16):
		c.draw_texture(hedges.left, Vector2(0.0, y))
		c.draw_texture(hedges.right, Vector2(VIEW.x - HEDGE_DEPTH, y))


func paint_overlay(c: CanvasItem, w) -> void:
	_crowd(w)
	c.draw_set_transform(shake) # what glows in the field shakes with it (main.gd moves the field); the HUD does not
	_telegraphs(c, w)
	effects.paint(c)
	_chop_ring(c, w)
	_slash(c, w)
	var night := 1.0 - daylight(w)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var k: Dictionary = _picture[i]
		var look: Dictionary = k.look
		var at: Vector2 = e.pos + _bob(w, i, look) + _lift(e) - look.anchor
		if k.glow != null:
			c.draw_texture(k.glow, at.round())
		var dark: bool = _lit[i] == 0
		if dark and k.dark_glow != null:
			_dark_glow(c, e, k.dark_glow, at)
		if dark and not k.eyes.is_empty(): # its eyes, on the frame and facing it is drawn in
			var eyes: Texture2D = k.eyes[_frame[i]][_mirror[i]]
			c.draw_texture(eyes, (at + _paw(w, e)).round(), Color(k.eye_colour, night))
		if e.move == "rest":
			var stars := Sprites.texture("dazed", (w.steps / DAZED_STEPS) % 2 == 1)
			c.draw_texture(stars, (e.pos + DAZED_AT).round())
	_dash_bar(c, w)
	_ember(c, w)
	_beacons(c, w)
	c.draw_set_transform(Vector2.ZERO)
	if scrim > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, VIEW).grow(Juice.MARGIN), Color(SCRIM, scrim))
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
	var tiles := tiles(w)
	for id in tiles:
		_tile(c, w, id, tiles[id])
	_sparks(c, w)
	_bolts(c, w)
	_coming(c, w)
	_boss_bar(c, w)
	_night_bar(c, w)
	_edge_arrows(c, w) # over the HUD panels, so one under the top corners still shows


## The upgrades held, each once, in the order first taken.
static func held(w) -> Array:
	var out := []
	for id in w.picks:
		if not out.has(id):
			out.append(id)
	return out


## Where each held upgrade's tile is: id -> top-left. One row per side, a side with nothing held takes no row.
static func tiles(w) -> Dictionary:
	var out := {}
	var row := 0
	for side in Looks.SIDES:
		var ids := held(w).filter(func(id): return Looks.side(id) == side)
		for i in ids.size():
			out[ids[i]] = HUD_PICKS + Vector2(i * TILE_STEP.x, row * TILE_STEP.y)
		row += 1 if not ids.is_empty() else 0
	return out


## The middle of an upgrade's icon on its tile, where the ui flies a picked card's icon to.
static func icon_spot(w, id: String) -> Vector2:
	return tiles(w).get(id, HUD_PICKS) + TILE_ICON + Vector2(ICON_SIZE, ICON_SIZE) / 2.0


## The lowest pixel of the HUD's top-left panel, so a box in the middle can keep clear of it.
static func hud_bottom(w) -> float:
	var bottom := fuel_bar(w).end.y
	for at in tiles(w).values():
		bottom = maxf(bottom, at.y + TILE.y)
	return bottom + HUD_PAD


## The right edge of the HUD's top-left panel.
func hud_right(w) -> float:
	var right := fuel_bar(w).end.x + (HUD_FUEL_TEXT + fuel_text_width if fuel_text_width > 0.0 else 0.0)
	right = maxf(right, HUD_HEARTS.x + w.max_hp() * HUD_HEART_STEP - 1.0)
	for at in tiles(w).values():
		right = maxf(right, at.x + TILE.x)
	return right + HUD_PAD


## One held upgrade on its tile: the side's colour, the icon, a pip per level it can reach (the reached ones gold),
## a gold edge at its last level, the dash's wait shaded over it, and a white ring growing off it when just taken.
func _tile(c: CanvasItem, w, id: String, at: Vector2) -> void:
	var level: int = w.level(id)
	var most: int = w.max_level(id)
	var side := Looks.side(id)
	c.draw_rect(Rect2(at, TILE).grow(1.0), Sprites.PALETTE["k"])
	c.draw_rect(Rect2(at, TILE), Sprites.PALETTE[TILE_FULL] if level >= most else TILE_EDGE[side])
	c.draw_rect(Rect2(at + Vector2.ONE, TILE - Vector2(2.0, 2.0)), TILE_BACK[side])
	if id != hidden_pick:
		c.draw_texture(icon(id, false, w.character), at + TILE_ICON)
		if id == "dash" and w.player.dash_wait > 0.0: # shaded over the share of the wait still to go
			var left: float = w.player.dash_wait / w.mod("dash_every", 1.0)
			c.draw_rect(Rect2(at + TILE_ICON, Vector2(ICON_SIZE, ceilf(ICON_SIZE * left))), ICON_WAIT)
	var pips_w := most * TILE_PIP.x + (most - 1)
	var x0 := at.x + floorf((TILE.x - pips_w) / 2.0)
	for d in most:
		c.draw_rect(Rect2(Vector2(x0 + d * (TILE_PIP.x + 1.0), at.y + TILE_PIP_Y), TILE_PIP), Sprites.PALETTE[TILE_FULL if d < level else TILE_EMPTY])
	if id == flash_pick and flash > 0.0:
		var ring := Rect2(at, TILE).grow(1.0 + TILE_FLASH * (1.0 - flash))
		c.draw_rect(ring, Color(1.0, 1.0, 1.0, flash), false, 1.0)
		c.draw_rect(Rect2(at + Vector2.ONE, TILE - Vector2(2.0, 2.0)), Color(1.0, 1.0, 1.0, 0.5 * flash * flash))


## The lit ring round each log and berry on the ground (and each log a thief carries off), and now and then a glint.
func _beacons(c: CanvasItem, w) -> void:
	var day := daylight(w)
	var things := []
	for l in w.logs:
		things.append(["log", l - LOG_ANCHOR, LOG_RIM])
	for e in w.enemies:
		if e.carrying:
			things.append(["log", e.pos + THIEF_CARRY - LOG_ANCHOR, LOG_RIM])
	for b in w.berries:
		things.append(["berry", b - BERRY_ANCHOR + _berry_bob(w, b), BERRY_RIM])
	for t in things:
		var at: Vector2 = t[1].round()
		var phase := _hash(int(at.x), int(at.y))
		var breath: float = 0.5 + 0.5 * sin(w.steps * RIM_BREATH + phase % 64 * 0.1)
		var lit: bool = w.in_light(at)
		var band: Array = RIM_LIT if lit else RIM_DARK
		var alpha: float = lerpf(band[0], band[1], breath) * (1.0 - day * 0.7)
		if not lit: # out in the dark the thing itself glows a little too, so it keeps its colour, not just a ring
			c.draw_texture(Sprites.texture(t[0]), at, Color(1.0, 1.0, 1.0, alpha * SELF_LIT))
		c.draw_texture(Sprites.rim(t[0]), at - Vector2.ONE, Color(Sprites.PALETTE[t[2]], alpha))
		var since: int = (w.steps + phase) % GLINT_EVERY
		if since < GLINT_STEPS:
			var glint := Sprites.texture("glint_b" if since > GLINT_STEPS / 4 and since < GLINT_STEPS * 3 / 4 else "glint_a")
			var size := Sprites.texture(t[0]).get_size()
			c.draw_texture(glint, (at + Vector2(size.x - 2.0, -1.0) - glint.get_size() / 2.0).round())


## A berry's bob: up a pixel every other half beat, each on its own beat.
static func _berry_bob(w, b: Vector2) -> Vector2:
	return Vector2(0.0, -1.0 if ((w.steps + _hash(int(b.x), int(b.y)) % 40) / BERRY_BOB_STEPS) % 2 == 0 else 0.0)


## The dark panels behind the HUD. The words' widths come from main.gd, which writes them.
func _hud_panels(c: CanvasItem, w) -> void:
	var left := HUD_HEARTS.x - HUD_PAD
	c.draw_rect(Rect2(left, 1.0, hud_right(w) - left, hud_bottom(w) - 1.0), HUD_PANEL)
	if w.phase == "night":
		c.draw_rect(CLOCK_PANEL, HUD_PANEL)
	if score_panel.x > 0.0:
		c.draw_rect(Rect2(VIEW.x - score_panel.x - 4.0 - HUD_PAD * 2.0, 1.0, score_panel.x + HUD_PAD * 2.0 + 2.0, score_panel.y), HUD_PANEL)


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


## The keeper's embers right now, as [middle, radius, lit]: the disc each is drawn as, the same as what it hits.
static func bolt_discs(w) -> Array:
	return w.bolts.map(func(b): return [b.pos, b.radius, w.in_light(b.pos)])


## The keeper's embers glow where the night does not dim them: a disc of what they hit, a hot middle that flickers
## inside it, a flickering core and a short tail; effects.gd adds the sparks they shed, their pop and their fizzle.
func _bolts(c: CanvasItem, w) -> void:
	c.draw_set_transform(shake)
	for i in w.bolts.size():
		var b: Dictionary = w.bolts[i]
		var disc: Array = bolt_discs(w)[i]
		var beat: int = w.steps + i * 3
		for t in BOLT_TAIL:
			c.draw_rect(Rect2((b.pos - b.dir * t[0]).round(), Vector2.ONE), Sprites.PALETTE[t[1]])
		var hot: Color = BOLT_DISC_LIT if disc[2] else BOLT_DISC
		c.draw_circle(disc[0], disc[1], Color(hot, BOLT_GLOW))
		c.draw_circle(disc[0], disc[1] * BOLT_INNER[beat % BOLT_INNER.size()], Color(hot.lightened(0.25), 0.9))
		var core := Sprites.texture(BOLT_CORES[beat % BOLT_CORES.size()])
		c.draw_texture(core, (b.pos - core.get_size() / 2.0).round())
	c.draw_set_transform(Vector2.ZERO)


## The lights the embers carry right now, as [middle, radius, energy]: one per ember in flight, one per burst while
## its ring goes out, at most MAX_LIGHTS.
func ember_lights(w) -> Array:
	var out := []
	for i in w.bolts.size():
		var beat: float = 0.5 + 0.5 * sin((w.steps + i * 7) * 0.9)
		out.append([w.bolts[i].pos, BOLT_LIGHT, lerpf(BOLT_LIGHT_ENERGY[0], BOLT_LIGHT_ENERGY[1], beat)])
	for r in effects.rings:
		if r.kind == "burst":
			var k := float(r.age) / Effects.RINGS.burst[0]
			out.append([r.pos, r.radius + BURST_LIGHT, BURST_LIGHT_ENERGY * (1.0 - k)])
	return out.slice(0, MAX_LIGHTS)


## The bosses on the field (not their decoys), in the order they came.
static func bosses(w) -> Array:
	return w.enemies.filter(func(e): return e.T.get("boss", false) and not e.dead and not e.decoy)


## Where the bar of the i-th boss on the field goes: stacked up from BOSS_BAR.
static func boss_bar(i: int) -> Rect2:
	return Rect2(BOSS_BAR.position - Vector2(0.0, BOSS_BAR_STEP * i), BOSS_BAR.size)


func _boss_bar(c: CanvasItem, w) -> void:
	var list := bosses(w)
	for i in list.size():
		var b = list[i]
		var bar := boss_bar(i)
		c.draw_rect(bar.grow(2.0), HUD_PANEL)
		c.draw_rect(bar.grow(1.0), Sprites.PALETTE["k"])
		c.draw_rect(bar, Sprites.PALETTE["K"])
		c.draw_rect(Rect2(bar.position, Vector2(ceilf(bar.size.x * float(b.hp) / b.full_hp), bar.size.y)), Sprites.PALETTE[BOSS_BAR_COLOUR])


func _shadows(c: CanvasItem, w) -> void:
	# Out past CAST_FADE's end of the light (where most of a crowd stands) no long shadow shows: skip the work.
	var light: float = w.light_radius()
	var casts: bool = w.fuel > 0.0 and daylight(w) < 1.0
	for i in w.enemies.size():
		var e = w.enemies[i]
		var k: Dictionary = _picture[i]
		var look: Dictionary = k.look
		c.draw_texture(k.shadow, (e.pos + look.shadow_at).round())
		if casts and not look.flies and e.move != "air" and (e.pos - T.pos).length() / light < CAST_FADE[1]:
			_cast(c, w, k.frames[_frame[i]][_mirror[i]], k.feet[_frame[i]], e.pos, look.anchor)
	if _keeper_shows(w) and not w.player.dead:
		c.draw_texture(Sprites.texture("shadow"), (w.player.pos + SHADOW).round())
		var keeper := _keeper(w)
		_cast(c, w, Sprites.texture(keeper[0], keeper[1]), Sprites.foot(keeper[0]), w.player.pos, BODY)


## The long shadow the torch throws behind one standing thing: its sprite, dark, turned to lie away from the torch
## with its feet where they are drawn. anchor is the pixel of the sprite that sits on pos.
func _cast(c: CanvasItem, w, sprite: Texture2D, foot_row: int, pos: Vector2, anchor: Vector2) -> void:
	var from: Vector2 = pos - T.pos
	var share: float = from.length() / w.light_radius()
	var alpha: float = CAST.a * (1.0 - daylight(w)) * (1.0 - smoothstep(CAST_FADE[0], CAST_FADE[1], share))
	if w.fuel <= 0.0 or alpha <= 0.0 or from.length() < CAST_NEAR:
		return
	var away := from.normalized()
	var length: float = lerpf(CAST_LENGTH[0], CAST_LENGTH[1], clampf(share, 0.0, 1.0))
	var foot := float(foot_row)
	var feet := pos + Vector2(0.0, foot - 1.0 - anchor.y)
	c.draw_set_transform_matrix(Transform2D(away.rotated(PI / 2.0), -away * length, feet.round()))
	c.draw_texture(sprite, Vector2(-anchor.x, -foot), Color(CAST, alpha))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


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
func _tint(e, lit: bool, warms: bool) -> Color:
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
		_put(out, b.y + 2.0, "berry", b + _berry_bob(w, b), BERRY_ANCHOR)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var k: Dictionary = _picture[i]
		var look: Dictionary = k.look
		if look.flies:
			continue
		var white: bool = e.flash > 0.0 or (e.move in ["warn", "split"] and (w.steps / MARK_BLINK_STEPS) % 2 == 0)
		var tex: Texture2D = k.frames[_frame[i]][_mirror[i] + (2 if white else 0)]
		out.append([e.pos.y + 4.0, out.size(), tex, (e.pos + _lift(e) + _paw(w, e) - look.anchor).round(), _tint(e, _lit[i] == 1, warms)])
		if e.carrying:
			_put(out, e.pos.y + 4.1, "log", e.pos + THIEF_CARRY, LOG_ANCHOR)
	var me: Dictionary = Looks.character(w.character)
	if p.dead:
		_put(out, p.pos.y + 5.0, me.sprite + "_dead", p.pos, BODY)
	elif _keeper_shows(w):
		var look := _keeper(w)
		for g in DASH_GHOSTS if p.dash_t > 0.0 else 0:
			var ghost := DASH_GHOST
			ghost.a *= 1.0 - float(g) / DASH_GHOSTS
			_put(out, p.pos.y + 4.8, look[0], p.pos - p.dash_dir * DASH_GHOST_GAP * (g + 1), BODY, look[1], true, ghost)
		_put(out, p.pos.y + 5.0, look[0], p.pos + _lean(w), BODY, look[1], p.hurt_t > 0.0)
		if w.mod("thorns", 0) > 0 and me.cloak: # the thorn cloak: behind the keeper, except seen from behind
			_put(out, p.pos.y + (5.05 if look[2] == "up" else 4.95), "thorns_%s" % look[2], p.pos + _lean(w), BODY, look[1], p.hurt_t > 0.0)
		if p.carrying: # held overhead, a stack one on another
			for i in p.held:
				_put(out, p.pos.y + 5.1 + i * 0.001, "log", p.pos + CARRY + STACK_STEP * i, LOG_ANCHOR)
		elif me.weapon != "":
			var behind: bool = sin(_blade(w)[1]) < BEHIND
			out.append([p.pos.y + (4.9 if behind else 5.2), out.size(), null]) # the sword: paint() draws it at this depth
	return out


## Whether an enemy is drawn mirrored: one that turns, heading left (or lined up that way to charge).
static func _turned(e, look: Dictionary) -> bool:
	var heading: Vector2 = e.aim if e.move in ["warn", "charge", "rest"] else e.vel
	return look.turns and heading.x < 0.0


## How far a leaping boss is lifted off the ground (and off its shadow) right now.
static func _lift(e) -> Vector2:
	if e.move != "air":
		return Vector2.ZERO
	var air: float = e.hop().air
	var k: float = clampf(1.0 - e.move_t / air, 0.0, 1.0)
	return Vector2(0.0, -roundf(sin(k * PI) * LEAP_HEIGHT * air / e.T.leap.air)) # a hop is lower than a leap


## Where a boss is about to strike: the slime king's marked landing, the shade lord's line to the torch.
func _telegraphs(c: CanvasItem, w) -> void:
	var colour: Color = Sprites.PALETTE[MARK]
	var blink: bool = (w.steps / MARK_BLINK_STEPS) % 2 == 0
	for e in w.enemies:
		if e.T.has("leap") and e.move in ["warn", "air"]:
			_landing_mark(c, w, e)
		elif e.T.has("lunge") and e.move == "warn":
			_dashes(c, e.pos, e.move_to, Color(colour, 0.9 if blink else 0.5))
		elif e.move == "split": # wisps of smoke spread out from it toward where its decoys will stand
			var k: float = clampf(1.0 - e.split_t / e.T.split.warn, 0.0, 1.0)
			var smoke: Color = Sprites.PALETTE[SPLIT_SMOKE]
			for i in e.T.split.count:
				var at: Vector2 = Config.TORCH.pos + (e.pos - Config.TORCH.pos).rotated(TAU * (i + 1) / (e.T.split.count + 1) * k)
				_wisp(c, w, at, e.T.radius * (0.6 + 0.6 * k), Color(smoke, 0.5 + 0.4 * k), i)
			_dashed_ring(c, e.pos.round(), e.T.radius + 4.0 + 4.0 * k, w.steps * Config.STEP * MARK_TURN, Color(MARK_RING, 0.9 if blink else 0.55))
		elif e.T.has("charge") and e.move in ["warn", "charge"]:
			_charge_mark(c, w, e, blink)
		elif e.T.has("charge") and e.move == "rest":
			var since: int = roundi((e.T.charge.rest - e.move_t) / Config.STEP) # a skid puff where it stopped
			if since < Effects.POOF.size() * Effects.POOF_STEPS:
				c.draw_texture(Sprites.texture(Effects.POOF[since / Effects.POOF_STEPS]), (e.pos + e.aim * 4.0 - Effects.POOF_ANCHOR).round(), Color(1.0, 0.92, 0.8, 0.8))


## The radius the slime king's marked landing is drawn at: the shock of the leap (or hop) under way, where it hurts.
static func mark_radius(e) -> float:
	return e.hop().shock


## The marked landing: the king's shadow growing to the shock as it falls, cracks running out through it, a dashed
## ring turning at the shock (mark_radius) and dust trickling down inside it.
func _landing_mark(c: CanvasItem, w, e) -> void:
	var L: Dictionary = e.hop()
	var left: float = e.move_t + (L.air if e.move == "warn" else 0.0)
	var k: float = clampf(1.0 - left / (L.warn + L.air), 0.0, 1.0) # 0 when marked, 1 as it lands
	var at: Vector2 = e.move_to.round()
	var r := mark_radius(e)
	c.draw_circle(at, r * lerpf(MARK_SHADOW_FROM, 1.0, k), Color(MARK_SHADOW, MARK_SHADOW_MOST * (0.4 + 0.6 * k)))
	var seed_ := _hash(int(at.x), int(at.y))
	for i in MARK_CRACKS:
		var a := TAU * (i + (seed_ % 7) / 7.0) / MARK_CRACKS
		var from := at
		for j in MARK_CRACK_KINKS:
			var bend := ((_hash(seed_ + i, j) % 9) - 4) * 0.08
			var to := at + Vector2.from_angle(a + bend) * r * k * 0.9 * (j + 1) / MARK_CRACK_KINKS
			c.draw_line(from.round(), to.round(), Color(MARK_CRACK, 0.85), 1.0)
			from = to
	var blink: bool = (w.steps / MARK_BLINK_STEPS) % 2 == 0
	_dashed_ring(c, at, r, w.steps * Config.STEP * MARK_TURN, Color(MARK_RING, 0.95 if blink else 0.65))
	for i in MARK_DUST: # dust shaken loose, falling a few pixels and starting again
		var h := _hash(seed_ + 31 * i, w.steps / 12)
		var spot := at + Vector2.from_angle(TAU * (h % 64) / 64.0) * r * (0.3 + 0.6 * (h % 10) / 10.0)
		var fall := float((w.steps + i * 5) % 12) / 2.0
		c.draw_rect(Rect2((spot + Vector2(0.0, fall - 6.0)).round(), Vector2.ONE), Color(Sprites.PALETTE[DUST[i % DUST.size()]], 0.8))


## A ring of dashes at radius r round at, turned by turn radians.
static func _dashed_ring(c: CanvasItem, at: Vector2, r: float, turn: float, colour: Color) -> void:
	var step := TAU / MARK_DASHES
	for i in MARK_DASHES:
		var a0 := turn + i * step
		c.draw_arc(at, r, a0, a0 + step * 0.55, 4, colour, 1.0)


## A little turning ring of smoke pixels at at, radius r.
static func _wisp(c: CanvasItem, w, at: Vector2, r: float, colour: Color, i: int) -> void:
	var turn: float = w.steps * Config.STEP * (2.0 + i)
	for j in SPLIT_WISP:
		var p := at + Vector2.from_angle(turn + TAU * j / SPLIT_WISP) * r * (0.8 + 0.2 * (j % 2))
		var size := 2.0 if j % 3 == 0 else 1.0
		c.draw_rect(Rect2(p.round(), Vector2(size, size)), colour)


## A charger's band: soft and see-through with its edge (where safe begins) the clearest part, filling toward its end
## as the wind-up runs out; chevrons sliding along it toward the end; dust at its feet while it paws, and behind it
## while it charges.
func _charge_mark(c: CanvasItem, w, e, blink: bool) -> void:
	var band := charge_band(e)
	var k: float = 1.0 if e.move == "charge" else clampf(1.0 - e.move_t / e.T.charge.warn, 0.0, 1.0) # 0 when lined up, 1 as it goes
	c.draw_colored_polygon(band, Color(LANE, LANE_FAINT))
	if k > 0.0:
		c.draw_colored_polygon(charge_band(e, k), Color(LANE, LANE_FULL - LANE_FAINT))
	band.append(band[0])
	c.draw_polyline(band, Color(LANE, LANE_EDGE if blink else LANE_EDGE * 0.7), 1.0)
	var side: Vector2 = e.aim.orthogonal()
	for tip in chevrons(e):
		var back: Vector2 = tip - e.aim * CHEVRON_SIZE
		c.draw_line(tip.round(), (back + side * CHEVRON_SIZE).round(), Color(LANE, CHEVRON), 1.0)
		c.draw_line(tip.round(), (back - side * CHEVRON_SIZE).round(), Color(LANE, CHEVRON), 1.0)
	var seed_ := _hash(int(e.move_to.x), int(e.move_to.y))
	if e.move == "warn":
		for i in PAW_DUST:
			var h := _hash(seed_ + i, w.steps / PAW_STEPS)
			var rise := float((w.steps + i * 2) % (PAW_STEPS * 3))
			var spot: Vector2 = e.pos - e.aim * (e.T.radius + 1.0 + h % 4) + side * ((h % 9) - 4.0) + Vector2(0.0, 3.0 - rise)
			c.draw_rect(Rect2(spot.round(), Vector2.ONE), Color(Sprites.PALETTE[DUST[h % DUST.size()]], 0.85))
	else:
		for i in TRAIL_DUST:
			var h := _hash(seed_ + i, w.steps / 2)
			var back := TRAIL_LENGTH * (i + 0.5) / TRAIL_DUST
			var spot: Vector2 = e.pos - e.aim * back + side * ((h % 7) - 3.0) + Vector2(0.0, 3.0 - (h % 3))
			c.draw_rect(Rect2(spot.round(), Vector2.ONE * (2.0 if i < 3 else 1.0)), Color(Sprites.PALETTE[DUST[h % DUST.size()]], 0.8 * (1.0 - back / TRAIL_LENGTH)))


## Where the chevrons on a charger's band are right now, by their tips: CHEVRON_GAP apart along its line from the
## charger to where its band ends, sliding toward the end at CHEVRON_SPEED (from the first to the second as the
## wind-up runs out; none under the charge itself), each well inside the band (its arms reach CHEVRON_SIZE to the sides).
static func chevrons(e) -> PackedVector2Array:
	var out := PackedVector2Array()
	var length: float = e.pos.distance_to(e.charge_end())
	if e.move != "warn": # under the charge itself the dust trail says enough
		return out
	var s: Array = CHEVRON_SPEED
	var warn: float = e.T.charge.warn
	var t: float = warn - e.move_t
	var gone: float = s[0] * t + 0.5 * (s[1] - s[0]) * t * t / warn # how far they have slid since the band was laid
	var first := fmod(gone, CHEVRON_GAP) + CHEVRON_SIZE
	var d := first
	while d <= length:
		out.append(e.pos + e.aim * d)
		d += CHEVRON_GAP
	return out

## Where a charger's charge hurts, as a polygon: a band from it to Enemy.charge_end(), Enemy.lane_half() each side
## of its line, round at both ends (every point within lane_half of the line it runs). share: only the first part of
## it, from the charger, for the fill that grows as the wind-up runs out.
static func charge_band(e, share := 1.0) -> PackedVector2Array:
	var r: float = e.lane_half()
	var a: Vector2 = e.pos
	var b: Vector2 = a.lerp(e.charge_end(), share)
	var along: Vector2 = e.aim
	var out := PackedVector2Array()
	for i in LANE_ROUND + 1: # round the far end, from one side to the other
		out.append(b + along.rotated(-PI / 2.0 + PI * i / LANE_ROUND) * r)
	for i in LANE_ROUND + 1: # and back round the charger
		out.append(a + along.rotated(PI / 2.0 + PI * i / LANE_ROUND) * r)
	return out


## A dashed line from a to b.
static func _dashes(c: CanvasItem, a: Vector2, b: Vector2, colour: Color) -> void:
	var to: Vector2 = b - a
	for d in int(to.length() / (RUSH_DASH * 2.0)):
		var from: Vector2 = a + to.normalized() * RUSH_DASH * 2.0 * d
		c.draw_line(from.round(), (from + to.normalized() * RUSH_DASH).round(), colour, 1.0)


## A charger pawing the ground before it charges shuffles a pixel back and forth along its line.
static func _paw(w, e) -> Vector2:
	if e.move != "warn" or not e.T.has("charge"):
		return Vector2.ZERO
	return (e.aim * (1.0 if (w.steps / PAW_STEPS) % 2 == 0 else -1.0)).round()


## Enemies beyond the field, coming in: a small arrow on their edge, pointing out at each, so you see where they come
## from before they step out of the trees. One leaving the field (a thief with a log) gets none.
func _edge_arrows(c: CanvasItem, w) -> void:
	if w.phase != "night":
		return
	var f: Rect2 = Config.FIELD
	var lo := Vector2(EDGE_ARROW_IN, EDGE_ARROW_IN)
	for e in w.enemies:
		if f.has_point(e.pos) or e.carrying or e.move == "air":
			continue
		var out := Vector2(1.0 if e.pos.x > f.end.x else (-1.0 if e.pos.x < f.position.x else 0.0),
			1.0 if e.pos.y > f.end.y else (-1.0 if e.pos.y < f.position.y else 0.0)).normalized()
		var tip: Vector2 = e.pos.clamp(lo, VIEW - lo)
		var back: Vector2 = tip - out * EDGE_ARROW
		var side: Vector2 = out.orthogonal() * EDGE_ARROW * 0.75
		var arrow := PackedVector2Array([tip.round(), (back + side).round(), (back - side).round()])
		c.draw_colored_polygon(arrow, Color(Sprites.PALETTE[EDGE_ARROW_COLOUR], EDGE_ARROW_ALPHA))
		c.draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(Sprites.PALETTE["k"], EDGE_ARROW_ALPHA), 1.0)


## The ember floating at the keeper's side, away from the sword hand: big and gold while it is hot, small and
## dimmer as it cools.
func _ember(c: CanvasItem, w) -> void:
	var p = w.player
	if p.dead or not _keeper_shows(w):
		return
	var side: float = -1.0 if p.face.rotated(PI / 2.0).x > 0.0 else 1.0
	var bob := Vector2(0.0, -1.0 if (w.steps / EMBER_BOB_STEPS) % 2 == 0 else 0.0)
	var tex := Sprites.texture("ember_hot" if ember > EMBER_HOT or ember_flare > 0.0 else "ember")
	var at: Vector2 = p.pos + Vector2(EMBER_AT.x * side, EMBER_AT.y) + bob - tex.get_size() / 2.0
	c.draw_texture(tex, at.round(), Color(1.0, 1.0, 1.0, lerpf(EMBER_DIM, 1.0, ember)))


## The dash's cooldown under the keeper, while it is not ready.
func _dash_bar(c: CanvasItem, w) -> void:
	var p = w.player
	var every: float = w.mod("dash_every", 0.0)
	if every <= 0.0 or p.dash_wait <= 0.0 or p.dead or w.phase != "night":
		return
	var bar := Rect2((p.pos + DASH_BAR.position).round(), DASH_BAR.size)
	c.draw_rect(bar.grow(1.0), Sprites.PALETTE["k"])
	c.draw_rect(Rect2(bar.position, Vector2(ceilf(bar.size.x * (1.0 - p.dash_wait / every)), bar.size.y)), Sprites.PALETTE[DASH_BAR_COLOUR])


## A boss on its way: the edge it will come from glows and an arrow points at it, blinking. Each on its way has its own.
func _coming(c: CanvasItem, w) -> void:
	if w.phase != "night":
		return
	for b in w.bosses_coming():
		_coming_at(c, w, b.from)


func _coming_at(c: CanvasItem, w, f: Vector2) -> void:
	var out := Vector2.ZERO # which edge: the one it is past
	if f.x < Config.FIELD.position.x: out = Vector2.LEFT
	elif f.x > Config.FIELD.end.x: out = Vector2.RIGHT
	elif f.y < Config.FIELD.position.y: out = Vector2.UP
	else: out = Vector2.DOWN
	var spot: Vector2 = f.clamp(Vector2.ZERO, VIEW)
	var on: bool = (w.steps / COMING_BLINK_STEPS) % 2 == 0
	var colour: Color = Sprites.PALETTE[MARK]
	var band_size := COMING_BAND if out.y != 0.0 else Vector2(COMING_BAND.y, COMING_BAND.x)
	var band_at := spot - band_size / 2.0 - out * band_size / 2.0
	var band := Rect2(band_at, band_size).intersection(Rect2(Vector2.ZERO, VIEW))
	c.draw_rect(band, Color(colour, 0.85 if on else 0.4))
	var along := out.orthogonal()
	for i in COMING_SMOKE: # smoke curling in over the edge where it will break through
		var h := _hash(int(f.x) + i * 13, w.steps / 6)
		var drift := float((w.steps + i * 7) % 30) / 30.0
		var p: Vector2 = spot - out * (2.0 + drift * 14.0) + along * (((h % 41) - 20.0) * COMING_BAND.x / 45.0)
		c.draw_rect(Rect2(p.round(), Vector2.ONE * (2.0 if h % 3 == 0 else 1.0)), Color(Sprites.PALETTE[COMING_SMOKE_KEY if h % 2 == 0 else SPLIT_SMOKE], 0.8 * (1.0 - drift)))
	var tip: Vector2 = (spot - out * COMING_IN).clamp(Vector2(COMING_IN, COMING_IN), VIEW - Vector2(COMING_IN, COMING_IN))
	var back: Vector2 = tip - out * COMING_ARROW
	var side: Vector2 = out.orthogonal() * COMING_ARROW * 0.7
	var arrow := PackedVector2Array([tip.round(), (back + side).round(), (back - side).round()])
	c.draw_colored_polygon(arrow, Color(colour, 1.0 if on else 0.6))
	c.draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Sprites.PALETTE["k"], 1.0)


## What flies is painted above everything that stands, bobbing.
func _fliers(c: CanvasItem, w) -> void:
	var warms := _warms(w)
	for i in w.enemies.size():
		var e = w.enemies[i]
		var k: Dictionary = _picture[i]
		var look: Dictionary = k.look
		if look.flies:
			var tex: Texture2D = k.frames[_frame[i]][2 if e.flash > 0.0 else 0]
			c.draw_texture(tex, (e.pos + _bob(w, i, look) - look.anchor).round(), _tint(e, _lit[i] == 1, warms))


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
	var sprite: String = Looks.character(w.character).sprite
	if _swinging(w):
		var pose := "raise" if _chopping(w) and _swing_share(w) < _blow(w) else "atk"
		return ["%s_%s_%s" % [sprite, dir, pose], dir == "side" and p.face.x < 0.0, dir]
	var walking: bool = p.vel.length() > 1.0 and p.hurt_t <= 0.0
	var beat: int = (w.steps / WALK_STEPS) % 4 if walking else 0 # stand, step, stand, other step
	var frame := "b" if beat % 2 == 1 else "a"
	var flip: bool = p.face.x < 0.0 if dir == "side" else beat == 3
	return ["%s_%s%s_%s" % [sprite, dir, "_lift" if p.carrying else "", frame], flip, dir]


func _swinging(w) -> bool:
	return w.player.attack_t >= 0.0 and not w.player.dead


## How far into the swing it is, 0 to 1, or -1 when the keeper is not swinging.
func _swing_share(w) -> float:
	return clampf(w.player.attack_t / w.stat("attack_time"), 0.0, 1.0) if _swinging(w) else -1.0


## The share of the swing at which the blow stops landing: the trail is gone by then.
static func _hold(w) -> float:
	return w.stat("attack_hit_until") / w.stat("attack_time")


## The share of the swing at which the blow starts landing.
static func _blow(w) -> float:
	return w.stat("attack_hit_at") / w.stat("attack_time")


## Whether the keeper's attack under way (or the next) is a chop, drawn as one: an axe that comes down in front
## (attack "chop"); a spin still sweeps round.
static func _chopping(w) -> bool:
	return w.stats.attack == "chop" and not w.player.spin and _weapon(w) != ""


## The weapon the keeper swings ("sword", "axe"), and the pixel of its sprite held in the fist.
static func _weapon(w) -> String:
	return Looks.character(w.character).weapon


static func _grip(w) -> Vector2:
	return Looks.WEAPONS[_weapon(w)].grip


## Where along a stage of the swing k is, 0 to 1.
func _stage(k: float, from: float, to: float) -> float:
	return clampf((k - from) / (to - from), 0.0, 1.0)


## How far the keeper leans into the blow: a pixel toward the facing while the swing strikes and holds.
func _lean(w) -> Vector2:
	var k := _swing_share(w)
	if _chopping(w) and k >= 0.0 and k < _blow(w): # rocking back under the raised axe
		return (-w.player.face * LUNGE).round() if k >= _blow(w) * CHOP_RAISE * 0.5 else Vector2.ZERO
	if _chopping(w) and k >= 0.0 and k < _hold(w):
		return (w.player.face * LUNGE).round()
	if k < SWING_WIND or k >= _hold(w) or _weapon(w) == "":
		return Vector2.ZERO
	return (w.player.face * LUNGE).round()


## The angles of the swing: [start of the arc, end of the arc, wound up]. The sweep turns counter-clockwise on the
## screen and starts on the hand side, the side the facing turned a quarter clockwise points to.
func _arc(w) -> Array:
	var half: float = w.swing_half() # a spin goes all the way round
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
	if _chopping(w):
		return _chop_blade(w)
	var shoulder: Vector2 = p.pos + _lean(w) + SHOULDER
	var a: float
	var out := 1.0 # how far the hand is from rest toward the arm's length out
	if k < SWING_WIND:
		var rest := _rest(w, arc[2])
		out = ease(_stage(k, 0.0, SWING_WIND), 0.4)
		a = lerpf(rest[1], arc[2], out)
	elif k < SWING_STRIKE:
		a = lerpf(arc[2], arc[1] - OVERSHOOT, smoothstep(0.0, 1.0, _stage(k, SWING_WIND, SWING_STRIKE)))
	elif k < _hold(w):
		a = lerpf(arc[1] - OVERSHOOT, arc[1], ease(_stage(k, SWING_STRIKE, _hold(w)), 0.5))
	else:
		var rest := _rest(w, arc[1])
		out = 1.0 - smoothstep(0.0, 1.0, _stage(k, _hold(w), 1.0))
		a = lerpf(rest[1], arc[1], out)
	var rest_hand: Vector2 = _rest(w, a)[0]
	return [rest_hand.lerp(shoulder + Vector2.from_angle(a) * ARM, out), a, out]


## Where the axe is in a chop: [hand position, angle, how far the hand is out from rest, 0 to 1, x scale of the
## sprite]. phi is the axe's angle up from lying flat ahead; its screen direction is ahead (from the hand down flat to
## world.chop_centre(), about the facing) times cos(phi) and up times CHOP_HEIGHT sin(phi), so its sprite is drawn
## that much shorter (at most its full length). Down flat, its head lies on the centre.
func _chop_blade(w) -> Array:
	var p = w.player
	var k := _swing_share(w)
	var blow := _blow(w)
	var phi := 0.0
	var out := 1.0
	if k < blow * CHOP_RAISE:
		out = ease(_stage(k, 0.0, blow * CHOP_RAISE), 0.4)
		phi = CHOP_UP
	elif k < blow:
		phi = lerpf(CHOP_UP, 0.0, ease(_stage(k, blow * CHOP_RAISE, blow), 2.2)) # falling faster and faster
	elif k >= _hold(w):
		out = 1.0 - smoothstep(0.0, 1.0, _stage(k, _hold(w), 1.0))
	var shoulder: Vector2 = p.pos + _lean(w) + SHOULDER
	var sword := _sword_texture(w)
	var to: Vector2 = w.chop_centre(p.pos, p.face) - (shoulder + p.face * ARM) # from the hand, down flat, to the centre
	var ahead: Vector2 = to.normalized()
	var seen: Vector2 = ahead * cos(phi) + Vector2.UP * CHOP_HEIGHT * sin(phi)
	var length := minf(1.0, seen.length())
	var a: float = seen.angle()
	var hand: Vector2 = shoulder + seen.normalized() * ARM * length
	var since: int = floori((p.attack_t - w.stat("attack_hit_at")) / Config.STEP + 0.0001)
	if since >= 0 and since < CHOP_QUIVER and k < _hold(w): # bitten into the ground: it quivers
		hand += (p.face.orthogonal() * (1.0 if since % 2 == 0 else -1.0)).round()
	var chop: float = maxf(0.1, to.length() / (sword.get_width() - AXE_HEAD - _grip(w).x)) * length
	var rest := _rest(w, a)
	var rest_scale := _stretch(w, sword, 0.0)
	return [rest[0].lerp(hand, out), lerpf(rest[1], a, out), out, lerpf(rest_scale, chop, out)]


## The x scale the weapon sprite is drawn at for blade (_blade()): a chop's own, or the stretch toward the reach.
func _scale(w, sword: Texture2D, blade: Array) -> float:
	return blade[3] if blade.size() > 3 else _stretch(w, sword, blade[2])


## Where the chop comes down, while its blow lands (from attack_hit_at to attack_hit_until): { centre, radius (the
## dust ring's outer edge), cracks (polylines from the middle), fade (0 as it lands, toward 1 as the blow ends) }, or
## empty. The centre and radius are the simulation's (world.chop_centre(), world.chop_radius()), and every crack lies
## inside the round, so what the dent covers is struck (tools/rules_test.gd).
func chop_marks(w) -> Dictionary:
	var p = w.player
	var k := _swing_share(w)
	if p.dead or p.carrying or not _chopping(w) or k < 0.0 or p.attack_t < w.stat("attack_hit_at") or p.attack_t > w.stat("attack_hit_until"):
		return {} # exactly while World.melee() strikes
	var centre: Vector2 = w.chop_centre(p.pos, p.face)
	var r: float = w.chop_radius()
	var fade := _stage(k, _blow(w), _hold(w))
	var spread := minf(1.0, 0.55 + fade * 2.0) # the cracks run out quickly
	var cracks := []
	for i in CHOP_CRACKS:
		var a: float = p.face.angle() + TAU * (i + 0.5 * (_hash(p.swings, i) % 256) / 255.0) / CHOP_CRACKS
		var line := PackedVector2Array([centre])
		for j in range(1, CRACK_JOINTS + 1):
			var bend: float = CRACK_BEND * ((_hash(p.swings * 7 + j, i) % 3) - 1)
			line.append(centre + Vector2.from_angle(a + bend) * r * CRACK_REACH * spread * j / CRACK_JOINTS)
		cracks.append(line)
	return { "centre": centre, "radius": r, "cracks": cracks, "fade": fade }


## The dent and its cracks, on the ground under everything that stands (the night darkens them as the ground).
func _chop_ground(c: CanvasItem, w) -> void:
	var m := chop_marks(w)
	if m.is_empty():
		return
	var burning := _burning(w)
	var left: float = 1.0 - m.fade * m.fade
	c.draw_circle(m.centre, m.radius - 1.0, Color(Sprites.PALETTE[CHOP_DENT[0]], CHOP_DENT[1] * left))
	for line in m.cracks:
		c.draw_polyline(line, Color(Sprites.PALETTE[CHOP_CRACK[1 if burning else 0]], left), 1.0)


## The ring of thrown dust at the round's edge, in the overlay so it reads out of the light too.
func _chop_ring(c: CanvasItem, w) -> void:
	var m := chop_marks(w)
	if m.is_empty():
		return
	var colour: Color = Sprites.PALETTE[CHOP_RING[1 if _burning(w) else 0]]
	var width := CHOP_RING_WIDE if m.fade < 0.5 else 1.0 # thick as it lands, thinning as the dust settles
	c.draw_arc(m.centre, m.radius - width / 2.0, 0.0, TAU, 32, Color(colour, 0.9 * (1.0 - m.fade * m.fade)), width)


## True while the fire blade does its extra damage: it is held and the keeper stands in the light.
func _burning(w) -> bool:
	return w.mod("lit_damage", 0) > 0 and w.in_light(w.player.pos)


func _sword_texture(w) -> Texture2D:
	return Sprites.texture(SWORD % [_weapon(w), "_long" if w.mod("reach_bonus", 0.0) > 0.0 else "", "_fire" if _burning(w) else ""])


## How much the weapon sprite is stretched along its length, so that at full length its tip reaches as far past the
## base weapon's as world.reach() goes past the keeper's base reach, and it looks shorter at rest.
func _stretch(w, sword: Texture2D, out: float) -> float:
	var grip := _grip(w)
	var base := Sprites.texture(_weapon(w)).get_width() - grip.x
	var stretch: float = (w.reach() - w.stat("reach") + base) / (sword.get_width() - grip.x)
	return stretch * lerpf(REST_LENGTH, 1.0, out)


func _sword(c: CanvasItem, w) -> void:
	var blade := _blade(w)
	var sword := _sword_texture(w)
	c.draw_set_transform(blade[0].round(), blade[1], Vector2(_scale(w, sword, blade), 1.0))
	c.draw_texture(sword, -_grip(w))
	c.draw_set_transform(Vector2.ZERO)


## The trail follows the blade through the strike at the reach the simulation hits (world.reach()), then shrinks
## into the blade and fades while the swing holds. It is drawn round the keeper's position, the point the simulation
## measures from, and only over the arc it hits: the blade winds up before the arc and flies past its end, but its
## trail stays inside (world.in_swing() strikes every body it covers). A burning blade sheds flames that rise off it.
## The trail's lines right now, outermost first: [radius, from angle, to angle, PALETTE key, width]. None outside
## the strike, while carrying, or once the keeper is down. tools/rules_test.gd holds every one inside world.in_swing().
func slash_lines(w) -> Array:
	var p = w.player
	var k := _swing_share(w)
	if p.dead or p.carrying or _weapon(w) == "" or _chopping(w) or k < SWING_WIND or k >= _hold(w):
		return []
	var arc := _arc(w)
	var a: float = clampf(_blade(w)[1], arc[1], arc[0])
	var hold := _stage(k, SWING_STRIKE, _hold(w))
	var lines: Array = (SLASH_FIRE if _burning(w) else SLASH).duplicate()
	if w.mod("reach_bonus", 0.0) > 0.0:
		lines.push_front(SLASH_GLEAM)
	var width: float = WIDE_LINE if w.mod("arc_bonus", 0.0) < 0.0 or Looks.character(w.character).heavy else 1.0
	var out := []
	for i in lines.size():
		var tail: float = clampf(lerpf(a, arc[2], lines[i][0] * (1.0 - hold)), arc[1], arc[0])
		if absf(tail - a) > 0.05:
			out.append([w.reach() - (i + 0.5) * width + 0.5, tail, a, lines[i][1], width])
	return out


## The smear right now, widest band first: [polygon in field pixels, colour], the last the head's glint while the
## blade strikes. None where slash_lines() has none.
func smear(w) -> Array:
	var p = w.player
	var k := _swing_share(w)
	if p.dead or p.carrying or _weapon(w) == "" or _chopping(w) or k < SWING_WIND or k >= _hold(w):
		return []
	var look: Dictionary = SMEAR[_weapon(w)]
	var arc := _arc(w)
	var a: float = clampf(_blade(w)[1], arc[1], arc[0])
	var hold := _stage(k, SWING_STRIKE, _hold(w))
	var grow: float = SMEAR_WIDE if w.mod("arc_bonus", 0.0) < 0.0 else 1.0
	var centre: Vector2 = p.pos.round()
	var r: float = w.reach()
	var burning := _burning(w)
	var out := []
	for i in look.bands.size():
		var band: Array = look.bands[i]
		var tail: float = clampf(lerpf(a, arc[2], band[1] * (1.0 - hold)), arc[1], arc[0])
		if absf(tail - a) < 0.08:
			continue
		var width: float = minf(band[0] * grow * (1.0 - 0.6 * hold), r - 2.0)
		var steps: int = look.steps
		var poly := PackedVector2Array()
		for j in steps + 1:
			poly.append(centre + Vector2.from_angle(lerpf(tail, a, float(j) / steps)) * r)
		for j in range(steps, -1, -1):
			var t := float(j) / steps
			poly.append(centre + Vector2.from_angle(lerpf(tail, a, t)) * (r - width * lerpf(SMEAR_TAIL, 1.0, t)))
		var key: String = SMEAR_FIRE[mini(i, SMEAR_FIRE.size() - 1)] if burning else band[2]
		out.append([poly, Color(Sprites.PALETTE[key], band[3] * (1.0 - hold * hold))])
	if not out.is_empty() and hold <= 0.0:
		var h := SMEAR_HEAD / 2.0
		var mid := r - h - 0.5
		var inset := h * 1.5 / mid # the square's corners stay inside the arc's ends too
		var at: Vector2 = centre + Vector2.from_angle(clampf(a, arc[1] + inset, maxf(arc[1] + inset, arc[0] - inset))) * mid
		out.append([PackedVector2Array([at + Vector2(-h, -h), at + Vector2(h, -h), at + Vector2(h, h), at + Vector2(-h, h)]), Sprites.PALETTE["W"]])
	return out


func _slash(c: CanvasItem, w) -> void:
	var p = w.player
	if p.dead or p.carrying or _weapon(w) == "":
		return
	var burning := _burning(w)
	var blade := _blade(w)
	if burning: # a flame licks the tip whenever the blade burns, swinging or not
		var sword := _sword_texture(w)
		var tip: Vector2 = blade[0] + Vector2.from_angle(blade[1]) * (sword.get_width() - _grip(w).x - 1.0) * _scale(w, sword, blade)
		var lick := Sprites.texture("flame_s_%s" % ("a" if (w.steps / FLAME_STEPS_FAST) % 2 == 0 else "b"))
		c.draw_texture(lick, (tip - Vector2(3.0, 5.0)).round())
	var hold := _stage(_swing_share(w), SWING_STRIKE, _hold(w))
	var fade := Color(1.0, 1.0, 1.0, 1.0 - hold * hold)
	var at: Vector2 = p.pos.round()
	for band in smear(w):
		c.draw_colored_polygon(band[0], band[1])
	var lines := slash_lines(w)
	for line in lines.slice(0, 1): # the outermost: a crisp edge at the reach over the smear, which shows the rest
		c.draw_arc(at, line[0], line[1], line[2], SMEAR[_weapon(w)].steps, Sprites.PALETTE[line[3]] * fade, line[4])
	if lines.is_empty():
		return
	var arc := _arc(w)
	var a: float = clampf(blade[1], arc[1], arc[0])
	var r: float = w.reach()
	if burning:
		for j in SWORD_FLAMES:
			var share := (j + 1.0) / (SWORD_FLAMES + 1.0)
			var spot: float = clampf(lerpf(a, arc[2], share * (1.0 - hold * 0.5)), arc[1], arc[0])
			var flame := Sprites.texture("flame_s_%s" % ("a" if (w.steps / FLAME_STEPS_FAST + j) % 2 == 0 else "b"))
			var rise := Vector2(0.0, -FLAME_RISE * hold - j)
			c.draw_texture(flame, (at + Vector2.from_angle(spot) * (r - 3.0) + rise - Vector2(3.0, 5.0)).round(), fade)


## Adds one thing to _standing()'s list. The second field keeps the order things were added in among equal depths, so
## paint() can sort the list with Array.sort() (no callback per comparison) and never compares the textures.
func _put(list: Array, depth: float, sprite: String, at: Vector2, anchor: Vector2, flip := false, white := false, tint := Color.WHITE) -> void:
	list.append([depth, list.size(), Sprites.texture(sprite, flip, white), (at - anchor).round(), tint])


## Fills _picture, _frame, _mirror and _lit for the world as it is; again only once the world has moved on.
func _crowd(w) -> void:
	var key := [w.steps, w.time, w.night, w.enemies.size(), w.fuel, w.picks.size()]
	if key == _crowd_for:
		return
	_crowd_for = key
	var n: int = w.enemies.size()
	_picture.resize(n)
	_frame.resize(n)
	_mirror.resize(n)
	_lit.resize(n)
	var light: float = w.light_radius()
	for i in n:
		var e = w.enemies[i]
		var looks_as: String = Looks.DECOYS[e.kind] if e.decoy else e.kind
		var k := _kind(looks_as, e.tier)
		_picture[i] = k
		_frame[i] = Looks.frame_index(looks_as, w.steps, i)
		_mirror[i] = 1 if _turned(e, k.look) else 0
		_lit[i] = 1 if e.pos.distance_to(T.pos) <= light else 0 # w.in_light(e.pos)


## An enemy kind's pictures at a tier: each walking frame [as is, mirrored, white, mirrored white] in the tier's
## colours, where its feet are on each frame, its eyes for the dark on each frame [as is, mirrored] and their colour,
## its shadow and its glows (a tier has its kind's shape, so these are the same at every tier).
func _kind(kind: String, tier: int = 1) -> Dictionary:
	var key := Looks.thing(kind, tier)
	if _kinds.has(key):
		return _kinds[key]
	var look := Looks.enemy(kind)
	var k := { "look": look, "frames": [], "feet": [], "eyes": [], "eye_colour": Color.WHITE,
		"shadow": Sprites.texture(look.shadow),
		"glow": Sprites.texture(look.glow) if look.glow != "" else null,
		"dark_glow": Sprites.texture(look.dark_glow) if look.dark_glow != "" else null }
	for frame in Looks.FRAMES:
		var name: String = frame % kind
		var coloured := Sprites.tiered(name, tier)
		k.frames.append([Sprites.texture(coloured), Sprites.texture(coloured, true), Sprites.texture(name, false, true), Sprites.texture(name, true, true)])
		k.feet.append(Sprites.foot(name))
		if not look.in_dark.is_empty():
			k.eyes.append([Sprites.only(name, look.in_dark[0]), Sprites.only(name, look.in_dark[0], true)])
	if not look.in_dark.is_empty():
		k.eye_colour = Sprites.PALETTE[look.in_dark[1]]
	_kinds[key] = k
	return k


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
