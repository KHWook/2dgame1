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

const SWING := 10 # steps: long enough for a swing to land (PLAYER.attack_hit_at)
const LIT := Vector2(30.0, 0.0) # from the torch: well inside its light
const DARK := Vector2(110.0, 0.0) # from the torch: well outside its light
const NEAR := Vector2(16.0, 0.0) # from the player: in front, within the sword's reach, not touching
const NEVER := 1.0e9 # a time that does not come: keeps the night from adding things of its own to a scene


## Every failure as a message; empty when all scenes hold.
static func run() -> Array:
	var out := []
	out.append_array(_swing_area())
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
	out.append_array(_charger())
	out.append_array(_logs())
	out.append_array(_nights())
	out.append_array(_company())
	out.append_array(_setup())
	out.append_array(_coaching())
	out.append_array(_crowds())
	out.append_array(_late_nights())
	out.append_array(_tier_stats())
	out.append_array(_tier_nights())
	out.append_array(_tier_looks())
	return out


## A night already under way with these upgrades taken, the player standing at at from the torch, facing right, and
## nothing else on the field.
static func _night(at: Vector2, upgrades: Array = []):
	var w = World.new(1)
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
	for ups in [[], ["long_blade", "long_blade"], ["wide_swing", "wide_swing"], ["spin"]]:
		w = _night(DARK, ups)
		for turn in 3: # the spin upgrade goes round on the third swing
			w.player.face = Vector2.from_angle(0.7 * turn + 0.2)
			for i in roundi(Config.PLAYER.attack_time / Config.STEP) + 2:
				_play(w, 1, "attack" if i == 0 else "")
				for line in painter.slash_lines(w):
					drawn += 1
					for j in 9:
						var at: Vector2 = w.player.pos.round() + Vector2.from_angle(lerpf(line[1], line[2], j / 8.0)) * (line[0] + line[4] / 2.0)
						if not w.in_swing(at, 1.0):
							out.append("the trail is drawn where the swing does not hit (%s, %s at %s)" % [ups, at - w.player.pos, w.player.attack_t])
							break
				if not painter.slash_lines(w).is_empty() and w.player.attack_t > Config.PLAYER.attack_hit_until:
					out.append("the trail still shows once the blow has stopped landing (%s)" % [ups])
	_expect(out, "the painter drew a trail in the swings", drawn > 0, true)
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
	w.player.carrying = true
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
	w.player.carrying = true
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
		w.boss_due = w._boss_night()
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
	w.boss_due = true
	w.time = Config.NIGHT.length * Config.BOSS.at - Config.BOSS.warn - Config.STEP * 0.5
	told = []
	var coming_at = null
	for i in 1:
		w.step(InputFrame.new())
		for ev in w.events:
			told.append(ev.kind)
			if ev.kind == "coming":
				coming_at = ev.pos
	_expect(out, "a boss's coming is told BOSS.warn seconds ahead, before it comes", [told.has("coming"), told.has("boss"), w.boss_from == coming_at and coming_at != null], [true, false, true])
	told = _play(w, int(Config.BOSS.warn / Config.STEP) - 2)
	_expect(out, "the boss does not come during its warning", told.has("boss"), false)
	told = _play(w, 3)
	var bosses: Array = w.enemies.filter(func(e): return e.T.get("boss", false))
	_expect(out, "the boss comes where its coming pointed", [told.has("boss"), bosses.size(), bosses.size() > 0 and coming_at != null and bosses[0].pos.distance_to(coming_at) < 2.0, w.boss_from], [true, 1, true, null])
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
	w.player.carrying = true
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
	w.night = 20
	w.boss_due = true
	w.time = Config.NIGHT.length * Config.BOSS.at
	_play(w, 1)
	_play(w, 1)
	_expect(out, "a boss is tier 1 on a late night", w.enemies.filter(func(e): return e.T.get("boss", false)).map(func(e): return e.tier), [1])
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
