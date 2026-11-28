## What a run is for, and what plays under it, held to what they claim: the dawn that wins is told once and changes
## no step after it (a run that wins and one that never can are hashed step by step against each other); the same
## seed again is the same run from its first offer; the choosing screen's locks are not asked for the demo bot or
## --char=ID, and only a person's own run on a screen writes the player's files; what main.gd decides between the
## engine and all that is asked of its own functions, never read from its text; the HUD shows the goal; the music
## follows the world (dusk, night, a boss on the field, the torch running low), cross-fades, steps back for a warning,
## waits for the first press in a browser, and its samples are whole, unclipped, seamless and under the warnings.
extends RefCounted

const World := preload("res://src/sim/world.gd")
const Enemy := preload("res://src/sim/enemy.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")
const Bot := preload("res://src/bot.gd")
const Replay := preload("res://tools/replay_test.gd")
const Main := preload("res://src/main.gd")
const Music := preload("res://src/audio/music.gd")
const Sfx := preload("res://src/audio/sfx.gd")
const Juice := preload("res://src/art/juice.gd")
const Painter := preload("res://src/art/painter.gd")
const Ui := preload("res://src/ui.gd")
const Records := preload("res://src/records.gd")
const ReplayScript := preload("res://tests/replay_script.gd")

const SEED := ReplayScript.SEED # the replay's: the bot (slot 1, the knight) is still standing after eight nights
const NO_FILE := "user://goals_test_%s.json" # the files of records that write nothing (_main): never there
const MOST := 60 * 200 # steps: past the third dusk
const SEAM := 0.02 # the most a loop's last sample may differ from its first, of full scale
const DUCKED_UNDER := 10.0 # dB a warning stays over the loudest music while the music steps back for it


## Every failure as a message; empty when all hold.
static func run() -> Array:
	var out := []
	out.append_array(_win())
	out.append_array(_win_box())
	out.append_array(_win_ignored())
	out.append_array(_retry())
	out.append_array(_locks())
	out.append_array(_hud())
	out.append_array(_music_state())
	out.append_array(_music_fade())
	out.append_array(_music_samples())
	return out


static func _expect(out: Array, what: String, got, want) -> void:
	if got != want:
		out.append("%s: got %s, want %s" % [what, got, want])


## The dawn that ends night goal wins the run: "won" is told on that step, right after its "dawn", once; the world's
## won is false until then and true after, through the nights that follow; a restart clears it. The goal is the
## config row's night.
static func _win() -> Array:
	var out := []
	_expect(out, "a new world's goal is Config.GOAL's night, the tenth", [World.new(1).goal, Config.GOAL.night], [10, 10])
	var w = World.new(SEED)
	w.goal = 2
	var bot = Bot.new(1)
	var told := [] # [the night it named, the night the world was on before the step, what came just before it]
	var won_before := false
	var boxes := 0 # the steps after which main.gd puts the win box up
	for s in MOST:
		var night: int = w.night
		var was: bool = w.won
		w.step(bot.frame(w))
		boxes += 1 if Main.won_in(w.events) else 0
		for i in w.events.size():
			if w.events[i].kind == "won":
				told.append([w.events[i].night, night, w.events[i - 1].kind if i > 0 else ""])
				won_before = was
		if w.night >= 4:
			break
	_expect(out, "the bot saw three dawns (or the scene shows nothing)", w.night, 4)
	_expect(out, "with the goal at 2, the win is told once, on the dawn that ends night 2, right after that dawn", told, [[2, 2, "dawn"]])
	_expect(out, "the world had not won before that step and has ever since", [won_before, w.won], [false, true])
	_expect(out, "main.gd puts the win box up after one step of those three nights, the one that told the win", boxes, told.size())
	w.phase = "out"
	var f := InputFrame.new()
	f.pressed["restart"] = true
	w.step(f)
	_expect(out, "a run started again has not won", [w.won, w.night], [false, 1])
	return out


## main.gd as far as it goes without a window: its own functions on a real Ui, the world given and records that
## write nothing. _drop frees it.
static func _main(w):
	var main = Main.new()
	main.world = w
	main.records = Records.new(NO_FILE % "records", NO_FILE % "guide", NO_FILE % "character")
	main.records.saves = false
	main.overlay = Node2D.new()
	main.ui = Ui.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(main.ui)
	main.ui.setup(Painter.new(1), main.records, main.overlay, 0, w)
	return main


