## Numbers the whole simulation agrees on. Tuning values live here or in these tables, never inline in logic (N1).
## Top-down: x right, y down. The whole field is on screen at once.
extends RefCounted

const STEP := 1.0 / 60.0 # the fixed simulation step, in seconds (D5: project.godot runs physics at 60 Hz)
const VIEW := Vector2(480.0, 270.0) # the screen, in game pixels; project.godot's viewport must match (R1 checks)
const FIELD := Rect2(8.0, 8.0, 464.0, 254.0) # where the player can walk: the view less the treetops at its edges

## A swing's blow lands from attack_hit_at to attack_hit_until seconds into it (while the painter shows its trail),
## on every enemy that is in it then (World.in_swing), each at most once per swing.
const PLAYER := {
	"start": Vector2(240.0, 165.0), "speed": 80.0, "carry_speed": 58.0, "radius": 6.0, "hp": 5,
	"invuln": 1.2, "hurt_time": 0.25, "hurt_knock": 140.0,
	"attack_time": 0.28, "attack_hit_at": 0.1, "attack_hit_until": 0.18, "reach": 22.0, "arc": 0.3, "aim_slack": 10.0, "grab": 9.0,
	"dash_speed": 250.0, "dash_time": 0.14, # the dash upgrade: how fast and how long; you cannot be hurt during it
}

## How many directions the touch stick steers in (InputFrame.stick). The keys give eight; the stick's 64 are fine
## enough to feel like any direction, and whole numbers, so a touch run is as exact as a key run.
const STICK_DIRECTIONS := 64

## The spark upgrade: embers the torch shoots at an enemy in its light. They fly straight and burn the first enemy
## they touch.
const SPARK := { "speed": 170.0, "life": 1.2, "radius": 3.0, "damage": 1, "mouth": Vector2(0.0, -6.0) }

## The torch you keep alive until dawn. Fuel burns every second (how fast is in NIGHTS); a log adds fuel; slimes at
## the torch smother it. Light radius follows fuel: from light_min (almost out) to light_max (full).
const TORCH := {
	"pos": Vector2(240.0, 135.0), "max_fuel": 100.0, "start_fuel": 70.0, "log_fuel": 25.0,
	"smother": 8.0, "reach": 12.0, "light_min": 28.0, "light_max": 100.0,
}

## Logs appear on the ground away from the torch, a few at a time. On a night whose torch burns faster than pace
## (fuel per second, before upgrades), they come that much more often, so the wood keeps up with the fire.
const WOOD := { "first": 1.0, "every": 5.5, "max_on_ground": 3, "keep_away": 45.0, "pace": 2.8 }

## Berries appear now and then, far from the torch. Walking over one heals you if you are hurt.
const BERRY := { "first": 18.0, "every": 20.0, "max_on_ground": 1, "keep_away": 55.0, "heal": 1 }

const SPOT_TRIES := 12 # random spots tried when placing a log or a berry before giving up for this turn

## Every night: how long until dawn, when in it the torch offers a choice besides at dusk (shares of the night),
## how many upgrades it offers, and how long after dusk the first enemy comes.
const NIGHT := { "length": 60.0, "picks_at": [0.5], "offer_size": 3, "first_spawn": 2.5 }

