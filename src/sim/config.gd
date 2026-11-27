## Numbers the whole simulation agrees on. Tuning values live here or in these tables, never inline in logic (N1).
## Top-down: x right, y down. The whole field is on screen at once.
extends RefCounted

const STEP := 1.0 / 60.0 # the fixed simulation step, in seconds (D5: project.godot runs physics at 60 Hz)
const VIEW := Vector2(480.0, 270.0) # the screen, in game pixels; project.godot's viewport must match (R1 checks)
const FIELD := Rect2(8.0, 8.0, 464.0, 254.0) # where the player can walk: the view less the treetops at its edges

## The keeper, as the knight plays it; a character (CHARACTERS) changes some of these. A swing's blow lands from
## attack_hit_at to attack_hit_until seconds into it (while the painter shows its trail), on every enemy that is in it
## then (World.in_blow), each at most once per swing. attack: "swing" (a blow round the keeper), "chop" (a blow that
## lands in front of it, see chop) or "shoot" (an ember fired at attack_hit_at, see bolt). damage: what a blow does; push: how hard it knocks back (share of ENEMY.knock).
## carry: how many logs it can hold at once; carry_speed is its speed with one, carry_slow less for each more.
## log_bonus: fuel each log it brings adds besides TORCH.log_fuel.
const PLAYER := {
	"start": Vector2(240.0, 165.0), "speed": 80.0, "carry_speed": 58.0, "radius": 6.0, "hp": 5,
	"invuln": 1.2, "hurt_time": 0.25, "hurt_knock": 140.0,
	"attack_time": 0.28, "attack_hit_at": 0.1, "attack_hit_until": 0.18, "reach": 22.0, "arc": 0.3, "aim_slack": 10.0, "grab": 9.0,
	"dash_speed": 250.0, "dash_time": 0.14, # the dash upgrade: how fast and how long; you cannot be hurt during it
	"attack": "swing", "damage": 1, "push": 1.0, "carry": 1, "carry_slow": 0.0, "log_bonus": 0.0,
}

