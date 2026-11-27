## How the things the rules name look: each enemy kind and each upgrade. The rules know nothing of this.
## By convention an enemy kind is drawn as the sprites <kind>_a and <kind>_b and an upgrade as icon_<id>, so a new
## row in Config needs only its grids in sprites.gd. ./verify checks they are there (A2), because a missing one
## would otherwise fail only when that enemy or upgrade first shows up in a game.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const Sprites := preload("res://src/art/sprites.gd")

const ICON := "icon_%s"
const FRAMES := ["%s_a", "%s_b"]

## What an enemy looks like unless its row below says otherwise. steps: simulation steps per frame. anchor: the
## pixel of the sprite that sits on its position. shadow, shadow_at: the shadow sprite and where its top-left goes.
## flies: painted above everything that stands, bobbing. turns: mirrored when it heads left. bits: PALETTE keys of
## the pixels that fly off it when it is hit. glow: a sprite painted over it that the night does not dim.
## dark_glow: the same, painted only while it is outside the torch's light, with a streak behind it (a kind with
## dark_speed_mult in its row, so you see where it is faster). in_dark: [PALETTE key, PALETTE key]: the pixels of its
## own sprite drawn with the first key (its eyes) show in the second colour while it is outside the light, where the
## night is too dark to see the rest of it. A kind with a glow or a dark_glow needs none.
const DEFAULT := {
	"steps": 12, "anchor": Vector2(8.0, 10.0), "shadow": "shadow", "shadow_at": Vector2(-6.0, 1.0),
	"flies": false, "turns": false, "bits": ["W", "a", "A"], "glow": "", "dark_glow": "", "in_dark": [],
}
const ENEMIES := {
	"slime": { "steps": 14, "bits": ["h", "g", "G"], "in_dark": ["W", "h"] },
	"bat": { "steps": 5, "anchor": Vector2(8.0, 11.0), "shadow": "shadow_small", "shadow_at": Vector2(-4.0, 4.0), "flies": true, "bits": ["p", "P", "q"], "dark_glow": "bat_eyes" },
	"shade": { "steps": 14, "bits": ["7", "8", "l"], "glow": "shade_eyes" },
	"big_slime": { "steps": 18, "anchor": Vector2(12.0, 13.0), "shadow": "shadow_big", "shadow_at": Vector2(-10.0, 2.0), "bits": ["h", "G", "j"], "in_dark": ["W", "h"] },
	"thief": { "steps": 6, "turns": true, "bits": ["o", "O", "n"], "in_dark": ["W", "y"] },
	"boar": { "steps": 7, "turns": true, "bits": ["b", "B", "S"], "in_dark": ["i", "i"] },
	"slime_king": { "steps": 20, "anchor": Vector2(16.0, 17.0), "shadow": "shadow_huge", "shadow_at": Vector2(-14.0, 5.0), "bits": ["h", "g", "Y"], "in_dark": ["W", "h"] },
	"shade_lord": { "steps": 16, "anchor": Vector2(12.0, 14.0), "shadow": "shadow_big", "shadow_at": Vector2(-10.0, 6.0), "bits": ["7", "8", "Y"], "glow": "shade_lord_eyes" },
}

## One line that says what a thing does, shown the first time it turns up in a game. One per enemy kind, and "berry".
const HINTS := {
	"slime": "슬라임: 횃불에 붙어 불을 덮는다",
	"bat": "박쥐: 기사를 쫓아온다, 빛 밖에서는 더 빠르다",
	"thief": "도둑 비버: 장작을 물고 달아난다",
	"shade": "그림자: 횃불 빛 안에서만 벨 수 있다",
	"big_slime": "큰 슬라임: 죽으면 둘로 갈라진다",
	"boar": "멧돼지: 멈춰 선이 그어지면 곧장 돌진한다, 옆으로 비켜라. 돌진 뒤 어지러울 때 베라",
	"slime_king": "슬라임 왕: 가까이 가면 뛰어올라 덮친다, 빨간 원 밖으로 피하라",
	"shade_lord": "그림자 군주: 어둠 속을 돌다 횃불로 달려든다, 빛 안에 있을 때 베라",
	"berry": "열매: 다쳤을 때 밟으면 체력이 회복된다",
}