static func _drop(main) -> void:
	main.ui.free() # and the overlay, which is its child
	main.free()


## While the win box is up the world is held, as under the pause, the guide, the choosing screen and a phone held
## upright; under those the box does not answer. Its answers, given to main.gd: "go_on" takes the box away and
## records nothing; "restart" records the run as it stands, as won, and opens the choosing screen.
static func _win_box() -> Array:
	var out := []
	_expect(out, "nothing up: the world steps; the win box up: it holds the world and answers", [Main.held_by(false, false, false, false, false), Main.held_by(false, false, false, false, true)], ["", "win"])
	for i in 4:
		var on := [i == 0, i == 1, i == 2, i == 3]
		_expect(out, "the pause, the guide, the choosing screen and a phone upright each hold the world (%s), over the win box too" % [on],
			[Main.held_by(on[0], on[1], on[2], on[3], false), Main.held_by(on[0], on[1], on[2], on[3], true)], ["screen", "screen"])
	for did in ["go_on", "restart"]:
		var w = World.new(SEED)
		w.won = true
		w.night = 11
		w.score = 500
		var main = _main(w)
		main._set_winning(true)
		_expect(out, "the win box goes up in main.gd, the Ui and the box itself", [main.winning, main.ui.winning, main.ui.winbox.open], [true, true, true])
		main._win_answer(did)
		_expect(out, "after %s: the box is gone; the choosing screen is up and the run recorded as won only for a new run" % did,
			[main.winning, main.ui.winning, main.ui.winbox.open, main.choosing, main.records.runs.map(func(r): return [r.score, r.night, r.won])],
			[false, false, false, did == "restart", [[500, 11, true]] if did == "restart" else []])
		_drop(main)
	return out


## The win changes nothing a rule reads: a run that wins at its first dawn and the same run with the goal out of
## reach are the same world on every step (Replay.digest: the state, the generator, the picks) and tell the same
## events but for "won", through two more nights.
static func _win_ignored() -> Array:
	var out := []
	var wins = World.new(SEED)
	wins.goal = 1
	var never = World.new(SEED)
	never.goal = 1000
	var bots := [Bot.new(1), Bot.new(1)]
	var hashes := [HashingContext.new(), HashingContext.new()]
	for h in hashes:
		h.start(HashingContext.HASH_SHA256)
	var first := -1
	for s in MOST:
		var worlds := [wins, never]
		for i in 2:
			worlds[i].step(bots[i].frame(worlds[i]))
			var kinds := []
			for ev in worlds[i].events:
				if ev.kind != "won":
					kinds.append(ev.kind)
			hashes[i].update(("%s|%s" % [Replay.digest(worlds[i]), ",".join(kinds)]).to_utf8_buffer())
		if first < 0 and Replay.digest(wins) != Replay.digest(never):
			first = s
		if wins.night >= 3 and wins.phase == "night" and wins.time > 20.0:
			break
	_expect(out, "the run that won played on into its third night", [wins.won, never.won, wins.night, wins.phase], [true, false, 3, "night"])
	_expect(out, "the first step on which the run that won differs from the one that could not (-1: none)", first, -1)
	_expect(out, "both runs hash the same over every step: state, generator, picks and the events but for the win's",
		hashes[0].finish().hex_encode(), hashes[1].finish().hex_encode())
	return out


