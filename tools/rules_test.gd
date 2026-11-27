## Small scenes that hold each rule to what it says (R1): set a world up by hand, play a few steps, look at what
## came of it. The replay proves the game is the same as it was; these prove a rule does what it claims.
## Add a scene here when you add an enemy kind, an upgrade or a pickup.
extends RefCounted

const World := preload("res://src/sim/world.gd")
const Enemy := preload("res://src/sim/enemy.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")
const Ui := preload("res://src/ui.gd")
const Painter := preload("res://src/art/painter.gd")
const Coach := preload("res://src/coach.gd")
const Sprites := preload("res://src/art/sprites.gd")
const Looks := preload("res://src/art/looks.gd")
const Bot := preload("res://src/bot.gd")
const Effects := preload("res://src/art/effects.gd")
const Juice := preload("res://src/art/juice.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Replay := preload("res://tools/replay_test.gd")
const Main := preload("res://src/main.gd")

const SWING := 10 # steps: long enough for a swing to land (PLAYER.attack_hit_at)
const LIT := Vector2(30.0, 0.0) # from the torch: well inside its light
const DARK := Vector2(110.0, 0.0) # from the torch: well outside its light
const NEAR := Vector2(16.0, 0.0) # from the player: in front, within the sword's reach, not touching
const NEVER := 1.0e9 # a time that does not come: keeps the night from adding things of its own to a scene


## Every failure as a message; empty when all scenes hold.
static func run() -> Array:
	var out := []
	out.append_array(_swing_area())
	out.append_array(_splash())
	out.append_array(_shade())
	out.append_array(_big_slime())
	out.append_array(_thief())
	out.append_array(_berry())
	out.append_array(_upgrades())
	out.append_array(_levels())
	out.append_array(_new_upgrades())
	out.append_array(_rebalanced())
	out.append_array(_dark())
	out.append_array(_bosses())
	out.append_array(_patterns())
	out.append_array(_boss_nights())
	out.append_array(_hops())
	out.append_array(_split())
	out.append_array(_harden())
	out.append_array(_charger())
	out.append_array(_logs())
	out.append_array(_nights())
	out.append_array(_company())
	out.append_array(_omens())
	out.append_array(_omen_rolls())
	out.append_array(_surges())
	out.append_array(_surge_totals())
	out.append_array(_setup())
	out.append_array(_coaching())
	out.append_array(_crowds())
	out.append_array(_late_nights())
	out.append_array(_tier_stats())
	out.append_array(_tier_nights())
	out.append_array(_tier_looks())
	out.append_array(_characters())
	out.append_array(_woodcutter())
	out.append_array(_stack())
	out.append_array(_mage())
	out.append_array(_bolt_edges())
	out.append_array(_character_upgrades())
	out.append_array(_keeper_words())
	out.append_array(_swift())
	out.append_array(_auto_attack())
	out.append_array(_seeds())
	out.append_array(_ground_map())
	out.append_array(_build())
	out.append_array(_fillers())
	out.append_array(_rerolls())
	out.append_array(_slot_tiles())
	out.append_array(_only())
	out.append_array(_needs())
	out.append_array(_own_rows())
	out.append_array(_combined_rows())
	return out


## A night already under way with these upgrades taken, the player standing at at from the torch, facing right, and
## nothing else on the field.
static func _night(at: Vector2, upgrades: Array = [], who := "knight"):
	var w = World.new(1, who)
	w.picks = upgrades.duplicate()
	w.offer = []
	w.phase = "night"
	w.next_spawn = NEVER
	w.next_wood = NEVER
	w.next_berry = NEVER
	w.player.pos = Config.TORCH.pos + at
	w.player.face = Vector2.RIGHT
	return w


static func _add(w, kind: String, from_player: Vector2):
	var e = Enemy.new(kind, w.player.pos + from_player)
	w.enemies.append(e)
	return e


## Plays steps, pressing press on the first one and holding hold throughout. Returns the kind of every event the
## world told on the way.
static func _play(w, steps: int, press: String = "", hold: String = "") -> Array:
	var told := []
	for i in steps:
		var f := InputFrame.new()
		if hold != "":
			f.held[hold] = true
		if i == 0 and press != "":
			f.pressed[press] = true
		w.step(f)
		for ev in w.events:
			told.append(ev.kind)
	return told


static func _expect(out: Array, what: String, got, want) -> void:
	if got != want:
		out.append("%s: got %s, want %s" % [what, got, want])


## What looks struck is struck (World.in_swing): a big body whose middle is past the edge of the arc but whose side
## is in it, and anything pressed against the keeper, behind too; not a body just past the reach, nor one behind
## that is not touching. The blow keeps landing while the trail shows (PLAYER.attack_hit_at to attack_hit_until), on
## what comes into it then, once per enemy per swing, and not on the halves of the slime it broke. Every line of the
## trail the painter draws lies inside what the swing hits.
static func _swing_area() -> Array:
	var out := []
	var hp: int = Config.ENEMY_TYPES.big_slime.hp
	var half: float = acos(Config.PLAYER.arc)
	var w = _night(DARK)
	var edge = _add(w, "big_slime", Vector2.from_angle(half + 0.35) * 20.0) # its middle 20 degrees past the edge
	var behind = _add(w, "bat", Vector2(-9.0, 2.0)) # pressed against the keeper's back
	var far = _add(w, "big_slime", Vector2(Config.PLAYER.reach + Config.ENEMY_TYPES.big_slime.radius + 2.5, 0.0).rotated(-0.3)) # walks 2 px nearer by the blow
	var back = _add(w, "slime", Vector2(-18.0, 0.0)) # behind, close, not touching
	var aim_off = _add(w, "slime", Vector2(0.0, 60.0)) # far below: the swing does not turn to it
	w.player.face = Vector2.RIGHT
	w.player.attack_t = 0.0 # a swing just begun, facing right (pressing attack would turn it to the nearest)
	w.player.struck = []
	w.player.invuln = NEVER # the bat at its back would hurt it and knock it about
	_play(w, SWING)
	_expect(out, "a big slime whose side is in the arc is struck", edge.hp, hp - 1)
	_expect(out, "a bat pressed against the keeper's back is struck", behind.dead, true)
	_expect(out, "a big slime just past the reach is not struck", far.hp, hp)
	_expect(out, "a slime behind, not touching, is not struck", back.hp, Config.ENEMY_TYPES.slime.hp)
	_expect(out, "an enemy far away is not struck", aim_off.hp, Config.ENEMY_TYPES.slime.hp)
	# Into the swing while the trail shows: struck once. Past attack_hit_until: not.
	var into := roundi(Config.PLAYER.attack_hit_at / Config.STEP) + 2
	var late := roundi(Config.PLAYER.attack_hit_until / Config.STEP) + 1
	for at in [into, late]:
		w = _night(DARK)
		var later = Enemy.new("big_slime", w.player.pos + Vector2(0.0, 80.0))
		w.player.face = Vector2.RIGHT
		w.player.attack_t = 0.0 # mid-swing from here, facing right, nothing to aim at
		w.player.struck = []
		for i in at:
			_play(w, 1)
		w.enemies.append(later)
		later.pos = w.player.pos + NEAR
		_play(w, SWING)
		_expect(out, "a big slime that comes into the swing %d steps in: hit" % at, later.hp, hp - (1 if at == into else 0))
	w = _night(DARK)
	var front = _add(w, "slime", NEAR)
	var biter = _add(w, "bat", Vector2(-9.0, 0.0)) # hurts the keeper the step the swing begins
	_play(w, SWING, "attack")
	_expect(out, "hurt as the swing begins, the keeper still lands it", [w.player.hp, front.hp], [Config.PLAYER.hp - 1, Config.ENEMY_TYPES.slime.hp - 1])
	w = _night(DARK)
	var twice = _add(w, "big_slime", NEAR + Vector2(6.0, 0.0)) # not touching, so it does not hurt the keeper
	_play(w, SWING * 2, "attack")
	_expect(out, "a swing hits an enemy once however long it stays in it", twice.hp, hp - 1)
	w = _night(LIT, ["fire_blade", "fire_blade"]) # 3 per blow: one blow breaks a big slime of 3, its halves land in the arc
	var big = _add(w, "big_slime", NEAR + Vector2(6.0, 0.0))
	big.hp = 3
	_play(w, 1, "attack")
	var told: Array = []
	for i in SWING:
		told.append_array(_play(w, 1))
	var halves: Array = w.enemies.filter(func(e): return e.kind == "slime")
	_expect(out, "the swing that breaks a big slime does not also cut its halves", [big.dead, halves.size(), halves.all(func(e): return e.hp == Config.ENEMY_TYPES.slime.hp)], [true, 2, true])
	# The painter's trail, step by step through swings of every kind: each line within what in_swing strikes.
	var painter = Painter.new(1)
	var drawn := 0
	var smeared := 0
	for run in [[[], "knight"], [["long_blade", "long_blade"], "knight"], [["wide_swing", "wide_swing"], "knight"], [["spin"], "knight"],
			[[], "woodcutter"], [["long_blade", "wide_swing", "wide_swing"], "woodcutter"], [["spin", "spin"], "woodcutter"],
			[["swift", "swift", "swift"], "knight"], [["swift", "swift", "swift", "wide_swing"], "woodcutter"]]:
		var ups: Array = run[0]
		w = _night(DARK, ups, run[1])
		for turn in 3: # the spin upgrade goes round on the third swing
			w.player.face = Vector2.from_angle(0.7 * turn + 0.2)
			for i in roundi(w.stat("attack_time") / Config.STEP) + 2:
				_play(w, 1, "attack" if i == 0 else "")
				for line in painter.slash_lines(w):
					drawn += 1
					for j in 9:
						var at: Vector2 = w.player.pos.round() + Vector2.from_angle(lerpf(line[1], line[2], j / 8.0)) * (line[0] + line[4] / 2.0)
						if not w.in_swing(at, 1.0):
							out.append("the trail is drawn where the swing does not hit (%s, %s at %s)" % [ups, at - w.player.pos, w.player.attack_t])
							break
				for band in painter.smear(w):
					smeared += 1
					for at in band[0]:
						if not w.in_swing(at, 1.0):
							out.append("the smear is drawn where the swing does not hit (%s, %s at %s)" % [ups, at - w.player.pos, w.player.attack_t])
							break
				if not (painter.slash_lines(w).is_empty() and painter.smear(w).is_empty()) and w.player.attack_t > w.stat("attack_hit_until"):
					out.append("the trail or the smear still shows once the blow has stopped landing (%s)" % [ups])
	_expect(out, "the painter drew a trail in the swings", drawn > 0, true)
	_expect(out, "the painter drew a smear in the swings", smeared > 0, true)
	return out


## A still enemy of kind at from_player, that does not walk.
static func _planted(w, kind: String, from_player: Vector2):
	var e = _add(w, kind, from_player)
	e.T = e.T.duplicate()
	e.T.speed = 0.0
	return e


## The mage's ember bursts where it stops (bolt.splash): splash_damage on every other enemy whose body comes within
## splash of the middle of the one it stopped in (a slime a pixel inside the edge burns, one a pixel outside does
## not), told as a "burst" with that radius; not on the enemies it goes through in the light, only the last; each
## ember of a fan bursts on its own; the embers' light is only to see by (the rules' light stays the torch's).
static func _splash() -> Array:
	var out := []
	var B: Dictionary = World.character_stats("mage").bolt
	var r: float = Config.ENEMY_TYPES.slime.radius
	for inside in [true, false]:
		var w = _night(DARK, [], "mage")
		var target = _planted(w, "big_slime", Vector2(40.0, 0.0))
		var side = _planted(w, "slime", Vector2(40.0, B.splash + r + (-0.5 if inside else 0.5)))
		var far = _planted(w, "slime", Vector2(40.0, -(B.splash + r + 20.0)))
		var told := []
		for i in 30:
			told.append_array(_play(w, 1, "attack" if i == 0 else ""))
			for ev in w.events:
				if ev.kind == "burst":
					_expect(out, "a burst is told with its radius, at the enemy it stopped in", [ev.radius, ev.pos], [B.splash, target.pos])
		_expect(out, "the ember burns its target (%s)" % ("inside" if inside else "outside"), target.hp, Config.ENEMY_TYPES.big_slime.hp - B.damage)
		_expect(out, "the burst burns a slime a pixel %s its edge %s" % ["inside" if inside else "outside", "" if inside else "not at all"], side.hp, Config.ENEMY_TYPES.slime.hp - (B.splash_damage if inside else 0))
		_expect(out, "the burst leaves a slime far off alone, and is told once", [far.hp, told.count("burst")], [Config.ENEMY_TYPES.slime.hp, 1])
		_expect(out, "in_splash says the same (%s)" % ("inside" if inside else "outside"), World.in_splash(Vector2.ZERO, B.splash, Vector2(0.0, B.splash + r + (-0.5 if inside else 0.5)), r), inside)
	# In the light the ember goes through one and bursts on the next, not on the one it went through.
	var w = _night(Vector2(-50.0, 0.0), [], "mage")
	var through = _planted(w, "big_slime", Vector2(25.0, 0.0))
	var stop = _planted(w, "big_slime", Vector2(63.0, 0.0))
	var by_through = _planted(w, "slime", Vector2(25.0, -(B.splash + r - 1.0)))
	var by_stop = _planted(w, "slime", Vector2(63.0, B.splash + r - 1.0))
	var told := _play(w, 30, "attack")
	_expect(out, "in the light the ember bursts once, on the enemy it stops in", [told.count("burst"), by_through.hp, by_stop.hp], [1, Config.ENEMY_TYPES.slime.hp, Config.ENEMY_TYPES.slime.hp - B.splash_damage])
	_expect(out, "...after going through the first", [through.hp < through.full_hp, stop.hp < stop.full_hp], [true, true])
	# A fan of three: each ember bursts where it stops.
	w = _night(DARK, ["spin"], "mage")
	w.player.swings = 2
	for turn in [-B.spread, 0.0, B.spread]:
		_planted(w, "big_slime", Vector2.from_angle(turn) * 60.0)
	told = _play(w, 40, "attack")
	_expect(out, "each ember of a fan bursts on its own", told.count("burst"), 3)
	# The embers light the dark only to see by.
	w = _night(DARK, [], "mage")
	_play(w, 10, "attack")
	var painter = Painter.new(1)
	var lights: Array = painter.ember_lights(w)
	_expect(out, "an ember in flight carries a light, and the rules' dark stays dark", [lights.size(), lights[0][0] if lights.size() > 0 else null, w.in_light(w.bolts[0].pos) if w.bolts.size() > 0 else true], [1, w.bolts[0].pos if w.bolts.size() > 0 else Vector2.ZERO, false])
	return out


static func _shade() -> Array:
	var out := []
	var w = _night(DARK)
	var shade = _add(w, "shade", NEAR)
	var told := _play(w, SWING, "attack")
	_expect(out, "a shade struck in the dark keeps its hp", shade.hp, Config.ENEMY_TYPES.shade.hp)
	_expect(out, "a blow through a shade in the dark is told as passed", told.has("passed"), true)
	w = _night(LIT)
	shade = _add(w, "shade", NEAR)
	told = _play(w, SWING, "attack")
	_expect(out, "a shade struck in the light loses hp", shade.hp, Config.ENEMY_TYPES.shade.hp - 1)
	_expect(out, "a blow on a shade in the light is told as a hit", told.has("hit"), true)
	return out


static func _big_slime() -> Array:
	var out := []
	var w = _night(DARK)
	var big = _add(w, "big_slime", Vector2(20.0, 0.0))
	big.hp = 1
	_play(w, SWING, "attack")
	_expect(out, "a big slime that dies leaves two slimes", w.enemies.map(func(e): return e.kind), ["slime", "slime"])
	_expect(out, "killing a big slime scores one kill", w.score, Config.SCORE.kill)
	w = _night(DARK)
	var at_torch = Enemy.new("big_slime", Config.TORCH.pos + Vector2(20.0, 0.0))
	w.enemies.append(at_torch)
	var before: float = w.fuel
	_play(w, 1)
	var burn: float = (Config.NIGHTS[0].burn + Config.TORCH.smother * Config.ENEMY_TYPES.big_slime.smother) * Config.STEP
	_expect(out, "a big slime at the torch smothers as two slimes", is_equal_approx(before - w.fuel, burn), true)
	return out


static func _thief() -> Array:
	var out := []
	var w = _night(DARK)
	var log_at: Vector2 = Config.TORCH.pos + Vector2(-100.0, 0.0)
	w.logs.append(log_at)
	var thief = Enemy.new("thief", log_at + Vector2(0.0, 20.0))
	w.enemies.append(thief)
	_play(w, 60)
	_expect(out, "a thief picks up the log it reaches", [thief.carrying, w.logs.size()], [true, 0])
	_play(w, 600)
	_expect(out, "a thief that leaves the field with a log is gone", w.enemies.size(), 0)
	_expect(out, "a thief that got away is not a kill", w.score, 0)
	w = _night(DARK)
	thief = _add(w, "thief", NEAR)
	thief.carrying = true
	_play(w, SWING, "attack")
	_expect(out, "a thief killed with a log drops it", [w.enemies.size(), w.logs.size()], [0, 1])
	w = _night(DARK)
	w.player.take_log()
	thief = _add(w, "thief", Vector2(8.0, 0.0))
	_play(w, 1)
	_expect(out, "a thief snatches the log the player carries", [w.player.carrying, thief.carrying], [false, true])
	_expect(out, "touching a thief does not hurt", w.player.hp, Config.PLAYER.hp)
	return out


static func _berry() -> Array:
	var out := []
	var w = _night(DARK)
	w.player.hp = 3
	w.berries.append(w.player.pos)
	var told := _play(w, 1)
	_expect(out, "a hurt player eats the berry and heals", [w.player.hp, w.berries.size()], [3 + Config.BERRY.heal, 0])
	_expect(out, "eating a berry is told as healed", told.has("healed"), true)
	w = _night(DARK)
	w.berries.append(w.player.pos)
	_play(w, 1)
	_expect(out, "at full health the berry stays", w.berries.size(), 1)
	return out


static func _upgrades() -> Array:
	var out := []
	var w = World.new(1)
	w.offer = ["sturdy"]
	_play(w, 1, "pick_1")
	_expect(out, "sturdy raises max hp and heals by one", [w.max_hp(), w.player.hp], [Config.PLAYER.hp + 1, Config.PLAYER.hp + 1])
	w = _night(DARK, ["thorns"])
	w.next_thorn = NEVER # only the blow back, not the prickling (that has its own scene)
	var slime = _add(w, "slime", Vector2(8.0, 0.0))
	_play(w, 1)
	_expect(out, "with thorns the enemy that hurts you is hurt too", [w.player.hp, slime.hp], [Config.PLAYER.hp - 1, Config.ENEMY_TYPES.slime.hp - 1])
	for wide in [false, true]:
		w = _night(DARK, ["wide_swing"] if wide else [])
		_add(w, "slime", NEAR)
		var beside = _add(w, "slime", Vector2(-4.0, -18.0)) # a little behind the side: its body is clear of the usual arc
		_play(w, SWING, "attack")
		_expect(out, "a swing reaches an enemy at its side only with wide swing (%s)" % wide, beside.hp, Config.ENEMY_TYPES.slime.hp - (1 if wide else 0))
	for at in [LIT, DARK]:
		w = _night(at, ["fire_blade"])
		slime = _add(w, "slime", NEAR)
		_play(w, SWING, "attack")
		_expect(out, "the fire blade adds a point of damage only in the light (%s)" % ("lit" if at == LIT else "dark"), slime.hp, Config.ENEMY_TYPES.slime.hp - (2 if at == LIT else 1))
	return out


static func _levels() -> Array:
	var out := []
	var w = _night(DARK, ["ember_ring"])
	_expect(out, "an upgrade starts at level 1", [w.level("ember_ring"), w.mod("ember_radius", 0.0)], [1, Config.UPGRADES.ember_ring.ember_radius])
	w.picks.append("ember_ring")
	_expect(out, "taken again it is level 2, with its level-2 numbers", [w.level("ember_ring"), w.mod("ember_radius", 0.0)], [2, Config.UPGRADES.ember_ring.levels[0].ember_radius])
	w = World.new(1)
	w.picks = ["quick_hands", "ember_ring", "ember_ring", "ember_ring"]
	for i in 50:
		w._offer()
		_expect(out, "a maxed upgrade or one without levels is not offered again", w.offer.has("quick_hands") or w.offer.has("ember_ring"), false)
	w = World.new(1)
	w.picks = ["slow_burn"]
	var seen := false
	for i in 100:
		w._offer()
		seen = seen or w.offer.has("slow_burn")
	_expect(out, "an upgrade with a next level can be offered again", seen, true)
	w = World.new(1)
	w.picks = ["sturdy"]
	w.player.hp = 3
	w.offer = ["sturdy"]
	_play(w, 1, "pick_1")
	_expect(out, "sturdy at level 2 adds one more max hp and heals by one", [w.max_hp(), w.player.hp], [Config.PLAYER.hp + 2, 4])
	return out


static func _new_upgrades() -> Array:
	var out := []
	# dash
	for has in [false, true]:
		var w = _night(DARK, ["dash"] if has else [])
		var from: Vector2 = w.player.pos
		_play(w, 1, "dash", "right")
		_play(w, 9, "", "right")
		var walked: float = Config.PLAYER.speed * Config.STEP * 10.0
		_expect(out, "the dash key dashes only with the dash upgrade (%s)" % has, w.player.pos.x - from.x > walked + 10.0, has)
	var w = _night(DARK, ["dash"])
	_play(w, 1, "dash", "right")
	_add(w, "slime", Vector2(4.0, 0.0))
	_play(w, 1)
	_expect(out, "nothing hurts you while you dash", w.player.hp, Config.PLAYER.hp)
	_play(w, int(Config.PLAYER.dash_time / Config.STEP) + 2)
	_play(w, 1, "dash", "left")
	_expect(out, "the dash has to wait before it comes again", w.player.dash_t > 0.0, false)
	# spin
	w = _night(DARK, ["spin"])
	var ahead = _add(w, "slime", NEAR) # nearer, so the swing aims at it
	var behind = _add(w, "slime", -NEAR * 1.25)
	for e in [ahead, behind]:
		e.hp = 99
		e.T = e.T.duplicate()
		e.T.speed = 0.0
		e.T.heavy = 0.0
	for i in Config.UPGRADES.spin.spin_every:
		_play(w, SWING + 10, "attack")
		_expect(out, "only every %dth swing goes all the way round (swing %d)" % [Config.UPGRADES.spin.spin_every, i + 1], behind.hp < 99, i + 1 == Config.UPGRADES.spin.spin_every)
	# spark
	for at in [LIT, DARK]:
		w = _night(Vector2(0.0, 60.0), ["spark"])
		var e = Enemy.new("big_slime", Config.TORCH.pos + at)
		e.T = e.T.duplicate()
		e.T.speed = 0.0
		w.enemies.append(e)
		var told := _play(w, 60)
		_expect(out, "the torch shoots a spark only at an enemy in its light (%s)" % ("lit" if at == LIT else "dark"), [told.has("shot"), e.hp < e.T.hp], [at == LIT, at == LIT])
	# vampire
	w = _night(DARK, ["vampire"])
	w.player.hp = 3
	var healed := false
	for i in Config.UPGRADES.vampire.vamp_kills:
		_expect(out, "the vampire blade heals only on its %dth kill" % Config.UPGRADES.vampire.vamp_kills, w.player.hp, 3)
		var bat = _add(w, "bat", NEAR)
		bat.T = bat.T.duplicate()
		bat.T.speed = 0.0
		healed = _play(w, SWING + 10, "attack").has("healed")
	_expect(out, "the vampire blade heals after enough sword kills, and says so", [w.player.hp, healed], [4, true])
	# the kills it wants grow with the night: vamp_kills up to night vamp_from, vamp_grow times as many each night
	# after it; no rest
	var V: Dictionary = Config.UPGRADES.vampire
	_expect(out, "the vampire blade wants vamp_kills on the first night", w.vamp_need(), V.vamp_kills)
	w.night = V.vamp_from
	_expect(out, "and up to night vamp_from", w.vamp_need(), V.vamp_kills)
	w.night = 10
	var need: int = roundi(V.vamp_kills * pow(V.vamp_grow, 10 - V.vamp_from))
	_expect(out, "and vamp_grow times as many on each night after (night 10)", [w.vamp_need(), need > V.vamp_kills * 3], [need, true])
	w.night = 9
	_expect(out, "one night less wants fewer", w.vamp_need() < need, true)
	w.night = 10
	w.player.hp = 3
	w.blade_kills = 0
	w.time = 0.0 # each run of kills below fits in one night
	w.fuel = 1.0e6 # and the torch outlasts them all
	for i in need:
		_expect(out, "on night 10 it heals only on its %dth kill" % need, w.player.hp, 3)
		var bat = _add(w, "bat", NEAR)
		bat.T = bat.T.duplicate()
		bat.T.speed = 0.0
		_play(w, SWING + 10, "attack")
	_expect(out, "on night 10 it heals after %d sword kills" % need, w.player.hp, 4)
	w.time = 0.0
	for i in need: # straight after a heal: kills count at once, there is no rest
		var bat = _add(w, "bat", NEAR)
		bat.T = bat.T.duplicate()
		bat.T.speed = 0.0
		_play(w, SWING + 10, "attack")
	_expect(out, "right after a heal the next kills count at once (no rest)", w.player.hp, 5)
	w.player.hp = w.max_hp()
	w.blade_kills = 0
	w.time = 0.0
	for i in need + 3:
		var bat = _add(w, "bat", NEAR)
		bat.T = bat.T.duplicate()
		bat.T.speed = 0.0
		_play(w, SWING + 10, "attack")
	_expect(out, "kills at full health are kept for one heal, no more", w.blade_kills, need)
	w.night = 1
	w.picks = ["vampire", "vampire"]
	var second: int = World.upgrade("vampire", 2).vamp_kills
	_expect(out, "at level 2 it wants fewer kills, growing by the same share", [w.vamp_need(), second < V.vamp_kills], [second, true])
	w.night = 10
	_expect(out, "(level 2, night 10)", w.vamp_need(), roundi(second * pow(V.vamp_grow, 10 - V.vamp_from)))
	w.night = 1
	w.picks = []
	_expect(out, "without the blade it wants nothing", w.vamp_need(), 0)
	# big torch
	w = _night(DARK, ["big_torch"])
	w.fuel = Config.TORCH.max_fuel
	w.player.take_log()
	w.player.pos = Config.TORCH.pos
	_play(w, 1)
	_expect(out, "a big torch takes fuel past the usual full tank", w.fuel > Config.TORCH.max_fuel, true)
	return out


## An enemy that stays where it is put.
static func _still(e):
	e.T = e.T.duplicate()
	e.T.speed = 0.0
	e.T.heavy = 0.0
	return e


## What the upgrade rebalance asks of the ember ring, bright fire, thorn cloak and big torch.
static func _rebalanced() -> Array:
	var out := []
	var er: Dictionary = Config.UPGRADES.ember_ring
	# ember ring: scorches down to 1 hp, never kills, once every ember_every
	var w = _night(Vector2(0.0, 60.0), ["ember_ring"])
	var big = _still(Enemy.new("big_slime", Config.TORCH.pos + Vector2(20.0, 0.0)))
	var slime = _still(Enemy.new("slime", Config.TORCH.pos + Vector2(-20.0, 0.0)))
	w.enemies.append_array([big, slime])
	w.fuel = 1.0e6 # the big slime smothers the torch the whole time; keep it lit
	_play(w, 1)
	_expect(out, "the ember ring scorches what is beside the torch", [big.hp, slime.hp], [Config.ENEMY_TYPES.big_slime.hp - 1, 1])
	_play(w, int(er.ember_every / Config.STEP) - 2)
	_expect(out, "the ember ring waits ember_every before it scorches again", big.hp, Config.ENEMY_TYPES.big_slime.hp - 1)
	_play(w, int(10.0 / Config.STEP))
	_expect(out, "the ember ring never kills: the last point is left to you", [big.hp, slime.hp, big.dead or slime.dead, w.score, w.phase], [1, 1, false, 0, "night"])
	# ember ring: smotherers at the torch smother less
	for has in [false, true]:
		w = _night(DARK, ["ember_ring"] if has else [])
		w.next_ember = NEVER
		w.enemies.append(Enemy.new("slime", Config.TORCH.pos + Vector2(19.0, 0.0)))
		var before: float = w.fuel
		_play(w, 1)
		var want: float = (Config.NIGHTS[0].burn + Config.TORCH.smother * (er.smother_mult if has else 1.0)) * Config.STEP
		_expect(out, "a slime at the torch smothers less with the ember ring (%s)" % has, is_equal_approx(before - w.fuel, want), true)
	# bright fire: faster on foot in the light, the usual speed outside it
	for at in [LIT, DARK]:
		for has in [false, true]:
			w = _night(at, ["bright"] if has else [])
			var from: Vector2 = w.player.pos
			_play(w, 10, "", "up")
			var want: float = Config.PLAYER.speed * Config.STEP * 10.0 * (Config.UPGRADES.bright.lit_speed_mult if has and at == LIT else 1.0)
			_expect(out, "bright fire speeds you up only in the light (%s, %s)" % ["lit" if at == LIT else "dark", has], is_equal_approx(from.y - w.player.pos.y, want), true)
	# thorn cloak: an enemy pressed up against you, not touching, is pricked every thorn_every
	var th: Dictionary = Config.UPGRADES.thorns
	for has in [false, true]:
		w = _night(DARK, ["thorns"] if has else [])
		var gap: float = Config.ENEMY_TYPES.slime.radius + Config.PLAYER.radius + th.thorn_reach * 0.5
		slime = _still(_add(w, "slime", Vector2(gap, 0.0)))
		slime.hp = 99
		_play(w, 1)
		_expect(out, "the thorn cloak pricks an enemy close by without being hit (%s)" % has, [slime.hp, w.player.hp], [98 if has else 99, Config.PLAYER.hp])
		_play(w, int(th.thorn_every / Config.STEP) - 2)
		_expect(out, "the thorn cloak waits thorn_every before it pricks again (%s)" % has, slime.hp, 98 if has else 99)
		_play(w, 3)
		_expect(out, "the thorn cloak pricks again after thorn_every (%s)" % has, slime.hp, 97 if has else 99)
	w = _night(DARK, ["thorns"])
	slime = _still(_add(w, "slime", Vector2(Config.ENEMY_TYPES.slime.radius + Config.PLAYER.radius + th.thorn_reach + 2.0, 0.0)))
	_play(w, 1)
	_expect(out, "the thorn cloak does not reach an enemy farther off", slime.hp, Config.ENEMY_TYPES.slime.hp)
	# big torch: dawn tops it up in proportion to the tank
	for picks in [[], ["big_torch"], ["big_torch", "big_torch"]]:
		w = _night(DARK, picks)
		w.fuel = 1.0
		w.time = Config.NIGHT.length - Config.STEP * 0.5
		_play(w, 1)
		var want: float = Config.TORCH.start_fuel * w.max_fuel() / Config.TORCH.max_fuel
		_expect(out, "dawn tops the torch up to its share of the tank (big torch level %d)" % picks.size(), [is_equal_approx(w.fuel, want), w.fuel > Config.TORCH.start_fuel], [true, not picks.is_empty()])
	return out


## The dark is where bats hunt: out of the torch's light they fly faster, in it they keep their speed (and the warm
## glow still slows them there). A kind without dark_speed_mult, a slime, is the same speed in both.
static func _dark() -> Array:
	var out := []
	var steps := 10
	for kind in ["bat", "slime"]:
		var T: Dictionary = Config.ENEMY_TYPES[kind]
		for at in [LIT, DARK]:
			for glow in [false, true]:
				var w = _night(at, ["warm_glow"] if glow else [])
				# a bat starts beside the player, a slime where the player stands (and walks off to the torch)
				var e = _add(w, kind, Vector2(20.0, 0.0) if kind == "bat" else Vector2.ZERO)
				w.player.pos += Vector2(0.0, 40.0) if kind == "slime" else Vector2.ZERO
				var from: Vector2 = e.pos
				var lit: bool = at == LIT
				_expect(out, "the %s starts %s the light" % [kind, "in" if lit else "out of"], w.in_light(from), lit)
				_play(w, steps)
				var mult: float = (Config.UPGRADES.warm_glow.glow_slow if glow else 1.0) if lit else T.get("dark_speed_mult", 1.0)
				_expect(out, "a %s's speed %s the light (warm glow %s)" % [kind, "in" if lit else "out of", glow], snappedf(from.distance_to(e.pos), 0.001), snappedf(T.speed * mult * Config.STEP * steps, 0.001))
	_expect(out, "bats are faster in the dark", Config.ENEMY_TYPES.bat.get("dark_speed_mult", 1.0) > 1.0, true)
	return out


static func _bosses() -> Array:
	var out := []
	var every: int = Config.BOSS.every
	for night in [every - 1, every, every * 2]:
		var w = _night(DARK)
		w.night = night
		w.bosses_due = w._plan_bosses()
		w.time = Config.NIGHT.length * Config.BOSS.at - Config.STEP * 0.5
		var told := _play(w, 1)
		var bosses: Array = w.enemies.filter(func(e): return e.T.get("boss", false)).map(func(e): return e.kind)
		var want: Array = [] if night % every != 0 else [Config.BOSS.kinds[(night / every - 1) % Config.BOSS.kinds.size()]]
		_expect(out, "night %d brings its boss partway through, and says so" % night, [bosses, told.has("boss")], [want, not want.is_empty()])
	var w = _night(DARK)
	var king = _add(w, "slime_king", Vector2(60.0, 0.0))
	_play(w, int(Config.ENEMY_TYPES.slime_king.summon.every / Config.STEP) + 1)
	_expect(out, "a boss calls its kind every so often", w.enemies.filter(func(e): return e.kind == "slime").size(), Config.ENEMY_TYPES.slime_king.summon.count)
	w = _night(DARK)
	king = _add(w, "slime_king", Vector2(22.0, 0.0))
	king.T = king.T.duplicate()
	king.T.speed = 0.0
	_play(w, SWING + 10, "attack") # the whole swing, so the next press starts another
	_expect(out, "a heavy boss is barely knocked back", king.knock.length() < Config.ENEMY.knock * 0.5, true)
	king.hp = 1
	w.score = 0
	_play(w, SWING + 20, "attack")
	_expect(out, "the slime king breaks into two big slimes and scores its own worth", [w.enemies.filter(func(e): return e.kind == "big_slime").size(), w.score], [2, Config.ENEMY_TYPES.slime_king.score])
	return out


## Boss patterns, each warned before it strikes. The slime king marks where you stand, crouches, flies, and hurts you
## on landing only if you stayed in the shock; it does not leap at you from far off. The shade lord circles outside the
## light, where blows pass through it, rushes the torch after warning, can be cut there, and goes back out. And a
## boss's coming is told BOSS.warn seconds ahead, from the edge where it then comes.
static func _patterns() -> Array:
	var out := []
	var K: Dictionary = Config.ENEMY_TYPES.slime_king
	var L: Dictionary = K.leap
	var airborne := int(round((L.warn + L.air) / Config.STEP))
	for flee in [false, true]:
		var w = _night(DARK + Vector2(0.0, 40.0))
		w.fuel = 1.0e6
		var king = _add(w, "slime_king", Vector2(-L.range * 0.6, 0.0))
		king.move_t = 0.0
		var mark: Vector2 = w.player.pos
		var told := _play(w, 1)
		_expect(out, "the slime king marks where you stand and says so (flee %s)" % flee, [king.move, king.move_to, told.has("warn")], ["warn", mark, true])
		var took_off: Vector2 = king.pos
		_play(w, airborne - 2, "", "up" if flee else "")
		_expect(out, "the slime king is still up and has hurt no one just before it lands (flee %s)" % flee, [king.move, w.player.hp], ["air", Config.PLAYER.hp])
		_expect(out, "the slime king does not touch you while in the air (flee %s)" % flee, king.touches(w.player), false)
		told = _play(w, 3, "", "up" if flee else "")
		_expect(out, "the slime king lands on the mark and says so (flee %s)" % flee, [king.move, king.pos, told.has("landed"), king.pos != took_off], ["", mark, true, true])
		_expect(out, "the landing hurts you only if you stayed in the shock (flee %s)" % flee, w.player.hp, Config.PLAYER.hp - (0 if flee else 1))
		_expect(out, "fleeing gets you out of the shock in time", (not flee) or w.player.pos.distance_to(mark) > L.shock + Config.PLAYER.radius, true)
		told = _play(w, int(L.every / Config.STEP) - 5)
		_expect(out, "the slime king waits leap.every before it leaps again (flee %s)" % flee, told.has("warn"), false)
	var w = _night(DARK + Vector2(0.0, 40.0))
	var king = _add(w, "slime_king", Vector2(-(L.range + 20.0), 0.0))
	king.move_t = 0.0
	_play(w, 10)
	_expect(out, "the slime king does not leap at you from out of range", king.move, "")
	# guarding the torch: the king's mark is pushed out so it never lands on the torch
	var keep: float = Config.TORCH.reach + K.radius + L.torch_gap
	for guard in [Vector2(0.0, 10.0), Vector2.ZERO]:
		w = _night(guard)
		w.fuel = 1.0e6
		king = _add(w, "slime_king", Vector2(-80.0, 0.0) - guard)
		king.move_t = 0.0
		_play(w, 1)
		_expect(out, "a king leaping at a player by the torch marks a spot torch_gap past smothering (guard %s)" % guard, snappedf(king.move_to.distance_to(Config.TORCH.pos), 0.01), snappedf(keep, 0.01))
		_play(w, airborne + 2)
		_expect(out, "the king lands off the torch, not smothering it (guard %s)" % guard, [king.move, king.at_torch], ["", false])
	w = _night(Vector2(0.0, keep + 30.0))
	w.fuel = 1.0e6
	king = _add(w, "slime_king", Vector2(-60.0, 0.0))
	king.move_t = 0.0
	var mark_far: Vector2 = w.player.pos
	_play(w, 1)
	_expect(out, "away from the torch the king still marks exactly where you stand", king.move_to, mark_far)
	_expect(out, "a slime king at the torch smothers less than two slimes (it cannot end the night in seconds)", K.smother < 2.0 * Config.ENEMY_TYPES.slime.get("smother", 1.0), true)
	# shade lord: circles in the dark, blows pass through it there
	var SL: Dictionary = Config.ENEMY_TYPES.shade_lord
	var R: Dictionary = SL.lunge
	w = _night(Vector2(0.0, 40.0))
	w.fuel = 50.0
	var lord = Enemy.new("shade_lord", Config.TORCH.pos + Vector2(150.0, 0.0))
	w.enemies.append(lord)
	lord.summon_t = NEVER
	lord.split_t = NEVER # this scene is about the rush; _split is about the decoys
	lord.move_t = R.every
	var lit_steps := 0
	var start_angle: float = (lord.pos - Config.TORCH.pos).angle()
	var told := []
	for i in int((R.every - 0.5) / Config.STEP):
		told += _play(w, 1)
		lit_steps += 1 if w.in_light(lord.pos) else 0
	var ring: float = w.light_radius() + R.ring + SL.radius
	_expect(out, "the shade lord keeps out of the light while it circles", [lit_steps, lord.at_torch, told.has("warn")], [0, false, false])
	_expect(out, "the shade lord circles the light at its ring", absf(lord.pos.distance_to(Config.TORCH.pos) - ring) < 3.0, true)
	_expect(out, "the shade lord goes round the torch", absf(angle_difference(start_angle, (lord.pos - Config.TORCH.pos).angle())) > 0.5, true)
	lord.hp = SL.hp
	_damage_once(w, lord)
	_expect(out, "blows pass through the shade lord while it circles in the dark", lord.hp, SL.hp)
	# it warns, stops, then rushes the torch
	var told2 := _play(w, int(0.5 / Config.STEP) + 2)
	var at_warn: Vector2 = lord.pos
	_expect(out, "the shade lord warns before it rushes, at the torch", [told2.has("warn"), lord.move, lord.move_to], [true, "warn", Config.TORCH.pos])
	_play(w, int(R.warn / Config.STEP) - 3)
	_expect(out, "the shade lord stands still while it warns", [lord.move, lord.pos.distance_to(at_warn) < 0.01], ["warn", true])
	_play(w, int(ring / R.speed / Config.STEP) + 10)
	_expect(out, "the shade lord rushes to the torch and stays there smothering it, in the light", [lord.move, lord.at_torch, w.in_light(lord.pos)], ["stay", true, true])
	_damage_once(w, lord)
	_expect(out, "at the torch the shade lord can be cut", lord.hp, SL.hp - 1)
	_play(w, int(R.stay / Config.STEP) + int(3.0 / Config.STEP))
	_expect(out, "after staying a while the shade lord goes back out into the dark", [lord.move, lord.at_torch, w.in_light(lord.pos)], ["", false, false])
	# a boss's coming is told ahead, from the edge it comes from
	w = _night(DARK)
	w.night = Config.BOSS.every
	w.bosses_due = w._plan_bosses()
	w.time = Config.NIGHT.length * Config.BOSS.at - Config.BOSS.warn - Config.STEP * 0.5
	told = []
	var coming_at = null
	for i in 1:
		w.step(InputFrame.new())
		for ev in w.events:
			told.append(ev.kind)
			if ev.kind == "boss_coming":
				coming_at = ev.pos
	_expect(out, "a boss's coming is told BOSS.warn seconds ahead, before it comes", [told.has("boss_coming"), told.has("boss"), w.bosses_coming().map(func(b): return b.from) == [coming_at] and coming_at != null], [true, false, true])
	told = _play(w, int(Config.BOSS.warn / Config.STEP) - 2)
	_expect(out, "the boss does not come during its warning", told.has("boss"), false)
	told = _play(w, 3)
	var bosses: Array = w.enemies.filter(func(e): return e.T.get("boss", false))
	_expect(out, "the boss comes where its coming pointed", [told.has("boss"), bosses.size(), bosses.size() > 0 and coming_at != null and bosses[0].pos.distance_to(coming_at) < 2.0, w.bosses_due], [true, 1, true, []])
	return out


## Bosses come every BOSS.every nights, more of them later (BOSS.counts), the kinds taking turns night to night and
## mixed on a night with several. Each comes BOSS.apart after the one before, each with its own warning from its own
## edge. The first boss nights' bosses are gentler (BOSS.strength: hp and summons) and later ones stronger, but a kill
## is worth its row's score all the same. The screen stacks a bar for each boss on the field, and not for decoys.
static func _boss_nights() -> Array:
	var out := []
	var every: int = Config.BOSS.every
	var kinds: Array = Config.BOSS.kinds
	for night in range(1, 25):
		var w = _night(DARK)
		w.night = night
		var want := 0
		if night % every == 0:
			for r in Config.BOSS.counts:
				if night >= r.from:
					want = r.count
		var got: Array = w.boss_kinds()
		_expect(out, "night %d brings %d bosses" % [night, want], got.size(), want)
		if want > 0:
			_expect(out, "night %d's first boss takes its turn" % night, got[0], kinds[(night / every - 1) % kinds.size()])
		if want > 1:
			_expect(out, "night %d's bosses are of mixed kinds" % night, kinds.all(func(k): return got.has(k)), true)
	_expect(out, "bosses come every third night, one at first, two from night 12, three from night 21", [Config.BOSS.every, Config.BOSS.counts.map(func(r): return [r.from, r.count])], [3, [[3, 1], [12, 2], [21, 3]]])
	# a night with several: each warned and coming in turn, apart
	var w = _night(DARK)
	w.night = 12
	w.player.hp = 1000
	w.fuel = 1.0e6
	w.bosses_due = w._plan_bosses()
	var at: float = Config.NIGHT.length * Config.BOSS.at
	w.time = at - Config.BOSS.warn - 1.0
	var seen := [] # [kind of event, enemy, night time, pos]
	for i in int((Config.BOSS.warn + Config.BOSS.apart + 2.0) / Config.STEP):
		w.step(InputFrame.new())
		for ev in w.events:
			if ev.kind in ["boss_coming", "boss"]:
				seen.append([ev.kind, ev.enemy, snappedf(w.time, 0.1), ev.pos])
	var a: Array = w.boss_kinds() + ["", ""] # (the count is checked above: past it, this scene fails, not errors)
	_expect(out, "two bosses are each warned BOSS.warn ahead and come BOSS.apart apart, in turn", seen.map(func(x): return [x[0], x[1], x[2]]),
		[["boss_coming", a[0], snappedf(at - Config.BOSS.warn, 0.1)], ["boss", a[0], snappedf(at, 0.1)],
		["boss_coming", a[1], snappedf(at + Config.BOSS.apart - Config.BOSS.warn, 0.1)], ["boss", a[1], snappedf(at + Config.BOSS.apart, 0.1)]])
	if seen.size() == 4:
		_expect(out, "each boss comes where its own warning pointed", [seen[1][3] == seen[0][3], seen[3][3] == seen[2][3]], [true, true])
	var list: Array = Painter.bosses(w)
	_expect(out, "the screen has a bar for each boss on the field", list.size(), 2)
	var b0: Rect2 = Painter.boss_bar(0)
	var b1: Rect2 = Painter.boss_bar(1)
	_expect(out, "the second boss's bar stacks over the first, their panels apart", [b1.position.y < b0.position.y, not b1.grow(2.0).intersects(b0.grow(2.0))], [true, true])
	# strength: gentle at first, stronger later; the score stays the row's
	var K: Dictionary = Config.ENEMY_TYPES.slime_king
	var S: Dictionary = Config.BOSS.strength
	var hp_on := {}
	for night in [every, every * 5]:
		w = _night(DARK)
		w.night = night
		var king = w._boss("slime_king", w.player.pos + Vector2(60.0, 0.0))
		hp_on[night] = [king.full_hp, king.hp, king.summons, king.splits]
	_expect(out, "the first boss night's king is gentle: hp, summons and what it breaks into multiplied by strength.first", hp_on[every], [ceili(K.hp * S.first), ceili(K.hp * S.first), maxi(1, roundi(K.summon.count * S.first)), maxi(1, roundi(K.split_count * S.first))])
	_expect(out, "a later boss night's king is stronger", hp_on[every * 5][0] > hp_on[every][0], true)
	w = _night(DARK)
	w.night = every * 30
	_expect(out, "boss strength stops at strength.most", w.boss_strength(), S.most)
	w = _night(DARK)
	w.night = every
	var king = w._boss("slime_king", w.player.pos + Vector2(22.0, 0.0))
	w.enemies.append(king)
	king.summon_t = NEVER
	king.hp = 1
	w.score = 0
	_play(w, SWING + 20, "attack")
	_expect(out, "a gentle king still scores its row's worth, and breaks into as many as it was made to", [king.dead, w.score, w.enemies.filter(func(e): return e.kind == K.splits_into).size()], [true, K.score, maxi(1, roundi(K.split_count * S.first))])
	return out


## The slime king's run of hops: every leap.hops.each-th leap is hops.count short hops instead, each marked and warned
## before it lands (hops.warn), at most hops.reach toward where you stand then, hurting you only if you stayed in its
## smaller shock. You can flee them all; standing still, one lands on you. Then it walks and waits leap.every.
static func _hops() -> Array:
	var out := []
	var L: Dictionary = Config.ENEMY_TYPES.slime_king.leap
	var H: Dictionary = L.hops
	var one := int(round((H.warn + H.air) / Config.STEP))
	for flee in [false, true]:
		var w = _night(Vector2.ZERO)
		w.fuel = 1.0e6
		w.player.pos = Vector2(330.0, 40.0)
		var king = _add(w, "slime_king", Vector2(-80.0, 0.0))
		king.summon_t = NEVER
		king.move_t = 0.0
		king.leaps = H.each - 1
		var told := []
		var marks := []
		var lands := []
		for i in (one + 2) * H.count + 3:
			var f := InputFrame.new()
			if flee:
				f.held["down"] = true
			var from: Vector2 = king.pos
			w.step(f)
			for ev in w.events:
				told.append(ev.kind)
				if ev.kind == "warn":
					marks.append([i, ev.at, from])
				if ev.kind == "landed":
					lands.append([i, ev.pos])
		_expect(out, "the king hops hops.count times, each warned before it lands (flee %s)" % flee, [told.count("warn"), told.count("landed")], [H.count, H.count])
		var apart := true
		var near := true
		for j in mini(marks.size(), lands.size()):
			apart = apart and absi(lands[j][0] - marks[j][0] - one) <= 2 and lands[j][1] == marks[j][1]
			near = near and marks[j][1].distance_to(marks[j][2]) <= H.reach + 0.01
		_expect(out, "each hop lands on its mark hops.warn + hops.air after it was marked (flee %s)" % flee, apart, true)
		_expect(out, "each hop goes at most hops.reach (flee %s)" % flee, near, true)
		_expect(out, "standing still a hop lands on you; fleeing, none does (flee %s)" % flee, w.player.hp, Config.PLAYER.hp - (0 if flee else 1))
		_expect(out, "after its hops the king walks again (flee %s)" % flee, [king.move, king.hops_left], ["", 0])
		told = _play(w, int(L.every / Config.STEP) - 5)
		_expect(out, "after its hops the king waits leap.every (flee %s)" % flee, told.has("warn"), false)
	# every each-th leap: the leap before is a single one, and the one after
	var w = _night(Vector2(0.0, 60.0))
	w.fuel = 1.0e6
	var king = _add(w, "slime_king", Vector2(-60.0, 0.0))
	king.summon_t = NEVER
	var runs := []
	for n in H.each + 1:
		king.move_t = 0.0
		king.pos = w.player.pos + Vector2(-60.0, 0.0)
		w.player.invuln = 1.0e6
		var told := _play(w, (one + 2) * H.count + int(L.warn / Config.STEP) + int(L.air / Config.STEP) + 4)
		runs.append(told.count("landed"))
	var want := []
	for n in H.each + 1:
		want.append(H.count if (n + 1) % H.each == 0 else 1)
	_expect(out, "every leap.hops.each-th leap is a run of hops, the others single leaps", runs, want)
	return out


## The shade lord's split: circling, it stops and flickers for split.warn (told, nothing yet), then split.count decoys
## appear round its ring. A decoy hurts no one, smothers nothing, breaks at a blow in the light for no score (in the
## dark blows pass through it as through its lord), rushes the torch together with its lord and fades there, and fades
## after split.life or when its lord dies. The bot does not fight a decoy.
static func _split() -> Array:
	var out := []
	var SL: Dictionary = Config.ENEMY_TYPES.shade_lord
	var S: Dictionary = SL.split
	var w = _night(Vector2(0.0, 40.0))
	w.fuel = 50.0
	var lord = Enemy.new("shade_lord", Config.TORCH.pos + Vector2(110.0, 0.0))
	w.enemies.append(lord)
	lord.summon_t = NEVER
	lord.move_t = 100.0
	_expect(out, "the shade lord first splits split.first after it comes", lord.split_t, S.first)
	lord.split_t = Config.STEP * 0.5
	var told := _play(w, 1)
	var at: Vector2 = lord.pos
	_expect(out, "the shade lord flickers before it splits, and says so", [lord.move, told.has("warn"), w.enemies.size()], ["split", true, 1])
	told = _play(w, int(S.warn / Config.STEP) - 2)
	_expect(out, "it stands still and has no decoys while it flickers", [lord.move, lord.pos.distance_to(at) < 0.01, w.enemies.size(), told.has("decoy")], ["split", true, 1, false])
	told = _play(w, 3)
	var decoys: Array = w.enemies.filter(func(e): return e.decoy)
	_expect(out, "then split.count decoys appear round its ring, and it walks on", [decoys.size(), told.count("decoy"), lord.move, lord.split_t > S.warn], [S.count, S.count, "", true])
	var spread := true
	for d in decoys:
		spread = spread and absf(d.pos.distance_to(Config.TORCH.pos) - lord.pos.distance_to(Config.TORCH.pos)) < 3.0 and d.pos.distance_to(lord.pos) > SL.radius * 3.0
	_expect(out, "the decoys stand on its ring, away from it", spread, true)
	_expect(out, "the decoys rush when it does", decoys.map(func(d): return d.move_t), decoys.map(func(_d): return lord.move_t))
	_expect(out, "only the real one is a boss on the screen's bars", Painter.bosses(w), [lord])
	# a decoy hurts no one and smothers nothing
	var d = decoys[0]
	d.pos = w.player.pos
	var hp: int = w.player.hp
	_play(w, 2)
	_expect(out, "a decoy on the keeper hurts no one", w.player.hp, hp)
	d.pos = Config.TORCH.pos + Vector2(Config.TORCH.reach + SL.radius - 1.0, 0.0)
	var burn_before: float = w.burn_rate()
	told = _play(w, 1)
	_expect(out, "a decoy that reaches the torch fades there, smothering nothing", [d.gone, d.at_torch, told.has("faded"), w.burn_rate() <= burn_before], [true, false, true, true])
	# a blow: in the dark it passes, in the light it breaks the decoy for no score
	var e = decoys[1]
	e.pos = Config.TORCH.pos + DARK
	_damage_once(w, e)
	_expect(out, "in the dark a blow passes through a decoy", [e.gone, e.dead], [false, false])
	e.pos = Config.TORCH.pos + LIT
	w.score = 0
	w.events = []
	_damage_once(w, e)
	_expect(out, "in the light a blow breaks a decoy, for no score and no kill", [e.gone, e.dead, w.score, w.events.map(func(ev): return ev.kind)], [true, false, 0, ["faded"]])
	# they rush the torch together; and they fade with time or with their lord
	w = _night(Vector2(0.0, 40.0))
	w.fuel = 50.0
	lord = Enemy.new("shade_lord", Config.TORCH.pos + Vector2(110.0, 0.0))
	w.enemies.append(lord)
	lord.summon_t = NEVER
	lord.move_t = 3.0
	lord.split_t = 0.0
	_play(w, int(S.warn / Config.STEP) + 3)
	decoys = w.enemies.filter(func(x): return x.decoy)
	var together := true
	for i in int(6.5 / Config.STEP):
		_play(w, 1)
		together = together and decoys.all(func(x): return x.gone or x.move == lord.move or (lord.move == "stay"))
	_expect(out, "the decoys warn and rush the torch with their lord, and fade there", [together, decoys.all(func(x): return x.gone), lord.move], [true, true, "stay"])
	w = _night(Vector2(0.0, 40.0))
	lord = Enemy.new("shade_lord", Config.TORCH.pos + Vector2(110.0, 0.0))
	w.enemies.append(lord)
	lord.summon_t = NEVER
	lord.move_t = 1000.0
	lord.split_t = 0.0
	_play(w, int(S.warn / Config.STEP) + 3)
	_play(w, int(S.life / Config.STEP) - 10)
	_expect(out, "decoys last until split.life", w.enemies.filter(func(x): return x.decoy).size(), S.count)
	_play(w, 12)
	_expect(out, "then they fade", w.enemies.filter(func(x): return x.decoy).size(), 0)
	lord.split_t = 0.0
	_play(w, int(S.warn / Config.STEP) + 3)
	lord.dead = true
	_play(w, 1)
	_expect(out, "decoys fade when their lord dies", w.enemies.filter(func(x): return x.decoy and not x.gone).size(), 0)
	# the bot does not swing at a decoy beside it
	w = _night(LIT)
	lord = Enemy.new("shade_lord", Config.TORCH.pos + Vector2(-150.0, 0.0))
	lord.summon_t = NEVER
	lord.split_t = NEVER
	lord.move_t = 1000.0
	w.enemies.append(lord)
	d = Enemy.new("shade_lord", w.player.pos + NEAR)
	d.decoy = true
	d.lord = lord
	d.life_t = 100.0
	d.move_t = 1000.0
	w.enemies.append(d)
	var swung := false
	var bot = Bot.new(1)
	for i in 30:
		var f = bot.frame(w)
		swung = swung or f.is_pressed("attack")
		w.step(f)
	_expect(out, "the bot does not swing at a decoy", swung, false)
	return out


## The keeper hardens late (Config.HARDEN): three more hearts on night 10, one more on nights 12, 14 and 16, no more
## after; from night 10 dawn heals fully (and the night's new hearts come full), before it only DAWN.heal; and a hit
## keeps the next off longer night by night from night 10, up to invuln_most.
static func _harden() -> Array:
	var out := []
	var H: Dictionary = Config.HARDEN
	var w = _night(LIT)
	var hearts := []
	var shield := []
	for night in [9, 10, 11, 12, 16, 30]:
		w.night = night
		hearts.append(w.hardened_hp())
		shield.append(snappedf(w.keeper_invuln(), 0.001))
	_expect(out, "the keeper gains hearts on nights 10, 12, 14 and 16 (3, 1, 1, 1)", hearts, [0, 3, 3, 4, 6, 6])
	_expect(out, "the keeper's shield after a hit grows from night 10, up to invuln_most", shield,
		[Config.PLAYER.invuln, snappedf(Config.PLAYER.invuln + H.invuln_grow, 0.001), snappedf(Config.PLAYER.invuln + H.invuln_grow * 2, 0.001), snappedf(Config.PLAYER.invuln + H.invuln_grow * 3, 0.001), snappedf(minf(H.invuln_most, Config.PLAYER.invuln + H.invuln_grow * 7), 0.001), H.invuln_most])
	_expect(out, "the max hp counts the hearts", w.max_hp(), Config.PLAYER.hp + 6)
	for night in [8, 9, 11]:
		w = _night(LIT)
		w.night = night
		w.player.hp = 2
		w.time = Config.NIGHT.length - Config.STEP * 0.5
		_play(w, 1)
		var want: int = w.max_hp() if night + 1 >= H.from else 2 + Config.DAWN.heal
		_expect(out, "the dawn after night %d heals the keeper to %d" % [night, want], [w.night, w.player.hp], [night + 1, want])
	# the longer shield holds off a hit the usual one would let through
	w = _night(LIT)
	w.night = 11
	w.time = Config.NIGHT.length - Config.STEP * 0.5
	_play(w, 1) # dawn into night 12: tonight's shield is set
	w.offer = []
	w.phase = "night"
	w.next_spawn = NEVER
	var bat = _add(w, "bat", Vector2(4.0, 0.0))
	bat.T = bat.T.duplicate()
	bat.T.speed = 0.0
	var hp: int = w.player.hp
	_play(w, 1)
	_expect(out, "a hit on night 12 shields the keeper for keeper_invuln()", [w.player.hp, snappedf(w.player.invuln, 0.001)], [hp - 1, snappedf(w.keeper_invuln(), 0.001)])
	bat.pos = w.player.pos + Vector2(4.0, 0.0)
	_play(w, int((Config.PLAYER.invuln + 0.05) / Config.STEP))
	bat.pos = w.player.pos + Vector2(4.0, 0.0)
	_play(w, 1)
	_expect(out, "past the usual shield, the night's longer one still holds", w.player.hp, hp - 1)
	w = World.new(3)
	w.begin_at(12, 1)
	_expect(out, "a run begun at night 12 has its hearts full and its shield set", [w.player.hp, w.max_hp() >= Config.PLAYER.hp + 4, w.player.invuln_for], [w.max_hp(), true, w.keeper_invuln()])
	return out


## The boar lines up on you, paws the ground for charge.warn (hurting no one), then charges straight down the line it
## showed: it hurts you if you stayed in its lane and not if you stepped aside. Blows do not stop the charge; it ends
## after charge.dist or at the field's edge, and the boar stands dazed for charge.rest before it walks again and waits
## charge.every. It does not charge from out of range or from beyond the field.
static func _charger() -> Array:
	var out := []
	var B: Dictionary = Config.ENEMY_TYPES.boar
	var C: Dictionary = B.charge
	var warn_steps := int(round(C.warn / Config.STEP))
	var run_steps := int(round(C.dist / C.speed / Config.STEP))
	for dodge in [false, true]:
		var w = _night(DARK + Vector2(-20.0, 30.0))
		w.fuel = 1.0e6
		var boar = _add(w, "boar", Vector2(-60.0, 0.0))
		boar.move_t = 0.0
		var told := _play(w, 1)
		var from: Vector2 = boar.pos
		_expect(out, "the boar lines up on you and says so (dodge %s)" % dodge, [boar.move, boar.aim.is_equal_approx(Vector2.RIGHT), told.has("warn")], ["warn", true, true])
		_play(w, warn_steps - 2, "", "up" if dodge else "")
		_expect(out, "the boar stands pawing and has hurt no one before it charges (dodge %s)" % dodge, [boar.move, boar.pos.distance_to(from) < 0.01, w.player.hp], ["warn", true, Config.PLAYER.hp])
		_play(w, 2 + int(run_steps / 2.0), "", "up" if dodge else "")
		_expect(out, "the boar charges along the line it showed (dodge %s)" % dodge, [boar.move, absf(boar.pos.y - from.y) < 0.01, boar.pos.x - from.x > C.dist * 0.4], ["charge", true, true])
		_expect(out, "the charge hurts you only if you stayed in its lane (dodge %s)" % dodge, w.player.hp, Config.PLAYER.hp - (0 if dodge else 1))
		_play(w, run_steps - int(run_steps / 2.0) + 1)
		_expect(out, "the charge ends after charge.dist and the boar is dazed (dodge %s)" % dodge, [boar.move, absf(boar.pos.distance_to(from) - C.dist) < C.speed * Config.STEP * 1.5], ["rest", true])
		var dazed_at: Vector2 = boar.pos
		_play(w, int(C.rest / Config.STEP) - 2)
		_expect(out, "a dazed boar stands still (dodge %s)" % dodge, [boar.move, boar.pos.distance_to(dazed_at) < 0.01], ["rest", true])
		_play(w, 3)
		_expect(out, "after its daze the boar walks again (dodge %s)" % dodge, boar.move, "")
		told = _play(w, int(C.every / Config.STEP) - 5)
		_expect(out, "the boar waits charge.every before it charges again (dodge %s)" % dodge, told.has("warn"), false)
	# a blow does not stop a charge
	var w = _night(DARK + Vector2(-20.0, 30.0))
	var boar = _add(w, "boar", Vector2(-60.0, 0.0))
	boar.move_t = 0.0
	_play(w, warn_steps + 3)
	var before: Vector2 = boar.pos
	_damage_once(w, boar)
	_play(w, 1)
	_expect(out, "a blow hurts a charging boar but does not stop or turn it", [boar.hp, boar.move, (boar.pos - before).normalized().is_equal_approx(Vector2.RIGHT), boar.pos.distance_to(before) > C.speed * Config.STEP * 0.9], [B.hp - 1, "charge", true, true])
	# it stops at the edge of the field
	w = _night(Vector2(0.0, 0.0))
	w.player.pos = Vector2(Config.FIELD.end.x - 20.0, Config.TORCH.pos.y)
	boar = _add(w, "boar", Vector2(-60.0, 0.0))
	boar.move_t = 0.0
	_play(w, warn_steps + run_steps + 2)
	_expect(out, "a charge stops at the field's edge, and the boar is dazed there", [boar.move, Config.FIELD.grow(0.01).has_point(boar.pos), boar.pos.x > Config.FIELD.end.x - 1.0], ["rest", true, true])
	# not from out of range, nor from beyond the field
	w = _night(DARK)
	boar = _add(w, "boar", Vector2(-(C.range + 20.0), 0.0))
	boar.move_t = 0.0
	_play(w, 10)
	_expect(out, "the boar does not charge from out of range", boar.move, "")
	w = _night(Vector2(0.0, 0.0))
	w.player.pos = Vector2(Config.FIELD.position.x + 30.0, Config.TORCH.pos.y)
	boar = Enemy.new("boar", Vector2(Config.FIELD.position.x - Config.ENEMY.edge, Config.TORCH.pos.y))
	w.enemies.append(boar)
	boar.move_t = 0.0
	_play(w, 1)
	_expect(out, "the boar does not charge from beyond the field", boar.move, "")
	out.append_array(_charge_band())
	out.append_array(_fx_sizes())
	return out


## The red band the painter lays under a lined-up boar is where the charge hurts: a keeper standing just inside its
## edge (Enemy.lane_half() from the line, less a pixel) is hit, one just outside it is not; the painter's band holds
## the first point and not the second; and the band ends where the charge does, at the field's edge too.
static func _charge_band() -> Array:
	var out := []
	var C: Dictionary = Config.ENEMY_TYPES.boar.charge
	var warn_steps := int(round(C.warn / Config.STEP))
	var run_steps := int(round(C.dist / C.speed / Config.STEP))
	for inside in [true, false]:
		var w = _night(DARK + Vector2(-20.0, 30.0))
		w.fuel = 1.0e6
		var boar = _add(w, "boar", Vector2(-60.0, 0.0))
		boar.move_t = 0.0
		_play(w, 1)
		var half: float = boar.lane_half()
		var spot: Vector2 = boar.pos + boar.aim * 60.0 + boar.aim.orthogonal() * (half + (-1.0 if inside else 1.0))
		w.player.pos = spot
		var drawn: bool = Geometry2D.is_point_in_polygon(spot, Painter.charge_band(boar))
		_expect(out, "the painter's band holds a point a pixel %s its edge" % ("inside" if inside else "outside"), drawn, inside)
		var end: Vector2 = boar.charge_end()
		_play(w, warn_steps + run_steps + 2)
		_expect(out, "the band ends where the charge does (%s)" % ("hit" if inside else "missed"), [boar.move, boar.pos.distance_to(end) < C.speed * Config.STEP * 1.5], ["rest", true])
		_expect(out, "the charge hurts a keeper a pixel %s the band's edge" % ("inside" if inside else "outside"), w.player.hp, Config.PLAYER.hp - (1 if inside else 0))
	_expect(out, "the band is as wide as the charge hurts: the boar's body and the keeper's", Enemy.new("boar", Vector2.ZERO).lane_half(), Config.ENEMY_TYPES.boar.radius + Config.PLAYER.radius)
	# at the field's edge the band ends where the boar stops
	var w = _night(Vector2(0.0, 0.0))
	w.player.pos = Vector2(Config.FIELD.end.x - 20.0, Config.TORCH.pos.y + 7.0)
	var boar = _add(w, "boar", Vector2(-60.0, -7.0))
	boar.move_t = 0.0
	_play(w, 1)
	var end: Vector2 = boar.charge_end()
	w.player.pos = Vector2(Config.FIELD.end.x - 20.0, Config.FIELD.position.y + 2.0) # out of the way
	_play(w, warn_steps + run_steps + 2)
	_expect(out, "the band ends where a charge into the trees stops", [boar.move, boar.pos.distance_to(end) < C.speed * Config.STEP * 1.5, end.x <= Config.FIELD.end.x + 0.01], ["rest", true, true])
	return out


## One blow of 1 on e from beside it, by the torch's own world rules (_damage), without a swing.
static func _damage_once(w, e) -> void:
	w._damage(e, 1, e.pos + Vector2(4.0, 0.0))


static func _logs() -> Array:
	var out := []
	var w = _night(DARK)
	w.player.take_log()
	_play(w, 1, "attack")
	_expect(out, "the attack key puts a carried log down", [w.player.carrying, w.logs.size()], [false, 1])
	_play(w, SWING)
	_expect(out, "a log just put down stays down while you stand on it", w.player.carrying, false)
	_play(w, 1, "attack")
	_expect(out, "with the log down, the attack key swings", w.player.attack_t >= 0.0, true)
	_play(w, 30, "", "right")
	_play(w, 30, "", "left")
	_expect(out, "walking off the log and back onto it picks it up", [w.player.carrying, w.logs.size()], [true, 0])
	return out


static func _nights() -> Array:
	var out := []
	var w = _night(DARK)
	_add(w, "slime", Vector2(40.0, 0.0))
	var thief = _add(w, "thief", Vector2(60.0, 0.0))
	thief.carrying = true
	w.player.hp = 3
	w.fuel = 20.0
	w.time = Config.NIGHT.length - Config.STEP * 0.5
	var told := _play(w, 1)
	_expect(out, "dawn starts the next night", [w.night, w.time], [2, 0.0])
	_expect(out, "the next night begins with the torch's offer", [w.phase, w.offer.size()], ["pick", Config.NIGHT.offer_size])
	_expect(out, "dawn clears the field, and a thief's log is left behind", [w.enemies.size(), w.logs.size()], [0, 1])
	_expect(out, "dawn heals and tops the torch up", [w.player.hp, w.fuel], [3 + Config.DAWN.heal, Config.TORCH.start_fuel])
	_expect(out, "dawn scores and is told", [w.score, told.has("dawn"), told.has("banished")], [Config.SCORE.dawn, true, true])
	for night in [1, Config.NIGHTS.size(), Config.NIGHTS.size() + 3]:
		w = _night(DARK)
		w.night = night
		var came := {}
		for i in 300:
			w.enemies = []
			w.next_spawn = 0.0
			_play(w, 1)
			for e in w.enemies:
				came[e.kind] = true
		var kinds: Array = came.keys()
		kinds.sort()
		var named: Array = Config.NIGHTS[mini(night, Config.NIGHTS.size()) - 1].who.keys()
		named.sort()
		_expect(out, "night %d brings exactly the kinds its row names" % night, kinds, named)
	w = _night(DARK)
	var first: float = w.burn()
	w.night = Config.NIGHTS.size() + 2
	_expect(out, "the torch burns faster on nights past the table", is_equal_approx(w.burn(), Config.NIGHTS[-1].burn + 2.0 * Config.LATER_NIGHTS.burn) and w.burn() > first, true)
	for night in [1, Config.NIGHTS.size() + 2]:
		w = _night(DARK)
		w.night = night
		w.next_wood = 0.0
		_play(w, 1)
		var gap: float = Config.WOOD.every * minf(1.0, Config.WOOD.pace / w.burn())
		_expect(out, "night %d: logs come every WOOD.every, more often as the fire burns past WOOD.pace" % night, snappedf(w.next_wood - w.time, 0.001), snappedf(gap, 0.001))
		_expect(out, "night %d: the logs keep up with the fire (a full night's logs hold a night's burn)" % night, Config.NIGHT.length / gap * Config.TORCH.log_fuel >= w.burn() * Config.NIGHT.length * 1.5, true)
	return out


## NIGHTS with: on a night whose row says a kind comes with others, each of that kind comes out of the dark with
## them, beside it on the same edge (a thief with the shade that guards it, a boar with bats at its side). Kinds the
## row does not name in with, and every kind on a night without it, come alone.
static func _company() -> Array:
	var out := []
	var seen := {} # night -> kinds that came with company
	for night in range(1, Config.NIGHTS.size() + 2):
		var company: Dictionary = Config.NIGHTS[mini(night, Config.NIGHTS.size()) - 1].get("with", {})
		var w = _night(DARK)
		w.night = night
		for i in 200:
			w.enemies = []
			w.next_spawn = 0.0
			_play(w, 1)
			var lead = w.enemies[0]
			var want: Array = [lead.kind] + company.get(lead.kind, [])
			var came: Array = w.enemies.map(func(e): return e.kind)
			if came != want:
				_expect(out, "night %d: a %s comes with exactly what the row says" % [night, lead.kind], came, want)
				break
			if want.size() > 1:
				seen[night] = seen.get(night, {})
				seen[night][lead.kind] = true
			for k in range(1, w.enemies.size()):
				var off: Vector2 = w.enemies[k].pos - lead.pos
				var gap: float = Config.ENEMY.with_gap * (int((k - 1) / 2) + 1)
				_expect(out, "night %d: the %s with a %s comes beside it, out of the dark" % [night, w.enemies[k].kind, lead.kind],
					[absf(off.length() - gap) < 3.0, Config.FIELD.has_point(w.enemies[k].pos)], [true, false])
			if w.enemies.size() > 2:
				_expect(out, "night %d: the company of a %s comes on both sides of it" % [night, lead.kind],
					(w.enemies[1].pos - lead.pos).dot(w.enemies[2].pos - lead.pos) < 0.0, true)
		for kind in company:
			_expect(out, "night %d: a %s came with company at least once in 200 spawns" % [night, kind], seen.get(night, {}).has(kind), true)
	_expect(out, "some night brings company (NIGHTS with)", seen.is_empty(), false)
	return out


## The keys an omen may set, and for each the number on the world it bends: what _omen_measure() reads.
const OMEN_KEYS := ["light_mult", "burn_mult", "wood_mult", "berry_mult", "gap_mult", "log_mult", "kinds"]
## What each omen's text says, written out from the Korean: per key, 1 when it says more of that number, -1 when less
## (light_mult: the light's radius; burn_mult: fuel a second; wood_mult, berry_mult, gap_mult: seconds between logs,
## berries, enemies; log_mult: fuel a log gives); under kinds, 1 for a kind it says more of come.
const OMEN_SAYS := {
	"fog": { "light_mult": -1, "kinds": { "bat": 1 } },
	"wind": { "burn_mult": 1, "wood_mult": -1 },
	"still": { "gap_mult": 1, "berry_mult": 1 },
	"harvest": { "log_mult": 1, "kinds": { "thief": 1 } },
	"dew": { "log_mult": -1, "berry_mult": -1 },
	"dark_moon": { "light_mult": -1, "kinds": { "shade": 1 } },
}
const OMEN_NIGHT := 5 # a night whose row has every kind an omen names, and no company
const OMEN_SPAWNS := 3000


## A night under way as _night() makes it, on night n under omen id ("" for none).
static func _omen_night(id: String, upgrades: Array = [], who := "knight", n := OMEN_NIGHT):
	var w = _night(DARK, upgrades, who)
	w.night = n
	w.omen = id
	return w


## The number on the world that an omen's key bends, read off the rules as they run.
static func _omen_measure(w, key: String) -> float:
	match key:
		"light_mult":
			w.fuel = 60.0
			return w.light_radius()
		"burn_mult":
			return w.burn_rate()
		"wood_mult":
			w.next_wood = 0.0
			_play(w, 1)
			return w.next_wood - w.time
		"berry_mult":
			w.next_berry = 0.0
			_play(w, 1)
			return w.next_berry - w.time
		"gap_mult":
			w.next_spawn = 0.0
			_play(w, 1)
			return w.next_spawn - w.time
		"log_mult":
			w.fuel = 10.0
			w.player.take_log()
			w.player.pos = Config.TORCH.pos + Vector2(0.0, Config.TORCH.reach)
			var burnt: float = w.burn_rate() * Config.STEP
			_play(w, 1)
			return w.fuel - 10.0 + burnt
	return NAN


## How many of each kind lead out of the dark over OMEN_SPAWNS spawns of the night w is in, as shares of them.
static func _lead_shares(w) -> Dictionary:
	var came := {}
	for i in OMEN_SPAWNS:
		w.enemies = []
		w.time = 1.0
		w.fuel = w.max_fuel()
		w.next_spawn = 0.0
		_play(w, 1)
		came[w.enemies[0].kind] = came.get(w.enemies[0].kind, 0.0) + 1.0 / OMEN_SPAWNS
	return came


## Config.OMENS: tonight's omen bends the numbers its row names, by what the row says, and nothing else; with
## upgrades that bend the same number the two multiply. Each does what its text says (OMEN_SAYS): the light is
## narrower, the fire burns faster, logs or berries or enemies come sooner or later, a log gives more or less, more
## of a kind come. Measured on the world as its rules run, against the same night without an omen.
static func _omens() -> Array:
	var out := []
	var builds := [[[], "knight"], [["bright", "slow_burn", "woodpile", "big_logs"], "woodcutter"]]
	var plain: Dictionary = _lead_shares(_omen_night(""))
	for id in Config.OMENS:
		var row: Dictionary = Config.OMENS[id]
		var says: Dictionary = OMEN_SAYS.get(id, {})
		for key in OMEN_KEYS:
			if key == "kinds":
				continue
			for b in builds:
				var with: float = _omen_measure(_omen_night(id, b[0], b[1]), key)
				var without: float = _omen_measure(_omen_night("", b[0], b[1]), key)
				_expect(out, "omen %s: %s is multiplied by what its row says, for a %s with %d upgrades" % [id, key, b[1], b[0].size()],
					snappedf(with / without, 0.0001), snappedf(row.get(key, 1.0), 0.0001))
			if says.has(key) or row.has(key):
				_expect(out, "omen %s: its text and its row agree which way %s goes" % [id, key], signf(row.get(key, 1.0) - 1.0), float(says.get(key, 0)))
		var bent: Dictionary = _lead_shares(_omen_night(id)) if row.has("kinds") else plain
		var shares: Dictionary = Config.NIGHTS[OMEN_NIGHT - 1].who
		var total := 0.0
		for kind in shares:
			total += shares[kind] * row.get("kinds", {}).get(kind, 1.0)
		for kind in shares:
			var want: float = shares[kind] * row.get("kinds", {}).get(kind, 1.0) / total
			if absf(bent.get(kind, 0.0) - want) > 0.03:
				out.append("omen %s: over %d spawns %s is %.3f of those that come, want %.3f" % [id, OMEN_SPAWNS, kind, bent.get(kind, 0.0), want])
		for kind in says.get("kinds", {}):
			_expect(out, "omen %s: more %s come than on a night without it" % [id, kind], bent.get(kind, 0.0) > plain.get(kind, 0.0) + 0.05, true)
		_expect(out, "omen %s: its text and its row name the same kinds" % id, says.get("kinds", {}).keys(), row.get("kinds", {}).keys())
		var night = _omen_night(id)
		night._plan_night()
		_expect(out, "omen %s: the night's first berry waits as its later ones do" % id, snappedf(night.next_berry, 0.0001), snappedf(Config.BERRY.first * row.get("berry_mult", 1.0), 0.0001))
	var w = _omen_night("", ["bright"])
	w.fuel = 60.0
	var lit: float = w.light_radius()
	w.omen = "fog"
	_expect(out, "the light narrows the moment the omen changes, the fuel being the same", snappedf(w.light_radius() / lit, 0.0001), snappedf(Config.OMENS.fog.light_mult, 0.0001))
	w.omen = ""
	_expect(out, "and widens again when it is gone", w.light_radius(), lit)
	return out


## Brings w to its next dusk as a kept night does: the dawn's own step, with nothing on the field.
static func _to_dusk(w) -> void:
	if w.phase == "pick":
		w._take(w.offer[0])
	w.enemies = []
	w.next_spawn = NEVER
	w.surges_due = []
	w.bosses_due = []
	w.player.hp = w.max_hp()
	w.fuel = w.max_fuel()
	w.picks_done = Config.NIGHT.picks_at.size()
	w.time = Config.NIGHT.length - Config.STEP * 0.5
	_play(w, 1)


## The omen is drawn at each dusk from Config.OMEN.from: none before it, and nothing drawn from the rng there (the
## first dusk leaves the rng where the offer alone leaves it); from then on every night has one, never last night's,
## never one before its own from or that names a kind the night's row lacks, and over many seeds every omen turns up.
static func _omen_rolls() -> Array:
	var out := []
	var seen := {}
	var from: int = Config.OMEN.from
	for seed_value in range(1, 41):
		var w = World.new(seed_value)
		var r = SimRng.new(seed_value)
		var pool: Array = Config.UPGRADES.keys().filter(func(id): return World.offered_on(id, 1))
		for i in Config.NIGHT.offer_size:
			pool.pop_at(r.index(pool.size()))
		_expect(out, "seed %d: the first dusk draws the offer from the rng and nothing else" % seed_value, w.rng.state(), r.state())
		var last := ""
		for night in range(1, 15):
			_expect(out, "seed %d: this is night %d" % [seed_value, night], w.night, night)
			var problem := ""
			if night < from and (w.omen != "" or not w.surges_due.is_empty() or w.surge_slow != 1.0):
				problem = "has an omen or a surge before OMEN.from"
			elif night >= from and not Config.OMENS.has(w.omen):
				problem = "has no omen"
			elif night >= from and w.omen == last:
				problem = "has last night's omen again"
			elif night >= from and not Config.OMENS[w.omen].get("kinds", {}).keys().all(func(k): return w._night_row().who.has(k)):
				problem = "has an omen about a kind its row lacks"
			elif night >= from and night < Config.OMENS[w.omen].get("from", 0):
				problem = "has an omen before that omen's own from"
			if problem != "":
				out.append("seed %d: night %d %s (%s after %s)" % [seed_value, night, problem, w.omen, last])
			seen[w.omen] = seen.get(w.omen, 0) + 1
			last = w.omen
			_to_dusk(w)
	for id in Config.OMENS:
		_expect(out, "omen %s turns up over 40 seeds of 14 nights" % id, seen.get(id, 0) >= 20, true)
	var w = World.new(3)
	_expect(out, "the first night's enemies come as its row says, further apart for nothing", [w.spawn_gap(), w.who()], [Config.NIGHTS[0].spawn[0], Config.NIGHTS[0].who])
	return out


## A world at the dusk of night n as a run of that seed reaches it, every night before it kept.
static func _dusk_at(seed_value: int, n: int):
	var w = World.new(seed_value)
	while w.night < n:
		_to_dusk(w)
	return w


## Config.SURGE: from the night from, packs come besides the trickle: as many as packs says, each of one kind that
## may come in packs and that tonight brings, one in each part of the night. Each is warned of warn seconds before,
## from an edge, and comes there: all of one kind and one tier, in a row along that edge, ENEMY.with_gap apart, out
## of sight. The screen's line names the pack.
static func _surges() -> Array:
	var out := []
	var S: Dictionary = Config.SURGE
	var L: float = Config.NIGHT.length
	var kinds_seen := {}
	var tiers_seen := {}
	var packs_seen := 0
	for seed_value in range(1, 9):
		for night in [1, 2, 3, 5, 8, 12]:
			var w = _dusk_at(seed_value, night)
			var want := 0
			for r in S.packs:
				if night >= maxi(r.from, S.from):
					want = r.count
			var planned: Array = w.surges_due.duplicate(true)
			_expect(out, "seed %d: night %d plans as many packs as SURGE.packs says" % [seed_value, night], planned.size(), want)
			if planned.size() != want:
				continue
			var part: float = L * (S.at[1] - S.at[0]) / maxi(1, want)
			for i in planned.size():
				var s: Dictionary = planned[i]
				kinds_seen[s.kind] = true
				_expect(out, "seed %d night %d: pack %d is of a kind that comes in packs and that tonight brings, of two or more, not yet placed" % [seed_value, night, i],
					[S.kinds.has(s.kind), w.who().has(s.kind), s.size >= 2, s.from], [true, true, true, null])
				_expect(out, "seed %d night %d: pack %d comes in its own part of the night" % [seed_value, night, i],
					s.at >= L * S.at[0] + part * i and s.at < L * S.at[0] + part * (i + 1), true)
			if want > 0:
				_expect(out, "seed %d night %d: the trickle comes further apart for its packs" % [seed_value, night], w.surge_slow > 1.05, true)
			w._take(w.offer[0])
			w.bosses_due = []
			w.next_spawn = NEVER
			w.next_wood = NEVER
			w.next_berry = NEVER
			var told := []
			while w.time < L - 2.0 * Config.STEP:
				if w.phase == "pick":
					w._take(w.offer[0])
				w.player.hp = w.max_hp()
				w.fuel = w.max_fuel()
				w.enemies = []
				w.step(InputFrame.new())
				for ev in w.events:
					if ev.kind in ["pack_coming", "pack"]:
						told.append([ev.kind, ev.enemy, w.time, ev.pos, ev.count, w.enemies.duplicate(), w.surges_coming().map(func(c): return c.from)])
			_expect(out, "seed %d night %d: each pack is warned of, then comes" % [seed_value, night], told.map(func(t): return t[0]).count("pack_coming") == want and told.map(func(t): return t[0]).count("pack") == want, true)
			for i in planned.size():
				var s: Dictionary = planned[i]
				var warned: Array = told.filter(func(t): return t[0] == "pack_coming" and absf(t[2] - (s.at - S.warn)) < 2.0 * Config.STEP)
				var came: Array = told.filter(func(t): return t[0] == "pack" and absf(t[2] - s.at) < 2.0 * Config.STEP)
				if warned.size() != 1 or came.size() != 1:
					out.append("seed %d night %d: pack %d (due at %.2f) is warned of SURGE.warn before and comes on time: got %s" % [seed_value, night, i, s.at, told.map(func(t): return [t[0], snappedf(t[2], 0.01)])])
					continue
				packs_seen += 1
				var edge: Vector2 = warned[0][3]
				var pack: Array = came[0][5]
				_expect(out, "seed %d night %d: pack %d's warning points where surges_coming() does, beyond the field" % [seed_value, night, i], [warned[0][6].has(edge), Config.FIELD.has_point(edge)], [true, false])
				_expect(out, "seed %d night %d: pack %d comes from the edge its warning pointed at, as many and of the kind it said" % [seed_value, night, i],
					[came[0][3], came[0][4], came[0][1], warned[0][4], warned[0][1]], [edge, s.size, s.kind, s.size, s.kind])
				_expect(out, "seed %d night %d: pack %d is all of its kind, as many as planned" % [seed_value, night, i], pack.map(func(e): return e.kind), _times(s.kind, s.size))
				_expect(out, "seed %d night %d: pack %d is of one tier" % [seed_value, night, i], pack.all(func(e): return e.tier == pack[0].tier), true)
				if pack.is_empty():
					continue
				tiers_seen[pack[0].tier] = true
				var along: Vector2 = w._along_edge(edge)
				var places: Array = pack.map(func(e): return snappedf((e.pos - edge).dot(along) / Config.ENEMY.with_gap, 0.001))
				places.sort()
				var row := []
				for k in pack.size():
					row.append(float(k - (pack.size() - 1) / 2))
				_expect(out, "seed %d night %d: pack %d stands in a row along its edge, with_gap apart, the warned spot in its middle" % [seed_value, night, i], places, row)
				_expect(out, "seed %d night %d: pack %d is on its edge's line, out of the field" % [seed_value, night, i],
					[pack.all(func(e): return absf((e.pos - edge).dot(along.orthogonal())) < 0.001), pack.any(func(e): return Config.FIELD.has_point(e.pos))], [true, false])
	_expect(out, "packs were seen, of more than one kind, and on a late night of more than one tier", [packs_seen >= 40, kinds_seen.size() > 1, tiers_seen.size() > 1], [true, true, true])
	_expect(out, "the line for a pack on its way", Config.SURGE.kinds.map(func(k): return Ui.coming_line(Ui.PACK % Looks.kind_name(k), Ui.PACK_COMING)),
		["슬라임 떼가 몰려온다!", "박쥐 떼가 몰려온다!", "그림자 떼가 몰려온다!", "도둑 비버 떼가 몰려온다!", "멧돼지 떼가 몰려온다!"])
	_expect(out, "the line for a boss on its way reads as before", Config.BOSS.kinds.map(func(k): return Ui.coming_line(Config.ENEMY_TYPES[k].name, Ui.BOSS_COMING)),
		["슬라임 왕이 다가온다!", "그림자 군주가 다가온다!"])
	return out


## How many enemies come out of the dark over the whole of the night w is at the dusk of, none of them fought, no boss.
static func _arrivals(w) -> int:
	var n := 0
	w.bosses_due = []
	w.next_wood = NEVER
	w.next_berry = NEVER
	while w.time < Config.NIGHT.length - 2.0 * Config.STEP:
		if w.phase == "pick":
			w._take(w.offer[0])
		w.player.hp = w.max_hp()
		w.fuel = w.max_fuel()
		w.enemies = []
		w.step(InputFrame.new())
		n += w.enemies.size()
	return n


## A night with surges brings about as many enemies as the same night without them, within a tenth: the packs are a
## share of the night, and the trickle comes further apart to make up for most of them (SURGE.makes_up). Counted over
## whole nights of several seeds, omens and all.
static func _surge_totals() -> Array:
	var out := []
	for night in [2, 3, 5, 7, 9, 12]:
		var with := 0
		var without := 0
		var packed := 0
		for seed_value in range(1, 17):
			var a = _dusk_at(seed_value, night)
			for s in a.surges_due:
				packed += s.size
			with += _arrivals(a)
			var b = _dusk_at(seed_value, night)
			b.surges_due = []
			b.surge_slow = 1.0
			without += _arrivals(b)
		if absf(with - without) > 0.1 * without:
			out.append("night %d: over 16 seeds %d enemies come with surges and %d without: more than a tenth apart" % [night, with, without])
		_expect(out, "night %d: its packs are a real share of it, at most SURGE.share and a little" % night, [packed > 0.1 * without, packed <= (Config.SURGE.share + 0.05) * without], [true, true])
	return out


## Not rules, but what the rules lean on: the tables agree with each other and with the project's settings.
static func _setup() -> Array:
	var out := []
	var named := {}
	for row in Config.NIGHTS:
		for kind in row.who:
			named[kind] = true
			_expect(out, "NIGHTS names a real enemy kind (%s)" % kind, Config.ENEMY_TYPES.has(kind), true)
		for kind in row.get("with", {}):
			for other in [kind] + row.with[kind]:
				_expect(out, "a kind in NIGHTS with is one its row names (%s)" % other, row.who.has(other), true)
	for kind in Config.BOSS.kinds:
		_expect(out, "BOSS names a boss (%s)" % kind, Config.ENEMY_TYPES.get(kind, {}).get("boss", false), true)
		named[kind] = true
	for kind in Config.ENEMY_TYPES:
		_expect(out, "every enemy kind comes on some night or as a boss (%s)" % kind, named.has(kind), true)
		if Config.ENEMY_TYPES[kind].has("summon"):
			_expect(out, "a boss summons a real enemy kind (%s)" % kind, Config.ENEMY_TYPES.has(Config.ENEMY_TYPES[kind].summon.kind), true)
	var early := 0
	for id in Config.OMENS:
		var row: Dictionary = Config.OMENS[id]
		_expect(out, "omen %s has a name and a text" % id, [row.get("name", "") != "", row.get("text", "") != ""], [true, true])
		_expect(out, "omen %s is said in the test's OMEN_SAYS" % id, OMEN_SAYS.has(id), true)
		var effects: Array = row.keys().filter(func(k): return not k in ["name", "text", "from"])
		_expect(out, "omen %s does something" % id, effects.is_empty(), false)
		for key in effects:
			_expect(out, "omen %s sets only keys the rules read (%s)" % [id, key], OMEN_KEYS.has(key), true)
		var first: int = maxi(Config.OMEN.from, row.get("from", 0))
		for kind in row.get("kinds", {}):
			_expect(out, "omen %s names a kind that comes on some night, not a boss (%s)" % [id, kind], [named.has(kind), Config.ENEMY_TYPES.get(kind, {}).get("boss", false)], [true, false])
			_expect(out, "omen %s comes no earlier than the %s it names" % [id, kind], Config.NIGHTS[mini(first, Config.NIGHTS.size()) - 1].who.has(kind), true)
		if first == Config.OMEN.from:
			early += 1
	_expect(out, "at least two omens may come from the first omen night, so every night has one to draw that last night did not have", early >= 2, true)
	for id in Config.UPGRADES:
		for n in World.max_level(id):
			_expect(out, "no upgrade sets kinds, which the omen sets and mod() does not multiply (%s)" % id, World.upgrade(id, n + 1).has("kinds"), false)
	for kind in Config.SURGE.kinds:
		_expect(out, "SURGE names a kind that comes on some night, not a boss (%s)" % kind, [named.has(kind), Config.ENEMY_TYPES.get(kind, {}).get("boss", false)], [true, false])
	var viewport := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	_expect(out, "project.godot's viewport is Config.VIEW", viewport, Config.VIEW)
	_expect(out, "the web page's title (project.godot config/name.web) is the first screen's title", ProjectSettings.get_setting("application/config/name.web"), Ui.INTRO_TITLE)
	_expect(out, "the field lies inside the view", Rect2(Vector2.ZERO, Config.VIEW).encloses(Config.FIELD), true)
	_expect(out, "the torch and the player start on the field", [Config.FIELD.has_point(Config.TORCH.pos), Config.FIELD.has_point(Config.PLAYER.start)], [true, true])
	return out


## The first night's coaching (src/coach.gd): an arrow at the nearest log until one is carried, at the torch until it
## is fed, at the first enemy that comes close until something is cut down; then nothing, and off. Off, never anything.
static func _coaching() -> Array:
	var out := []
	var w = _night(Vector2(0.0, 40.0))
	var c = Coach.new()
	w.logs = [w.player.pos + Vector2(30.0, 0.0), w.player.pos + Vector2(-60.0, 0.0)]
	_play(w, 1)
	c.step(w)
	_expect(out, "off, it shows nothing", c.now(w), [])
	c.on = true
	c.step(w)
	_expect(out, "first it points at the nearest log", c.now(w), [Coach.HAUL, w.logs[0]])
	w.player.pos = w.logs[0]
	_play(w, 1)
	c.step(w)
	_expect(out, "carrying a log, it points at the torch", c.now(w), [Coach.FEED, Config.TORCH.pos])
	w.player.pos = Config.TORCH.pos + Vector2(0.0, Config.TORCH.reach)
	_play(w, 1)
	c.step(w)
	_expect(out, "once a log is fed, the hauling is done", [c.haul, c.now(w)], ["done", []])
	var bat = _add(w, "bat", Vector2(Coach.NEAR - 5.0, 0.0))
	_play(w, 1)
	c.step(w)
	_expect(out, "an enemy close: cut it", c.now(w), [Coach.FIGHT, bat.pos])
	w.player.face = Vector2.RIGHT
	w.player.pos = bat.pos - Vector2(14.0, 0.0)
	for i in SWING: # the ui steps the coach after every world step, so it sees each step's events
		_play(w, 1, "attack" if i == 0 else "")
		c.step(w)
	_expect(out, "something cut down: all done and off", [c.fight, c.on, c.now(w)], ["done", false, []])
	return out


## What keeps a crowd of hundreds cheap answers exactly what the slow way did. World.mod() is looked up from a table
## made once per change of picks: for many random sets of picks, taken one by one and also swapped in whole, it gives
## the very value the old loop over every upgrade gives (the same float: the product is taken in the same order).
## The light's radius is kept until the fuel changes, and follows it when it does. Dropping the dead keeps the
## living in their order, and the newly born go after them.
static func _crowds() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new() # check-ok: a test's own layouts, never the world's rng
	rng.seed = 7
	var keys := {}
	for id in Config.UPGRADES:
		for n in World.max_level(id):
			for key in World.upgrade(id, n + 1):
				keys[key] = true
	var ids: Array = Config.UPGRADES.keys()
	var wrong := 0
	for trial in 40:
		var w = _night(LIT)
		for i in rng.randi_range(0, 20):
			var id: String = ids[rng.randi() % ids.size()]
			if w.level(id) < World.max_level(id):
				if trial % 2 == 0:
					w.picks.append(id) # one by one, as the offers do
				else:
					w.picks = w.picks + [id] # swapped in whole, as the scenes do
			for key in keys:
				var fast = w.mod(key, 1.0)
				var slow = _mod_the_slow_way(w, key, 1.0)
				if typeof(fast) != typeof(slow) or fast != slow:
					wrong += 1
	_expect(out, "mod() from its table equals the loop over every upgrade, for random picks", wrong, 0)
	var w = _night(LIT, ["bright"])
	w.fuel = 10.0
	var dim: float = w.light_radius()
	w.fuel = 90.0
	_expect(out, "the light's radius follows the fuel", [w.light_radius() > dim, is_equal_approx(w.light_radius(), lerpf(Config.TORCH.light_min, Config.TORCH.light_max, 0.9) * 1.3)], [true, true])
	w.picks = []
	_expect(out, "and the picks", is_equal_approx(w.light_radius(), lerpf(Config.TORCH.light_min, Config.TORCH.light_max, 0.9)), true)
	w = _night(DARK)
	var a = _add(w, "slime", Vector2(0.0, 60.0))
	var b = _add(w, "big_slime", NEAR)
	var c = _add(w, "slime", Vector2(0.0, -60.0))
	b.hp = 1
	_play(w, SWING, "attack")
	_expect(out, "a kill leaves the others in their order and its halves after them", w.enemies.map(func(e): return e.kind), ["slime", "slime", "slime", "slime"])
	_expect(out, "(the same two first)", [is_same(w.enemies[0], a), is_same(w.enemies[1], c)], [true, true])
	return out


## World.mod() as it was before the table: a loop over every upgrade, merging its levels, at every call.
static func _mod_the_slow_way(w, key: String, fallback):
	var v = fallback
	for id in Config.UPGRADES:
		var n: int = w.picks.count(id)
		if n == 0:
			continue
		var u: Dictionary = World.upgrade(id, n)
		if not u.has(key):
			continue
		v = v * u[key] if key.ends_with("_mult") or key == "glow_slow" else u[key]
	return v


## Nights past the table come closer together night by night (LATER_NIGHTS.spawn), but never closer than
## LATER_NIGHTS.min_gap, however late; a boss night's still come further apart than that.
static func _late_nights() -> Array:
	var out := []
	var w = _night(DARK)
	var gaps := []
	for night in [Config.NIGHTS.size(), Config.NIGHTS.size() + 1, Config.NIGHTS.size() + 2, Config.NIGHTS.size() + 6]:
		w.night = night
		w.time = 0.0
		gaps.append(w.spawn_gap())
	_expect(out, "each night past the table its enemies come closer together", [gaps[1] < gaps[0] or w._boss_night(), gaps[2] < gaps[1], gaps[3] < gaps[2]], [true, true, true])
	w.night = 61 # not a boss night
	w.time = Config.NIGHT.length
	_expect(out, "however late, they never come closer than min_gap", w.spawn_gap(), Config.LATER_NIGHTS.min_gap)
	w.night = 18 # the floor is a guard for the nights past twenty, not a cap on the crowds before them
	_expect(out, "up to night 18 the floor never shortens a gap", w.spawn_gap() > Config.LATER_NIGHTS.min_gap, true)
	w.night = 60
	_expect(out, "and a boss night's come further apart than that", is_equal_approx(w.spawn_gap(), Config.LATER_NIGHTS.min_gap * Config.BOSS.spawn_mult), true)
	return out


## Config.TIERS: a stronger tier is its kind's row with hp and score multiplied and rounded up, speed and smother
## multiplied, and (tier 3) less knockback; a kill of one scores its tier's worth and says which tier it was; the
## torch is smothered harder; a big slime breaks into halves of its own tier. Tier 1 is the row itself.
static func _tier_stats() -> Array:
	var out := []
	for kind in Config.ENEMY_TYPES:
		var base: Dictionary = Config.ENEMY_TYPES[kind]
		_expect(out, "%s at tier 1 is its row" % kind, Enemy.row(kind, 1) == base, true)
		if base.get("boss", false):
			continue
		for t in Config.TIERS.size():
			var up: Dictionary = Config.TIERS[t]
			var r: Dictionary = Enemy.row(kind, t + 2)
			_expect(out, "%s tier %d: hp, speed, smother, score" % [kind, t + 2], [r.hp, snappedf(r.speed, 0.001), snappedf(r.smother, 0.001), r.score],
				[ceili(base.hp * up.hp), snappedf(base.speed * up.speed, 0.001), snappedf(base.get("smother", 1.0) * up.smother, 0.001), ceili(base.get("score", Config.SCORE.kill) * up.score)])
		_expect(out, "%s: each tier is tougher than the one below" % kind, base.hp <= Enemy.row(kind, 2).hp and Enemy.row(kind, 2).hp <= Enemy.row(kind, 3).hp and Enemy.row(kind, 3).hp > base.hp, true)
	var e = Enemy.new("slime", Vector2.ZERO, 3)
	_expect(out, "an enemy made at a tier has its tier's row and hp", [e.tier, e.hp, is_same(e.T, Enemy.row("slime", 3))], [3, Enemy.row("slime", 3).hp, true])
	# a kill scores the tier's worth and the event names the tier, so the E1 count can follow it
	var w = _night(DARK)
	var red = Enemy.new("slime", w.player.pos + NEAR, 3)
	red.hp = 1
	w.enemies.append(red)
	var before: int = w.score
	var tiers := []
	for i in SWING:
		_play(w, 1, "attack" if i == 0 else "")
		for ev in w.events:
			if ev.kind == "kill":
				tiers.append(ev.tier)
	_expect(out, "a red slime's kill scores its tier's worth and says its tier", [w.score - before, tiers], [Enemy.row("slime", 3).score, [3]])
	# smother
	for t in [1, 3]:
		w = _night(DARK)
		var s = Enemy.new("slime", Config.TORCH.pos, t)
		s.at_torch = true
		w.enemies.append(s)
		_expect(out, "a tier %d slime at the torch smothers it by its row's smother" % t, snappedf(w.burn_rate() - w.burn(), 0.001), snappedf(Config.TORCH.smother * Enemy.row("slime", t).get("smother", 1.0), 0.001))
	# knockback
	var pushed := []
	for t in [1, 3]:
		w = _night(DARK)
		var s = Enemy.new("slime", w.player.pos + NEAR, t)
		s.hp = 99
		w.enemies.append(s)
		_play(w, SWING, "attack")
		pushed.append(s.knock.length() + s.vel.length())
	_expect(out, "a red slime is knocked back less than a green one", pushed[1] < pushed[0] * 0.8, true)
	# splits
	w = _night(DARK)
	var big = Enemy.new("big_slime", w.player.pos + NEAR, 2)
	big.hp = 1
	w.enemies.append(big)
	_play(w, SWING, "attack")
	_expect(out, "an orange big slime breaks into orange slimes", w.enemies.map(func(h): return [h.kind, h.tier]), [["slime", 2], ["slime", 2]])
	return out


## Config.TIER_NIGHTS: before its first row every enemy is tier 1 and no roll is made for it (the rng moves as it
## did before tiers, so those nights are the same game); from a row on, the tiers come in its shares, those that
## come along with an enemy share its tier, the strongest grow commoner night by night, and a boss stays tier 1.
static func _tier_nights() -> Array:
	var out := []
	var first: int = Config.TIER_NIGHTS[0].from
	for night in range(1, first + 1):
		var w = _night(DARK)
		w.night = night
		var ref := RandomNumberGenerator.new() # check-ok: replays the world's own draws to count them
		ref.seed = w.seed_value
		ref.state = w.rng.state()
		w.next_spawn = 0.0
		_play(w, 1)
		var draws := 2 + (1 if night >= first else 0) # the kind, the spot on the edge, and (from the first row) the tier
		for i in draws:
			ref.randf()
		_expect(out, "night %d: a spawn draws %d numbers from the rng" % [night, draws], w.rng.state(), ref.state)
	var last_strong := -1.0
	for r in Config.TIER_NIGHTS:
		var strong: float = r.shares[-1] / r.shares.reduce(func(a, b): return a + b, 0.0)
		_expect(out, "from night %d the strongest tier is no rarer than before" % r.from, strong >= last_strong, true)
		last_strong = strong
	_expect(out, "late on, the strongest tier is the commonest", Config.TIER_NIGHTS[-1].shares.max() == Config.TIER_NIGHTS[-1].shares[-1], true)
	for night in [first - 1, first, 12, 18]:
		var w = _night(DARK)
		w.night = night
		var seen := {}
		var mixed := 0
		var spawns := 400
		for i in spawns:
			w.enemies = []
			w.next_spawn = 0.0
			_play(w, 1)
			for e in w.enemies:
				seen[e.tier] = seen.get(e.tier, 0) + 1
			if w.enemies.any(func(e): return e.tier != w.enemies[0].tier):
				mixed += 1
		var shares: Array = w.tier_shares() if not w.tier_shares().is_empty() else [1.0]
		var total: float = shares.reduce(func(a, b): return a + b, 0.0)
		var leads := 0
		for t in seen:
			leads += seen[t]
		for t in range(1, shares.size() + 1):
			var want: float = shares[t - 1] / total
			var got: float = float(seen.get(t, 0)) / leads
			_expect(out, "night %d: tier %d comes about %.0f%% of the time" % [night, t, want * 100.0], absf(got - want) < 0.07 and (want > 0.0) == (got > 0.0), true)
		_expect(out, "night %d: no tier above the table's" % night, seen.keys().all(func(t): return t <= shares.size()), true)
		_expect(out, "night %d: an enemy and those that come along with it are of one tier" % night, mixed, 0)
	var w = _night(DARK)
	w.night = 21
	w.bosses_due = w._plan_bosses()
	w.time = Config.NIGHT.length * Config.BOSS.at + Config.BOSS.apart * 2
	_play(w, 2)
	_expect(out, "bosses are tier 1 on a late night", w.enemies.filter(func(e): return e.T.get("boss", false)).map(func(e): return e.tier), [1, 1, 1])
	return out


## A tier is the same picture in other colours (src/art/sprites.gd TIERS): every pixel is where its frame's is and
## as see-through, the outline and the eyes keep their colour, and every other pixel takes its tier's colour. The
## first sighting of a tier has its own line, named by its colour.
static func _tier_looks() -> Array:
	var out := []
	for name in Sprites.tier_names():
		var frame: String = name.get_slice("~", 0)
		var a := Sprites.image(frame)
		var b := Sprites.image(name)
		var grid := Sprites.rows(frame)
		var wrong := 0
		var kept := 0
		var changed := 0
		for y in grid.size():
			for x in grid[y].length():
				var key: String = grid[y][x]
				if a.get_pixel(x, y).a != b.get_pixel(x, y).a:
					wrong += 1
				elif Sprites.TIER_KEEP.has(key):
					kept += 0 if a.get_pixel(x, y) == b.get_pixel(x, y) else 1
				elif a.get_pixel(x, y) != b.get_pixel(x, y) or key in ["e", "i", "l"]: # eyes may keep their colour
					changed += 1
				else:
					wrong += 1
		_expect(out, "%s: the same shape, outline and whites kept, every other colour swapped" % name, [a.get_size() == b.get_size(), wrong, kept, changed > 0], [true, 0, 0, true])
		_expect(out, "%s: its feet are where its frame's are" % name, Sprites.foot(name), Sprites.foot(frame))
	var lines := {}
	for kind in Looks.TIER_NAMES:
		for t in Config.TIERS.size():
			var line := Looks.hint(Looks.thing(kind, t + 2))
			_expect(out, "%s tier %d has a first-sighting line of its own" % [kind, t + 2], line != "" and not lines.has(line) and line != Looks.hint(kind), true)
			lines[line] = true
	_expect(out, "an orange slime is told as one", Looks.hint(Looks.thing("slime", 2)).begins_with("주황 슬라임: "), true)
	_expect(out, "a tier's bits are in its colours", Looks.bit_colours("slime", 3) != Looks.bit_colours("slime", 1), true)
	return out



## The characters (Config.CHARACTERS): the knight is the keeper as it always was (Config.PLAYER untouched, every
## upgrade as its row reads); each character's numbers are PLAYER with its stats over them; every one has a name, a
## description, a weakness line and bars; a run starts again with another keeper by choose(), on the seed it is
## handed.
static func _characters() -> Array:
	var out := []
	var w = World.new(1)
	_expect(out, "a world starts with the knight", w.character, "knight")
	_expect(out, "the knight's numbers are Config.PLAYER's", w.stats, Config.PLAYER)
	for id in Config.UPGRADES:
		var row: Dictionary = Config.UPGRADES[id].duplicate()
		row.erase("as")
		_expect(out, "the knight's %s reads as its row" % id, World.upgrade_row(id, "knight"), row)
	for id in Config.CHARACTERS:
		var c: Dictionary = Config.CHARACTERS[id]
		for key in ["name", "text", "trait", "bars", "stats"]:
			_expect(out, "character %s has %s" % [id, key], c.has(key), true)
		for key in c.stats:
			_expect(out, "character %s's stat %s is one PLAYER has" % [id, key], Config.PLAYER.has(key) or key in ["bolt", "chop"], true)
		var cw = World.new(1, id)
		_expect(out, "%s's max hp is its hp" % id, cw.max_hp(), c.stats.get("hp", Config.PLAYER.hp))
		_expect(out, "%s starts with full hearts" % id, cw.player.hp, cw.max_hp())
	var a = World.new(5)
	a.choose("mage", 5)
	var b = World.new(5, "mage")
	_expect(out, "choose() starts the run again as a world made with that keeper", [a.character, a.offer, a.player.hp, a.rng.state()], [b.character, b.offer, b.player.hp, b.rng.state()])
	_expect(out, "the knight's offer at dusk does not change when the world is made for it", World.new(5, "knight").offer, World.new(5).offer)
	return out


## The woodcutter's axe chops (attack "chop"): slower than the sword (its blow lands later and the swing lasts
## longer), and it comes down on a round in front of him, Config.CHARACTERS' chop: ahead pixels along his facing,
## radius pixels wide. A body a hair inside the round's far edge is struck, a hair outside is not; what presses
## against his back or his side is not struck (the sword's wide arc cuts both); a spin still goes round. It strikes
## hard (2 a blow: a slime falls at once) and knocks back further, lands at attack_hit_at and not before, strikes
## what comes into the round while the blow lands and not after, and the long haft and the wide chop move and widen
## the round.
static func _woodcutter() -> Array:
	var out := []
	var C: Dictionary = World.character_stats("woodcutter")
	var R: float = Config.ENEMY_TYPES.slime.radius
	var body: float = Config.PLAYER.radius
	_expect(out, "the axe swings slower than the sword", C.attack_time > Config.PLAYER.attack_time and C.attack_hit_at > Config.PLAYER.attack_hit_at, true)
	_expect(out, "the woodcutter chops", [C.attack, C.chop.has("ahead"), C.chop.has("radius")], ["chop", true, true])
	_expect(out, "the woodcutter aims as far as the round's far edge", World.new(1, "woodcutter").attack_range(), C.chop.ahead + C.chop.radius)
	# Where each slime stands, facing right, and whether the chop strikes it; the knight's sword against the same.
	var spots := [
		["in the middle of the round", Vector2(C.chop.ahead, 0.0), true, true],
		["a hair inside the far edge", Vector2(C.chop.ahead + C.chop.radius + R - 0.5, 0.0), true, false],
		["a hair outside the far edge", Vector2(C.chop.ahead + C.chop.radius + R + 0.5, 0.0), false, false],
		["a hair inside the edge, off to the side", Vector2(C.chop.ahead, 0.0) + Vector2.from_angle(1.2) * (C.chop.radius + R - 0.5), true, null],
		["a hair outside the edge, off to the side", Vector2(C.chop.ahead, 0.0) + Vector2.from_angle(1.2) * (C.chop.radius + R + 0.5), false, null],
		["pressed against his back", Vector2(-(body + R - 1.0), 0.0), false, true],
		["pressed against his side", Vector2(0.0, body + R - 1.0), false, true],
		["at his side, a step off", Vector2(0.0, body + R + 3.0), false, true],
		["behind him, a step off", Vector2(-(body + R + 3.0), 0.0), false, false],
	]
	for spot in spots: # [where, from the woodcutter, struck by the chop, struck by the sword (null: not compared)]
		for who in ["woodcutter", "knight"] if spot[3] != null else ["woodcutter"]:
			var w = _night(DARK, [], who)
			w.player.invuln = NEVER # what presses against him would hurt him and knock him about
			var e = _planted(w, "slime", spot[1])
			if who == "woodcutter":
				_expect(out, "World.in_chop and the hit agree on a slime %s" % spot[0], w.in_chop(e.pos, R), spot[2])
			w.player.attack_t = 0.0 # a swing just begun, facing right (pressing attack would turn it to the slime)
			w.player.struck = []
			_play(w, roundi(w.stat("attack_time") / Config.STEP))
			_expect(out, "a slime %s is struck by the %s" % [spot[0], who], e.hp < e.full_hp, spot[2] if who == "woodcutter" else spot[3])
	# A spin still goes round: the one against his back is cut then.
	var sw = _night(DARK, ["spin"], "woodcutter")
	sw.player.invuln = NEVER
	sw.player.swings = 2 # the next is the third: a spin
	var back = _planted(sw, "slime", Vector2(-(body + R - 1.0), 0.0))
	_play(sw, 1, "attack")
	_play(sw, SWING * 2)
	_expect(out, "the woodcutter's spin goes round: the slime at his back is struck", back.dead, true)
	# The blow: not before attack_hit_at, 2 a blow, push times the sword's knockback.
	var w = _night(DARK, [], "woodcutter")
	var slime = _add(w, "slime", Vector2(C.chop.ahead, 0.0))
	var big = _add(w, "big_slime", Vector2(C.chop.ahead, 0.0).rotated(-0.5))
	w.player.attack_t = 0.0
	w.player.struck = []
	var land: int = ceili(C.attack_hit_at / Config.STEP - 0.0001)
	_play(w, land - 1)
	_expect(out, "the axe's blow has not landed before attack_hit_at", slime.hp, Config.ENEMY_TYPES.slime.hp)
	_play(w, 1)
	var axe_knock: float = big.knock.length() # in the step the blow lands
	_expect(out, "the axe lands on the step attack_hit_at is reached", [slime.dead, big.hp], [true, Config.ENEMY_TYPES.big_slime.hp - C.damage])
	var k = _night(DARK)
	var kbig = _add(k, "big_slime", NEAR)
	k.player.attack_t = 0.0
	k.player.struck = []
	var sword_knock := 0.0
	for i in roundi(Config.PLAYER.attack_hit_until / Config.STEP):
		_play(k, 1)
		if sword_knock == 0.0 and kbig.hp < kbig.full_hp:
			sword_knock = kbig.knock.length()
	_expect(out, "the sword does 1", kbig.hp, Config.ENEMY_TYPES.big_slime.hp - 1)
	_expect(out, "the axe knocks back push times as far as the sword", snappedf(axe_knock / maxf(sword_knock, 0.001), 0.01), C.push)
	_play(w, roundi(C.attack_time / Config.STEP))
	_expect(out, "the axe's swing is over after its attack_time", w.player.attack_t, -1.0)
	# Into the round while the blow lands: struck. After attack_hit_until: not.
	var into := land + 2
	for at in [into, ceili(C.attack_hit_until / Config.STEP) + 1]:
		var t = _night(DARK, [], "woodcutter")
		t.player.attack_t = 0.0
		t.player.struck = []
		_play(t, at)
		var late = _planted(t, "slime", Vector2(C.chop.ahead, 0.0))
		_play(t, SWING)
		_expect(out, "a slime that comes into the round %d steps in: struck" % at, late.hp < late.full_hp, at == into)
	# The bot chops only when the blow would strike (World.foe_in_reach), stands with the foe under the round, and lands.
	var b = _night(DARK, [], "woodcutter")
	b.player.invuln = NEVER
	var dummy = _planted(b, "big_slime", Vector2(-40.0, 25.0)) # knocked about by each blow, so the bot must follow it
	dummy.hp = 1000
	var bot = Bot.new(1)
	var starts := 0
	var blind := 0
	for i in 300:
		var f = bot.frame(b)
		if f.is_pressed("attack") and b.player.attack_t < 0.0 and not b.foe_in_reach(b.player.pos):
			blind += 1
		var was: float = b.player.attack_t
		b.step(f)
		starts += 1 if was < 0.0 and b.player.attack_t >= 0.0 else 0
	_expect(out, "the bot never chops where the blow would strike nothing", blind, 0)
	_expect(out, "the bot chops a foe it fights, about as often as the axe lets it (5 seconds)", [starts > 0, starts >= 300 / ceili(C.attack_time / Config.STEP) / 2], [true, true])
	_expect(out, "the bot's chops land", dummy.hp < 1000, true)
	# With the long haft at its top the round starts past a bat at its feet: the bot steps back before it chops.
	var h = _night(DARK, ["long_blade", "long_blade"], "woodcutter")
	h.player.invuln = NEVER
	var bat = _planted(h, "bat", Vector2(3.0, 0.0))
	var hbot = Bot.new(1)
	var hblind := 0
	for i in 120:
		var f = hbot.frame(h)
		if f.is_pressed("attack") and h.player.attack_t < 0.0 and not h.foe_in_reach(h.player.pos):
			hblind += 1
		h.step(f)
	_expect(out, "the bot does not chop at a bat under its feet, outside the round; it steps back and cuts it", [hblind, bat.dead], [0, true])
	# The upgrades: the long haft brings the round further out, the wide chop widens it.
	for run in [[["long_blade"], 5.0, 0.0], [["long_blade", "long_blade"], 9.0, 0.0], [["wide_swing"], 0.0, 3.0], [["wide_swing", "wide_swing"], 0.0, 5.0],
			[["long_blade", "wide_swing"], 5.0, 3.0]]:
		var u = _night(DARK, run[0], "woodcutter")
		_expect(out, "the woodcutter's round with %s" % [run[0]], [u.chop_ahead(), u.chop_radius()], [C.chop.ahead + run[1], C.chop.radius + run[2]])
		var reach_edge: float = u.chop_ahead() + u.chop_radius() + R - 0.5 # struck now, past the plain round's edge
		var gain = _planted(u, "slime", Vector2(reach_edge, 0.0))
		u.player.attack_t = 0.0
		u.player.struck = []
		_play(u, SWING)
		_expect(out, "with %s a slime %.1f px ahead (past the plain round) is struck" % [run[0], reach_edge], [reach_edge > C.chop.ahead + C.chop.radius + R, gain.hp < gain.full_hp], [true, true])
	return out


## The woodcutter carries up to Config.CHARACTERS' carry logs (the knight one): he picks up one a step while there is
## room, never more; he walks slower with each (carry_speed, carry_slow less a log more); at the torch every log goes
## in, each worth its fuel (and his log_bonus), its score and its "fed" event; a thief takes one log of the stack; the
## attack key puts them all down.
static func _stack() -> Array:
	var out := []
	var C: Dictionary = World.character_stats("woodcutter")
	var w = _night(Vector2(0.0, 80.0), [], "woodcutter")
	for i in C.carry + 1:
		w.logs.append(w.player.pos)
	for i in C.carry + 2:
		_play(w, 1)
	_expect(out, "the woodcutter picks up logs until his arms are full, and no more", [w.player.held, w.logs.size()], [C.carry, 1])
	var k = _night(Vector2(0.0, 80.0))
	k.logs = [k.player.pos, k.player.pos]
	_play(k, 3)
	_expect(out, "the knight carries one log", [k.player.held, k.logs.size()], [1, 1])
	var speeds := []
	for n in [1, 2, 3]:
		var s = _night(Vector2(0.0, 80.0), [], "woodcutter")
		for i in n:
			s.player.take_log()
		_play(s, 1, "", "right")
		speeds.append(snappedf(s.player.vel.x, 0.01))
	_expect(out, "the woodcutter walks slower with each log", speeds, [C.carry_speed, C.carry_speed - C.carry_slow, C.carry_speed - 2.0 * C.carry_slow])
	_expect(out, "with his full stack he is no faster than the knight with one", speeds[2] <= Config.PLAYER.carry_speed, true)
	var q = _night(Vector2(0.0, 80.0), ["quick_hands"], "woodcutter")
	for i in 3:
		q.player.take_log()
	_play(q, 1, "", "right")
	_expect(out, "quick hands: a full stack does not slow him", q.player.vel.x, C.speed)
	# At the torch: all of them go in.
	w = _night(Vector2(0.0, 30.0), [], "woodcutter")
	w.fuel = 10.0
	for i in 3:
		w.player.take_log()
	w.player.pos = Config.TORCH.pos + Vector2(0.0, Config.TORCH.reach)
	var score: int = w.score
	var told := _play(w, 1)
	_expect(out, "feeding the torch puts every log in", [w.player.held, w.player.carrying], [0, false])
	_expect(out, "each log is worth its fuel and the woodcutter's bonus", w.fuel, minf(w.max_fuel(), 10.0 + 3.0 * (Config.TORCH.log_fuel + C.log_bonus) - w.burn() * Config.STEP))
	_expect(out, "each log fed scores and is told", [w.score - score, told.count("fed")], [3 * Config.SCORE.log, 3])
	# A thief takes one.
	w = _night(Vector2(0.0, 80.0), [], "woodcutter")
	for i in 3:
		w.player.take_log()
	w.player.invuln = NEVER
	var thief = _add(w, "thief", Vector2(3.0, 0.0))
	_play(w, 1)
	_expect(out, "a thief takes one log of the woodcutter's stack", [w.player.held, thief.carrying], [2, true])
	# The attack key puts them all down.
	_play(w, 1, "attack")
	_expect(out, "the attack key puts every log down, and swings no axe", [w.player.held, w.player.carrying, w.logs.size(), w.player.attack_t], [0, false, 2, -1.0])
	return out


## The ember mage: 3 hearts; the attack shoots an ember along World.aim() at attack_hit_at (once a shot); it flies
## bolt.speed and burns the first enemy it touches, bolt.damage, lit_bonus more to one in the torch's light; a shade
## in the dark lets it through; the ember is drawn (Painter.bolt_discs) where it is and as big as what it hits; the
## spin upgrade as the mage has it fans three embers out every few shots; the bot as the mage shoots and backs off.
static func _mage() -> Array:
	var out := []
	var B: Dictionary = World.character_stats("mage").bolt
	var w = _night(DARK, [], "mage")
	_expect(out, "the mage has 3 hearts", [w.max_hp(), w.player.hp], [3, 3])
	var slime = _add(w, "big_slime", Vector2(40.0, 0.0))
	slime.T = slime.T.duplicate()
	slime.T.speed = 0.0
	_play(w, 1, "attack")
	_expect(out, "no ember before attack_hit_at", w.bolts.size(), 0)
	_play(w, roundi(w.stat("attack_hit_at") / Config.STEP))
	_expect(out, "one ember at attack_hit_at", w.bolts.size(), 1)
	var painter = Painter.new(1)
	var discs: Array = Painter.bolt_discs(w)
	_expect(out, "the ember is drawn where it is, as big as it hits", [discs[0][0], discs[0][1]], [w.bolts[0].pos, w.bolt_radius()])
	_expect(out, "the ember flies the aimed way at bolt.speed", snappedf(w.bolts[0].dir.x, 0.001), 1.0)
	_play(w, 30)
	_expect(out, "the ember burns a big slime in the dark for bolt.damage", slime.hp, Config.ENEMY_TYPES.big_slime.hp - B.damage)
	_expect(out, "the ember stops at the enemy it burns", w.bolts.size(), 0)
	# In the light: lit_bonus more.
	w = _night(Vector2(-40.0, 0.0), [], "mage")
	var lit = _add(w, "big_slime", Vector2(40.0, 0.0))
	lit.T = lit.T.duplicate()
	lit.T.speed = 0.0
	_play(w, 40, "attack")
	_expect(out, "the ember burns an enemy in the torch's light for damage + lit_bonus", lit.hp, Config.ENEMY_TYPES.big_slime.hp - B.damage - B.lit_bonus)
	w = _night(Vector2(-40.0, 0.0), ["fire_blade"], "mage")
	lit = _add(w, "big_slime", Vector2(40.0, 0.0))
	lit.T = lit.T.duplicate()
	lit.T.speed = 0.0
	_play(w, 40, "attack")
	_expect(out, "the fire upgrade as the mage has it: 1 more in the light", lit.hp, Config.ENEMY_TYPES.big_slime.hp - B.damage - B.lit_bonus - 1)
	# A shade in the dark lets it through (the ember is spent on it all the same).
	w = _night(DARK, [], "mage")
	var shade = _add(w, "shade", Vector2(40.0, 0.0))
	shade.T = shade.T.duplicate()
	shade.T.speed = 0.0
	var told := _play(w, 40, "attack")
	_expect(out, "an ember through a shade in the dark: passed, no hp lost", [shade.hp, told.has("passed")], [Config.ENEMY_TYPES.shade.hp, true])
	# It stops at the first enemy unless it pierces.
	w = _night(DARK, [], "mage")
	var first = _add(w, "big_slime", Vector2(30.0, 0.0))
	var second = _add(w, "big_slime", Vector2(60.0, 0.0))
	for e in [first, second]:
		e.T = e.T.duplicate()
		e.T.speed = 0.0
	_play(w, 40, "attack")
	_expect(out, "in the dark the ember (pierce %d) burns the first enemy in line and not the one behind" % B.pierce, [first.hp < first.full_hp, second.hp], [true, second.full_hp])
	w = _night(Vector2(-50.0, 0.0), [], "mage") # in the light: it goes through lit_pierce more
	var line := []
	for i in B.lit_pierce + 2:
		var e = _add(w, "big_slime", Vector2(25.0 + 38.0 * i, 0.0)) # apart by more than a burst (bolt.splash)
		e.T = e.T.duplicate()
		e.T.speed = 0.0
		line.append(e)
	_play(w, 40, "attack")
	var burnt := line.map(func(e): return e.hp < e.full_hp)
	var want := []
	for i in line.size():
		want.append(i <= B.pierce + B.lit_pierce)
	_expect(out, "in the light the ember goes through lit_pierce (%d) more and stops at the next" % B.lit_pierce, burnt, want)
	# The fan: the spin upgrade as the mage has it.
	w = _night(DARK, ["spin"], "mage")
	var shots := []
	for i in 3:
		_play(w, 1, "attack")
		_play(w, roundi(w.stat("attack_hit_at") / Config.STEP) + 1)
		shots.append(w.bolts.size())
		w.bolts = []
		_play(w, roundi(w.stat("attack_time") / Config.STEP))
	_expect(out, "three embers in a fan on the third shot with the mage's spin", shots, [1, 1, 3])
	# It aims as far as the ember flies: an enemy well past a sword's reach turns the shot.
	w = _night(DARK, [], "mage")
	_add(w, "slime", Vector2(0.0, 60.0))
	w.player.face = Vector2.RIGHT
	_play(w, 1, "attack")
	_expect(out, "the mage's shot turns to an enemy 60 pixels off, within the ember's range", w.player.face.y > 0.99, true)
	# Bot: shoots a slime coming close, and backs off.
	var bot = Bot.new(1)
	w = _night(Vector2(0.0, 60.0), [], "mage")
	_add(w, "slime", Vector2(30.0, 0.0))
	var f = bot.frame(w)
	_expect(out, "the bot as the mage shoots what comes close", f.pressed.has("attack"), true)
	_expect(out, "the bot as the mage backs away from it", f.held.has("left") and not f.held.has("right"), true)
	# With the torch low and wood about, it keeps hauling: shoots on its way, and never drops its log to fight
	# something that is not right on it.
	w = _night(Vector2(0.0, 60.0), [], "mage")
	w.fuel = 0.3 * w.max_fuel()
	w.logs = [w.player.pos + Vector2(-60.0, 0.0)]
	_add(w, "slime", Vector2(30.0, 0.0))
	f = bot.frame(w)
	_expect(out, "a hungry torch: the bot as the mage shoots on its way to the wood", [f.pressed.has("attack"), f.held.has("left")], [true, true])
	w.player.take_log()
	w.logs = []
	w.enemies[0].pos = w.player.pos + Vector2(Bot.SHOOT_DROP + 2.0, 0.0)
	f = bot.frame(w)
	_expect(out, "the bot as the mage does not drop its log for an enemy %.0f pixels off" % (Bot.SHOOT_DROP + 2.0), f.pressed.has("attack"), false)
	return out


## What looks hit by an ember is hit (World.in_bolt): a body whose edge it passes within its radius of, along its
## whole flight, up to bolt range plus the two radii; not one half a pixel further out, nor past the range.
static func _bolt_edges() -> Array:
	var out := []
	var B: Dictionary = World.character_stats("mage").bolt
	var r: float = Config.ENEMY_TYPES.big_slime.radius
	for case in [[Vector2(50.0, r + B.radius - 0.5), true], [Vector2(50.0, r + B.radius + 0.5), false],
			[Vector2(B.range + r + B.radius - 0.5, 0.0), true], [Vector2(B.range + r + B.radius + 0.5, 0.0), false]]:
		var w = _night(Vector2(-150.0, -60.0), [], "mage")
		var e = _add(w, "big_slime", case[0])
		e.T = e.T.duplicate()
		e.T.speed = 0.0
		w.player.face = Vector2.RIGHT
		w.player.attack_t = w.stat("attack_hit_at") - Config.STEP * 0.5 # fires on the next step, facing right
		_play(w, roundi(B.range / B.speed / Config.STEP) + 5)
		_expect(out, "an ember past a big slime at %s: hit" % case[0], e.hp < e.full_hp, case[1])
	_expect(out, "in_bolt: a body touching the stretch flown", World.in_bolt(Vector2.ZERO, Vector2(10.0, 0.0), 3.0, Vector2(5.0, 7.9), 5.0), true)
	_expect(out, "in_bolt: a body just clear of it", World.in_bolt(Vector2.ZERO, Vector2(10.0, 0.0), 3.0, Vector2(5.0, 8.1), 5.0), false)
	return out


## Upgrades read for the character that takes them (UPGRADES' as): the mage's long blade sends the ember further and
## leaves the reach alone, its wide swing makes the ember bigger and leaves the arc alone, its spin is a fan; the
## woodcutter's are named for the axe; every character's every level has a name and a text, and the mage's sword
## upgrades say nothing of a sword.
static func _character_upgrades() -> Array:
	var out := []
	var B: Dictionary = World.character_stats("mage").bolt
	var w = _night(DARK, ["long_blade"], "mage")
	_expect(out, "the mage's long blade: the ember flies 30 further, the reach is as it was", [w.bolt_range(), w.reach()], [B.range + 30.0, Config.PLAYER.reach])
	_expect(out, "the mage aims as far as the ember flies", w.attack_range(), w.bolt_range())
	w.picks.append("long_blade")
	_expect(out, "the mage's long blade at level 2: 50 further", w.bolt_range(), B.range + 50.0)
	w = _night(DARK, ["wide_swing", "wide_swing"], "mage")
	_expect(out, "the mage's wide swing at level 2: the ember is 3.5 bigger, the arc as it was", [w.bolt_radius(), w.arc()], [B.radius + 3.5, Config.PLAYER.arc])
	w = _night(DARK, ["spin"], "mage")
	_expect(out, "the mage's spin: no swing goes round", [w.mod("spin_every", 0), w.mod("spread_every", 0)], [0, 3])
	w = _night(DARK, ["long_blade", "vampire", "vampire"], "woodcutter")
	_expect(out, "the woodcutter's upgrades work as the knight's (the long haft also brings the chop out)", [w.reach(), w.vamp_need(), w.chop_ahead()], [Config.CHARACTERS.woodcutter.stats.reach + 8.0, 5, Config.CHARACTERS.woodcutter.stats.chop.ahead + 5.0])
	for id in ["long_blade", "wide_swing", "spin"]:
		for n in range(1, World.max_level(id) + 1):
			var u := World.upgrade(id, n, "woodcutter")
			if "휘두르기" in u.name or "베" in u.name + u.text:
				out.append("the woodcutter's %s at level %d still speaks of a sweep: %s / %s" % [id, n, u.name, u.text])
	for who in Config.CHARACTERS:
		for id in Config.UPGRADES.keys().filter(func(i): return World.open_to(i, who)): # another's own row is never on its cards
			for n in range(1, World.max_level(id) + 1):
				var u := World.upgrade(id, n, who)
				if not (u.get("name", "") != "" and u.get("text", "") != ""):
					out.append("%s's %s at level %d has no name or text" % [who, id, n])
				if who == "mage" and Looks.side(id) == "keeper" and ("칼" in u.name + u.text or "베" in u.name + u.text):
					out.append("the mage's %s at level %d still speaks of a sword: %s / %s" % [id, n, u.name, u.text])
				if who == "woodcutter" and "칼" in u.name + u.text:
					out.append("the woodcutter's %s at level %d still speaks of a sword: %s / %s" % [id, n, u.name, u.text])
	_expect(out, "the knight's card texts are the rows'", World.upgrade("vampire", 2, "knight").text, Config.UPGRADES.vampire.levels[0].text)
	return out



## The dressed-up warnings keep the sizes the rules hurt at: the slime king's marked landing is drawn at the shock of
## the leap or hop under way (Painter.mark_radius), the debris its landing throws out ends at that shock (the "landed"
## event carries it), and the chevrons on a boar's band slide along its line, from the boar to where the charge ends,
## inside the band, toward its end and faster as the wind-up runs out.
static func _fx_sizes() -> Array:
	var out := []
	var L: Dictionary = Config.ENEMY_TYPES.slime_king.leap
	var w = _night(DARK)
	var king = _add(w, "slime_king", Vector2(-40.0, 0.0))
	_expect(out, "a leap's mark is drawn at its shock", Painter.mark_radius(king), L.shock)
	king.hops_left = 2
	_expect(out, "a hop's mark is drawn at the hop's shock", Painter.mark_radius(king), L.hops.shock)
	king.hops_left = 0
	king.move = "air"
	king.move_t = Config.STEP * 0.5
	king.move_to = king.pos + Vector2(10.0, 0.0)
	king.move_from = king.pos
	w.player.invuln = NEVER
	_play(w, 1)
	var landed: Array = w.events.filter(func(ev): return ev.kind == "landed")
	_expect(out, "a landing tells its shock", landed.map(func(ev): return ev.get("shock")), [L.shock])
	var fx = Effects.new(1)
	fx.step(w)
	_expect(out, "a landing throws one ring of debris", fx.rings.size(), 1)
	if fx.rings.size() == 1:
		var r: Dictionary = fx.rings[0]
		var radii := []
		for i in Effects.RINGS.debris[0]:
			radii.append(Effects.ring_radius(r))
			r.age += 1
		_expect(out, "the debris ends at the shock", snappedf(radii[-1], 0.001), L.shock)
		_expect(out, "the debris never goes past the shock", radii.all(func(x): return x <= L.shock + 0.001), true)
	var C: Dictionary = Config.ENEMY_TYPES.boar.charge
	w = _night(Vector2(-100.0, 30.0))
	w.fuel = 1.0e6
	var boar = _add(w, "boar", Vector2(-60.0, 0.0))
	boar.move_t = 0.0
	_play(w, 1)
	var first := []
	var slid := []
	for at in [2, 3, int(C.warn / Config.STEP) - 3, int(C.warn / Config.STEP) - 2]:
		while roundi((C.warn - boar.move_t) / Config.STEP) < at:
			_play(w, 1)
		var tips: PackedVector2Array = Painter.chevrons(boar)
		var length: float = boar.pos.distance_to(boar.charge_end())
		_expect(out, "there are chevrons on the band", tips.size() > 0, true)
		for t in tips:
			var along: float = (t - boar.pos).dot(boar.aim)
			if absf((t - boar.pos).dot(boar.aim.orthogonal())) > 0.01 or along < Painter.CHEVRON_SIZE - 0.01 or along > length + 0.01:
				out.append("a chevron's tip is off the band's line: %s" % (t - boar.pos))
				break
		first.append(((tips[0] - boar.pos).dot(boar.aim)) if tips.size() > 0 else 0.0)
	_expect(out, "a chevron's arms stay inside the band", Painter.CHEVRON_SIZE < boar.lane_half(), true)
	var early: float = fposmod(first[1] - first[0], Painter.CHEVRON_GAP)
	var late: float = fposmod(first[3] - first[2], Painter.CHEVRON_GAP)
	_expect(out, "the chevrons slide toward the end, faster as the wind-up runs out", early > 0.0 and late > early, true)
	out.append_array(_attack_fx())
	var B: Dictionary = World.character_stats("mage").bolt
	w = _night(DARK, [], "mage")
	_planted(w, "big_slime", Vector2(40.0, 0.0))
	var bfx = Effects.new(1)
	for i in 30:
		_play(w, 1, "attack" if i == 0 else "")
		bfx.step(w)
		if bfx.rings.size() > 0:
			break
	_expect(out, "an ember's burst throws one ring", bfx.rings.size(), 1)
	if bfx.rings.size() == 1:
		var ring: Dictionary = bfx.rings[0]
		var burst_radii := []
		for i in Effects.RINGS.burst[0]:
			burst_radii.append(Effects.ring_radius(ring))
			ring.age += 1
		_expect(out, "the burst's ring ends at the splash radius", snappedf(burst_radii[-1], 0.001), B.splash)
		_expect(out, "the burst's ring never goes past it", burst_radii.all(func(x): return x <= B.splash + 0.001), true)
	return out


## The keepers' own attacks are drawn as big as they hit: a swing's smear reaches exactly world.reach() (the long
## blade's too) and, over the swing, sweeps the whole arc world.swing_half() each side of the facing (and not past
## it); an ember's disc stays bolt_radius() however its middle flickers (the big ember's and each of a fan's too);
## an ember pops where it touched what it burned and fizzles exactly bolt_range() from where it was cast (the long
## ember's too); each keeper's blow plays its own mark; and the marks stay within Effects.MAX_FLASHES.
## The marks (Effects.flashes) the last fx.step() started: they are a step old.
static func _new_marks(fx) -> Array:
	return fx.flashes.filter(func(f): return f.age == 1)


static func _attack_fx() -> Array:
	var out := _chop_fx()
	var painter = Painter.new(1)
	for run in [[[], "knight"], [["long_blade", "long_blade"], "knight"], [["wide_swing"], "knight"], [["swift", "swift", "swift"], "knight"]]:
		var w = _night(DARK, run[0], run[1])
		var half: float = w.swing_half()
		var far := 0.0
		var low := INF
		var high := -INF
		_play(w, 1, "attack")
		for i in roundi(w.stat("attack_time") / Config.STEP) + 1:
			var centre: Vector2 = w.player.pos.round()
			for band in painter.smear(w):
				for at in band[0]:
					far = maxf(far, at.distance_to(centre))
					var turn: float = Vector2.RIGHT.angle_to(at - centre)
					low = minf(low, turn)
					high = maxf(high, turn)
			_play(w, 1)
		_expect(out, "the smear's outer edge is the reach (%s)" % [run], snappedf(far, 0.01), snappedf(w.reach(), 0.01))
		_expect(out, "the smear sweeps the whole arc and no further (%s)" % [run], [snappedf(low, 0.01), snappedf(high, 0.01)], [snappedf(-half, 0.01), snappedf(half, 0.01)])
	for run in [[[], 3], [["wide_swing", "wide_swing"], 3], [["spin"], 3], [["swift", "swift", "swift", "spin"], 3]]: # the big ember; the fan on its third shot
		var w = _night(DARK, run[0], "mage")
		w.player.swings = 2
		_play(w, 1, "attack")
		var radii := {}
		for i in 12:
			_play(w, 1)
			for d in Painter.bolt_discs(w):
				radii[snappedf(d[1], 0.001)] = true
		_expect(out, "every ember's disc is drawn as big as it hits, flicker or not (%s)" % [run[0]], radii.keys(), [snappedf(w.bolt_radius(), 0.001)])
	var cores: Array = Painter.BOLT_CORES.map(func(n): return Sprites.texture(n).get_width() / 2.0)
	_expect(out, "an ember's flickering middle and core stay inside its disc", Painter.BOLT_INNER.max() < 1.0 and cores.max() <= World.character_stats("mage").bolt.radius, true)
	for ups in [[], ["long_blade"], ["swift", "swift", "swift"]]:
		var w = _night(DARK, ups, "mage")
		var from: Vector2 = w.player.pos
		var fx = Effects.new(1)
		var marks := []
		for i in 60:
			_play(w, 1, "attack" if i == 0 else "")
			fx.step(w)
			marks.append_array(_new_marks(fx))
		var fizzles: Array = marks.filter(func(f): return f.kind == "fizzle")
		_expect(out, "an ember that hits nothing fizzles once, where its range ends (%s)" % [ups], fizzles.map(func(f): return snappedf(f.pos.distance_to(from), 0.01)), [snappedf(w.bolt_range(), 0.01)])
		_expect(out, "an ember that hits nothing pops nowhere (%s)" % [ups], marks.filter(func(f): return f.kind == "strike").size(), 0)
	for gap in [40.0, 6.0]: # in flight, and so close that the ember burns it on its first step and is gone
		var w = _night(DARK, [], "mage")
		var slime = _add(w, "big_slime", Vector2(gap, 0.0))
		slime.T = slime.T.duplicate()
		slime.T.speed = 0.0
		var fx = Effects.new(1)
		var told := []
		var marks := []
		var struck_at := Vector2.INF
		for i in 40:
			told.append_array(_play(w, 1, "attack" if i == 0 else ""))
			fx.step(w)
			for f in _new_marks(fx):
				marks.append(f)
				struck_at = slime.pos # where it was when burned (it is pushed off afterwards)
		_expect(out, "an ember that burns a big slime %d px off is told and pops once" % gap, [told.count("hit"), marks.size()], [1, 1])
		if marks.size() == 1:
			_expect(out, "the pop is where the ember touched it (%d px off)" % gap, [marks[0].kind, marks[0].frames, marks[0].pos.distance_to(struck_at) < w.bolt_radius() + slime.T.radius and (marks[0].pos - struck_at).x < 0.0], ["strike", Effects.STRIKES.mage.frames, true])
	var looks := {}
	for who in Effects.STRIKES:
		looks[Effects.STRIKES[who].frames] = who
	_expect(out, "each keeper's blow has its own mark", looks.size(), Config.CHARACTERS.size())
	for run in [[[], "knight"], [[], "woodcutter"], [["swift", "swift", "swift"], "knight"], [["swift", "swift", "swift"], "woodcutter"]]:
		var who: String = run[1]
		var w = _night(DARK, run[0], who)
		var slime = _add(w, "big_slime", NEAR)
		var fx = Effects.new(1)
		var juice = Juice.new(1)
		var marks := []
		var shook := false
		for i in SWING:
			_play(w, 1, "attack" if i == 0 else "")
			fx.step(w)
			juice.step(w)
			shook = shook or juice.shake_left > 0
			marks.append_array(_new_marks(fx))
		_expect(out, "the %s's blow does not shake the field %s" % [who, run[0]], shook, false)
		_expect(out, "the %s's blow plays its own mark once %s" % [who, run[0]], marks.map(func(f): return f.frames), [Effects.STRIKES[who].frames])
		var many = Effects.new(1)
		for i in Effects.MAX_FLASHES * 2:
			many._strike(Effects.STRIKES[who], Vector2.ZERO, Vector2.RIGHT)
		many.step(_night(DARK))
		_expect(out, "the marks stay within MAX_FLASHES (%s)" % who, many.flashes.size() <= Effects.MAX_FLASHES, true)
	return out


## The woodcutter's chop is drawn where and as big as it strikes: the swing sweeps no smear (a spin still does); while
## the blow lands, and only then, the dent's ring is world.chop_radius() about world.chop_centre() and every crack lies
## inside the round; the dust Effects throws out on each landing (one ring, struck or not) ends at the round's edge
## about the same centre; and the axe's head, down flat, lies on that centre. A single blow never shakes the field;
## a chop that kills three at once jolts it a pixel, and not again until Juice.CRUSH's apart frames have gone by.
static func _chop_fx() -> Array:
	var out := []
	var painter = Painter.new(1)
	for run in [[], ["long_blade", "wide_swing"], ["long_blade", "long_blade", "wide_swing", "wide_swing"], ["swift", "swift", "swift"], ["fire_blade"]]:
		var w = _night(LIT if run.has("fire_blade") else DARK, run, "woodcutter")
		var fx = Effects.new(1)
		var shown := 0
		var heads := []
		var rings := []
		for turn in 2:
			w.player.face = Vector2.from_angle(1.9 * turn + 0.3)
			for i in roundi(w.stat("attack_time") / Config.STEP) + 2:
				_play(w, 1, "attack" if i == 0 else "")
				fx.step(w)
				for r in fx.rings.filter(func(x): return x.kind == "dust" and x.age == 1):
					rings.append(r)
				if not (painter.smear(w).is_empty() and painter.slash_lines(w).is_empty()):
					out.append("a chop draws a sweep's smear (%s)" % [run])
				var m: Dictionary = painter.chop_marks(w)
				var landing: bool = w.player.attack_t >= w.stat("attack_hit_at") and w.player.attack_t <= w.stat("attack_hit_until")
				if m.is_empty() != not landing:
					out.append("the chop's marks show %s the blow lands (%s at %.3f)" % ["outside the time" if landing == false else "not all the time", run, w.player.attack_t])
				if m.is_empty():
					continue
				shown += 1
				var centre: Vector2 = w.chop_centre(w.player.pos, w.player.face)
				_expect(out, "the dent is about the chop's centre and as wide as its round (%s)" % [run], [m.centre, m.radius], [centre, w.chop_radius()])
				for line in m.cracks:
					for at in line:
						if not w.in_chop(at, 0.0):
							out.append("a crack runs outside the round the chop strikes (%s, %s)" % [run, at - centre])
				var blade: Array = painter._blade(w)
				var sword: Texture2D = painter._sword_texture(w)
				var head: Vector2 = blade[0] + Vector2.from_angle(blade[1]) * (_steel_middle(sword_name(painter, w)) - Painter._grip(w).x) * blade[3]
				heads.append(head.distance_to(centre))
		_expect(out, "the chop's marks showed in each blow (%s)" % [run], shown > 0, true)
		_expect(out, "the axe's head comes down on the chop's centre (%s)" % [run], heads.filter(func(d): return d > 2.0), []) # the quiver moves it a pixel (diagonally, 1.41)
		_expect(out, "each chop throws one ring of dust (%s)" % [run], rings.size(), 2)
		for r in rings:
			var radii := []
			for i in Effects.RINGS.dust[0]:
				radii.append(Effects.ring_radius(r))
				r.age += 1
			_expect(out, "the dust ends at the round's edge (%s)" % [run], snappedf(radii[-1], 0.001), snappedf(w.chop_radius(), 0.001))
			_expect(out, "the dust never goes past it (%s)" % [run], radii.all(func(x): return x <= w.chop_radius() + 0.001), true)
	var spun = _night(DARK, ["spin"], "woodcutter")
	spun.player.swings = 2
	var swept := 0
	for i in SWING:
		_play(spun, 1, "attack" if i == 0 else "")
		swept += painter.smear(spun).size()
		if not painter.chop_marks(spun).is_empty():
			out.append("a spin draws a chop's dent")
	_expect(out, "the woodcutter's spin sweeps a smear round", swept > 0, true)
	# Three slimes in the round, killed by one chop: a pixel's jolt, once; again at once: none; after apart frames: one.
	var apart: int = Juice.CRUSH.woodcutter.apart
	var juice = Juice.new(1)
	var crushes := []
	for wait in [0, 0, apart]:
		var w = _night(DARK, [], "woodcutter")
		w.player.invuln = NEVER # a hurt shakes the field too
		for a in [-0.4, 0.0, 0.4]:
			_planted(w, "slime", Vector2(w.chop_ahead(), 0.0) + Vector2.from_angle(a * 4.0) * 4.0)
		for i in wait:
			juice.frame()
		var shook := false
		for i in SWING:
			_play(w, 1, "attack" if i == 0 else "")
			juice.step(w)
			shook = shook or juice.shake_left == Juice.SHAKE.crush[1] # a new one: the last may still be running
			juice.frame()
		crushes.append([w.enemies.filter(func(e): return not e.dead).size(), shook])
	_expect(out, "three killed at once jolt the field; at once again not; after the wait again", crushes, [[0, true], [0, false], [0, true]])
	var two = _night(DARK, [], "woodcutter")
	two.player.invuln = NEVER
	var j2 = Juice.new(1)
	for a in [-0.5, 0.5]:
		_planted(two, "slime", Vector2(two.chop_ahead(), 0.0) + Vector2(0.0, a * 6.0))
	var two_shook := false
	for i in SWING:
		_play(two, 1, "attack" if i == 0 else "")
		j2.step(two)
		two_shook = two_shook or j2.shake_left > 0
	_expect(out, "two killed at once do not shake the field", [two.enemies.filter(func(e): return not e.dead).size(), two_shook], [0, false])
	return out


## The axe sprite the painter draws now, by name (Painter.SWORD).
static func sword_name(painter, w) -> String:
	return Painter.SWORD % [Painter._weapon(w), "_long" if w.mod("reach_bonus", 0.0) > 0.0 else "", "_fire" if painter._burning(w) else ""]


## Where along a weapon sprite the middle of its head (its steel or fire pixels) is, in sprite pixels from its left.
static func _steel_middle(sprite: String) -> float:
	var sum := 0.0
	var n := 0
	for row in Sprites.rows(sprite):
		for x in row.length():
			if row[x] in ["a", "A", "Z", "f", "F", "x"]:
				sum += x + 0.5
				n += 1
	return sum / maxi(1, n)


## The words name the keeper being played: a line that speaks of the keeper ({who}, Looks.say) says the chosen
## character's name, with each particle after it in the form that name takes (을 after 나무꾼, 를 after 기사 and
## 불씨 술사, ...). No line a woodcutter or a mage is shown says 기사, and no string in src/ writes the knight's name out
## but its own row in Config.CHARACTERS (a line that wants it says {who}).
static func _keeper_words() -> Array:
	var out := []
	var knight: String = Config.CHARACTERS.knight.name
	_expect(out, "particles after a vowel", ["를", "가", "는", "와", "로"].map(func(p): return Looks.particle("기사", p)), ["를", "가", "는", "와", "로"])
	_expect(out, "particles after a final consonant", ["를", "가", "는", "와", "로"].map(func(p): return Looks.particle("나무꾼", p)), ["을", "이", "은", "과", "으로"])
	_expect(out, "불씨 술사 ends in a vowel", ["를", "가"].map(func(p): return Looks.particle("불씨 술사", p)), ["를", "가"])
	_expect(out, "로 after ㄹ, 이 after it", [Looks.particle("슬라임 왕", "로"), Looks.particle("슬라임 왕", "가"), Looks.particle("횃불", "로")], ["으로", "이", "로"])
	_expect(out, "a word not ending in Korean reads as ending in a vowel", [Looks.particle("Bot", "를"), Looks.particle("", "가")], ["를", "가"])
	_expect(out, "the bat's hint names the woodcutter", Looks.hint("bat", "woodcutter"), "박쥐: 나무꾼을 쫓아온다, 빛 밖에서는 더 빠르다")
	_expect(out, "the bat's hint names the mage", Looks.hint("bat", "mage"), "박쥐: 불씨 술사를 쫓아온다, 빛 밖에서는 더 빠르다")
	_expect(out, "the bat's hint names the knight", Looks.hint("bat"), "박쥐: 기사를 쫓아온다, 빛 밖에서는 더 빠르다")
	_expect(out, "every particle after {who} is put in its form", Looks.say("{who}를 {who}가 {who}는 {who}와 {who}로 {who}의", "woodcutter"), "나무꾼을 나무꾼이 나무꾼은 나무꾼과 나무꾼으로 나무꾼의")
	_expect(out, "the keeper's side is named for the character", [Looks.side_name("keeper", "woodcutter"), Looks.side_name("keeper", "mage"), Looks.side_name("torch", "mage")], ["나무꾼의 힘", "불씨 술사의 힘", "횃불의 힘"])
	for who in Config.CHARACTERS:
		var lines := []
		for kind in Config.ENEMY_TYPES.keys() + ["berry"]:
			lines.append(Looks.hint(kind, who))
			for t in Looks.TIER_NAMES.get(kind, []).size():
				lines.append(Looks.hint(Looks.thing(kind, t + 2), who))
		for side in Looks.SIDES:
			lines.append(Looks.side_name(side, who))
		for id in Config.UPGRADES:
			for n in range(1, World.max_level(id) + 1):
				var u := World.upgrade(id, n, who)
				lines.append_array([u.name, u.text])
		for c in Config.CHARACTERS.values():
			lines.append_array([c.name, c.text, c.trait])
		for line in lines:
			if "{" in line or "}" in line:
				out.append("a line is shown to the %s with a blank in it: %s" % [who, line])
			if who != "knight" and knight in line and line != knight:
				out.append("a line shown to the %s says %s: %s" % [who, knight, line])
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var found := []
	for path in Ui._scripts("res://src"):
		for m in strings.search_all(FileAccess.get_file_as_string(path)):
			if knight in m.get_string():
				found.append("%s: %s" % [path.get_file(), m.get_string()])
	_expect(out, "the knight's name is written out only in its own row (a line about the keeper says {who})", found, ["config.gd: \"%s\"" % knight])
	return out


## Swift (attack_mult) shortens the time between attacks for every keeper alike, its blow or its ember coming at the
## same share of the shorter attack; the bot keeps time with it. The torch offers it only from its from_night (10):
## never on the nights before, and on those nights the offers are drawn exactly as if it were not a row (so the
## runs up to night 9 are what they were), also when begin_at draws the nights before a late start.
static func _swift() -> Array:
	var out := []
	var from: int = Config.UPGRADES.swift.from_night
	_expect(out, "swift comes from night 10", from, 10)
	_expect(out, "swift is the last row, so the rows before it keep their order", Config.UPGRADES.keys()[-1], "swift")
	_expect(out, "swift is offered from its night only", [World.offered_on("swift", from - 1), World.offered_on("swift", from), World.offered_on("swift", from + 5), World.offered_on("spin", 1)], [false, true, true, true])
	var before := 0
	var after := 0
	var same := true
	for seed_value in range(1, 41):
		var w = World.new(seed_value)
		for n in [1, from - 1, from]:
			w.night = n
			var twin = World.new(seed_value) # draws from a pool that never held swift, on the same rng
			twin.rng = SimRng.new(seed_value + 1000)
			w.rng = SimRng.new(seed_value + 1000)
			w._offer()
			var pool: Array = Config.UPGRADES.keys().filter(func(id): return id != "swift" and World.open_to(id, "knight") and not Config.UPGRADES[id].has("needs"))
			var want := []
			while want.size() < Config.NIGHT.offer_size:
				want.append(twin._draw(pool))
			if n < from:
				before += w.offer.count("swift")
				same = same and w.offer == want and w.rng.state() == twin.rng.state()
			else:
				after += w.offer.count("swift")
	_expect(out, "swift is never offered before night %d" % from, before, 0)
	_expect(out, "before night %d the offers are drawn as if swift were not there" % from, same, true)
	_expect(out, "swift is offered on night %d (some of 40 draws)" % from, after > 0, true)
	var late_seen := 0
	for seed_value in range(1, 21):
		for slot in [1, 2, 3]:
			var w = World.new(seed_value)
			w.begin_at(from, slot)
			if w.picks.has("swift"):
				out.append("begin_at took swift before night %d (seed %d, slot %d)" % [from, seed_value, slot])
			late_seen += w.offer.count("swift")
			_expect(out, "begin_at ends on the night it starts", w.night, from)
	_expect(out, "begin_at's first offer, at the dusk of night %d, can hold swift" % from, late_seen > 0, true)
	# Each level shortens the attack for every keeper, and every time of it alike.
	for who in Config.CHARACTERS:
		var base := World.character_stats(who)
		var last := INF
		for n in range(0, World.max_level("swift") + 1):
			var ups := []
			for i in n:
				ups.append("swift")
			var w = _night(DARK, ups, who)
			var k: float = World.upgrade("swift", n, who).attack_mult if n > 0 else 1.0
			_expect(out, "%s with swift %d: every time of its attack is %.2f of its own" % [who, n, k],
				Config.ATTACK_TIMES.map(func(key): return snappedf(w.stat(key), 0.0001)), Config.ATTACK_TIMES.map(func(key): return snappedf(base[key] * k, 0.0001)))
			_play(w, 1, "attack")
			var steps := 1
			while w.player.attack_t >= 0.0 and steps < 200:
				_play(w, 1)
				steps += 1
			_expect(out, "%s with swift %d: the attack is over after its shortened time" % [who, n], steps, ceili(base.attack_time * k / Config.STEP - 0.0001))
			if not steps < last:
				out.append("%s: swift %d does not shorten the attack (%d steps, %s before)" % [who, n, steps, last])
			last = steps
	# The blow comes sooner: with swift at its last level an axe lands before the plain axe's attack_hit_at, and over
	# two seconds of holding the key a mage casts more embers.
	var cut := {}
	for ups in [[], ["swift", "swift", "swift"]]:
		var w = _night(DARK, ups, "woodcutter")
		var slime = _planted(w, "big_slime", NEAR)
		_play(w, 1, "attack")
		var at := 1
		while slime.hp == slime.full_hp and at < 60:
			_play(w, 1)
			at += 1
		cut[ups.size()] = at
	_expect(out, "the woodcutter's blow lands sooner with swift", cut[3] < cut[0], true)
	_expect(out, "the woodcutter's blow lands at the same share of its swing", cut[3], ceili(World.character_stats("woodcutter").attack_hit_at * World.upgrade("swift", 3, "woodcutter").attack_mult / Config.STEP - 0.0001))
	var cast := {}
	for ups in [[], ["swift", "swift", "swift"]]:
		var w = _night(DARK, ups, "mage")
		var told := []
		for i in 120:
			told.append_array(_play(w, 1, "attack"))
		cast[ups.size()] = told.count("cast")
	_expect(out, "the mage casts more embers with swift, about as many more as its attack is shorter (2 seconds)", [cast[3] > cast[0], absf(cast[3] * World.upgrade("swift", 3, "mage").attack_mult - cast[0]) <= 1.0], [true, true])
	# The bot keeps time with it: its beat is as much shorter as the swing (at the levels it still presses for itself).
	var swung := {}
	for ups in [[], ["swift"], ["swift", "swift"]]:
		var w = _night(DARK, ups)
		w.player.invuln = NEVER
		var king = _planted(w, "slime_king", Vector2(30.0, 0.0))
		king.hp = 1000
		var bot = Bot.new(1)
		var starts := 0
		for i in 240:
			var was: float = w.player.attack_t
			w.step(bot.frame(w))
			if was < 0.0 and w.player.attack_t >= 0.0:
				starts += 1
		swung[ups.size()] = starts
	_expect(out, "the bot swings more often with swift, more at each level", swung[0] < swung[1] and swung[1] < swung[2], true)
	return out


## Swift's last level attacks by itself (auto_attack): with an enemy in reach (World.attack_range()) and nothing in
## its arms, each keeper attacks as soon as its attack is ready, turned to the nearest enemy as a pressed attack is;
## not at the lower levels, not at the air, never while it carries logs (the key would put them down, it does not),
## and pressing the key as well never attacks faster. It is the same game every time it is played.
static func _auto_attack() -> Array:
	var out := []
	var top: int = World.max_level("swift")
	for who in Config.CHARACTERS:
		_expect(out, "only swift's last level attacks by itself (%s)" % who, range(1, top + 1).map(func(n): return World.upgrade("swift", n, who).get("auto_attack", false)), range(1, top + 1).map(func(n): return n == top))
		_expect(out, "swift's card says so at its last level (%s)" % who, range(1, top + 1).map(func(n): return "최대: " in World.upgrade("swift", n, who).text), range(1, top + 1).map(func(n): return n == top))
	for who in Config.CHARACTERS:
		var near := Vector2(14.0, 0.0) if who != "mage" else Vector2(60.0, 0.0) # in its reach: a blow's, or an ember's
		for n in [top - 1, top]:
			var w = _night(DARK, _times("swift", n), who)
			w.player.invuln = NEVER # touching it would stun the keeper, who cannot attack then
			var dummy = _planted(w, "big_slime", near)
			var told := []
			var starts := 0
			for i in 120:
				var was: float = w.player.attack_t
				told.append_array(_play(w, 1))
				_hold_still(dummy, w.player.pos + near)
				starts += 1 if was < 0.0 and w.player.attack_t >= 0.0 else 0
			var cycle := ceili(World.character_stats(who).attack_time * World.upgrade("swift", n, who).attack_mult / Config.STEP - 0.0001)
			_expect(out, "%s with swift %d and an enemy in reach, no key pressed: attacks %s" % [who, n, "on every ready step" if n == top else "never"], starts, ceili(120.0 / cycle) if n == top else 0)
			if n == top:
				_expect(out, "%s's own attacks land by themselves (%s)" % [who, "cast" if who == "mage" else "hit"], told.has("cast" if who == "mage" else "hit"), true)
				# Pressing the key every step as well: no more attacks than the cooldown lets.
				var k = _night(DARK, _times("swift", n), who)
				k.player.invuln = NEVER
				var target = _planted(k, "big_slime", near)
				var pressed := 0
				for i in 120:
					var was: float = k.player.attack_t
					_play(k, 1, "attack")
					_hold_still(target, k.player.pos + near)
					pressed += 1 if was < 0.0 and k.player.attack_t >= 0.0 else 0
				_expect(out, "%s at swift's top, pressing too, attacks no faster than its cooldown" % who, pressed, starts)
		# Nothing in reach: no swing at the air.
		var idle = _night(DARK, _times("swift", top), who)
		_planted(idle, "slime", Vector2(idle.attack_range() + Config.ENEMY_TYPES.slime.radius + 20.0, 0.0) if who != "mage" else Vector2(0.0, -(idle.attack_range() + 30.0)))
		var swung := false
		for i in 60:
			_play(idle, 1)
			swung = swung or idle.player.attack_t >= 0.0
		_expect(out, "%s at swift's top with nothing in reach does not attack" % who, swung, false)
		# Carrying: it never puts its logs down, nor attacks.
		var c = _night(DARK, _times("swift", top), who)
		for i in c.stats.carry:
			c.player.take_log()
		c.player.invuln = NEVER
		_planted(c, "big_slime", near)
		var held: int = c.player.held
		var attacked := false
		for i in 60:
			_play(c, 1)
			attacked = attacked or c.player.attack_t >= 0.0
		_expect(out, "%s at swift's top carrying logs keeps them and does not attack" % who, [c.player.held, c.logs.size(), attacked], [held, 0, false])
	# A chop asks for an enemy inside the round it would come down on, not just within its far edge: with the long
	# haft at its top the round starts past a bat that overlaps the woodcutter's feet, and he does not chop at it.
	var haft = _night(DARK, _times("swift", top) + ["long_blade", "long_blade"], "woodcutter")
	haft.player.invuln = NEVER
	var under = _planted(haft, "bat", Vector2(3.0, 0.0))
	var chopped := false
	for i in 30:
		_play(haft, 1)
		_hold_still(under, haft.player.pos + Vector2(3.0, 0.0))
		chopped = chopped or haft.player.attack_t >= 0.0
	_expect(out, "the woodcutter at swift's top does not chop at a bat within reach but outside the round", [haft.player.pos.distance_to(under.pos) < haft.attack_range(), haft.foe_in_reach(haft.player.pos), chopped], [true, false, false])
	under.pos = haft.player.pos + Vector2(haft.chop_ahead(), 0.0)
	_expect(out, "... and does at one in the round", haft.foe_in_reach(haft.player.pos), true)
	# It turns to the nearest in reach: one in reach behind it, one nearer in reach above it.
	for who in ["knight", "woodcutter"]:
		var w = _night(DARK, _times("swift", top), who)
		w.player.face = Vector2.RIGHT
		_planted(w, "slime", Vector2(-18.0, 0.0))
		_planted(w, "slime", Vector2(0.0, -14.0))
		_play(w, 1)
		_expect(out, "%s at swift's top turns to the nearest enemy in reach" % who, [w.player.attack_t >= 0.0, w.player.face.is_equal_approx(Vector2.UP)], [true, true])
	var m = _night(DARK, _times("swift", top), "mage")
	m.player.face = Vector2.RIGHT
	_planted(m, "slime", Vector2(-70.0, 0.0))
	_planted(m, "slime", Vector2(0.0, 50.0))
	_play(m, 1)
	_expect(out, "the mage at swift's top shoots toward the nearest enemy within the ember's range", m.player.face.is_equal_approx(Vector2.DOWN), true)
	# The same game every time: two late runs with swift at its top, the bot playing, step for step.
	var ends := []
	for i in 2:
		var w = World.new(5, "woodcutter")
		w.begin_at(10, 1)
		w.picks.append_array(_times("swift", top - w.level("swift")))
		var bot = Bot.new(1)
		for s in 60 * 90:
			w.step(bot.frame(w))
		ends.append([w.night, w.time, w.score, w.player.pos, w.player.hp, w.enemies.size(), w.rng.state(), w.player.swings])
	_expect(out, "two runs with swift's auto attack end alike", ends[0], ends[1])
	return out


## A run is the night its seed gives, and every run a person starts gets a seed of its own. World.choose(id, seed)
## starts the run that keeper and that seed give, whatever the world was before: the offer a world made with them
## starts with and, played alike, the same world step for step. Another seed gives another offer. A world that
## restarts by itself keeps the seed it was handed. The ground the painter lays out again for a run
## (Painter.lay_ground) is its seed's, with nothing left of the run before. The seed main.gd draws from its two
## clocks (Main.fresh_seed) is always 1 to SEED_MOST, the same for the same clocks, another one a microsecond later,
## and a thousand starts a microsecond apart get nearly a thousand seeds, spread over the whole range.
static func _seeds() -> Array:
	var out := []
	var steps := 600
	var made = World.new(5, "mage")
	var chosen = World.new(1)
	chosen.choose("mage", 5)
	var played = World.new(9, "woodcutter")
	var bot = Bot.new(1)
	for i in steps:
		played.step(bot.frame(played))
	played.choose("mage", 5)
	for w in [chosen, played]:
		_expect(out, "choose(id, seed) starts the run a world made with that keeper and seed starts",
			[w.character, w.seed_value, w.offer, w.steps, w.rng.state()], [made.character, 5, made.offer, 0, made.rng.state()])
	var ends := []
	for w in [made, chosen, played]:
		for i in steps:
			w.step(bot.frame(w))
		ends.append(Replay.digest(w))
	_expect(out, "the worlds compared are not still at dusk: things have come at random while the bot played", made.rng.state() != World.new(5, "mage").rng.state(), true)
	_expect(out, "the same keeper and seed, played alike for %d steps, are the same world" % steps, [ends[1], ends[2]], [ends[0], ends[0]])
	var offers := {}
	for seed_value in range(1, 21):
		var w = World.new(1)
		w.choose("knight", seed_value)
		offers[",".join(w.offer)] = true
		_expect(out, "choose(knight, %d) deals seed %d's offer" % [seed_value, seed_value], w.offer, World.new(seed_value).offer)
	if offers.size() < 15:
		out.append("another seed gives another offer: 20 seeds dealt only %d different offers at dusk" % offers.size())
	var again = World.new(1)
	again.choose("knight", 6)
	var dusk: Array = again.offer.duplicate()
	again.phase = "out"
	_play(again, 1, "restart")
	_expect(out, "a world that restarts by itself keeps the seed it was handed", [again.seed_value, again.phase, again.offer], [6, "pick", dusk])
	var painter = Painter.new(1)
	var first: Array = painter.scenery.duplicate()
	painter.lay_ground(2)
	_expect(out, "the ground laid out again from another seed is that seed's, with nothing left of the last", [painter.scenery == Painter.new(2).scenery, painter.scenery == first], [true, false])
	painter.lay_ground(1)
	_expect(out, "and the first seed's again when it is laid out from that one", painter.scenery == first, true)
	var most: int = Main.SEED_MOST
	_expect(out, "a seed has at most six digits, to read off the screen and to type", most, 999999)
	var outside := []
	var edges := [0, 1, -1, 0x7fffffff, 0x80000000, 0xffffffff, 1 << 62, 9223372036854775807, -9223372036854775807 - 1, 1795766400000000]
	for a in edges:
		for b in edges:
			var s: int = Main.fresh_seed(a, b)
			if s < 1 or s > most:
				outside.append([a, b, s])
	var clock := 1795766400123456
	var ticks := 7654321
	var seed_then: int = Main.fresh_seed(clock, ticks)
	_expect(out, "fresh_seed is pure: the same two clocks give the same seed", Main.fresh_seed(clock, ticks), seed_then)
	_expect(out, "a microsecond later on either clock, or on both, the seed is another",
		[Main.fresh_seed(clock, ticks + 1) != seed_then, Main.fresh_seed(clock + 1, ticks) != seed_then, Main.fresh_seed(clock + 1, ticks + 1) != seed_then], [true, true, true])
	for moving in [[0, 1], [1, 0], [1, 1]]:
		var seen := {}
		var tenths := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		for i in 1000:
			var s: int = Main.fresh_seed(clock + i * moving[0], ticks + i * moving[1])
			if s < 1 or s > most:
				outside.append([clock + i * moving[0], ticks + i * moving[1], s])
			seen[s] = true
			tenths[clampi((s - 1) * 10 / most, 0, 9)] += 1
		if seen.size() < 990:
			out.append("1000 starts a microsecond apart (clocks moving by %s) got %d different seeds, want at least 990" % [moving, seen.size()])
		if tenths.min() < 50:
			out.append("1000 starts a microsecond apart (clocks moving by %s) got seeds that cluster: %s in the tenths of the range, want at least 50 in each" % [moving, tenths])
	_expect(out, "fresh_seed stays in 1..%d: for 0, 1, -1, the ends of an int and between, and for every start above ([clock, ticks, seed] outside)" % most, outside, [])
	return out


## The picture the paper ground's shader takes its colours from (Painter.ground_map) is the ground paint() paints
## without it: the view's size, GROUND out to the corners, and the clearing's own pixels where the clearing lies, so
## the earth under the torch is earth. The strips painted past it for a shake, with the view, fill the grown view.
static func _ground_map() -> Array:
	var out := []
	var map: Image = Painter.ground_map()
	_expect(out, "the ground map is the view's size", map.get_size(), Vector2i(Config.VIEW))
	var corners := []
	for at in [Vector2i.ZERO, Vector2i(Config.VIEW) - Vector2i.ONE]:
		corners.append(map.get_pixelv(at).to_html())
	_expect(out, "the ground map's far corners are GROUND", corners, [Painter.GROUND.to_html(), Painter.GROUND.to_html()])
	var earth: Image = Painter._clearing_image()
	var from := Vector2i(Painter.clearing_at())
	var wrong := []
	var bare := 0
	for y in Painter.CLEARING.y:
		for x in Painter.CLEARING.x:
			var own: Color = earth.get_pixel(x, y)
			var want: Color = own if own.a > 0.0 else Painter.GROUND
			bare += 1 if own.a > 0.0 else 0
			if map.get_pixelv(from + Vector2i(x, y)).to_html() != want.to_html() and wrong.size() < 5:
				wrong.append([x, y])
	_expect(out, "the ground map has the clearing's own colours where the clearing lies, GROUND round it (pixels of the clearing that differ)", wrong, [])
	var dirt := [Sprites.PALETTE["M"].to_html(), Sprites.PALETTE["m"].to_html(), Sprites.PALETTE["N"].to_html()]
	var under: String = map.get_pixelv(Vector2i(Config.TORCH.pos + Painter.CLEARING_DROP)).to_html()
	_expect(out, "under the torch the ground map is bare earth (%s is one of %s), and the clearing has earth in it" % [under, dirt], [dirt.has(under), bare > 0], [true, true])
	var view := Rect2(Vector2.ZERO, Config.VIEW)
	var area := view.get_area()
	var overlap := false
	for strip in Painter.margin_strips():
		area += strip.get_area()
		overlap = overlap or strip.intersects(view) or not view.grow(Juice.MARGIN).encloses(strip)
	_expect(out, "the strips past the view and the view fill the view grown by the shake's margin, the strips outside the view",
		[area, overlap], [view.grow(Juice.MARGIN).get_area(), false])
	return out


## Puts an enemy back where it stood, unhurt and unpushed: a target that stays in reach however often it is struck.
static func _hold_still(e, at: Vector2) -> void:
	e.pos = at
	e.hp = e.full_hp
	e.knock = Vector2.ZERO


## id, n times over: an upgrade at level n.
static func _times(id: String, n: int) -> Array:
	var out := []
	for i in n:
		out.append(id)
	return out


## The upgrades of a side that take one of its slots and that who can come to hold, in Config's order.
static func _slotted(side: String, who := "knight") -> Array:
	return Config.UPGRADES.keys().filter(func(id): return World.side(id) == side and World.takes_slot(id) and World.open_to(id, who))


## A world at its first dusk holding these upgrades (each at level 1), its offer drawn again for them.
static func _holding(seed_value: int, upgrades: Array, night := 1, who := "knight"):
	var w = World.new(seed_value, who)
	w.picks = upgrades.duplicate()
	w.night = night
	w._offer()
	return w


## A build with nothing left to offer: every slot of each side filled, each upgrade at its last level, and the
## upgrades that take no slot too.
static func _done_build() -> Array:
	var done := []
	for side in Config.BUILD.slots:
		for id in _slotted(side).filter(func(i): return World.max_level(i) > 1).slice(0, Config.BUILD.slots[side]):
			done.append_array(_times(id, World.max_level(id)))
	for id in Config.UPGRADES:
		if not World.takes_slot(id):
			done.append_array(_times(id, World.max_level(id)))
	return done


## build less the last level of n of its upgrades: those n, and nothing else, can still be offered.
static func _levels_short(build: Array, n: int) -> Array:
	var out := build.duplicate()
	for id in Config.UPGRADES:
		if n > 0 and out.count(id) > 1:
			out.erase(id)
			n -= 1
	return out


## The build (Config.BUILD): a side holds only so many different upgrades. A full side is never offered a new one and
## is still offered levels of what it holds; an upgrade with from_night takes no slot and is offered to a full side;
## over whole runs of offers no offer repeats a card, is ever short of a card, or takes a side past its slots; a rare
## card is drawn as often as its weight says. The table says what the screen and the rules need of it.
static func _build() -> Array:
	var out := []
	var B: Dictionary = Config.BUILD
	_expect(out, "each side the screen shows has slots, and no other does", B.slots.keys(), Looks.SIDES)
	var rare: Array = Config.UPGRADES.keys().filter(func(id): return Config.UPGRADES[id].get("rare", false))
	_expect(out, "some upgrades are rare, most are not", [rare.size() >= 2, rare.size() * 3 < Config.UPGRADES.size()], [true, true])
	_expect(out, "a rare card is drawn less often than another, but is drawn", B.rare_weight > 0.0 and B.rare_weight < 1.0, true)
	for id in Config.UPGRADES:
		_expect(out, "upgrade %s is on a side that has slots" % id, B.slots.has(Config.UPGRADES[id].get("side", "")), true)
		_expect(out, "the screen groups %s on the side the rules count it on" % id, Looks.side(id), World.side(id))
		_expect(out, "%s takes a slot unless it comes only from a later night or is a combined one" % id, World.takes_slot(id), not (Config.UPGRADES[id].has("from_night") or Config.UPGRADES[id].has("needs")))
		_expect(out, "%s weighs what its row says" % id, World.weight(id), B.combo_weight if Config.UPGRADES[id].has("needs") else B.rare_weight if rare.has(id) else 1.0)
	for side in B.slots:
		_expect(out, "the %s side has fewer slots than upgrades that want one, so a build is a choice" % side, [B.slots[side] >= 1, B.slots[side] < _slotted(side).size()], [true, true])
	for path in DirAccess.get_files_at("res://src/sim"):
		if path.ends_with(".gd"):
			_expect(out, "the simulation loads nothing from src/art (%s)" % path, FileAccess.get_file_as_string("res://src/sim/" + path).contains("res://src/art"), false)

	# A full side: never a new upgrade of that side, still the next levels of what it holds, and new ones of the other.
	for side in B.slots:
		var other: String = B.slots.keys().filter(func(s): return s != side)[0]
		var full: Array = _slotted(side).filter(func(id): return World.max_level(id) > 1).slice(0, B.slots[side])
		_expect(out, "the scene can fill the %s side with upgrades that have a next level" % side, full.size(), B.slots[side])
		var fresh := 0
		var levels := 0
		var others := 0
		for seed_value in range(1, 201):
			var w = _holding(seed_value, full)
			_expect(out, "a keeper holding %d %s upgrades has that side full" % [full.size(), side], [w.slots_used(side), w.slots_used(other)], [B.slots[side], 0])
			for id in w.offer:
				if Config.FILLERS.has(id):
					out.append("seed %d: a filler (%s) is offered while upgrades are left" % [seed_value, id])
				elif World.side(id) == side and not full.has(id) and World.takes_slot(id):
					fresh += 1
				elif World.side(id) == side:
					levels += 1
				else:
					others += 1
		_expect(out, "a full %s side is never offered a new upgrade (of 600 cards)" % side, fresh, 0)
		_expect(out, "a full %s side is still offered levels of what it holds, and the other side new upgrades" % side, [levels > 50, others > 50], [true, true])
		var w = _holding(1, full.slice(1))
		_expect(out, "one short of full, the %s side can still be offered a new upgrade" % side, _slotted(side).filter(func(id): return not full.has(id)).all(w.can_offer), true)

	# An upgrade that comes from a later night takes no slot: a full side is offered it and is no fuller for it.
	var late: Array = Config.UPGRADES.keys().filter(func(id): return Config.UPGRADES[id].has("from_night"))
	_expect(out, "some upgrade comes only from a later night", late.is_empty(), false)
	for id in late:
		var side: String = World.side(id)
		var from: int = Config.UPGRADES[id].from_night
		var full: Array = _slotted(side).slice(0, B.slots[side])
		var seen := 0
		for seed_value in range(1, 101):
			seen += _holding(seed_value, full, from).offer.count(id)
		_expect(out, "%s is offered to a full %s side from its night (some of 100 offers)" % [id, side], seen > 5, true)
		var w = _holding(1, full, from)
		_expect(out, "%s may be offered to a full side, not before its night" % id, [w.can_offer(id), _holding(1, full, from - 1).can_offer(id)], [true, false])
		w.offer = [id]
		_play(w, 1, "pick_1")
		_expect(out, "%s taken, the %s side holds one more upgrade and no more slots are used" % [id, side], [w.level(id), w.slots_used(side)], [1, B.slots[side]])

	# Whole runs of offers, a random card taken at each: every offer is full, repeats nothing, offers nothing that
	# cannot be taken, and no side ever holds more than its slots.
	var offers := 0
	var filler_offers := 0
	var per_night: int = 1 + Config.NIGHT.picks_at.size()
	for seed_value in range(1, 61):
		var w = World.new(seed_value)
		var dice = SimRng.new(seed_value + 500)
		var check := func(cards: Array) -> int:
			var once := {}
			for id in cards:
				once[id] = true
				if Config.UPGRADES.has(id) and not w.can_offer(id):
					out.append("seed %d night %d: %s is offered, but cannot be taken (levels %d, slots used %d)" % [seed_value, w.night, id, w.level(id), w.slots_used(World.side(id))])
			var there: int = Config.UPGRADES.keys().filter(w.can_offer).size() + Config.FILLERS.keys().filter(w.can_fill).size()
			if once.size() != cards.size() or cards.size() != mini(Config.NIGHT.offer_size, there):
				out.append("seed %d night %d: an offer holds %d different cards of %d (%d could come): %s" % [seed_value, w.night, once.size(), Config.NIGHT.offer_size, there, cards])
			var fillers: Array = cards.filter(func(id): return Config.FILLERS.has(id))
			if not fillers.is_empty() and cards.slice(cards.size() - fillers.size()) != fillers:
				out.append("seed %d night %d: fillers come before upgrades in an offer: %s" % [seed_value, w.night, cards])
			return dice.index(cards.size()) if seed_value % 2 == 0 else 0 # a random card, or always the first: a build done sooner
		for i in per_night * 24:
			w.play_offers(1, check)
			offers += 1
			filler_offers += 1 if w.offer.all(func(id): return Config.FILLERS.has(id)) else 0
			for side in B.slots:
				if w.slots_used(side) > B.slots[side]:
					out.append("seed %d night %d: the %s side holds %d upgrades in %d slots" % [seed_value, w.night, side, w.slots_used(side), B.slots[side]])
			for id in w.picks:
				if Config.FILLERS.has(id) or w.level(id) > World.max_level(id):
					out.append("seed %d night %d: the build holds %s %d times" % [seed_value, w.night, id, w.level(id)])
		_expect(out, "seed %d: 24 nights of offers end on the dusk of night 25" % seed_value, [w.night, w.picks_done, w.phase], [25, 0, "pick"])
	_expect(out, "the runs of offers reach builds with nothing left to offer", [offers, filler_offers > 0], [60 * per_night * 24, true])

	# A rare card is drawn as often as its weight says: the first card of 4000 first offers, where every upgrade
	# that may come on the first night is in the pool. Within a fifth of what the weights give (over three standard
	# deviations of the count); with the weight ignored it comes out near 470.
	var pool: Array = Config.UPGRADES.keys().filter(World.new(1).can_offer)
	_expect(out, "the first night's pool is the knight's rows that need no other upgrade and no later night", pool,
		Config.UPGRADES.keys().filter(func(id): return World.offered_on(id, 1) and World.open_to(id, "knight") and not Config.UPGRADES[id].has("needs")))
	var weights := 0.0
	var rare_weights := 0.0
	for id in pool:
		weights += B.rare_weight if rare.has(id) else 1.0 # from the table, not from World.weight: this is what holds it
		rare_weights += B.rare_weight if rare.has(id) else 0.0
	var draws := 4000
	var want: float = draws * rare_weights / weights
	var got := 0
	var each := {}
	for seed_value in range(1, draws + 1):
		var first: String = World.new(seed_value).offer[0]
		each[first] = each.get(first, 0) + 1
		got += 1 if rare.has(first) else 0
	if absf(got - want) > want * 0.2:
		out.append("a rare card comes first in %d of %d first offers; its weight (%.2f against 1) says %.0f, give or take a fifth" % [got, draws, B.rare_weight, want])
	_expect(out, "every upgrade of the first night comes first in some first offer", each.size(), pool.size())
	return out


## Fillers (Config.FILLERS): when the torch has fewer upgrades to offer than an offer holds, it fills the offer up
## with them, after the upgrades; with nothing left the offer is all fillers and a dusk is never empty. A filler
## taken does what its row says once, and is not part of the build.
static func _fillers() -> Array:
	var out := []
	var known := ["name", "text", "fuel", "heal", "logs", "log_at"]
	for id in Config.FILLERS:
		var row: Dictionary = Config.FILLERS[id]
		_expect(out, "filler %s has a name and a text, and is not also an upgrade" % id, [row.get("name", "") != "", row.get("text", "") != "", Config.UPGRADES.has(id)], [true, true, false])
		_expect(out, "filler %s sets only keys the rules read" % id, row.keys().all(func(k): return known.has(k)), true)
		_expect(out, "filler %s gives something" % id, row.get("fuel", 0.0) > 0.0 or row.get("heal", 0) > 0 or row.get("logs", 0) > 0, true)
		_expect(out, "filler %s has its icon" % id, Sprites.SPRITES.has(Looks.ICON % id), true)
	_expect(out, "there is a filler, so an offer is never empty", Config.FILLERS.is_empty(), false)
	var done := _done_build()
	var fills: int = mini(Config.NIGHT.offer_size, Config.FILLERS.size())
	for seed_value in range(1, 41):
		var w = _holding(seed_value, done, 30)
		var once := {}
		for id in w.offer:
			once[id] = true
		_expect(out, "seed %d: with nothing left to offer, the offer is fillers, each once, and the clock stops for it" % seed_value,
			[w.offer.all(func(id): return Config.FILLERS.has(id)), w.offer.size(), once.size(), w.phase], [true, fills, fills, "pick"])
	var w = _holding(1, _levels_short(done, 1), 30)
	_expect(out, "with one upgrade left, the offer is that upgrade and then fillers", [Config.UPGRADES.has(w.offer[0]), w.can_offer(w.offer[0]), w.offer.size(), w.offer.slice(1).all(func(id): return Config.FILLERS.has(id))], [true, true, Config.NIGHT.offer_size, true])
	# What each gives, from a hurt keeper and a low torch, and to the brim of a full one.
	for id in Config.FILLERS:
		var row: Dictionary = Config.FILLERS[id]
		w = _holding(1, done, 30)
		w.fuel = 20.0
		w.player.hp = 1
		w.logs = []
		w.offer = [id]
		var steps_before: int = w.steps
		var told := _play(w, 1, "pick_1")
		_expect(out, "filler %s taken: the night goes on, the build is as it was, and the screen is told" % id, [w.phase, w.picks, w.offer, told.has("took"), w.steps], ["night", done, [], true, steps_before + 1])
		_expect(out, "filler %s gives the fuel its row says, now" % id, w.fuel, 20.0 + row.get("fuel", 0.0))
		_expect(out, "filler %s heals the hearts its row says, now" % id, w.player.hp, 1 + row.get("heal", 0))
		_expect(out, "filler %s drops the logs its row says" % id, w.logs.size(), row.get("logs", 0))
		for l in w.logs:
			_expect(out, "filler %s drops each log its log_at from the torch, on the field, out of the torch's reach" % id,
				[snappedf(l.distance_to(Config.TORCH.pos), 0.001), Config.FIELD.has_point(l), l.distance_to(Config.TORCH.pos) > Config.TORCH.reach + Config.PLAYER.radius + Config.PLAYER.grab], [row.log_at, true, true])
		if w.logs.size() > 1:
			_expect(out, "filler %s drops its logs apart" % id, w.logs[0].distance_to(w.logs[1]) > Config.PLAYER.grab * 2.0, true)
		w = _holding(1, done, 30)
		w.fuel = w.max_fuel() - 1.0
		w.player.hp = w.max_hp()
		w.offer = [id]
		_play(w, 1, "pick_1")
		_expect(out, "filler %s fills neither the torch nor the keeper past full" % id, [w.fuel <= w.max_fuel(), w.player.hp], [true, w.max_hp()])
	# A filler that would give nothing is not offered: hearts to an unhurt keeper. Fuel and logs may always come, so
	# an offer is never empty.
	var healers: Array = Config.FILLERS.keys().filter(func(id): return not (Config.FILLERS[id].has("fuel") or Config.FILLERS[id].has("logs")))
	_expect(out, "some filler only heals, and others can always come", [healers.is_empty(), healers.size() < Config.FILLERS.size()], [false, true])
	var unhurt := 0
	var hurt := 0
	for seed_value in range(1, 101):
		w = _holding(seed_value, done, 30)
		w.player.hp = w.max_hp()
		w.fuel = w.max_fuel()
		w._offer()
		unhurt += w.offer.filter(func(id): return healers.has(id)).size()
		_expect(out, "seed %d: an unhurt keeper by a full torch is still offered every other filler, each once" % seed_value,
			[w.offer.size(), w.phase, w.offer.all(func(id): return Config.FILLERS.has(id) and w.can_fill(id))], [mini(Config.NIGHT.offer_size, Config.FILLERS.size() - healers.size()), "pick", true])
		_press(w, "reroll")
		unhurt += w.offer.filter(func(id): return healers.has(id)).size()
		w.player.hp -= 1
		w._offer()
		hurt += w.offer.filter(func(id): return healers.has(id)).size()
	_expect(out, "a filler that only heals is never offered to an unhurt keeper (100 offers, each rerolled)", unhurt, 0)
	_expect(out, "it is offered to a hurt one (100 offers)", hurt > 50, true)
	_expect(out, "the fuel filler's card says it stops at a full torch", Config.FILLERS.values().filter(func(row): return row.has("fuel")).all(func(row): return "가득" in row.text), true)
	# An offer answered without its night (play_offers) takes the card and gives nothing: there is no night to help.
	w = _holding(1, done, 30)
	w.fuel = 20.0
	w.player.hp = 1
	w.logs = []
	var skipped := []
	w.play_offers(3, func(cards: Array) -> int:
		skipped.append(cards[0])
		return 0)
	_expect(out, "fillers taken by play_offers give no fuel, no hearts and no logs", [skipped.size(), skipped.all(func(id): return Config.FILLERS.has(id)), w.fuel, w.player.hp, w.logs, w.picks], [3, true, 20.0, 1, [], done])
	# A late start (begin_at) past a done build takes fillers on its way and still starts rested, the torch at its
	# start share, no logs lying.
	for slot in [1, 2, 3]:
		w = World.new(4)
		w.begin_at(30, slot)
		_expect(out, "begin_at(30) with slot %d starts at that dusk, rested, the torch at its start share, no filler's logs lying" % slot,
			[w.night, w.picks_done, w.phase, w.logs, w.player.hp, snappedf(w.fuel, 0.001)], [30, 0, "pick", [], w.max_hp(), snappedf(Config.TORCH.start_fuel * w.max_fuel() / Config.TORCH.max_fuel, 0.001)])
		_expect(out, "begin_at(30) with slot %d leaves no side past its slots" % slot, Config.BUILD.slots.keys().all(func(side): return w.slots_used(side) <= Config.BUILD.slots[side]), true)
	return out


static func _press(w, action: String) -> void:
	var f := InputFrame.new()
	f.pressed[action] = true
	w.step(f)


## Rerolls (Config.BUILD.rerolls a run): "reroll" pressed while an offer is up draws it again, leaving out the cards
## just shown wherever enough others exist, and uses one up; with none left, or outside the pick phase, it does
## nothing at all (the rng is not touched); a new run has them all again. The bot never rerolls.
static func _rerolls() -> Array:
	var out := []
	var most: int = Config.BUILD.rerolls
	_expect(out, "a run has a couple of rerolls", most >= 1 and most <= 3, true)
	var others_seen := 0
	for seed_value in range(1, 101):
		var w = World.new(seed_value)
		_expect(out, "seed %d: a run starts with every reroll" % seed_value, [w.rerolls, w.can_reroll()], [most, true])
		for n in most:
			var shown: Array = w.offer.duplicate()
			_press(w, "reroll")
			var again: Array = w.offer.filter(func(id): return shown.has(id))
			others_seen += w.offer.size() - again.size()
			if not again.is_empty():
				out.append("seed %d: reroll %d shows %s again (was %s, now %s), with %d other upgrades to draw" % [seed_value, n + 1, again, shown, w.offer, Config.UPGRADES.size() - shown.size()])
			_expect(out, "seed %d: reroll %d costs one, keeps the offer up and full, and takes nothing" % [seed_value, n + 1],
				[w.rerolls, w.phase, w.offer.size(), w.picks, w.steps], [most - n - 1, "pick", Config.NIGHT.offer_size, [], n + 1])
		var shown: Array = w.offer.duplicate()
		var state = w.rng.state()
		_press(w, "reroll")
		_expect(out, "seed %d: with none left a reroll does nothing: the same cards, the rng untouched" % seed_value, [w.rerolls, w.offer, w.rng.state(), w.can_reroll(), w.phase], [0, shown, state, false, "pick"])
		_press(w, "pick_1")
		_expect(out, "seed %d: a rerolled offer is taken like any other" % seed_value, [w.picks, w.phase], [[shown[0]], "night"])
		state = w.rng.state()
		w.rerolls = most
		w.next_spawn = NEVER
		w.next_wood = NEVER
		w.next_berry = NEVER
		w.surges_due = []
		_press(w, "reroll")
		_expect(out, "seed %d: outside the pick phase a reroll is ignored" % seed_value, [w.rerolls, w.offer, w.rng.state(), w.phase, w.can_reroll()], [most, [], state, "night", false])
		w.rerolls = 0
		w.reset()
		_expect(out, "seed %d: a new run has every reroll again" % seed_value, w.rerolls, most)
	_expect(out, "rerolls showed other cards", others_seen, 100 * most * Config.NIGHT.offer_size)
	# Too few others: the cards just shown come back only to fill the offer, after the others.
	var size: int = Config.NIGHT.offer_size
	var w = _holding(1, _levels_short(_done_build(), size + 1), 30)
	var left: Array = Config.UPGRADES.keys().filter(w.can_offer)
	var shown: Array = w.offer.duplicate()
	_expect(out, "the scene has one more upgrade to offer than an offer holds", [left.size(), shown.all(func(id): return left.has(id))], [size + 1, true])
	_press(w, "reroll")
	_expect(out, "with one other upgrade to draw, a reroll shows it first and fills the offer with cards just shown, no filler",
		[shown.has(w.offer[0]), w.offer.size(), w.offer.slice(1).all(func(id): return shown.has(id)), w.rerolls], [false, size, true, most - 1])
	# No other card at all: a reroll would only shuffle the same cards, so it is not taken and costs nothing.
	w = _holding(1, _levels_short(_done_build(), size), 30)
	shown = w.offer.duplicate()
	_expect(out, "the scene has as many upgrades to offer as an offer holds", shown.all(func(id): return Config.UPGRADES.has(id)), true)
	_press(w, "reroll")
	_expect(out, "with no card but those shown, a reroll does nothing and costs nothing", [w.offer, w.rerolls, w.can_reroll()], [shown, most, false])
	# Fewer upgrades than an offer holds: they stay, and the fillers beside them are others where there are others.
	w = _holding(1, _levels_short(_done_build(), size - 1), 30)
	shown = w.offer.duplicate()
	_press(w, "reroll")
	var fresh: int = mini(1, Config.FILLERS.size() - 1)
	_expect(out, "with fewer upgrades than an offer holds, a reroll keeps them and draws other fillers where there are any",
		[w.offer.slice(0, size - 1).all(func(id): return Config.UPGRADES.has(id) and shown.has(id)), w.offer.slice(size - 1).filter(func(id): return not shown.has(id)).size(), w.rerolls], [true, fresh, most - fresh])
	# A reroll pressed that cannot be taken is not there: a card picked in the same step is taken. One that can be
	# taken comes first, and nothing is picked.
	var both := InputFrame.new()
	both.pressed["reroll"] = true
	both.pressed["pick_2"] = true
	w = World.new(3)
	w.rerolls = 0
	var cards: Array = w.offer.duplicate()
	w.step(both)
	_expect(out, "with no reroll left, a card picked in the same step as a reroll press is taken", [w.picks, w.phase, w.rerolls], [[cards[1]], "night", 0])
	w = World.new(3)
	w.step(both)
	_expect(out, "with a reroll left, a reroll pressed with a pick draws again and takes nothing", [w.picks, w.phase, w.rerolls, w.offer.any(func(id): return cards.has(id))], [[], "pick", most - 1, false])
	# The bot plays its runs without one: the replay, the balance tool and the demo are what they are without rerolls.
	for slot in [1, 2, 3]:
		var run = World.new(slot + 20)
		var bot = Bot.new(slot)
		var pressed := 0
		var offers := 0
		for s in 60 * 150:
			var f = bot.frame(run)
			pressed += 1 if f.is_pressed("reroll") else 0
			offers += 1 if run.phase == "pick" else 0
			run.step(f)
			if run.phase in ["out", "dead"]:
				break
		_expect(out, "the bot (slot %d) never rerolls: it met offers, pressed no reroll and has them all left" % slot, [offers >= 3, pressed, run.rerolls], [true, 0, most])
	return out


## The HUD's slots (Painter.tiles, Painter.empty_slots): each side's row is as long as its slots, the held upgrades
## from the left, the rest empty; an upgrade that takes no slot has its tile past the row's last slot; no two overlap.
static func _slot_tiles() -> Array:
	var out := []
	var B: Dictionary = Config.BUILD
	var free: Array = Config.UPGRADES.keys().filter(func(id): return not World.takes_slot(id))
	for held in [[], [_slotted("torch")[0]], _slotted("keeper").slice(0, B.slots.keeper) + free, _slotted("torch").slice(0, B.slots.torch) + _slotted("keeper").slice(0, 2) + free]:
		var w = _night(LIT, held)
		var tiles: Dictionary = Painter.tiles(w)
		var empty: Array = Painter.empty_slots(w)
		_expect(out, "holding %d upgrades, each has a tile" % held.size(), tiles.size(), held.size())
		var rects := []
		for row in Looks.SIDES.size():
			var side: String = Looks.SIDES[row]
			var filled: Array = held.filter(func(id): return World.side(id) == side and World.takes_slot(id))
			var hollow: Array = empty.filter(func(s): return s[1] == side)
			_expect(out, "holding %d upgrades, the %s side shows its slots: the filled and the empty make up all of them" % [held.size(), side], filled.size() + hollow.size(), B.slots[side])
			var last_slot_end: float = Painter.HUD_PICKS.x + (B.slots[side] - 1) * Painter.TILE_STEP.x + Painter.TILE.x
			for id in filled:
				_expect(out, "%s sits in a slot of its row" % id, [tiles[id].x + Painter.TILE.x <= last_slot_end, tiles[id].y], [true, Painter.HUD_PICKS.y + row * Painter.TILE_STEP.y])
			for s in hollow:
				_expect(out, "an empty %s slot is in its row, right of the filled ones" % side, [s[0].y, s[0].x + Painter.TILE.x <= last_slot_end, filled.all(func(id): return tiles[id].x < s[0].x)], [Painter.HUD_PICKS.y + row * Painter.TILE_STEP.y, true, true])
			for id in held.filter(func(i): return World.side(i) == side and not World.takes_slot(i)):
				_expect(out, "%s, which takes no slot, is past its row's last slot" % id, tiles[id].x > last_slot_end, true)
		for at in tiles.values() + empty.map(func(s): return s[0]):
			rects.append(Rect2(at, Painter.TILE))
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					out.append("holding %d upgrades, two HUD tiles overlap: %s and %s" % [held.size(), rects[i], rects[j]])
			_expect(out, "holding %d upgrades, the HUD's panel is behind every tile" % held.size(), rects[i].end.y <= Painter.hud_bottom(w) and rects[i].end.x <= Painter.new(1).hud_right(w), true)
	# The offer's box has the reroll button to fit under its cards and the HUD's two rows of slots above it: no
	# card's words (any upgrade at any level for any keeper, any filler) take more lines than Ui.CARD_LINES.
	# An ingredient's card also says what it combines into (Ui.combo_hint), on lines of its own under its words.
	var font := Ui.font(Ui.SMALL)
	var texts := Config.FILLERS.values().map(func(row): return [row.text])
	for who in Config.CHARACTERS:
		var keeper = _night(LIT, [], who)
		for id in Config.UPGRADES:
			for n in range(1, World.max_level(id) + 1):
				texts.append([World.upgrade(id, n, who).text, Ui.combo_hint(keeper, id)])
	for text in texts:
		var lines := 0
		for part in text:
			lines += Ui.wrapped(font, part, Ui.CARD_TEXT_WIDTH).count("\n") + 1 if part != "" else 0
		if lines > Ui.CARD_LINES:
			out.append("a card's words take %d lines (at most %d fit the offer under the HUD): %s" % [lines, Ui.CARD_LINES, text])
	return out


## Every card that was on a table over a run of offers for who: nights of them, a random card taken at each.
static func _offered(who: String, seed_value: int, nights: int) -> Dictionary:
	var w = World.new(seed_value, who)
	var dice = SimRng.new(seed_value + 900)
	var seen := {}
	w.play_offers(nights * (1 + Config.NIGHT.picks_at.size()), func(cards: Array) -> int:
		for id in cards:
			seen[id] = seen.get(id, 0) + 1
		return dice.index(cards.size()))
	return seen


## Upgrades of one character (a row's only): the torch offers the row to that character and never to another, over
## many runs of offers; to its own it comes like any other row and takes a slot of its side. Each character has two.
static func _only() -> Array:
	var out := []
	var own := {}
	for who in Config.CHARACTERS:
		own[who] = []
	for id in Config.UPGRADES:
		var row: Dictionary = Config.UPGRADES[id]
		if not row.has("only"):
			continue
		_expect(out, "%s is for a character there is, takes a slot and combines nothing" % id, [Config.CHARACTERS.has(row.only), World.takes_slot(id), row.has("needs")], [true, true, false])
		if own.has(row.only):
			own[row.only].append(id)
		for who in Config.CHARACTERS:
			_expect(out, "%s may be offered to %s only if it is theirs" % [id, who], [World.open_to(id, who), World.new(1, who).can_offer(id)], [who == row.only, who == row.only])
	for who in Config.CHARACTERS:
		_expect(out, "%s has two upgrades of its own" % who, own[who].size(), 2)
		var seen := {}
		for seed_value in range(1, 81):
			var run := _offered(who, seed_value, 12)
			for id in run:
				seen[id] = seen.get(id, 0) + run[id]
		for id in seen:
			if Config.UPGRADES.has(id) and not World.open_to(id, who):
				out.append("%s is offered %s, which is %s's alone, %d times over 80 runs of offers" % [who, id, Config.UPGRADES[id].only, seen[id]])
		for id in own[who]:
			_expect(out, "%s is offered its own %s over 80 runs of offers" % [who, id], seen.get(id, 0) > 20, true)
			var w = _night(LIT, [], who)
			var used: int = w.slots_used(World.side(id))
			w.picks.append(id)
			_expect(out, "%s held takes one of the %s side's slots" % [id, World.side(id)], w.slots_used(World.side(id)), used + 1)
	return out


## Combined upgrades (a row's needs): offered only while both upgrades it names are held, never with one or none;
## whoever holds both sees it within a few offers (Config.BUILD.combo_weight); it takes no slot, so a full side is
## offered it too; an ingredient's card says what it combines with and into what, until the combined one is held.
static func _needs() -> Array:
	var out := []
	var combos: Array = Config.UPGRADES.keys().filter(func(id): return Config.UPGRADES[id].has("needs"))
	_expect(out, "there are combined upgrades, and one is drawn more often than any other card", [combos.size() >= 4, Config.BUILD.combo_weight > 1.0], [true, true])
	var parts := {}
	for made in combos:
		var needs: Array = Config.UPGRADES[made].needs
		var side: String = World.side(made)
		_expect(out, "%s combines two different upgrades, neither combined nor one character's alone, and is no one's alone" % made,
			[needs.size(), needs[0] != needs[-1], needs.all(func(id): return Config.UPGRADES.has(id) and not Config.UPGRADES[id].has("needs") and not Config.UPGRADES[id].has("only")), Config.UPGRADES[made].has("only")], [2, true, true, false])
		_expect(out, "%s takes no slot, has one level and weighs what a combined card weighs" % made, [World.takes_slot(made), World.max_level(made), World.weight(made)], [false, 1, Config.BUILD.combo_weight])
		for id in needs:
			_expect(out, "%s goes into one combined upgrade only (its card has one line to say so)" % id, parts.has(id), false)
			parts[id] = made
		for who in Config.CHARACTERS:
			var soon := 0
			for seed_value in range(1, 101):
				for held in [[], [needs[0]], [needs[1]]]:
					var short = _holding(seed_value, held, 1, who)
					var shown: Array = short.offer.duplicate()
					for again in Config.BUILD.rerolls:
						_press(short, "reroll")
						shown.append_array(short.offer)
					if short.can_offer(made) or shown.has(made):
						out.append("seed %d: %s holding %s is offered %s, which needs %s" % [seed_value, who, held, made, needs])
				var w = _holding(seed_value, needs, 1, who)
				_expect(out, "seed %d: %s holding %s may be offered %s" % [seed_value, who, needs, made], w.can_offer(made), true)
				var seen: bool = w.offer.has(made)
				for again in 2:
					w._offer()
					seen = seen or w.offer.has(made)
				soon += 1 if seen else 0
			_expect(out, "%s holding %s sees %s within three offers in most of 100 seeds (%d)" % [who, needs, made, soon], soon >= 75, true)
			var w = _holding(1, needs, 1, who)
			var used: int = w.slots_used(side)
			w.offer = [made]
			_play(w, 1, "pick_1")
			_expect(out, "%s taken by %s: held, no slot of the %s side used for it, and not offered again" % [made, who, side], [w.level(made), w.slots_used(side), w.can_offer(made)], [1, used, false])
			var keeper = _night(LIT, [], who)
			for i in 2:
				_expect(out, "%s's card for %s says what it combines with and into what" % [who, needs[i]], Ui.combo_hint(keeper, needs[i]),
					Ui.COMBO_HINT % [World.upgrade_row(needs[1 - i], who).name, World.upgrade_row(made, who).name])
			keeper.picks = [made]
			_expect(out, "once %s holds %s its ingredients say nothing of it" % [who, made], [Ui.combo_hint(keeper, needs[0]), Ui.combo_hint(keeper, needs[1])], ["", ""])
		var full: Array = needs.duplicate()
		for id in _slotted(side):
			if not full.has(id) and full.filter(func(x): return World.side(x) == side).size() < Config.BUILD.slots[side]:
				full.append(id)
		var w = _holding(1, full)
		_expect(out, "%s is offered to a full %s side that holds both" % [made, side], [w.slots_used(side), w.can_offer(made)], [Config.BUILD.slots[side], true])
	var plain: Array = Config.UPGRADES.keys().filter(func(id): return not parts.has(id) and not combos.has(id))
	_expect(out, "an upgrade that goes into no combined one says nothing of one", Ui.combo_hint(_night(LIT), plain[0]), "")
	_expect(out, "a combined card has its own colour, not the rare one's nor a plain card's", [Ui.COMBO != Ui.RARE, Ui.COMBO != Ui.CARD_EDGE, Ui.RARE, Ui.COMBO], [true, true, Sprites.PALETTE["p"], Sprites.PALETTE["L"]])
	return out


## The characters' own upgrades do what their rows say. guard: a hit keeps the knight safe longer and throws back
## what stands round it. momentum: a kill makes it walk faster for a while. splitter: an enemy the woodcutter's axe
## kills leaves a log now and then, rolled on the world's rng and only by one who has it. big_pack: one more log
## carried. piercing: the mage's ember goes through more. kindle: an enemy an ember kills throws a spark at the
## nearest other in reach, and that spark's kill throws none.
static func _own_rows() -> Array:
	var out := []
	for n in [0, 1, 2]:
		var G: Dictionary = World.upgrade("guard", maxi(n, 1))
		var w = _night(LIT, _times("guard", n))
		var hitter = _planted(w, "slime", Vector2(8.0, 0.0))
		var near = _planted(w, "slime", Vector2(0.0, 34.0)) # its body within the first level's reach
		var mid = _planted(w, "slime", Vector2(0.0, -46.0)) # within the second level's only
		var far = _planted(w, "slime", Vector2(-70.0, 0.0))
		_expect(out, "the guard scene's slimes stand where the levels' reaches tell them apart",
			[34.0 < World.upgrade("guard", 1).guard_reach + near.T.radius, 46.0 < World.upgrade("guard", 1).guard_reach + mid.T.radius, 46.0 < World.upgrade("guard", 2).guard_reach + mid.T.radius, 70.0 < World.upgrade("guard", 2).guard_reach + far.T.radius], [true, false, true, false])
		var told := _play(w, 1)
		_expect(out, "guard at level %d: a hit costs a heart and keeps the knight from the next for its invuln more" % n,
			[w.player.hp, snappedf(w.player.invuln, 0.001)], [Config.PLAYER.hp - 1, snappedf(w.keeper_invuln() + (G.guard_invuln if n > 0 else 0.0), 0.001)])
		var dmg: int = G.guard_damage if n > 0 else 0
		_expect(out, "guard at level %d: the hit throws back the enemies within its reach, away from the knight, and does them its damage" % n,
			[near.knock.y > 0.0, mid.knock.y < 0.0, far.knock != Vector2.ZERO, told.count("wave"), hitter.hp, near.hp, mid.hp, far.hp],
			[n >= 1, n >= 2, false, mini(n, 1), hitter.full_hp - dmg, near.full_hp - dmg, mid.full_hp - (dmg if n >= 2 else 0), far.full_hp])
		if told.has("wave"):
			var wave: Dictionary = w.events.filter(func(ev): return ev.kind == "wave")[0]
			_expect(out, "guard at level %d tells the screen where and how far" % n, [wave.pos, wave.radius, Effects.RINGS.has(wave.ring)], [w.player.pos, G.guard_reach, true])
	for n in [0, 1, 2]:
		var M: Dictionary = World.upgrade("momentum", maxi(n, 1))
		var w = _night(LIT, _times("momentum", n))
		_add(w, "bat", NEAR)
		var told := _play(w, SWING, "attack")
		var from: float = w.player.pos.x
		_play(w, 30, "", "right")
		var fast: float = (w.player.pos.x - from) / (30 * Config.STEP)
		var swing: float = w.stat("attack_time")
		_play(w, roundi(M.haste_time / Config.STEP))
		from = w.player.pos.x
		_play(w, 30, "", "right")
		var after: float = (w.player.pos.x - from) / (30 * Config.STEP)
		_expect(out, "momentum at level %d: after a kill the knight walks its haste times as fast and its swing takes haste_attack of its time; both as before once haste_time is over" % n,
			[told.has("kill"), snappedf(fast, 0.01), snappedf(swing, 0.0001), snappedf(after, 0.01), w.stat("attack_time")],
			[true, snappedf(Config.PLAYER.speed * (M.haste if n > 0 else 1.0), 0.01), snappedf(Config.PLAYER.attack_time * (M.haste_attack if n > 0 else 1.0), 0.0001), Config.PLAYER.speed, Config.PLAYER.attack_time])
	for n in [0, 1, 2]:
		var chance: float = World.upgrade("splitter", n).log_chance if n > 0 else 0.0
		var w = _night(LIT, _times("splitter", n), "woodcutter")
		var state: int = w.rng.state()
		var kills := 600
		for i in kills:
			var e = _add(w, "slime", Vector2(20.0, 0.0))
			w._damage(e, e.hp, w.player.pos, true)
		var spread: float = 4.0 * sqrt(kills * chance * (1.0 - chance))
		if absf(w.logs.size() - kills * chance) > spread:
			out.append("splitter at level %d: %d of %d enemies the axe killed left a log; its chance (%.2f) says %.0f, give or take %.0f" % [n, w.logs.size(), kills, chance, kills * chance, spread])
		_expect(out, "splitter at level %d: the logs lie where the enemies fell, and only one who has it rolls for them" % n,
			[w.logs.all(func(l): return l == w.player.pos + Vector2(20.0, 0.0)), w.rng.state() == state], [true, n == 0])
	var w = _night(LIT, _times("splitter", 2), "woodcutter")
	var state: int = w.rng.state()
	for i in 200:
		var e = _add(w, "slime", Vector2(20.0, 0.0))
		w._damage(e, e.hp, w.player.pos)
	_expect(out, "splitter: an enemy killed by anything but the keeper's own blow leaves no log and rolls nothing", [w.logs.size(), w.rng.state()], [0, state])
	for i in 200:
		var e = _add(w, "slime", Vector2.ZERO)
		e.pos = Config.FIELD.end + Vector2(10.0, 10.0)
		w._damage(e, e.hp, w.player.pos, true)
	_expect(out, "splitter: a log left by an enemy killed off the field lies on its edge", [w.logs.size() > 10, w.logs.all(func(l): return l == Config.FIELD.end)], [true, true])
	w = _night(LIT, _times("splitter", 2), "woodcutter")
	for i in 40:
		_add(w, "bat", Vector2(w.chop_ahead(), 0.0))
		_play(w, roundi(w.stat("attack_time") / Config.STEP) + 2, "attack")
	_expect(out, "splitter: 40 bats chopped down leave some logs, not forty", [w.enemies.size(), w.logs.size() > 0, w.logs.size() < 20], [0, true, true])
	for n in [0, 1]:
		var carry: int = World.character_stats("woodcutter").carry
		w = _night(DARK, _times("big_pack", n), "woodcutter")
		for i in carry + 2:
			w.logs.append(w.player.pos)
		_play(w, carry + 3)
		_expect(out, "big_pack at level %d: the woodcutter carries that many more logs, and no more" % n, [w.carry(), w.player.held, w.logs.size()], [carry + n, carry + n, 2 - n])
		w.fuel = 10.0
		w.player.pos = Config.TORCH.pos
		var told := _play(w, 1)
		_expect(out, "big_pack at level %d: every log carried goes on the fire" % n, [told.count("fed"), w.player.held, w.score], [carry + n, 0, (carry + n) * Config.SCORE.log])
	var B: Dictionary = World.character_stats("mage").bolt
	for lit in [false, true]:
		for n in [0, 1, 2]:
			w = _night(Vector2(-50.0, 0.0) if lit else DARK, _times("piercing", n), "mage")
			var line := []
			for i in 4:
				line.append(_still(_add(w, "slime", Vector2(20.0 + 25.0 * i, 0.0)))) # apart by more than a burst reaches
			var told := _play(w, 60, "attack")
			var through: int = B.pierce + (B.lit_pierce if lit else 0) + (World.upgrade("piercing", n).pierce_bonus if n > 0 else 0)
			var want := []
			for i in line.size():
				want.append(i <= through)
			_expect(out, "piercing at level %d, %s: the ember burns %d in a line and stops" % [n, "in the light" if lit else "in the dark", through + 1], line.map(func(e): return e.hp < e.full_hp), want)
			_expect(out, "piercing at level %d, %s: the ember bursts where it stops, and with piercing on each enemy it goes through" % [n, "in the light" if lit else "in the dark"], told.count("burst"), through + 1 if n > 0 else 1)
	for n in [0, 1, 2]:
		var reach: float = World.upgrade("kindle", n).kindle_reach if n > 0 else 0.0
		for gap in [44.0, 70.0]: # how far beside the bat the other stands: within the first level's reach, within the second's only
			w = _night(DARK, _times("kindle", n), "mage")
			var bat = _still(_add(w, "bat", Vector2(30.0, 0.0)))
			var other = _still(_add(w, "big_slime", Vector2(30.0, gap)))
			var far = _still(_add(w, "big_slime", Vector2(30.0, -120.0)))
			var thrown: bool = gap - other.T.radius < reach
			var told := _play(w, 70, "attack")
			_expect(out, "kindle at level %d, another enemy %d away: the bat the ember kills throws a spark at it only within its reach, and it burns for a spark's damage" % [n, gap],
				[bat.dead, told.count("shot"), other.hp, far.hp, w.sparks.size()], [true, 1 if thrown else 0, other.full_hp - (Config.SPARK.damage if thrown else 0), far.full_hp, 0])
	w = _night(DARK, ["kindle"], "mage")
	_still(_add(w, "bat", Vector2(30.0, 0.0)))
	var second = _still(_add(w, "bat", Vector2(30.0, 30.0)))
	var third = _still(_add(w, "big_slime", Vector2(30.0, 62.0)))
	var told := _play(w, 70, "attack")
	_expect(out, "kindle: the spark kills the second bat, and a spark's kill throws no spark", [second.dead, told.count("shot"), third.hp], [true, 1, third.full_hp])
	return out


## The combined upgrades do what their rows say, and nothing without them. scorch: the ember ring burns an enemy's
## last point away. beacon: an enemy the keeper's blow hits in the light is what the torch's sparks go for, and the
## next comes sooner. bramble: a dash hurts each enemy it passes through, once. blast: logs put on the fire throw
## back the enemies near the torch.
static func _combined_rows() -> Array:
	var out := []
	for with in [false, true]:
		var w = _night(DARK, ["ember_ring", "warm_glow"] + (["scorch"] if with else []))
		var e = Enemy.new("slime", Config.TORCH.pos + Vector2(20.0, 0.0))
		w.enemies.append(e)
		var told := _play(w, roundi(w.mod("ember_every", 1.0) * 3.0 / Config.STEP))
		_expect(out, "the ember ring %s: a slime in it for three burns %s" % ["with scorch" if with else "alone", "is burnt away, and scored" if with else "is left at 1"],
			[e.dead, e.hp, told.has("kill"), w.score], [with, 0 if with else 1, with, Config.SCORE.kill if with else 0])
	for who in Config.CHARACTERS:
		for with in [false, true]:
			var w = _night(Vector2(-70.0, 0.0) if who == "mage" else Vector2(40.0, 0.0), ["spark", "fire_blade"] + (["beacon"] if with else []), who)
			w.fuel = Config.TORCH.max_fuel
			var by_torch = _still(_add(w, "big_slime", Vector2.ZERO))
			by_torch.pos = Config.TORCH.pos + Vector2(0.0, 24.0) # nearer the torch than the one the keeper strikes
			var struck = _still(_add(w, "big_slime", Vector2(w.chop_ahead() if who == "woodcutter" else 40.0 if who == "mage" else NEAR.x, 0.0)))
			var every: float = w.mod("spark_every", 0.0)
			w.next_spark = every # as if the torch had just fired
			_play(w, 30, "attack")
			_expect(out, "%s's blow lands on the enemy in the light and leaves it alive (the beacon scene)" % who, [struck.hp < struck.full_hp, struck.dead, w.in_light(struck.pos)], [true, false, true])
			_expect(out, "%s %s: the enemy its blow hit in the light is marked, and the next spark comes within mark_haste of the usual wait" % [who, "with beacon" if with else "without"],
				[w.marked == struck, w.next_spark == every, w.next_spark <= w.time + every * World.upgrade("beacon", 1).mark_haste], [with, not with, with])
			var steps := 30
			while w.sparks.is_empty() and steps < 600:
				_play(w, 1)
				steps += 1
			var from: Vector2 = Config.TORCH.pos + Config.SPARK.mouth
			var aimed = struck if with else by_torch
			_expect(out, "%s %s: the torch's next spark goes for %s" % [who, "with beacon" if with else "without", "the marked enemy" if with else "the enemy nearest the torch"],
				[w.sparks.size(), snappedf(w.sparks[0].vel.normalized().dot((aimed.pos - from).normalized()), 0.01) if not w.sparks.is_empty() else 0.0, steps * Config.STEP < every * 0.75], [1, 1.0, with])
			if with:
				w._damage(struck, struck.hp, w.player.pos)
				w.sparks = []
				w.next_spark = w.time
				_play(w, 1)
				_expect(out, "%s: once the marked enemy is dead the spark goes for the nearest again" % who,
					[w.sparks.size(), snappedf(w.sparks[0].vel.normalized().dot((by_torch.pos - from).normalized()), 0.01) if not w.sparks.is_empty() else 0.0], [1, 1.0])
	var dark = _night(DARK, ["spark", "fire_blade", "beacon"])
	var unlit = _still(_add(dark, "big_slime", NEAR))
	_play(dark, SWING, "attack")
	_expect(out, "beacon: an enemy hit outside the light is not marked", [unlit.hp < unlit.full_hp, dark.marked], [true, null])
	for with in [false, true]:
		var w = _night(LIT, ["dash", "thorns"] + (["bramble"] if with else []))
		var dmg: int = World.upgrade("bramble", 1).dash_damage if with else 0
		w.next_thorn = NEVER
		var inway = _still(_add(w, "big_slime", Vector2(18.0, 0.0)))
		var aside = _still(_add(w, "big_slime", Vector2(18.0, 40.0)))
		_play(w, 1, "dash", "right")
		while w.player.dash_t > 0.0:
			_play(w, 1, "", "right")
		_expect(out, "a dash through an enemy %s: it is hurt %d, once, the one aside not, and the dashing keeper not" % ["with bramble" if with else "without", dmg],
			[w.player.pos.x > inway.pos.x + inway.T.radius, inway.hp, aside.hp, w.player.hp], [true, inway.full_hp - dmg, aside.full_hp, Config.PLAYER.hp])
		_play(w, roundi(w.mod("dash_every", 1.0) / Config.STEP) + 2)
		_play(w, 1, "dash", "left")
		while w.player.dash_t > 0.0:
			_play(w, 1, "", "left")
		_expect(out, "a second dash back through it %s hurts it again" % ["with bramble" if with else "without"], [w.player.pos.x < inway.pos.x - inway.T.radius, inway.hp, w.player.hp], [true, inway.full_hp - 2 * dmg, Config.PLAYER.hp])
	for with in [false, true]:
		var L: Dictionary = World.upgrade("blast", 1)
		var w = _night(Vector2.ZERO, ["big_logs", "woodpile"] + (["blast"] if with else []))
		var on = _planted(w, "slime", Vector2(15.0, 0.0))
		var edge = _planted(w, "slime", Vector2(0.0, L.feed_reach + 5.0)) # its body just inside feed_reach
		var beyond = _planted(w, "slime", Vector2(-(L.feed_reach + 12.0), 0.0))
		_play(w, 1)
		var smothered: float = w.burn_rate()
		w.player.take_log()
		var told := _play(w, 1)
		_expect(out, "a log on the fire %s: the slime on the torch and the one at the edge of feed_reach are thrown back from the torch, the one beyond is not, none is hurt" % ["with blast" if with else "without"],
			[on.at_torch, told.count("fed"), told.count("wave"), on.knock.x > 0.0, edge.knock.y > 0.0, beyond.knock != Vector2.ZERO, on.hp], [true, 1, 1 if with else 0, with, with, false, on.full_hp])
		if told.has("wave"):
			var wave: Dictionary = w.events.filter(func(ev): return ev.kind == "wave")[0]
			_expect(out, "blast tells the screen where and how far", [wave.pos, wave.radius, Effects.RINGS.has(wave.ring)], [Config.TORCH.pos, L.feed_reach, true])
		_play(w, 30)
		_expect(out, "a log on the fire %s: the slime that smothered the torch %s" % ["with blast" if with else "without", "is off it, and the fire burns freely" if with else "is still on it"],
			[on.at_torch, w.burn_rate() < smothered], [not with, with])
	return out