## Who keeps the torch: chosen at the start of a run, all three from the first. stats: what it changes in PLAYER (the
## knight changes nothing, so it plays exactly as the keeper always has). name, text, trait and bars are for the
## choosing screen (src/ui.gd): bars are 1 to 5 of 5 pips, after one for hp that is worked out from stats.
## bolt (attack "shoot"): the ember it fires toward World.aim(). It flies speed pixels a second for range pixels,
## hits what its radius touches (World.in_bolt), does damage, lit_bonus more to an enemy in the torch's light, pushes
## push of a blow's knockback and passes through pierce enemies before it stops (lit_pierce more in the light); spread: radians between the embers
## of a fan (the spin upgrade as the mage has it). splash: where an ember burns an enemy it bursts, and splash_damage
## burns every other enemy whose body comes within splash pixels of that enemy's middle (World.in_splash), pushed out
## by splash_push of a blow's knockback, so a crowd melts and does not just queue up for the next shot.
## chop (attack "chop"): the axe comes down on a round of radius pixels whose middle is ahead pixels in front of the
## keeper along its facing (World.in_chop); what is behind it or at its sides is not struck, however close. A spin
## (the spin upgrade) still goes all the way round at reach.
## Upgrade rows can read differently per character (UPGRADES' as).
const CHARACTERS := {
	"knight": {
		"name": "기사", "text": "칼을 든 횃불 지기. 무엇이든 고르게 해낸다", "trait": "약점 없음",
		"bars": [["힘", 2], ["거리", 2], ["장작", 2]],
		"stats": {},
	},
	"woodcutter": {
		"name": "나무꾼", "text": "느리지만 앞을 세게 내리찍는 도끼. 장작을 셋까지 들고, 하나에 연료 +5",
		"trait": "약점: 느린 도끼질",
		"bars": [["힘", 4], ["거리", 2], ["장작", 5]],
		"stats": { "attack": "chop", "attack_time": 0.38, "attack_hit_at": 0.13, "attack_hit_until": 0.2, "reach": 21.0,
			"chop": { "ahead": 19.0, "radius": 14.0 },
			"damage": 2, "push": 1.5, "carry": 3, "carry_speed": 70.0, "carry_slow": 6.0, "log_bonus": 5.0 },
	},
	"mage": {
		"name": "불씨 술사", "text": "겨눈 쪽으로 불씨를 쏜다. 빛 안의 적에게 피해 +1, 하나를 꿰뚫는다",
		"trait": "약점: 체력 3",
		"bars": [["힘", 2], ["거리", 5], ["장작", 1]],
		"stats": { "hp": 3, "attack": "shoot", "attack_time": 0.68, "attack_hit_at": 0.06, "attack_hit_until": 0.06,
			"carry_speed": 50.0,
			"bolt": { "speed": 200.0, "range": 100.0, "radius": 3.0, "damage": 1, "lit_bonus": 1, "push": 0.5, "pierce": 0, "lit_pierce": 1, "spread": 0.3,
				"splash": 16.0, "splash_damage": 1, "splash_push": 0.3 } },
	},
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

## Stronger tiers of the regular kinds, for later nights. A boss is always tier 1; what a big slime breaks into
## is of its tier. One row per tier from 2, applied to the kind's row in ENEMY_TYPES (Enemy.row): hp and score
## multiplied and rounded up, speed and smother multiplied, heavy (optional) the share of a blow's knockback it takes.
## Each tier is the same picture in other colours (TIERS in src/art/sprites.gd) and has a name (looks.gd).
const TIERS := [
	{ "hp": 1.5, "speed": 1.1, "smother": 1.25, "score": 1.5 },
	{ "hp": 2.0, "speed": 1.2, "smother": 1.5, "score": 2.0, "heavy": 0.6 },
]
## Which tiers come when. From the night of a row (and until the next row's), each enemy that comes out of the dark,
## with those that come along with it, is of one tier, rolled over shares (tier 1, tier 2, tier 3). Before the
## first row every enemy is tier 1 and nothing is rolled, so those nights are the same as before tiers.
const TIER_NIGHTS := [
	{ "from": 8, "shares": [0.85, 0.15, 0.0] },
	{ "from": 10, "shares": [0.7, 0.3, 0.0] },
	{ "from": 12, "shares": [0.5, 0.4, 0.1] },
	{ "from": 14, "shares": [0.35, 0.45, 0.2] },
	{ "from": 16, "shares": [0.2, 0.4, 0.4] },
	{ "from": 18, "shares": [0.1, 0.35, 0.55] },
]

## Dawn: the sun clears the field, you rest (heal), and the torch is topped up to at least its starting fuel (its
## start_fuel share of the tank, so a big torch is topped up further).
const DAWN := { "heal": 1 }

## The keeper hardens as the nights go on, to keep up with crowds that grow faster than a few hearts can take. From
## the night from: hp_first more hearts that night and one more on every hp_every-th night after it, at most hp_most
## more; from that night on dawn heals the keeper fully (new hearts too); and after a hit it cannot be
## hurt for invuln_grow seconds longer per night from from on (counting that night), at most invuln_most in all.
const HARDEN := { "from": 10, "hp_first": 3, "hp_every": 2, "hp_most": 6, "invuln_grow": 0.15, "invuln_most": 2.4 }

## Every few nights bosses come, partway through the night, besides the usual enemies (which come a little less
## often that night). counts: how many come, from the night of a row (until the next row's). The first comes at at
## (a share of the night), each next one apart seconds after the one before. kinds take turns: the first boss night
## brings the first kind, the next the second, and so on; on a night with several, each next boss is the next kind.
## warn: seconds before each comes that the world picks the edge it comes from and says so (the screen points there).
## strength: what a boss's hp (and the numbers it summons and breaks into, never under one) is multiplied by on the boss night
## numbered n from 1: first, plus grow for each boss night before it, at most most. The first boss is gentle.
const BOSS := {
	"every": 3, "at": 0.25, "kinds": ["slime_king", "shade_lord"], "spawn_mult": 1.35, "warn": 2.0, "apart": 6.0,
	"counts": [{ "from": 3, "count": 1 }, { "from": 12, "count": 2 }, { "from": 21, "count": 3 }],
	"strength": { "first": 0.5, "grow": 0.2, "most": 1.5 },
}

## Each dusk from the night from, the night draws an omen: one row of OMENS, never the one the night before had.
## The first night has none, and nights before from draw nothing from the rng.
const OMEN := { "from": 2 }

## Omens: what tonight is like, besides its row in NIGHTS. name and text are what the screen says of it; the rest
## the rules read through World.mod(), as they read a picked upgrade, so an omen's multiplier and an upgrade's make a
## product. Only multipliers (keys ending in _mult), and kinds: for each enemy kind named, what its share of tonight's
## who is multiplied by. light_mult: the torch's light; burn_mult: fuel burnt per second; wood_mult, berry_mult:
## seconds between logs, between berries (and until the night's first berry); gap_mult: seconds between enemies;
## log_mult: fuel a log gives, bonuses and all. from (optional): the first night it may come, no earlier than the
## kinds it names do.
const OMENS := {
	"fog": { "name": "안개", "text": "빛이 좁아지고 박쥐가 몰려든다", "light_mult": 0.85, "kinds": { "bat": 2.0 }, "from": 3 },
	"wind": { "name": "바람", "text": "불이 빨리 타지만 장작이 자주 떨어진다", "burn_mult": 1.2, "wood_mult": 0.7, "from": 4 },
	"still": { "name": "고요", "text": "적이 드물고 열매도 드물다", "gap_mult": 1.1, "berry_mult": 2.0 },
	"harvest": { "name": "풍년", "text": "장작이 오래 타지만 도둑이 꼬인다", "log_mult": 1.2, "kinds": { "thief": 3.0 } },
	"dew": { "name": "이슬", "text": "젖은 장작이 덜 타고 열매가 자주 난다", "log_mult": 0.75, "berry_mult": 0.5 },
	"dark_moon": { "name": "그믐", "text": "빛이 조금 줄고 그림자가 늘어난다", "light_mult": 0.95, "kinds": { "shade": 1.6 }, "from": 4 },
}

## Surges: from the night from, packs come besides the steady trickle. Each is one kind (drawn over tonight's who
## among kinds) of one tier, and comes all at once along one edge, ENEMY.with_gap apart; warn seconds before, the
## world picks the edge and says so (the screen points there). packs: how many come in a night and the most one
## holds, from the night of a row (until the next row's). They come at random times, one in each equal part of the
## night between its shares at. Together they are share of the enemies the night would bring without them (fewer when
## most says so), and the trickle comes further apart to make up for makes_up of them, so the night brings about as
## many as before: at most share * (1 - makes_up) more.
const SURGE := {
	"from": 2, "share": 0.3, "makes_up": 0.75, "warn": 2.5, "at": [0.3, 0.9], "kinds": ["slime", "bat", "shade", "thief", "boar"],
	"packs": [{ "from": 2, "count": 1, "most": 3 }, { "from": 3, "count": 1, "most": 4 }, { "from": 4, "count": 2, "most": 8 }, { "from": 8, "count": 3, "most": 10 }],
}

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
## mark is hurt. hops: every each-th leap is count short hops in a row instead, each marked and warned the same way
## with its own warn, air and shock, toward where the player stands but at most reach pixels from the king.
## lunge (the shade lord): it circles ring pixels outside the torch's light, where blows pass through it;
## every so many seconds it stops for warn seconds, then rushes to the torch at speed, smothers it for stay seconds
## (in the light, so it can be cut) and walks back out into the dark. split (the shade lord): every so many seconds
## while it circles (the first first seconds after it comes) it stops and flickers for warn seconds, then count
## decoys of it appear round its ring. A decoy
## has no crown and dull eyes; it hurts no one and smothers nothing, rushes the torch when its lord does and fades
## there; a blow in the light (where blows reach it) breaks it with no score; it fades after life seconds.
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
		"leap": { "every": 5.0, "range": 110.0, "warn": 0.6, "air": 0.45, "shock": 24.0, "torch_gap": 24.0,
			"hops": { "each": 2, "count": 3, "warn": 0.45, "air": 0.3, "shock": 18.0, "reach": 45.0 } },
	},
	"shade_lord": {
		"hp": 18, "speed": 28.0, "radius": 10.0, "target": "torch", "smother": 2.0, "dark_proof": true,
		"boss": true, "name": "그림자 군주", "heavy": 0.2, "summon": { "kind": "shade", "every": 7.0, "count": 2 }, "score": 150,
		"lunge": { "every": 7.0, "warn": 1.0, "speed": 110.0, "stay": 3.5, "ring": 16.0 },
		"split": { "every": 12.0, "first": 4.0, "warn": 0.9, "count": 2, "life": 9.0 },
	},
}