## The same seed again: main.gd's seed for the next run is the one in hand when the run is played again (or the seed
## is fixed), else a fresh one; a world started on it with the same keeper deals the same first offer and, played
## alike, is the same world. T is the key, from an ending.
static func _retry() -> Array:
	var out := []
	var clock := 1764200000000000
	var ticks := 5000000
	_expect(out, "played again, the next seed is the one in hand; otherwise the fixed one, or a fresh one",
		[Main.seed_after(true, false, 77, clock, ticks), Main.seed_after(false, true, 77, clock, ticks), Main.seed_after(false, false, 77, clock, ticks)],
		[77, 77, Main.fresh_seed(clock, ticks)])
	_expect(out, "the fresh seed in this scene is another one", Main.fresh_seed(clock, ticks) != 77, true)
	var first = World.new(77, "mage")
	var offer: Array = first.offer.duplicate()
	var bot = Bot.new(2)
	for s in 900:
		first.step(bot.frame(first))
	var mark := Replay.digest(first)
	first.choose(first.character, Main.seed_after(true, false, first.seed_value, clock, ticks))
	_expect(out, "the run played again starts with the same keeper, seed and first offer", [first.character, first.seed_value, first.offer, first.steps], ["mage", 77, offer, 0])
	bot = Bot.new(2)
	for s in 900:
		first.step(bot.frame(first))
	_expect(out, "and, played alike for 900 steps, is the same world", Replay.digest(first), mark)
	_expect(out, "T asks for it, and is no other key", [Main.KEYS.get(KEY_T, ""), Main.KEYS.values().count("retry")], ["retry", 1])
	_expect(out, "at an ending a step's presses ask for the same run again (T, over R), a new one (R), or nothing",
		[Main.asks_again({ "retry": true }, true, false), Main.asks_again({ "retry": true, "restart": true }, true, false), Main.asks_again({ "restart": true }, true, false), Main.asks_again({ "attack": true }, true, false)],
		["retry", "retry", "restart", ""])
	_expect(out, "they ask nothing while the run goes on, or of the demo bot", [Main.asks_again({ "retry": true, "restart": true }, false, false), Main.asks_again({ "retry": true, "restart": true }, true, true)], ["", ""])
	return out


## Locks are the choosing screen's: the demo bot and --char=ID never see it, and are handed no locks if they did.
## Only a person's own run on a screen, with the goal where it is, writes the player's files.
static func _locks() -> Array:
	var out := []
	var all: Array = Config.CHARACTERS.keys()
	_expect(out, "with only the knight open, the other two are locked", Main.locks(["knight"], false), ["woodcutter", "mage"])
	_expect(out, "with everyone open, nobody is", Main.locks(all, false), [])
	_expect(out, "for the demo bot and --char=ID nobody is locked, whatever is open", [Main.locks(["knight"], true), Main.locks([], true)], [[], []])
	_expect(out, "the demo bot's runs and --char=ID's start without the choosing screen and its locks; a person's do not",
		[Main.unasked(true, false), Main.unasked(false, true), Main.unasked(true, true), Main.unasked(false, false)], [true, true, true, false])
	var kept := []
	for is_bot in [false, true]:
		for headless in [false, true]:
			for moved in [false, true]:
				if Main.keeps(is_bot, headless, moved):
					kept.append([is_bot, headless, moved])
	_expect(out, "only a person's run on a screen, not staged by a flag, writes the player's files", kept, [[false, false, false]])
	_expect(out, "a run is staged by --goal=N, --night=N or --crowd=K, each alone or among others",
		[Main.staged(["--goal=3"]), Main.staged(["--night=4"]), Main.staged(["--crowd=50"]), Main.staged(["--seed=9", "--flat", "--night=2"])], [true, true, true, true])
	_expect(out, "and by no other flag, or none", [Main.staged(["--seed=9", "--bot", "--char=mage", "--slot=2", "--skip=600", "--perf", "--flat"]), Main.staged([])], [false, false])
	return out


## The HUD shows the goal from the first night: a pip per dawn up to the one that wins, inside the clock's panel, the
## last one taller, none overlapping; and the dusk's offer says it in words until the run is won.
static func _hud() -> Array:
	var out := []
	for goal in [8, 10, 12, 15, Painter.GOAL_MOST]:
		var w = World.new(1)
		w.goal = goal
		var pips: Array = Painter.goal_pips(w)
		_expect(out, "a goal of %d dawns shows %d pips" % [goal, goal], pips.size(), goal)
		var bad := 0
		for i in pips.size():
			if not Painter.CLOCK_PANEL.encloses(pips[i].grow(1.0)) or pips[i].grow(1.0).intersects(Painter.NIGHT_BAR) or (i > 0 and pips[i].grow(1.0).intersects(pips[i - 1])):
				bad += 1
		_expect(out, "the %d pips lie in the clock's panel, under the night's bar, apart from each other" % goal, bad, 0)
		_expect(out, "the last of the %d pips, the dawn that wins, is the tall one" % goal, pips.filter(func(p): return p.size.y > Painter.GOAL_PIP.y), [pips[-1]])
	var far = World.new(1)
	far.goal = Painter.GOAL_MOST + 1
	_expect(out, "the row holds as many pips as lie inside the clock's panel, each with its edge, and not one more", [Painter.GOAL_MOST, Painter.GOAL_MOST * (Painter.GOAL_PIP.x + Painter.GOAL_GAP) <= Painter.CLOCK_PANEL.size.x, (Painter.GOAL_MOST + 1) * (Painter.GOAL_PIP.x + Painter.GOAL_GAP) > Painter.CLOCK_PANEL.size.x], [18, true, true])
	_expect(out, "a goal too far for the row shows no pips", Painter.goal_pips(far), [])
	var w = World.new(1)
	_expect(out, "the first dusk says the goal", Ui.dusk_words(w), Ui.GOAL_FIRST % 10)
	w.night = 10
	_expect(out, "the tenth dusk says one more dawn wins", Ui.dusk_words(w), Ui.GOAL_LEFT % 1)
	w.night = 11
	w.won = true
	_expect(out, "a dusk after the win says only that dawn came", Ui.dusk_words(w).contains("승리"), false)
	return out


