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
	"shade_decoy": { "steps": 16, "anchor": Vector2(12.0, 14.0), "shadow": "shadow_big", "shadow_at": Vector2(-10.0, 6.0), "bits": ["7", "8", "9"], "glow": "shade_decoy_eyes" },
}
## What a boss's decoys (its row's split) look like: a look above, drawn as <look>_a and <look>_b. The shade lord's
## have its shape under a plain hood, with dull eyes where its own burn blue: the real one has the crown and the blue eyes.
const DECOYS := { "shade_lord": "shade_decoy" }

## One line that says what a thing does, shown the first time it turns up in a game. One per enemy kind, and "berry".
## {who} in a line is the keeper being played (say()), never a name written out.
const HINTS := {
	"slime": "슬라임: 횃불에 붙어 불을 덮는다",
	"bat": "박쥐: {who}를 쫓아온다, 빛 밖에서는 더 빠르다",
	"thief": "도둑 비버: 장작을 물고 달아난다",
	"shade": "그림자: 횃불 빛 안에서만 벨 수 있다",
	"big_slime": "큰 슬라임: 죽으면 둘로 갈라진다",
	"boar": "멧돼지: 멈춰 붉은 띠가 깔리면 곧장 돌진한다, 띠 밖으로 비켜라. 돌진 뒤 어지러울 때 베라",
	"slime_king": "슬라임 왕: 가까이 가면 뛰어올라 덮친다, 빨간 원 밖으로 피하라",
	"shade_lord": "그림자 군주: 어둠 속을 돌다 횃불로 달려든다, 빛 안에 있을 때 베라. 왕관이 없고 눈이 흐린 분신은 가짜다",
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
const SIDE_NAMES := { "torch": "횃불의 힘", "keeper": "{who}의 힘" }

## How each character (Config.CHARACTERS) looks. sprite: the prefix of its pictures, each drawn as <sprite>_<down,
## up, side>_<a,b> walking, _lift_<a,b> with logs overhead, _atk while it attacks, and <sprite>_dead (CHARACTER_FRAMES).
## weapon: what it swings (WEAPONS), "" for none. cloak: the thorn cloak upgrade shows on it (its thorns_* fit
## the body). heavy: its swing's trail is drawn thick. button: the sprite on the touch attack button (src/touch.gd).
const CHARACTERS := {
	"knight": { "sprite": "keeper", "weapon": "sword", "cloak": true, "heavy": false, "button": "sword" },
	"woodcutter": { "sprite": "woodcutter", "weapon": "axe", "cloak": true, "heavy": true, "button": "axe" },
	"mage": { "sprite": "mage", "weapon": "", "cloak": true, "heavy": false, "button": "icon_wide_swing_mage" },
}
const CHARACTER_FRAMES := ["%s_down_a", "%s_down_b", "%s_up_a", "%s_up_b", "%s_side_a", "%s_side_b",
	"%s_down_lift_a", "%s_down_lift_b", "%s_up_lift_a", "%s_up_lift_b", "%s_side_lift_a", "%s_side_lift_b",
	"%s_down_atk", "%s_up_atk", "%s_side_atk", "%s_dead"]
## A weapon is drawn as its sprite and the variants the swing's upgrades show: <weapon>, _fire, _long, _long_fire.
## grip: the pixel of its sprite held in the fist.
const WEAPONS := {
	"sword": { "grip": Vector2(1.5, 2.5) },
	"axe": { "grip": Vector2(1.5, 3.5) },
}
const WEAPON_FRAMES := ["%s", "%s_fire", "%s_long", "%s_long_fire"]

static var _looks := {} # kind -> its finished look, made the first time it is asked for
static var _bits := {} # "kind~tier" -> bit_colours(), made once


static func enemy(kind: String) -> Dictionary:
	if not _looks.has(kind):
		var look: Dictionary = DEFAULT.duplicate()
		look.merge(ENEMIES.get(kind, {}), true)
		_looks[kind] = look
	return _looks[kind]


## What an enemy kind is called: the name its hint opens with.
static func kind_name(kind: String) -> String:
	return HINTS[kind].get_slice(":", 0)


## What a first sighting is of: an enemy kind at tier 1 (its HINTS line), or "<kind>~<tier>" for a stronger tier.
static func thing(kind: String, tier: int) -> String:
	return kind if tier <= 1 else "%s~%d" % [kind, tier]


## The line a first sighting shows ("name: what it does") to one playing who, or "" for a thing that has none.
static func hint(what: String, who: String = "knight") -> String:
	if not "~" in what:
		return say(HINTS.get(what, ""), who)
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


static func character(id: String) -> Dictionary:
	return CHARACTERS[id]


## The icon an upgrade shows for a character: icon_<id>_<character> where one is drawn (the mage's embers), else icon_<id>.
static func icon(upgrade: String, who: String = "knight") -> String:
	var own := "%s_%s" % [ICON % upgrade, who]
	return own if Sprites.SPRITES.has(own) else ICON % upgrade


## The name the HUD gives a side for a character: the torch's, or the character's own ("나무꾼의 힘").
static func side_name(side_id: String, who: String = "knight") -> String:
	return say(SIDE_NAMES[side_id], who)


## Korean particles that change with the word before them: [after a vowel, after a final consonant]. 로 is the odd
## one: a word ending in ㄹ takes 로 too (particle()).
const PARTICLES := [["를", "을"], ["가", "이"], ["는", "은"], ["와", "과"], ["로", "으로"]]
const WHO := "{who}"


## A line as one playing who reads it: {who} is that character's name (Config.CHARACTERS), and a particle written
## right after it (in its after-a-vowel form, PARTICLES) is put in the form that name takes: {who}를 reads 을 after
## 나무꾼, 를 after 불씨 술사.
static func say(line: String, who: String = "knight") -> String:
	var name: String = Config.CHARACTERS[who].name
	for pair in PARTICLES:
		line = line.replace(WHO + pair[0], name + particle(name, pair[0]))
	return line.replace(WHO, name)


## The particle (given in its after-a-vowel form, one of PARTICLES) that goes after word: 을, 이, 은, 과, 으로 after
## a final consonant, 를, 가, 는, 와, 로 after a vowel (and 로 after ㄹ as well). A word that does not end in a
## Korean syllable is read as ending in a vowel.
static func particle(word: String, vowel_form: String) -> String:
	var forms: Array = PARTICLES.filter(func(p): return p[0] == vowel_form)[0]
	var last := word.unicode_at(word.length() - 1) if word != "" else 0
	if last < 0xAC00 or last > 0xD7A3:
		return forms[0]
	var coda := (last - 0xAC00) % 28 # the final consonant: 0 none, 8 ㄹ
	return forms[1] if coda != 0 and not (coda == 8 and vowel_form == "로") else forms[0]


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
	for kind in Config.ENEMY_TYPES:
		if Config.ENEMY_TYPES[kind].has("split") and not DECOYS.has(kind):
			out.append("Boss '%s' splits off decoys but they have no look. Fix: add it to DECOYS in src/art/looks.gd (and draw that look's _a and _b in src/art/sprites.gd)." % kind)
	for kind in DECOYS:
		wanted.append_array([FRAMES[0] % DECOYS[kind], FRAMES[1] % DECOYS[kind]])
		if enemy(DECOYS[kind]).glow != "":
			wanted.append(enemy(DECOYS[kind]).glow)
	for id in Config.UPGRADES:
		wanted.append(ICON % id)
	out.append_array(character_problems(Config.CHARACTERS.keys(), CHARACTERS))
	for id in CHARACTERS:
		if CHARACTERS[id].has("sprite"):
			for f in CHARACTER_FRAMES:
				wanted.append(f % CHARACTERS[id].sprite)
			wanted.append(CHARACTERS[id].get("button", "sword"))
			var weapon: String = CHARACTERS[id].get("weapon", "")
			if weapon != "":
				for f in WEAPON_FRAMES:
					wanted.append(f % weapon)
	for id in TORCH_SIDE:
		if not Config.UPGRADES.has(id):
			out.append("TORCH_SIDE names '%s', which is not an upgrade. Fix: remove it from TORCH_SIDE in src/art/looks.gd." % id)
	return out + Sprites.missing(wanted)


## What is wrong with the characters' looks: every character in the rules (ids) has one, with a sprite and a weapon
## that WEAPONS knows (or none), and no look is for a character the rules do not have.
static func character_problems(ids: Array, looks: Dictionary) -> Array:
	var out := []
	for id in ids:
		if not looks.has(id):
			out.append("Character '%s' has no look. Fix: add it to CHARACTERS in src/art/looks.gd (and draw its frames in src/art/sprites.gd)." % id)
			continue
		for key in ["sprite", "weapon", "cloak", "heavy", "button"]:
			if not looks[id].has(key):
				out.append("Character '%s' has no %s in its look. Fix: add it to CHARACTERS in src/art/looks.gd." % [id, key])
		if looks[id].get("weapon", "") != "" and not WEAPONS.has(looks[id].weapon):
			out.append("Character '%s' swings '%s', which WEAPONS does not know. Fix: add it (and its grip) to WEAPONS in src/art/looks.gd." % [id, looks[id].weapon])
	for id in looks:
		if not ids.has(id):
			out.append("CHARACTERS in src/art/looks.gd has '%s', which is not a character. Fix: remove it, or add it to Config.CHARACTERS." % id)
	return out


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
	var look := { "sprite": "x", "weapon": "", "cloak": false, "heavy": false, "button": "x" }
	if character_problems(["a", "b"], { "a": look }).is_empty():
		fails.append("[A2] missed a character with no look")
	if character_problems(["a"], { "a": { "sprite": "x", "weapon": "spoon", "cloak": false, "heavy": false, "button": "x" } }).is_empty():
		fails.append("[A2] missed a character swinging a weapon nobody drew")
	if not character_problems(["a"], { "a": look }).is_empty():
		fails.append("[A2] flagged a character with a full look")
	return fails