## Torch upgrades. At each offer the torch puts on the table upgrades you do not have yet, or the next level of one
## you have. A row is its first level; levels holds what changes at the second level, the third, and so on (merged
## over the row, so a level names only what it changes). Effects are read by the rules through World.mod(); add a
## row here and handle its key there. as (optional): how the upgrade reads for a character, merged over the row (a
## key set to null is taken out; levels are merged one by one), for the characters whose attack is not the sword's.
## auto_attack (swift's last level): the keeper attacks by itself whenever its attack is ready, an enemy is within
## World.attack_range() (for a chop: in the round it would come down on, turned to the nearest) and it carries nothing
## (the attack key would put the logs down), turned to the nearest as a pressed attack is (World.aim). With nothing in
## reach it does not swing at the air. The key still works as before. chop_ahead, chop_radius: pixels added to a
## chop's (Config.CHARACTERS' chop) ahead and radius.
## from_night (optional): the torch offers it only from that night on (World.can_offer); before it, the offers are
## drawn as if the row were not there. A row with one goes last, so the rows before it keep their order, and it
## takes no slot (BUILD).
## side: whose power it is, "torch" or "keeper": the side whose slots (BUILD) it takes one of, and the group the
## screen shows it in. rare (optional): it changes how the keeper plays, and is drawn less often (BUILD.rare_weight).
## only (optional): a character (CHARACTERS); the torch offers the row to that character and to no other.
## needs (optional): two upgrades; a combined upgrade, offered only while both are held. It takes no slot and is
## drawn more often than another card (BUILD.combo_weight), so whoever holds the pair soon sees it.
## What the keys of the rows with only or needs mean: guard_invuln, guard_reach, guard_push, guard_damage: a hit the
## keeper takes keeps it from the next one that many seconds longer and throws back every enemy within reach of it
## (push: share of a blow's knockback), doing them that damage; haste, haste_time, haste_attack: after a kill the
## keeper walks haste times as fast for that many seconds, and its attack's times (ATTACK_TIMES) are multiplied by
## haste_attack meanwhile; log_chance: an enemy the keeper's own blow kills leaves a log, that often; carry_bonus:
## logs carried besides the character's carry; pierce_bonus: enemies an ember goes through besides bolt.pierce, and
## pierce_burst: it bursts (bolt.splash) on each of them too, not only where it stops; kindle_reach: an enemy an ember
## kills throws a spark (SPARK) at the nearest other enemy whose body is within that many pixels of it; scorch_every:
## every that many seconds the ember ring burns away the last point of each enemy in it that is down to one, bosses
## excepted; beacon_every: the keeper's own blow that lands on an enemy in the torch's light makes the torch fire a
## spark at once, at that enemy if it still lives and else at the nearest enemy in the light, at most once in that
## many seconds, besides the sparks spark_every brings; dash_damage: a dash does that to each enemy it touches, once;
## feed_reach, feed_push: logs put on the fire throw back every enemy within reach of the torch.
const UPGRADES := {
	"slow_burn": { "side": "torch", "name": "느린 불꽃", "text": "연료가 25% 천천히 탄다", "burn_mult": 0.75,
		"levels": [{ "text": "연료가 40% 천천히 탄다", "burn_mult": 0.6 }] },
	"big_logs": { "side": "torch", "name": "마른 장작", "text": "장작 하나에 연료 +12", "log_bonus": 12.0,
		"levels": [{ "text": "장작 하나에 연료 +20", "log_bonus": 20.0 }] },
	"ember_ring": { "side": "torch", "name": "불씨 고리", "text": "횃불 곁의 적을 1.5초마다 그을려 체력 1까지 깎고, 덮는 힘을 25% 줄인다",
		"ember_radius": 26.0, "ember_every": 1.5, "smother_mult": 0.75,
		"levels": [{ "text": "고리가 넓어지고 1.2초마다 그을린다, 덮는 힘 40% 줄임", "ember_radius": 32.0, "ember_every": 1.2, "smother_mult": 0.6 },
			{ "text": "고리가 더 넓어지고 0.9초마다 그을린다, 덮는 힘 절반", "ember_radius": 38.0, "ember_every": 0.9, "smother_mult": 0.5 }] },
	"warm_glow": { "side": "torch", "name": "따뜻한 빛", "text": "빛 안의 적이 40% 느려진다", "glow_slow": 0.6,
		"levels": [{ "text": "빛 안의 적이 55% 느려진다", "glow_slow": 0.45 }] },
	"woodpile": { "side": "torch", "name": "장작더미", "text": "장작이 더 자주, 더 많이 나온다", "wood_mult": 0.65, "wood_extra": 2,
		"levels": [{ "text": "장작이 훨씬 자주, 더 많이 나온다", "wood_mult": 0.5, "wood_extra": 3 }] },
	"quick_hands": { "side": "keeper", "name": "날랜 손", "text": "장작을 들어도 느려지지 않는다", "carry_full": true,
		"as": { "woodcutter": { "text": "장작을 여럿 들어도 느려지지 않는다" } } },
	"long_blade": { "side": "keeper", "name": "긴 칼날", "text": "베기 거리 +8", "reach_bonus": 8.0,
		"levels": [{ "text": "베기 거리 +14", "reach_bonus": 14.0 }],
		"as": { "woodcutter": { "name": "긴 도끼자루", "text": "도끼가 5 더 멀리 찍는다", "chop_ahead": 5.0,
				"levels": [{ "text": "도끼가 9 더 멀리 찍는다", "chop_ahead": 9.0 }] },
			"mage": { "name": "먼 불씨", "text": "불씨가 날아가는 거리 +30", "reach_bonus": null, "range_bonus": 30.0,
				"levels": [{ "text": "불씨가 날아가는 거리 +50", "reach_bonus": null, "range_bonus": 50.0 }] } } },
	"bright": { "side": "torch", "name": "밝은 불", "text": "빛 반경 +30%, 빛 안에서 15% 빨리 걷는다", "light_mult": 1.3, "lit_speed_mult": 1.15,
		"levels": [{ "text": "빛 반경 +50%, 빛 안에서 25% 빨리 걷는다", "light_mult": 1.5, "lit_speed_mult": 1.25 }] },
	"sturdy": { "side": "keeper", "name": "튼튼한 몸", "text": "최대 체력 +1, 체력 1 회복", "hp_bonus": 1,
		"levels": [{ "hp_bonus": 2 }, { "hp_bonus": 3 }] },
	"thorns": { "side": "keeper", "name": "가시 망토", "text": "나를 때린 적도 피해 1, 바짝 붙은 적은 1초마다 찔린다", "thorns": 1,
		"thorn_every": 1.0, "thorn_reach": 6.0,
		"levels": [{ "text": "나를 때린 적도 피해 2, 바짝 붙은 적은 0.7초마다 찔린다", "thorns": 2, "thorn_every": 0.7 }] },
	"wide_swing": { "side": "keeper", "name": "넓은 베기", "text": "베기 범위가 넓어진다", "arc_bonus": -0.5,
		"levels": [{ "text": "베기 범위가 더 넓어진다", "arc_bonus": -0.8 }],
		"as": { "woodcutter": { "name": "넓게 찍기", "text": "찍는 자리가 넓어진다 (반경 +3)", "arc_bonus": null, "chop_radius": 3.0,
				"levels": [{ "text": "찍는 자리가 더 넓어진다 (반경 +5)", "arc_bonus": null, "chop_radius": 5.0 }] },
			"mage": { "name": "큰 불씨", "text": "불씨가 커져 맞히는 반경 +2", "arc_bonus": null, "bolt_bonus": 2.0,
				"levels": [{ "text": "불씨가 더 커져 맞히는 반경 +3.5", "arc_bonus": null, "bolt_bonus": 3.5 }] } } },
	"fire_blade": { "side": "keeper", "name": "불붙은 칼", "text": "빛 안에서 베면 피해 +1", "lit_damage": 1,
		"levels": [{ "text": "빛 안에서 베면 피해 +2", "lit_damage": 2 }],
		"as": { "woodcutter": { "name": "불붙은 도끼", "text": "빛 안에서 찍으면 피해 +1", "levels": [{ "text": "빛 안에서 찍으면 피해 +2" }] },
			"mage": { "name": "타오르는 불씨", "text": "빛 안의 적을 맞히면 피해 +1 더", "levels": [{ "text": "빛 안의 적을 맞히면 피해 +2 더" }] } } },
	"dash": { "side": "keeper", "rare": true, "name": "돌진", "text": "Shift로 짧게 돌진, 그동안 무적 (1.2초마다)", "dash_every": 1.2,
		"levels": [{ "text": "돌진을 0.7초마다 쓸 수 있다", "dash_every": 0.7 }] },
	"spin": { "side": "keeper", "rare": true, "name": "회전 베기", "text": "세 번째 베기마다 한 바퀴를 벤다", "spin_every": 3,
		"levels": [{ "text": "두 번째 베기마다 한 바퀴를 벤다", "spin_every": 2 }],
		"as": { "woodcutter": { "name": "회전 도끼", "text": "세 번째 도끼질마다 한 바퀴를 휘두른다", "levels": [{ "text": "두 번째 도끼질마다 한 바퀴를 휘두른다" }] },
			"mage": { "name": "세 갈래 불씨", "text": "세 번째 쏠 때마다 불씨 셋을 부채꼴로 쏜다", "spin_every": null, "spread_every": 3,
			"levels": [{ "text": "두 번째 쏠 때마다 불씨 셋을 쏜다", "spin_every": null, "spread_every": 2 }] } } },
	"spark": { "side": "torch", "name": "불씨 화살", "text": "횃불이 2.5초마다 빛 안의 적에게 불씨를 쏜다", "spark_every": 2.5,
		"levels": [{ "text": "횃불이 1.6초마다 불씨를 쏜다", "spark_every": 1.6 },
			{ "text": "횃불이 1.2초마다 불씨를 쏜다", "spark_every": 1.2 }] },
	"vampire": { "side": "keeper", "name": "흡혈 칼날", "text": "칼로 8번 처치할 때마다 체력 1, 5번째 밤부터 필요한 처치 수가 밤마다 25%씩 늘어난다",
		"vamp_kills": 8, "vamp_grow": 1.25, "vamp_from": 4,
		"levels": [{ "text": "칼로 5번 처치할 때마다 체력 1, 5번째 밤부터 밤마다 25%씩 늘어난다", "vamp_kills": 5 }],
		"as": { "woodcutter": { "name": "흡혈 도끼", "text": "도끼로 8번 처치할 때마다 체력 1, 5번째 밤부터 필요한 처치 수가 밤마다 25%씩 늘어난다",
				"levels": [{ "text": "도끼로 5번 처치할 때마다 체력 1, 5번째 밤부터 밤마다 25%씩 늘어난다" }] },
			"mage": { "name": "흡혈 불씨", "text": "불씨로 8번 처치할 때마다 체력 1, 5번째 밤부터 필요한 처치 수가 밤마다 25%씩 늘어난다",
				"levels": [{ "text": "불씨로 5번 처치할 때마다 체력 1, 5번째 밤부터 밤마다 25%씩 늘어난다" }] } } },
	"big_torch": { "side": "torch", "name": "큰 횃불", "text": "연료 최대치 +30, 새벽에 그만큼 더 채워진다", "fuel_bonus": 30.0,
		"levels": [{ "text": "연료 최대치 +60, 새벽에 그만큼 더 채워진다", "fuel_bonus": 60.0 }] },
	"guard": { "side": "keeper", "only": "knight", "name": "굳센 방패", "text": "맞으면 무적이 0.6초 길어지고 곁의 적을 밀쳐 내며 피해 1",
		"guard_invuln": 0.6, "guard_reach": 30.0, "guard_push": 1.5, "guard_damage": 1,
		"levels": [{ "text": "맞으면 무적이 1초 길어지고 더 멀리까지 밀쳐 내며 피해 2", "guard_invuln": 1.0, "guard_reach": 42.0, "guard_damage": 2 }] },
	"momentum": { "side": "keeper", "only": "knight", "name": "기세", "text": "적을 처치하면 3초 동안 25% 빨리 걷고 베기 간격이 30% 짧아진다",
		"haste": 1.25, "haste_time": 3.0, "haste_attack": 0.7,
		"levels": [{ "text": "적을 처치하면 4초 동안 40% 빨리 걷고 베기 간격이 30% 짧아진다", "haste": 1.4, "haste_time": 4.0 }] },
	"splitter": { "side": "keeper", "only": "woodcutter", "name": "쪼개기", "text": "도끼로 처치한 적이 가끔(8%) 장작을 남긴다", "log_chance": 0.08,
		"levels": [{ "text": "도끼로 처치한 적이 더 자주(14%) 장작을 남긴다", "log_chance": 0.14 }] },
	"big_pack": { "side": "keeper", "only": "woodcutter", "name": "큰 지게", "text": "장작을 하나 더 든다", "carry_bonus": 1 },
	"piercing": { "side": "keeper", "only": "mage", "name": "꿰뚫는 불씨", "text": "불씨가 적 하나를 더 꿰뚫고, 꿰뚫는 적마다 터진다", "pierce_bonus": 1, "pierce_burst": true,
		"levels": [{ "text": "불씨가 적 둘을 더 꿰뚫고, 꿰뚫는 적마다 터진다", "pierce_bonus": 2 }] },
	"kindle": { "side": "keeper", "only": "mage", "name": "불씨 옮기기", "text": "불씨로 처치한 적이 가까운 적에게 작은 불씨를 튀긴다", "kindle_reach": 40.0,
		"levels": [{ "text": "불씨로 처치한 적이 더 먼 적에게도 작은 불씨를 튀긴다", "kindle_reach": 64.0 }] },
	"scorch": { "side": "torch", "needs": ["ember_ring", "warm_glow"], "name": "화염 고리", "text": "불씨 고리가 4초마다 체력 1인 적을 마저 태운다 (보스는 빼고)", "scorch_every": 4.0 },
	"beacon": { "side": "torch", "needs": ["spark", "fire_blade"], "name": "불 표적", "text": "빛 안의 적을 베면 횃불이 그 적이나 가까운 적에게 불씨를 쏜다 (1초에 한 번)", "beacon_every": 1.0,
		"as": { "woodcutter": { "text": "빛 안의 적을 찍으면 횃불이 그 적이나 가까운 적에게 불씨를 쏜다 (1초에 한 번)" },
			"mage": { "text": "빛 안의 적을 맞히면 횃불이 그 적이나 가까운 적에게 불씨를 쏜다 (1초에 한 번)" } } },
	"bramble": { "side": "keeper", "needs": ["dash", "thorns"], "name": "가시 돌진", "text": "돌진으로 스친 적에게 피해 2", "dash_damage": 2 },
	"blast": { "side": "torch", "needs": ["big_logs", "woodpile"], "name": "장작 폭발", "text": "장작을 넣으면 횃불 곁의 적이 밀려난다", "feed_reach": 40.0, "feed_push": 1.5 },
	"swift": { "side": "keeper", "name": "빠른 칼놀림", "text": "베기 간격이 30% 짧아진다", "attack_mult": 0.7, "from_night": 10,
		"levels": [{ "text": "베기 간격이 45% 짧아진다", "attack_mult": 0.55 },
			{ "text": "베기 간격 60% 짧게, 최대: 닿는 적을 저절로 벤다", "attack_mult": 0.4, "auto_attack": true }],
		"as": { "woodcutter": { "name": "빠른 도끼질", "text": "도끼질 간격이 30% 짧아진다",
				"levels": [{ "text": "도끼질 간격이 45% 짧아진다" }, { "text": "도끼질 간격 60% 짧게, 최대: 닿는 적을 저절로 찍는다" }] },
			"mage": { "name": "잦은 불씨", "text": "불씨를 쏘는 간격이 20% 짧아진다", "attack_mult": 0.8,
				"levels": [{ "text": "불씨를 쏘는 간격이 35% 짧아진다", "attack_mult": 0.65 },
					{ "text": "쏘는 간격 절반으로, 최대: 닿는 적에게 저절로 쏜다", "attack_mult": 0.5 }] } } },
}