static func _boss(w, decoy := false):
	var e = Enemy.new(Config.BOSS.kinds[0], Config.TORCH.pos + Vector2(60.0, 0.0))
	e.decoy = decoy
	w.enemies.append(e)
	return e


## The music's state is the world's: calm at dusk, under a screen and at an ending; the night's loop at night and
## through the midnight offer; the boss's while a boss (not its decoy, not a dead one) is on the field. The tight loop
## comes in as the torch runs low, only at night. Juice names the win's sting on the step the world tells the win.
static func _music_state() -> Array:
	var out := []
	var w = World.new(1)
	_expect(out, "at the first dusk", Music.state(w, false), "calm")
	w.phase = "night"
	w.time = 5.0
	_expect(out, "at night", Music.state(w, false), "night")
	_expect(out, "at night under the choosing screen or the guide", Music.state(w, true), "calm")
	var boss = _boss(w)
	_expect(out, "with a boss on the field", Music.state(w, false), "boss")
	w.phase = "pick"
	_expect(out, "at the midnight offer with the boss still there", Music.state(w, false), "boss")
	w.phase = "night"
	boss.dead = true
	_expect(out, "once the boss is dead", Music.state(w, false), "night")
	w.enemies = []
	_boss(w, true)
	_expect(out, "with only a boss's decoy on the field", Music.state(w, false), "night")
	w.enemies = []
	w.phase = "pick"
	_expect(out, "at the midnight offer", Music.state(w, false), "night")
	w.time = 0.0
	_expect(out, "at the next dusk", Music.state(w, false), "calm")
	for ending in ["out", "dead"]:
		w.phase = ending
		_expect(out, "at the ending %s" % ending, Music.state(w, false), "calm")
	w.phase = "night"
	w.time = 5.0
	var rate: float = w.burn_rate()
	var by_fuel := []
	for left in [Music.TIGHT_FROM + 5.0, Music.TIGHT_FROM, (Music.TIGHT_FROM + Music.TIGHT_FULL) / 2.0, Music.TIGHT_FULL, 1.0]:
		w.fuel = rate * left
		by_fuel.append(snappedf(Music.urgency(w), 0.01))
	_expect(out, "the tight loop by how soon the torch goes out: none with time to spare, half way, all of it", by_fuel, [0.0, 0.0, 0.5, 1.0, 1.0])
	w.phase = "pick"
	_expect(out, "no urgency while the world waits on an offer", Music.urgency(w), 0.0)
	_expect(out, "the night's loop with the tight one over it", Music.targets("night", 0.5, true), { "calm": 0.0, "night": 1.0, "tight": 0.5, "boss": 0.0 })
	_expect(out, "the calm loop takes no tight one", Music.targets("calm", 1.0, true), { "calm": 1.0, "night": 0.0, "tight": 0.0, "boss": 0.0 })
	_expect(out, "with the music off nothing sounds", Music.targets("boss", 1.0, false), { "calm": 0.0, "night": 0.0, "tight": 0.0, "boss": 0.0 })
	var won = World.new(SEED)
	won.goal = 1
	won.phase = "night"
	won.offer = []
	won.time = Config.NIGHT.length
	var juice = Juice.new(1)
	juice.seen(won)
	won.step(InputFrame.new())
	juice.step(won)
	_expect(out, "the step that wins sounds the dawn and the win's sting", [juice.sounds.has("dawn"), juice.sounds.has("win"), Music.STINGS.has("win"), Music.STINGS.has("dawn")], [true, true, true, true])
	_expect(out, "the win's sting is the music's, not an effect", Sfx.SOUNDS.has("win"), false)
	return out