## The nights, one row each. burn: fuel the torch uses per second. spawn: seconds between enemies at dusk and
## just before dawn. who: each enemy kind's share of them; a kind first shows up on the night whose row first names
## it. with (optional): kinds that come along with a kind, from the same spot on the edge (a thief guarded by a shade,
## a boar with bats at its side); each must be one the row names. Nights after the last row use it again, each one
## harder than the one before by LATER_NIGHTS.
const NIGHTS := [
	{ "burn": 2.0, "spawn": [3.0, 2.0], "who": { "slime": 0.8, "bat": 0.2 } },
	{ "burn": 2.4, "spawn": [2.5, 1.7], "who": { "slime": 0.6, "bat": 0.2, "thief": 0.2 } },
	{ "burn": 2.8, "spawn": [2.3, 1.55], "who": { "slime": 0.5, "bat": 0.2, "thief": 0.1, "shade": 0.2 } },
	{ "burn": 3.2, "spawn": [2.0, 1.3], "who": { "slime": 0.45, "bat": 0.2, "thief": 0.1, "shade": 0.15, "big_slime": 0.1 } },
	{ "burn": 3.5, "spawn": [1.75, 1.15], "who": { "slime": 0.45, "bat": 0.2, "thief": 0.1, "shade": 0.15, "big_slime": 0.1 } },
	{ "burn": 3.75, "spawn": [1.6, 1.05], "who": { "slime": 0.4, "bat": 0.17, "thief": 0.08, "shade": 0.13, "big_slime": 0.1, "boar": 0.12 } },
	{ "burn": 4.05, "spawn": [1.4, 0.92], "who": { "slime": 0.33, "bat": 0.17, "thief": 0.14, "shade": 0.14, "big_slime": 0.1, "boar": 0.12 },
		"with": { "thief": ["shade"], "boar": ["bat"] } },
	{ "burn": 4.35, "spawn": [1.25, 0.84], "who": { "slime": 0.28, "bat": 0.16, "thief": 0.15, "shade": 0.13, "big_slime": 0.1, "boar": 0.18 },
		"with": { "thief": ["shade"], "boar": ["bat", "bat"] } },
	{ "burn": 4.65, "spawn": [1.05, 0.7], "who": { "slime": 0.24, "bat": 0.14, "thief": 0.16, "shade": 0.14, "big_slime": 0.1, "boar": 0.22 },
		"with": { "thief": ["shade", "shade"], "boar": ["bat", "bat"], "big_slime": ["boar"] } },
]
## Per night past the table: fuel per second added, spawn gap multiplied. min_gap: the gap never gets shorter than
## this (seconds), however late. It first bites at the very end of night 19, so the crowds up to there grow freely;
## past twenty it keeps the count (and the frame time) from running away.
const LATER_NIGHTS := { "burn": 0.3, "spawn": 0.82, "min_gap": 0.1 }

## Dawn: the sun clears the field, you rest (heal), and the torch is topped up to at least its starting fuel (its
## start_fuel share of the tank, so a big torch is topped up further).
const DAWN := { "heal": 1 }

## Every few nights a boss comes, partway through the night, besides the usual enemies (which come a little less
## often that night). kinds take turns: the first boss night brings the first, the next the second, and so on.
## warn: seconds before it comes that the world picks the edge it comes from and says so (the screen points there).
const BOSS := { "every": 5, "at": 0.25, "kinds": ["slime_king", "shade_lord"], "spawn_mult": 1.35, "warn": 2.0 }

const SCORE := { "kill": 10, "log": 5, "dawn": 100 }

const ENEMY := {
	"knock": 150.0, "knock_decay": 0.002, "knock_stop": 4.0, "flash": 0.12, "edge": 12.0,
	"steal": 8.0, "split_spread": 6.0, "split_knock": 70.0, "summon_gap": 6.0,
	"with_gap": 10.0, # pixels apart along the edge that a kind and those coming with it (NIGHTS with) appear
	"orbit_lead": 0.4, # radians ahead on its circle a boss that circles the light aims for: it goes round, not in
	"orbit_top": 64.0, # it keeps this far below the top of the field, where the HUD would hide it
}