## The build: what a keeper can hold. slots: how many different upgrades of each side; once a side is full the torch
## offers only further levels of what that side holds (an upgrade with from_night takes no slot and is offered all
## the same). rerolls: how many times in a run an offer can be drawn again (World.step's "reroll"). rare_weight: a
## rare upgrade's chance of being drawn, against 1 for any other; combo_weight: a combined upgrade's (a row with
## needs). The torch has the more slots (docs/DECISIONS.md).
const BUILD := { "slots": { "torch": 6, "keeper": 4 }, "rerolls": 2, "rare_weight": 0.5, "combo_weight": 5.0 }

## What the torch gives when it has fewer upgrades to offer than NIGHT.offer_size: the offer is filled up from these,
## drawn as upgrades are. Taken, one acts once, now, and is gone: it takes no slot and is not part of the build
## (World.picks). fuel: fuel added; heal: hearts healed; logs: logs dropped round the torch, log_at pixels from it
## (where logs fall by themselves: WOOD.keep_away); score: points added. Small on purpose: they come when a build is
## done. One that only heals is left out while the keeper is unhurt (World.can_fill); the others can always come, and
## there are NIGHT.offer_size of those, so an offer is never short of a card.
const FILLERS := {
	"kindling": { "name": "불쏘시개", "text": "지금 연료 +30 (가득 차면 거기까지)", "fuel": 30.0 },
	"rest": { "name": "숨 고르기", "text": "지금 체력 1 회복", "heal": 1 },
	"spare_log": { "name": "마른 장작 하나", "text": "횃불 곁에 장작 하나가 떨어진다", "logs": 1, "log_at": 48.0 },
	"tale": { "name": "밤의 이야기", "text": "지금 점수 +50", "score": 50 },
}

## The keeper's numbers that time its attack (PLAYER): the attack_mult upgrade (swift) shortens them all alike, so a
## faster swing lands at the same share of it (World.stat); so does haste_attack, for a while after a kill.
const ATTACK_TIMES := ["attack_time", "attack_hit_at", "attack_hit_until"]