## A change of state cross-fades over Music.FADE seconds, never at once; the music off fades everything out and on
## brings it back; a warning sound makes it step back to Music.DUCK and return; in a browser nothing may play before
## the first press.
static func _music_fade() -> Array:
	var out := []
	var m = Music.new()
	var frame := 1.0 / 60.0
	m.frame(frame, "calm", 0.0, true)
	_expect(out, "one frame into the calm loop it is barely there", m.levels.calm > 0.0 and m.levels.calm < 0.05, true)
	for i in int(Music.FADE * 60.0) + 2:
		m.frame(frame, "calm", 0.0, true)
	_expect(out, "after the fade it is all there, alone", [m.levels.calm, m.levels.night, m.levels.boss, m.levels.tight], [1.0, 0.0, 0.0, 0.0])
	var jump := 0.0
	var lowest := 1.0
	for i in int(Music.FADE * 60.0) + 2:
		var before: Dictionary = m.levels.duplicate()
		m.frame(frame, "night", 0.0, true)
		for name in m.levels:
			jump = maxf(jump, absf(m.levels[name] - before[name]))
		lowest = minf(lowest, m.levels.calm + m.levels.night)
	_expect(out, "from calm to night: no loop moves more than a frame's share of the fade, and the two together never dip",
		[jump <= frame / Music.FADE + 0.0001, lowest > 0.99], [true, true])
	_expect(out, "then the night's loop is all there and the calm one gone", [m.levels.calm, m.levels.night], [0.0, 1.0])
	m.sounded(["hit", "kill"])
	_expect(out, "a blow does not make the music step back", m.gain("night"), 1.0)
	m.sounded(["hit", "warn"])
	_expect(out, "a warning does, to Music.DUCK", is_equal_approx(m.gain("night"), Music.DUCK), true)
	for sound in Music.DUCKS:
		_expect(out, "%s is a sound the game makes" % sound, Sfx.SOUNDS.has(sound), true)
	for i in int(Music.DUCK_TIME * 60.0) + 2:
		m.frame(frame, "night", 0.0, true)
	_expect(out, "and it is back after Music.DUCK_TIME", m.gain("night"), 1.0)
	for i in int(Music.FADE * 60.0) + 2:
		m.frame(frame, "boss", 1.0, false)
	_expect(out, "with the music turned off everything fades out", m.levels.values().max(), 0.0)
	for i in int(Music.FADE * 60.0) + 2:
		m.frame(frame, "boss", 1.0, true)
	_expect(out, "and turned on again the boss's loop and the tight one come back", [m.levels.boss, m.levels.tight, m.levels.night], [1.0, 1.0, 0.0])
	var page = Music.new()
	_expect(out, "in a browser nothing may play before the first press; elsewhere it may", [page.may_play(true), page.may_play(false)], [false, true])
	page.heard = true
	_expect(out, "after it, it may", page.may_play(true), true)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	var tap := InputEventScreenTouch.new()
	var heard := []
	for event in [InputEventMouseMotion.new(), key, click, tap]: # each not pressed, then pressed, given to main.gd
		for down in [false, true]:
			if not event is InputEventMouseMotion:
				event.pressed = down
			var main = Main.new()
			main._input(event)
			heard.append(main.music.heard)
			main.free()
	_expect(out, "main.gd counts a key, a mouse button or a touch going down as the first press, and nothing else", heard, [false, false, false, true, false, true, false, true])
	_expect(out, "the music is made in a run on a screen, not in one without", [Main.makes_music(false), Main.makes_music(true)], [true, false])
	return out