## The stronger tiers of each regular kind (Config.TIERS, coloured by TIERS in src/art/sprites.gd): their names,
## from tier 2, and what the first sighting of one says about it (TIER_HINTS, one per tier from 2).
const TIER_NAMES := {
	"slime": ["주황 슬라임", "빨간 슬라임"],
	"bat": ["황금 박쥐", "붉은 박쥐"],
	"shade": ["청록 그림자", "붉은 그림자"],
	"big_slime": ["큰 주황 슬라임", "큰 빨간 슬라임"],
	"thief": ["잿빛 도둑 비버", "붉은 도둑 비버"],
	"boar": ["잿빛 멧돼지", "붉은 멧돼지"],
}
const TIER_HINTS := ["더 튼튼하고 빠르다", "훨씬 튼튼하고 빠르며, 칼에 덜 밀린다"]

## Which side an upgrade works on, so the HUD, the pause screen and the end screen group them: the torch and its
## fire, or the keeper (every upgrade not listed here). Order within a group is the order they were taken.
const TORCH_SIDE := ["slow_burn", "big_logs", "ember_ring", "warm_glow", "woodpile", "bright", "spark", "big_torch"]
const SIDES := ["torch", "keeper"]
const SIDE_NAMES := { "torch": "횃불의 힘", "keeper": "기사의 힘" }

static var _looks := {} # kind -> its finished look, made the first time it is asked for
static var _bits := {} # "kind~tier" -> bit_colours(), made once


static func enemy(kind: String) -> Dictionary:
	if not _looks.has(kind):
		var look: Dictionary = DEFAULT.duplicate()
		look.merge(ENEMIES.get(kind, {}), true)
		_looks[kind] = look
	return _looks[kind]


## What a first sighting is of: an enemy kind at tier 1 (its HINTS line), or "<kind>~<tier>" for a stronger tier.
static func thing(kind: String, tier: int) -> String:
	return kind if tier <= 1 else "%s~%d" % [kind, tier]


## The line a first sighting shows ("name: what it does"), or "" for a thing that has none.
static func hint(what: String) -> String:
	if not "~" in what:
		return HINTS.get(what, "")
	var t := int(what.get_slice("~", 1)) - 2
	return "%s: %s" % [TIER_NAMES[what.get_slice("~", 0)][t], TIER_HINTS[t]]


## The colours of the pixels that fly off an enemy of this kind and tier when it is hit: its bits, in its tier's
## colours.
static func bit_colours(kind: String, tier: int) -> Array:
	var key := thing(kind, tier)
	if not _bits.has(key):
		var colours: Dictionary = Sprites.tier_colours(Sprites.tiered(FRAMES[0] % kind, tier))
		_bits[key] = enemy(kind).bits.map(func(b): return Color(colours[b]) if colours.has(b) else Sprites.PALETTE[b])
	return _bits[key]


static func side(upgrade: String) -> String:
	return "torch" if TORCH_SIDE.has(upgrade) else "keeper"


## The sprite an enemy shows on this simulation step. offset keeps a crowd from moving in step.
static func frame(kind: String, steps: int, offset: int = 0) -> String:
	return FRAMES[frame_index(kind, steps, offset)] % kind


## Which of FRAMES that is.
static func frame_index(kind: String, steps: int, offset: int = 0) -> int:
	return (steps / enemy(kind).steps + offset) % 2


## Rule A2: messages for every sprite the rules' data asks for by name that is not drawn, for every enemy kind
## that has no hint, and for every enemy kind that would not show at all out in the dark.
static func problems() -> Array:
	var wanted := []
	var out := []
	for kind in Config.ENEMY_TYPES:
		if not HINTS.has(kind):
			out.append("Enemy kind '%s' has no hint. Fix: add a line for it to HINTS in src/art/looks.gd." % kind)
		var look := enemy(kind)
		wanted.append_array([FRAMES[0] % kind, FRAMES[1] % kind, look.shadow])
		for g in [look.glow, look.dark_glow]:
			if g != "":
				wanted.append(g)
		if Config.ENEMY_TYPES[kind].get("dark_speed_mult", 1.0) > 1.0 and look.dark_glow == "":
			out.append("Enemy kind '%s' is faster in the dark but does not show it. Fix: give it a dark_glow in ENEMIES in src/art/looks.gd." % kind)
		var frames := [FRAMES[0] % kind, FRAMES[1] % kind]
		if Sprites.missing(frames).is_empty():
			out.append_array(dark_problems(kind, look, frames.map(func(f): return Sprites.rows(f))))
		out.append_array(tier_problems(kind, Config.ENEMY_TYPES[kind].get("boss", false), Sprites.TIERS.get(kind, []), TIER_NAMES.get(kind, []), Config.TIERS.size()))
	for id in Config.UPGRADES:
		wanted.append(ICON % id)
	for id in TORCH_SIDE:
		if not Config.UPGRADES.has(id):
			out.append("TORCH_SIDE names '%s', which is not an upgrade. Fix: remove it from TORCH_SIDE in src/art/looks.gd." % id)
	return out + Sprites.missing(wanted)


