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
## dark_speed_mult in its row, so you see where it is faster).
const DEFAULT := {
	"steps": 12, "anchor": Vector2(8.0, 10.0), "shadow": "shadow", "shadow_at": Vector2(-6.0, 1.0),
	"flies": false, "turns": false, "bits": ["W", "a", "A"], "glow": "", "dark_glow": "",
}
const ENEMIES := {
	"slime": { "steps": 14, "bits": ["h", "g", "G"] },
	"bat": { "steps": 5, "anchor": Vector2(8.0, 11.0), "shadow": "shadow_small", "shadow_at": Vector2(-4.0, 4.0), "flies": true, "bits": ["p", "P", "q"], "dark_glow": "bat_eyes" },
	"shade": { "steps": 14, "bits": ["7", "8", "l"], "glow": "shade_eyes" },
	"big_slime": { "steps": 18, "anchor": Vector2(12.0, 13.0), "shadow": "shadow_big", "shadow_at": Vector2(-10.0, 2.0), "bits": ["h", "G", "j"] },
	"thief": { "steps": 6, "turns": true, "bits": ["o", "O", "n"] },
	"boar": { "steps": 7, "turns": true, "bits": ["b", "B", "S"] },
	"slime_king": { "steps": 20, "anchor": Vector2(16.0, 17.0), "shadow": "shadow_huge", "shadow_at": Vector2(-14.0, 5.0), "bits": ["h", "g", "Y"] },
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

static var _looks := {} # kind -> its finished look, made the first time it is asked for


static func enemy(kind: String) -> Dictionary:
	if not _looks.has(kind):
		var look: Dictionary = DEFAULT.duplicate()
		look.merge(ENEMIES.get(kind, {}), true)
		_looks[kind] = look
	return _looks[kind]


## The sprite an enemy shows on this simulation step. offset keeps a crowd from moving in step.
static func frame(kind: String, steps: int, offset: int = 0) -> String:
	return FRAMES[(steps / enemy(kind).steps + offset) % 2] % kind


## Rule A2: messages for every sprite the rules' data asks for by name that is not drawn, and for every enemy kind
## that has no hint.
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
	for id in Config.UPGRADES:
		wanted.append(ICON % id)
	return out + Sprites.missing(wanted)
