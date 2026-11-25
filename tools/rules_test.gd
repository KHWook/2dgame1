## Small scenes that hold each rule to what it says (R1): set a world up by hand, play a few steps, look at what
## came of it. The replay proves the game is the same as it was; these prove a rule does what it claims.
## Add a scene here when you add an enemy kind, an upgrade or a pickup.
extends RefCounted

const World := preload("res://src/sim/world.gd")
const Enemy := preload("res://src/sim/enemy.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")

const SWING := 10 # steps: long enough for a swing to land (PLAYER.attack_hit_at)
const LIT := Vector2(30.0, 0.0) # from the torch: well inside its light
const DARK := Vector2(110.0, 0.0) # from the torch: well outside its light
const NEAR := Vector2(16.0, 0.0) # from the player: in front, within the sword's reach, not touching
const NEVER := 1.0e9 # a time that does not come: keeps the night from adding things of its own to a scene


## Every failure as a message; empty when all scenes hold.
static func run() -> Array:
	var out := []
	out.append_array(_shade())
	out.append_array(_big_slime())
	out.append_array(_thief())
	out.append_array(_berry())
	out.append_array(_upgrades())
	out.append_array(_levels())
	out.append_array(_new_upgrades())
	out.append_array(_bosses())
	out.append_array(_logs())
	out.append_array(_nights())
	out.append_array(_setup())
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
	var slime = _add(w, "slime", Vector2(8.0, 0.0))
	_play(w, 1)
	_expect(out, "with thorns the enemy that hurts you is hurt too", [w.player.hp, slime.hp], [Config.PLAYER.hp - 1, Config.ENEMY_TYPES.slime.hp - 1])
	for wide in [false, true]:
		w = _night(DARK, ["wide_swing"] if wide else [])
		_add(w, "slime", NEAR)
		var beside = _add(w, "slime", Vector2(0.0, -18.0))
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
	# big torch
	w = _night(DARK, ["big_torch"])
	w.fuel = Config.TORCH.max_fuel
	w.player.carrying = true
	w.player.pos = Config.TORCH.pos
	_play(w, 1)
	_expect(out, "a big torch takes fuel past the usual full tank", w.fuel > Config.TORCH.max_fuel, true)
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
	return out


## Not rules, but what the rules lean on: the tables agree with each other and with the project's settings.
static func _setup() -> Array:
	var out := []
	var named := {}
	for row in Config.NIGHTS:
		for kind in row.who:
			named[kind] = true
			_expect(out, "NIGHTS names a real enemy kind (%s)" % kind, Config.ENEMY_TYPES.has(kind), true)
	for kind in Config.BOSS.kinds:
		_expect(out, "BOSS names a boss (%s)" % kind, Config.ENEMY_TYPES.get(kind, {}).get("boss", false), true)
		named[kind] = true
	for kind in Config.ENEMY_TYPES:
		_expect(out, "every enemy kind comes on some night or as a boss (%s)" % kind, named.has(kind), true)
		if Config.ENEMY_TYPES[kind].has("summon"):
			_expect(out, "a boss summons a real enemy kind (%s)" % kind, Config.ENEMY_TYPES.has(Config.ENEMY_TYPES[kind].summon.kind), true)
	var viewport := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	_expect(out, "project.godot's viewport is Config.VIEW", viewport, Config.VIEW)
	_expect(out, "the field lies inside the view", Rect2(Vector2.ZERO, Config.VIEW).encloses(Config.FIELD), true)
	_expect(out, "the torch and the player start on the field", [Config.FIELD.has_point(Config.TORCH.pos), Config.FIELD.has_point(Config.PLAYER.start)], [true, true])
	return out