## A sample's floats, -1 to 1.
static func _floats(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(stream.data.size() / 2)
	for i in out.size():
		out[i] = stream.data.decode_s16(i * 2) / 32767.0
	return out


## How loud a sample is: its root mean square in dB under full scale, and its peak; its first and last samples, and
## the biggest step between two samples next to each other inside it.
static func level(stream: AudioStreamWAV) -> Dictionary:
	var s := _floats(stream)
	var sum := 0.0
	var peak := 0.0
	var biggest_step := 0.0
	for i in s.size():
		sum += s[i] * s[i]
		peak = maxf(peak, absf(s[i]))
		biggest_step = maxf(biggest_step, absf(s[i] - s[i - 1]) if i > 0 else 0.0)
	return { "rms_db": linear_to_db(sqrt(sum / maxi(1, s.size()))), "peak": peak, "first": s[0], "last": s[-1], "samples": s.size(), "biggest_step": biggest_step }


## Every loop is as long as its row says, loops forward over all of it, never clips, is not silent, and its last
## sample runs into its first (a loop's notes wrap round its end). The three that play together are one length.
## Made a little at a time (as the game makes them) a sample is the same bytes as made at once. The loudest the
## music gets (a state's loop with the tight one, at main.gd's MUSIC_DB) is under every warning sound at SFX_DB, and
## DUCKED_UNDER dB under it while it steps back.
static func _music_samples() -> Array:
	var out := []
	var loud := {}
	for name in Music.LOOPS.keys() + Music.STINGS.keys():
		var stream := Music.make(name)
		var l := level(stream)
		loud[name] = l.rms_db
		_expect(out, "%s is as long as its row says" % name, l.samples, Music.length(name))
		_expect(out, "%s never clips and is not silent" % name, [l.peak < 0.98, l.rms_db > -40.0], [true, true])
		if Music.LOOPS.has(name):
			_expect(out, "%s loops forward over all of it" % name, [stream.loop_mode, stream.loop_begin, stream.loop_end], [AudioStreamWAV.LOOP_FORWARD, 0, l.samples])
			_expect(out, "%s's last sample runs into its first (%.4f then %.4f)" % [name, l.last, l.first], absf(l.first - l.last) <= SEAM, true)
		else:
			_expect(out, "the sting %s plays once and ends in silence (its last sample is %.4f)" % [name, l.last], [stream.loop_mode, absf(l.last) <= SEAM], [AudioStreamWAV.LOOP_DISABLED, true])
	# A note still sounding at a loop's end goes on from its start: here the only note begins on the last beat of four
	# and lasts two, so the loop's first beat holds its second half, and the seam is as smooth as the note's inside.
	var wrap = Music.Maker.new("wrap", { "bpm": 120.0, "beats": 4, "voices": [{ "wave": "tri", "vol": 0.5, "step": 3.0, "hold": 2.0, "env": "pad", "seq": [0, 57] }] })
	wrap.work(-1)
	var s := _floats(wrap.stream)
	var beat := s.size() / 4
	var heard := [0.0, 0.0, 0.0, 0.0] # the loudest sample in each beat
	var step: float = level(wrap.stream).biggest_step
	for i in s.size():
		heard[mini(i / beat, 3)] = maxf(heard[mini(i / beat, 3)], absf(s[i]))
	_expect(out, "a note over a loop's end sounds on its last beat, goes on in its first, and nowhere else",
		[heard[3] > 0.2, heard[0] > 0.2, heard[1] < 0.001, heard[2] < 0.001], [true, true, true, true])
	_expect(out, "and it runs through the seam with no bigger a step than inside it (%.4f then %.4f; inside at most %.4f)" % [s[-1], s[0], step], absf(s[0] - s[-1]) <= step, true)
	_expect(out, "the loops that play together are one length", Music.LAYERED.map(func(n): return Music.length(n)).max(), Music.LAYERED.map(func(n): return Music.length(n)).min())
	var slow = Music.Maker.new("tight")
	var calls := 0
	while not slow.work(0):
		calls += 1
	_expect(out, "made %d samples at a time, a loop takes many calls and is the same bytes as made at once" % Music.CHUNK, [calls > 20, slow.stream.data == Music.make("tight").data], [true, true])
	var most := -INF # the loudest pair of loops that can sound at once, as power
	for state in ["night", "boss"]:
		most = maxf(most, linear_to_db(sqrt(db_to_linear(loud[state]) ** 2 + db_to_linear(loud["tight"]) ** 2)))
	most = maxf(most, loud["calm"]) + Main.MUSIC_DB
	for sound in Music.DUCKS:
		var warning: float = level(Sfx.make(sound)).rms_db + Main.SFX_DB
		_expect(out, "the warning %s (%.1f dB) is over the loudest the music gets (%.1f dB), and %.0f dB over it while it steps back" % [sound, warning, most, DUCKED_UNDER],
			[warning > most, warning - (most + linear_to_db(Music.DUCK)) >= DUCKED_UNDER], [true, true])
	return out
