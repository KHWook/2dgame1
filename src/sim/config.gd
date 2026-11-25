## Numbers the whole simulation agrees on. Tuning values live here or in these tables, never inline in logic (N1).
## Top-down: x right, y down. The whole field is on screen at once.
extends RefCounted

const STEP := 1.0 / 60.0 # the fixed simulation step, in seconds (D5: project.godot runs physics at 60 Hz)
const VIEW := Vector2(480.0, 270.0) # the screen, in game pixels; project.godot's viewport must match (R1 checks)
const FIELD := Rect2(8.0, 8.0, 464.0, 254.0) # where the player can walk: the view less the treetops at its edges

const PLAYER := {
	"start": Vector2(240.0, 165.0), "speed": 80.0, "carry_speed": 58.0, "radius": 6.0, "hp": 5,
	"invuln": 1.2, "hurt_time": 0.25, "hurt_knock": 140.0,
	"attack_time": 0.28, "attack_hit_at": 0.1, "reach": 22.0, "arc": 0.3, "aim_slack": 10.0, "grab": 9.0,
}

## The torch you keep alive until dawn. Fuel burns every second (how fast is in NIGHTS); a log adds fuel; slimes at
## the torch smother it. Light radius follows fuel: from light_min (almost out) to light_max (full).
const TORCH := {
	"pos": Vector2(240.0, 135.0), "max_fuel": 100.0, "start_fuel": 70.0, "log_fuel": 25.0,
	"smother": 8.0, "reach": 12.0, "light_min": 28.0, "light_max": 100.0,
}

## Logs appear on the ground away from the torch, a few at a time.
const WOOD := { "first": 1.0, "every": 5.5, "max_on_ground": 3, "keep_away": 45.0 }

## Berries appear now and then, far from the torch. Walking over one heals you if you are hurt.
const BERRY := { "first": 18.0, "every": 20.0, "max_on_ground": 1, "keep_away": 55.0, "heal": 1 }

const SPOT_TRIES := 12 # random spots tried when placing a log or a berry before giving up for this turn

## Every night: how long until dawn, when in it the torch offers a choice besides at dusk (shares of the night),
## how many upgrades it offers, and how long after dusk the first enemy comes.
const NIGHT := { "length": 60.0, "picks_at": [0.5], "offer_size": 3, "first_spawn": 2.5 }

## The nights, one row each. burn: fuel the torch uses per second. spawn: seconds between enemies at dusk and
## just before dawn. who: each enemy kind's share of them; a kind first shows up on the night whose row first names
## it. Nights after the last row use it again, each one harder than the one before by LATER_NIGHTS.
const NIGHTS := [
	{ "burn": 2.0, "spawn": [3.0, 2.0], "who": { "slime": 0.8, "bat": 0.2 } },
	{ "burn": 2.4, "spawn": [2.5, 1.7], "who": { "slime": 0.6, "bat": 0.2, "thief": 0.2 } },
	{ "burn": 2.8, "spawn": [2.1, 1.4], "who": { "slime": 0.5, "bat": 0.2, "thief": 0.1, "shade": 0.2 } },
	{ "burn": 3.2, "spawn": [1.8, 1.2], "who": { "slime": 0.45, "bat": 0.2, "thief": 0.1, "shade": 0.15, "big_slime": 0.1 } },
]
const LATER_NIGHTS := { "burn": 0.4, "spawn": 0.78 } # per night past the table: fuel per second added, spawn gap multiplied

## Dawn: the sun clears the field, you rest (heal), and the torch is topped up to at least its starting fuel.
const DAWN := { "heal": 1 }

const SCORE := { "kill": 10, "log": 5, "dawn": 100 }

const ENEMY := {
	"knock": 150.0, "knock_decay": 0.002, "knock_stop": 4.0, "flash": 0.12, "edge": 12.0,
	"steal": 8.0, "split_spread": 6.0, "split_knock": 70.0,
}

## Enemy kinds: add a row to add an enemy (and draw <kind>_a and <kind>_b in src/art/sprites.gd).
## target: "torch" walks to the torch and smothers it, "player" hunts you, "log" carries a log off the field.
## Optional: smother (how many slimes it counts as at the torch), split_count and splits_into (what it breaks into
## when it dies), dark_proof (blows pass through it outside the torch's light), harmless (touching it does not hurt).
const ENEMY_TYPES := {
	"slime": { "hp": 2, "speed": 16.0, "radius": 7.0, "target": "torch" },
	"bat": { "hp": 1, "speed": 32.0, "radius": 5.0, "target": "player" },
	"shade": { "hp": 2, "speed": 24.0, "radius": 6.0, "target": "player", "dark_proof": true },
	"big_slime": { "hp": 5, "speed": 10.0, "radius": 10.0, "target": "torch", "smother": 2.0, "split_count": 2, "splits_into": "slime" },
	"thief": { "hp": 1, "speed": 40.0, "radius": 6.0, "target": "log", "harmless": true },
}

## Torch upgrades offered at night. Each id is picked at most once per night. Effects are read by the rules
## through World.mod(); add a row here and handle its key there.
const UPGRADES := {
	"slow_burn": { "name": "느린 불꽃", "text": "연료가 25% 천천히 탄다", "burn_mult": 0.75 },
	"big_logs": { "name": "마른 장작", "text": "장작 하나에 연료 +12", "log_bonus": 12.0 },
	"ember_ring": { "name": "불씨 고리", "text": "횃불 가까이 온 적에게 1초마다 피해", "ember_radius": 26.0, "ember_every": 1.0 },
	"warm_glow": { "name": "따뜻한 빛", "text": "빛 안의 적이 40% 느려진다", "glow_slow": 0.6 },
	"woodpile": { "name": "장작더미", "text": "장작이 더 자주, 더 많이 나온다", "wood_mult": 0.65, "wood_extra": 2 },
	"quick_hands": { "name": "날랜 손", "text": "장작을 들어도 느려지지 않는다", "carry_full": true },
	"long_blade": { "name": "긴 칼날", "text": "베기 거리 +8", "reach_bonus": 8.0 },
	"bright": { "name": "밝은 불", "text": "빛 반경 +30%", "light_mult": 1.3 },
	"sturdy": { "name": "튼튼한 몸", "text": "최대 체력 +1, 체력 1 회복", "hp_bonus": 1 },
	"thorns": { "name": "가시 망토", "text": "나를 때린 적도 피해 1", "thorns": 1 },
	"wide_swing": { "name": "넓은 베기", "text": "베기 범위가 넓어진다", "arc_bonus": -0.5 },
	"fire_blade": { "name": "불붙은 칼", "text": "빛 안에서 베면 피해 +1", "lit_damage": 1 },
}