## Enemy kinds: add a row to add an enemy (and draw <kind>_a and <kind>_b in src/art/sprites.gd).
## target: "torch" walks to the torch and smothers it, "player" hunts you, "log" carries a log off the field.
## Optional: smother (how many slimes it counts as at the torch), split_count and splits_into (what it breaks into
## when it dies), dark_proof (blows pass through it outside the torch's light), harmless (touching it does not hurt),
## boss (comes on boss nights only, see BOSS; name is what the screen calls it), heavy (share of a blow's knockback it
## takes), summon (every so many seconds it calls count enemies of kind around itself), score (worth more than a kill),
## dark_speed_mult (how much faster it moves outside the torch's light: the dark is where it hunts).
## leap (the slime king): every so many seconds, when the player is within range, it marks the spot where the player
## stands (but never closer to the torch than torch_gap beyond where it would smother it), crouches there for warn
## seconds, flies for air seconds and lands on the mark; a player within shock of the
## mark is hurt. lunge (the shade lord): it circles ring pixels outside the torch's light, where blows pass through it;
## every so many seconds it stops for warn seconds, then rushes to the torch at speed, smothers it for stay seconds
## (in the light, so it can be cut) and walks back out into the dark.
## charge (the boar): every so many seconds, on the field with the player within range, it fixes a line at the
## player and paws the ground for warn seconds, then charges along it at speed for dist pixels (or to the field's
## edge; blows do not stop it) and stands dazed for rest seconds.
const ENEMY_TYPES := {
	"slime": { "hp": 2, "speed": 16.0, "radius": 7.0, "target": "torch" },
	"bat": { "hp": 1, "speed": 26.0, "radius": 5.0, "target": "player", "dark_speed_mult": 1.5 },
	"shade": { "hp": 2, "speed": 24.0, "radius": 6.0, "target": "player", "dark_proof": true },
	"big_slime": { "hp": 5, "speed": 10.0, "radius": 10.0, "target": "torch", "smother": 2.0, "split_count": 2, "splits_into": "slime" },
	"thief": { "hp": 1, "speed": 40.0, "radius": 6.0, "target": "log", "harmless": true },
	"boar": { "hp": 3, "speed": 18.0, "radius": 7.0, "target": "player",
		"charge": { "every": 3.5, "range": 110.0, "warn": 0.8, "speed": 170.0, "dist": 150.0, "rest": 1.2 } },
	"slime_king": {
		"hp": 16, "speed": 9.0, "radius": 13.0, "target": "torch", "smother": 1.2, "split_count": 2, "splits_into": "big_slime",
		"boss": true, "name": "슬라임 왕", "heavy": 0.15, "summon": { "kind": "slime", "every": 8.0, "count": 2 }, "score": 150,
		"leap": { "every": 5.0, "range": 110.0, "warn": 0.6, "air": 0.45, "shock": 24.0, "torch_gap": 24.0 },
	},
	"shade_lord": {
		"hp": 18, "speed": 28.0, "radius": 10.0, "target": "torch", "smother": 2.0, "dark_proof": true,
		"boss": true, "name": "그림자 군주", "heavy": 0.2, "summon": { "kind": "shade", "every": 7.0, "count": 2 }, "score": 150,
		"lunge": { "every": 7.0, "warn": 1.0, "speed": 110.0, "stay": 3.5, "ring": 16.0 },
	},
}