## What is wrong with how one enemy kind shows outside the light, given the grids of its frames: the night is nearly
## black there, so it needs a glow, a dark_glow, or in_dark pixels that are on every frame.
static func dark_problems(kind: String, look: Dictionary, frames: Array) -> Array:
	if look.glow != "" or look.dark_glow != "":
		return []
	if look.in_dark.size() != 2:
		return ["Enemy kind '%s' cannot be seen in the dark. Fix: give it in_dark (the PALETTE key of its eyes, then of the colour they glow), a glow or a dark_glow in ENEMIES in src/art/looks.gd." % kind]
	for grid in frames:
		if not grid.any(func(row): return look.in_dark[0] in row):
			return ["Enemy kind '%s' has a frame with no '%s' pixel, so it vanishes in the dark on that frame. Fix: draw its eyes with that key on both frames, or change in_dark in src/art/looks.gd." % [kind, look.in_dark[0]]]
	return []


## What is wrong with one kind's tiers: a regular kind needs a colour map (src/art/sprites.gd TIERS) and a name for
## each of the want tiers above the first, and a boss (always tier 1) has none.
static func tier_problems(kind: String, boss: bool, maps: Array, names: Array, want: int) -> Array:
	if boss:
		if not maps.is_empty() or not names.is_empty():
			return ["Boss '%s' has tiers, but a boss always comes at tier 1. Fix: remove it from TIERS in src/art/sprites.gd and TIER_NAMES in src/art/looks.gd." % kind]
		return []
	var out := []
	if maps.size() != want:
		out.append("Enemy kind '%s' has %d tier colour maps, Config.TIERS has %d tiers above the first. Fix: give it one map per tier in TIERS in src/art/sprites.gd." % [kind, maps.size(), want])
	if names.size() != want:
		out.append("Enemy kind '%s' has %d tier names, Config.TIERS has %d tiers above the first. Fix: give it one name per tier in TIER_NAMES in src/art/looks.gd." % [kind, names.size(), want])
	if TIER_HINTS.size() != want:
		out.append("TIER_HINTS has %d lines, Config.TIERS has %d tiers above the first. Fix: one line per tier in src/art/looks.gd." % [TIER_HINTS.size(), want])
	return out


## A2's dark rule checks itself (G4).
static func selftest() -> Array:
	var fails := []
	var blind: Dictionary = DEFAULT.duplicate()
	var eyed: Dictionary = DEFAULT.duplicate()
	eyed.in_dark = ["W", "h"]
	if dark_problems("x", blind, [["kW"]]).is_empty():
		fails.append("[A2] missed an enemy with nothing to show in the dark")
	if dark_problems("x", eyed, [["kW"], ["kk"]]).is_empty():
		fails.append("[A2] missed a frame without its in_dark pixels")
	if not dark_problems("x", eyed, [["kW"], ["Wk"]]).is_empty():
		fails.append("[A2] flagged an enemy whose eyes show on both frames")
	var maps := [{}, {}]
	maps.resize(TIER_HINTS.size())
	var names := maps.map(func(_m): return "x")
	if tier_problems("x", false, maps.slice(1), names, maps.size()).is_empty():
		fails.append("[A2] missed a regular kind short of a tier's colours")
	if tier_problems("x", true, maps, names, maps.size()).is_empty():
		fails.append("[A2] missed a boss with tiers")
	if not tier_problems("x", false, maps, names, maps.size()).is_empty():
		fails.append("[A2] flagged a regular kind with every tier coloured and named")
	return fails