## Torch upgrades. At each offer the torch puts on the table upgrades you do not have yet, or the next level of one
## you have. A row is its first level; levels holds what changes at the second level, the third, and so on (merged
## over the row, so a level names only what it changes). Effects are read by the rules through World.mod(); add a
## row here and handle its key there.
const UPGRADES := {
	"slow_burn": { "name": "느린 불꽃", "text": "연료가 25% 천천히 탄다", "burn_mult": 0.75,
		"levels": [{ "text": "연료가 40% 천천히 탄다", "burn_mult": 0.6 }] },
	"big_logs": { "name": "마른 장작", "text": "장작 하나에 연료 +12", "log_bonus": 12.0,
		"levels": [{ "text": "장작 하나에 연료 +20", "log_bonus": 20.0 }] },
	"ember_ring": { "name": "불씨 고리", "text": "횃불 곁의 적을 1.5초마다 그을려 체력 1까지 깎고, 덮는 힘을 25% 줄인다",
		"ember_radius": 26.0, "ember_every": 1.5, "smother_mult": 0.75,
		"levels": [{ "text": "고리가 넓어지고 1.2초마다 그을린다, 덮는 힘 40% 줄임", "ember_radius": 32.0, "ember_every": 1.2, "smother_mult": 0.6 },
			{ "text": "고리가 더 넓어지고 0.9초마다 그을린다, 덮는 힘 절반", "ember_radius": 38.0, "ember_every": 0.9, "smother_mult": 0.5 }] },
	"warm_glow": { "name": "따뜻한 빛", "text": "빛 안의 적이 40% 느려진다", "glow_slow": 0.6,
		"levels": [{ "text": "빛 안의 적이 55% 느려진다", "glow_slow": 0.45 }] },
	"woodpile": { "name": "장작더미", "text": "장작이 더 자주, 더 많이 나온다", "wood_mult": 0.65, "wood_extra": 2,
		"levels": [{ "text": "장작이 훨씬 자주, 더 많이 나온다", "wood_mult": 0.5, "wood_extra": 3 }] },
	"quick_hands": { "name": "날랜 손", "text": "장작을 들어도 느려지지 않는다", "carry_full": true },
	"long_blade": { "name": "긴 칼날", "text": "베기 거리 +8", "reach_bonus": 8.0,
		"levels": [{ "text": "베기 거리 +14", "reach_bonus": 14.0 }] },
	"bright": { "name": "밝은 불", "text": "빛 반경 +30%, 빛 안에서 15% 빨리 걷는다", "light_mult": 1.3, "lit_speed_mult": 1.15,
		"levels": [{ "text": "빛 반경 +50%, 빛 안에서 25% 빨리 걷는다", "light_mult": 1.5, "lit_speed_mult": 1.25 }] },
	"sturdy": { "name": "튼튼한 몸", "text": "최대 체력 +1, 체력 1 회복", "hp_bonus": 1,
		"levels": [{ "hp_bonus": 2 }, { "hp_bonus": 3 }] },
	"thorns": { "name": "가시 망토", "text": "나를 때린 적도 피해 1, 바짝 붙은 적은 1초마다 찔린다", "thorns": 1,
		"thorn_every": 1.0, "thorn_reach": 6.0,
		"levels": [{ "text": "나를 때린 적도 피해 2, 바짝 붙은 적은 0.7초마다 찔린다", "thorns": 2, "thorn_every": 0.7 }] },
	"wide_swing": { "name": "넓은 베기", "text": "베기 범위가 넓어진다", "arc_bonus": -0.5,
		"levels": [{ "text": "베기 범위가 더 넓어진다", "arc_bonus": -0.8 }] },
	"fire_blade": { "name": "불붙은 칼", "text": "빛 안에서 베면 피해 +1", "lit_damage": 1,
		"levels": [{ "text": "빛 안에서 베면 피해 +2", "lit_damage": 2 }] },
	"dash": { "name": "돌진", "text": "Shift로 짧게 돌진, 그동안 무적 (1.2초마다)", "dash_every": 1.2,
		"levels": [{ "text": "돌진을 0.7초마다 쓸 수 있다", "dash_every": 0.7 }] },
	"spin": { "name": "회전 베기", "text": "세 번째 베기마다 한 바퀴를 벤다", "spin_every": 3,
		"levels": [{ "text": "두 번째 베기마다 한 바퀴를 벤다", "spin_every": 2 }] },
	"spark": { "name": "불씨 화살", "text": "횃불이 2.5초마다 빛 안의 적에게 불씨를 쏜다", "spark_every": 2.5,
		"levels": [{ "text": "횃불이 1.6초마다 불씨를 쏜다", "spark_every": 1.6 },
			{ "text": "횃불이 1.2초마다 불씨를 쏜다", "spark_every": 1.2 }] },
	"vampire": { "name": "흡혈 칼날", "text": "칼로 8번 처치할 때마다 체력 1, 회복 뒤 쉬는 시간이 밤마다 2초씩 길어진다",
		"vamp_kills": 8, "vamp_wait": 2.0,
		"levels": [{ "text": "칼로 5번 처치할 때마다 체력 1, 쉬는 시간은 밤마다 1.5초씩", "vamp_kills": 5, "vamp_wait": 1.5 }] },
	"big_torch": { "name": "큰 횃불", "text": "연료 최대치 +30, 새벽에 그만큼 더 채워진다", "fuel_bonus": 30.0,
		"levels": [{ "text": "연료 최대치 +60, 새벽에 그만큼 더 채워진다", "fuel_bonus": 60.0 }] },
}
