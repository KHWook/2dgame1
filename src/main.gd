## Boot, and the only bridge between the engine and the simulation. It turns key events into InputFrames, steps the
## world on Godot's fixed physics tick (D5), and shows the world by reading it (D4): src/art/painter.gd paints it.
## Words go in Control nodes such as Label, never into the world (C1): src/ui.gd holds them all.
## Touches become the same actions as keys in src/touch.gd, which main.gd merges in here.
## It also says which seed each run is played on: a new one for every run a person starts (fresh_seed).
extends Node2D

const World := preload("res://src/sim/world.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")
const Bot := preload("res://src/bot.gd")
const Painter := preload("res://src/art/painter.gd")
const Records := preload("res://src/records.gd")
const Juice := preload("res://src/art/juice.gd")
const Sfx := preload("res://src/audio/sfx.gd")
const Music := preload("res://src/audio/music.gd")
const Ui := preload("res://src/ui.gd")
const Touch := preload("res://src/touch.gd")
const Guide := preload("res://src/guide.gd")
const Looks := preload("res://src/art/looks.gd")
const Picker := preload("res://src/picker.gd")
const GroundShader := preload("res://src/art/ground.gdshader")

const KEYS := {
	KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right",
	KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down",
	KEY_X: "attack", KEY_J: "attack", KEY_SPACE: "attack",
	KEY_SHIFT: "dash", KEY_K: "dash",
	KEY_1: "pick_1", KEY_2: "pick_2", KEY_3: "pick_3", KEY_R: "restart",
	KEY_T: "retry", # from an ending: the same seed and keeper again
}
const PAUSE_KEYS := [KEY_P, KEY_ESCAPE]
const HELP_KEY := KEY_H # brings the first screen back
const MUSIC_KEY := KEY_M # the music on or off, on any screen; the effects stay
const SFX_DB := -12.0 # how loud the sound effects play: under the player's own music, if any
const MUSIC_DB := -19.0 # the loops, under the effects: a warning is never the quieter of the two (tools/goals_test.gd)
const STING_DB := -14.0 # the dawn's and the win's stings
const MUSIC_WORK_USEC := 3000 # the most of a frame spent making the music's samples, until they are all made
const TORCH_LIGHT := Color("#ffcf8a")
const TORCH_ENERGY := 1.25 # the night is nearly black, so what you see by is all the torch's
const DAY_ENERGY := 0.3 # the torch still glows a little once the sun is up
const FLARE_ENERGY := 0.5 # how much brighter the torch burns for a moment when it is fed
const BOT_LOOKS := 90 # steps a demo bot leaves an offer on screen before it picks, so a person watching can read it
const SEED_MOST := 999999 # a run's seed is 1 to this: few enough digits to read off the screen and to type after --seed=
const STIR_BITS := 0x7fffffff # fresh_seed mixes on 31 bits, so that its products stay inside an int
## On the web, the first tap asks the browser for the whole screen held sideways (Android browsers allow it after a
## tap; an iPhone's Safari has no such call for a page, and nothing happens).
const FULL_SCREEN_JS := "try{var d=document.documentElement;if(d.requestFullscreen){d.requestFullscreen({navigationUI:'hide'}).then(function(){if(screen.orientation&&screen.orientation.lock){return screen.orientation.lock('landscape');}}).catch(function(){});}}catch(e){}"

var world
var painter
var bot = null # set by the --bot user arg: the bot plays instead of the keyboard
var bot_looked := 0 # steps the demo bot has spent on the offer in front of it
var held := {}
var pending := {} # presses since the last step; each counts for exactly one step (D6)
var sky: CanvasModulate
var ground: ShaderMaterial = null
var overlay: Node2D # above the night and the lights: what glows by itself, and the HUD pictures
var ui # src/ui.gd: every word on screen, and the offer cards
var records # src/records.gd: the best runs on disk
var seed_value := 1
var seed_fixed := false
var torch_lights: Array = [] # one PointLight2D per ring of tongues (Painter.LIGHT_RINGS), turning against each other
var juice # src/art/juice.gd: hit-stop, shake, and which sounds the last step made
var sfx := {} # sound name -> its AudioStreamPlayer
var music = Music.new() # src/audio/music.gd: how much of each loop sounds now
var music_players := {} # loop or sting name -> its AudioStreamPlayer; none in a run without a screen
var music_makers: Array = [] # the samples still to make, the next one first (Music.Maker)
var winning := false # the win box is up (src/winbox.gd): the world waits until it is answered
var goal_flag := 0 # --goal=N: the dawn that wins, to look at the win box
var paused := false
var intro := false # the first screen is up (src/ui.gd, src/guide.gd): the world waits until its start button
var choosing := false # the choosing screen is up (src/chooser.gd): the world waits until a character is taken
var chosen_by_flag := false # --char=ID picked the character: the choosing screen is skipped, as for the bot
var start_night := 0 # --night=N: each run (whoever keeps the torch) starts at the dusk of night N
var start_slot := 1
var player_light: PointLight2D
var ember_lights: Array = [] # Painter.MAX_LIGHTS PointLight2Ds the mage's embers and bursts light the dark with
var touch # src/touch.gd: the stick and buttons on a phone
## Dev flags for looking at and measuring late nights; the replay and the balance tool never pass through here.
## --night=N starts at the dusk of night N (World.begin_at); --crowd=K keeps K enemies on the field and the keeper and
## the torch from failing (World.crowd); --perf prints, once a second, the crowd, the time world.step takes, the frame
## time and the draw calls. --flat paints the ground in flat colours.
var crowd := 0
var perf := false
var perf_frames := 0
var perf_step_us := 0
var perf_steps := 0
var perf_frame_max := 0.0
var perf_since := 0
var perf_held := 0
var perf_paint_us := 0

func _ready() -> void:
	var skip := 0
	var slot := 1
	var character := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
			seed_fixed = true
		if a.begins_with("--skip="):
			skip = int(a.substr(7))
		if a.begins_with("--slot="): # which offer the bot always takes; --bot --seed=6 --slot=3 is the replay's night
			slot = int(a.substr(7))
		if a.begins_with("--crowd="):
			crowd = int(a.substr(8))
		if a.begins_with("--char="): # who keeps the torch, without the choosing screen (for the bot and dev runs)
			character = a.substr(7)
		if a.begins_with("--goal="):
			goal_flag = int(a.substr(7))
	perf = OS.get_cmdline_user_args().has("--perf")
	if OS.get_cmdline_user_args().has("--bot"):
		bot = Bot.new(slot)
		seed_fixed = true
	# The window's title is the game's name on the first screen. project.godot keeps the old config/name, which on
	# desktop names the folder user://records.json lives in; the web build's page title comes from config/name.web.
	get_window().title = Ui.INTRO_TITLE
	records = Records.new()
	records.saves = keeps(bot != null, DisplayServer.get_name() == "headless", staged(Array(OS.get_cmdline_user_args())))
	records.settle()
	if character != "" and not Config.CHARACTERS.has(character):
		push_warning("--char=%s is not a character (%s): the knight keeps the torch" % [character, ", ".join(Config.CHARACTERS.keys())])
		character = "knight"
	chosen_by_flag = character != ""
	seed_value = _next_seed()
	world = World.new(seed_value, character if chosen_by_flag else records.last_character())
	if goal_flag > 0:
		world.goal = goal_flag
	painter = Painter.new(seed_value)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--night="):
			start_night = int(a.substr(8))
			start_slot = slot
			world.begin_at(start_night, slot)
	if unasked(bot != null, chosen_by_flag):
		_take_character(world.character)
	for i in skip if bot != null else 0: # --bot --skip=N: the bot plays N steps before the first frame, to look at a late night
		world.step(bot.frame(world))
	juice = Juice.new(seed_value)
	juice.seen(world)
	for name in Sfx.SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = Sfx.make(name)
		player.volume_db = SFX_DB
		add_child(player)
		sfx[name] = player
	if makes_music(DisplayServer.get_name() == "headless"):
		for name in Music.LOOPS.keys() + Music.STINGS.keys():
			var player := AudioStreamPlayer.new()
			player.volume_db = STING_DB if Music.STINGS.has(name) else -80.0
			add_child(player)
			music_players[name] = player
			music_makers.append(Music.Maker.new(name))
	sky = CanvasModulate.new()
	add_child(sky)
	if not OS.get_cmdline_user_args().has("--flat"):
		_lay_paper()
	for ring in Painter.LIGHT_RINGS:
		var light := PointLight2D.new()
		light.texture = ImageTexture.create_from_image(Painter.light_image(ring[0], Painter.LIGHT_LICK))
		light.color = TORCH_LIGHT
		light.position = Config.TORCH.pos
		add_child(light)
		torch_lights.append(light)
	var glow := ImageTexture.create_from_image(Painter.light_image())
	player_light = PointLight2D.new()
	player_light.texture = glow
	add_child(player_light)
	for i in Painter.MAX_LIGHTS:
		var light := PointLight2D.new()
		light.texture = glow
		light.color = TORCH_LIGHT
		light.visible = false
		add_child(light)
		ember_lights.append(light)
	overlay = Node2D.new()
	overlay.draw.connect(func():
		var t0 := Time.get_ticks_usec()
		painter.paint_overlay(overlay, world)
		perf_paint_us += Time.get_ticks_usec() - t0)
	ui = Ui.new()
	add_child(ui)
	ui.setup(painter, records, overlay, bot.pick if bot != null else 0, world)
	ui.coach.on = bot == null and not records.guide_read() # the first night is coached until the guide has been read once
	_set_intro(bot == null) # the demo bot starts at once
	ui.chosen.connect(func(slot: int): pending["pick_%d" % (slot + 1)] = true)
	ui.rerolled.connect(func(): pending["reroll"] = true)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = ui.layer + 1
	add_child(touch_layer)
	touch = Touch.new()
	touch_layer.add_child(touch)
	touch.pause_pressed.connect(_toggle_pause)
	touch.help_pressed.connect(func(): _set_intro(true)) # the H key's touch: over the pause screen too, as H is
	touch.music_pressed.connect(func(): records.set_music(not records.music)) # the M key's touch
	get_tree().root.size_changed.connect(_fit)
	_fit()


## The paper ground: one rectangle the size of the view under everything main.gd draws, which the shader fills with
## crayon strokes in the ground's colours. The painter then leaves the ground out of what it paints.
func _lay_paper() -> void:
	ground = ShaderMaterial.new()
	ground.shader = GroundShader
	ground.set_shader_parameter("ground", ImageTexture.create_from_image(Painter.ground_map()))
	var rect := ColorRect.new()
	rect.size = Config.VIEW
	rect.z_index = -1
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = ground
	add_child(rect)
	painter.paper = true


## On the web and on phones, the field keeps whole-pixel scaling unless that leaves it small (Touch.stretch_for).
func _fit() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		get_tree().root.content_scale_stretch = Touch.stretch_for(Vector2(get_tree().root.size))


func _toggle_pause() -> void:
	paused = not paused
	ui.set_paused(paused, world)


func _set_intro(on: bool) -> void:
	intro = on
	ui.intro = on
	if on:
		ui.guide.show(records.guide_read(), world.steps > 0)


func _set_choosing(on: bool) -> void:
	choosing = on
	ui.choosing = on
	if on:
		ui.chooser.show(world.character, locks(records.opened, unasked(bot != null, chosen_by_flag)), records.long_open())


## The win box goes up or away (src/winbox.gd). While it is up the world is not stepped.
func _set_winning(on: bool) -> void:
	winning = on
	ui.winning = on
	bot_looked = 0
	if on:
		ui.winbox.show()
	else:
		ui.winbox.close()


## The win box's answer: "go_on" plays on from the same step; "restart" records the run as it stands and starts anew.
func _win_answer(did: String) -> void:
	_set_winning(false)
	if did == "restart":
		records.close(world, seed_value, Time.get_datetime_string_from_system(false, true))
		_again(false)


## A new run from an ending or the win box: the same seed and keeper at once (same), or the choosing screen (the
## keeper --char=ID named, without it).
func _again(same: bool) -> void:
	if same or unasked(bot != null, chosen_by_flag):
		_take_character(world.character, same)
	else:
		_set_choosing(true)


## A run starts with this keeper, on a new seed unless the seed is fixed or the run before is played again (same):
## the offers are drawn for the keeper and the ground is laid out from the seed. The long night, when the choosing
## screen has it on, moves the dawn that wins.
func _take_character(id: String, same := false) -> void:
	seed_value = _next_seed(same)
	var long: bool = ui != null and ui.chooser.long
	records.mode = "long" if long else ""
	if goal_flag <= 0:
		world.goal = Config.UNLOCKS.long.night if long else Config.GOAL.night
	world.choose(id, seed_value)
	if start_night > 0:
		world.begin_at(start_night, start_slot)
	painter.lay_ground(seed_value)
	print("run: seed %d, %s" % [seed_value, id])


## The seed the next world is made from: the fixed one, the one just played (same), or a new one from the system's
## clock and the time since the game began.
func _next_seed(same := false) -> int:
	return seed_after(same, seed_fixed, seed_value, int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec())


## Pure: the seed of the next run. The one in hand when the seed is fixed or the run is played again, else fresh_seed.
static func seed_after(same: bool, fixed: bool, now: int, clock_usec: int, ticks_usec: int) -> int:
	return now if same or fixed else fresh_seed(clock_usec, ticks_usec)


## The characters the choosing screen keeps locked: those not opened yet. None when free: the demo bot and --char=ID
## never ask what is open, so tools keep working on a new machine.
static func locks(opened: Array, free: bool) -> Array:
	return [] if free else Config.CHARACTERS.keys().filter(func(id): return not opened.has(id))


## Whether this run may write the player's files (records, what is open, the music setting): not the demo bot's, not
## one without a screen, not a staged one.
static func keeps(is_bot: bool, headless: bool, staged_: bool) -> bool:
	return not (is_bot or headless or staged_)


## Whether a run is staged: started with a flag (args: the user's) that moves the goal or the night, --goal=N,
## --night=N or --crowd=K. A dawn seen that way would open a character, or win.
static func staged(args: Array) -> bool:
	return args.any(func(a): return a.begins_with("--goal=") or a.begins_with("--night=") or a.begins_with("--crowd="))


## Whether runs start without the choosing screen and its locks: the demo bot's, and those whose keeper --char=ID named.
static func unasked(is_bot: bool, by_flag: bool) -> bool:
	return is_bot or by_flag


## Whether the music's players and samples are made: not in a run without a screen, which then needs no audio device.
static func makes_music(headless: bool) -> bool:
	return not headless


## What holds the world this tick, so that it is not stepped: "screen" under the pause, the guide, the choosing
## screen or a phone held upright (the presses made there are dropped), "win" under the win box alone (which those
## presses may answer), "" when nothing does.
static func held_by(paused_: bool, intro_: bool, choosing_: bool, upright: bool, winning_: bool) -> String:
	return "screen" if paused_ or intro_ or choosing_ or upright else "win" if winning_ else ""


## Whether the step that made these events won the run: the world tells it once ("won").
static func won_in(events: Array) -> bool:
	return events.any(func(ev): return ev.kind == "won")


## What the presses of a step ask of an ending: "retry" (the same seed and keeper again), "restart" (a new run), or
## "" for neither, while the run has not ended, and for the demo bot.
static func asks_again(pressed: Dictionary, ended: bool, is_bot: bool) -> String:
	if not ended or is_bot:
		return ""
	return "retry" if pressed.has("retry") else "restart" if pressed.has("restart") else ""


## A run's seed, 1 to SEED_MOST, from two clocks in microseconds: the system's, which tells one launch from another,
## and the time since the game began, which tells apart two starts inside one tick of the system's (on Windows it
## moves a whole millisecond at a time). Pure: the same two numbers give the same seed.
static func fresh_seed(clock_usec: int, ticks_usec: int) -> int:
	var h := 0
	for n in [clock_usec, ticks_usec]:
		var left: int = n & 0x7fffffffffffffff
		for i in 3:
			h = _stir(h ^ (left & STIR_BITS))
			left >>= 31
	return 1 + h % SEED_MOST


## One turn of fresh_seed's mix: 31 bits in, 31 bits out, no two inputs giving the same output, and each bit that goes
## in moving about half of those that come out.
static func _stir(h: int) -> int:
	h = ((h ^ (h >> 16)) * 0x7feb352d) & STIR_BITS
	h = ((h ^ (h >> 15)) * 0x5bd1e995) & STIR_BITS
	return h ^ (h >> 16)


## Any press is the first input a browser waits for before a page may sound (Music.may_play).
func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		music.heard = true


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	var click := event as InputEventMouseButton
	if k != null and not k.pressed: # a key let go is let go under every screen, or it would still be held when the screen closes
		held.erase(KEYS.get(k.keycode, ""))
		return
	if k != null and k.pressed and not k.echo and k.keycode == MUSIC_KEY:
		records.set_music(not records.music)
		return
	if winning and not intro: # the win box takes every key but M; its two buttons are tapped through src/touch.gd
		if k != null and k.pressed and not k.echo and bot == null:
			var did: String = ui.winbox.key(k.keycode)
			if did != "":
				_win_answer(did)
		return
	if intro: # the guide takes every key and click; only its start button (or Enter, Space) closes it
		var did := ""
		if k != null and k.pressed and not k.echo:
			did = ui.guide.key(k.keycode)
		elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				ui.guide.press(click.position)
			else:
				did = ui.guide.release(click.position)
		if did == "start":
			records.read_guide()
			var returning: bool = ui.guide.returning
			_set_intro(false)
			if not returning and not unasked(bot != null, chosen_by_flag):
				_set_choosing(true)
			if touch.on and OS.has_feature("web"): # a tap on the start button asks for the whole screen
				JavaScriptBridge.eval(FULL_SCREEN_JS, true)
		return
	if choosing: # the choosing screen takes every key and click; a card taken starts the run with that keeper
		var took := ""
		var moved := event as InputEventMouseMotion
		if k != null and k.pressed and not k.echo:
			took = ui.chooser.key(k.keycode)
		elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				ui.chooser.press(click.position)
			else:
				took = ui.chooser.release(click.position)
		elif moved != null:
			ui.chooser.hover(moved.position)
		if took != "":
			records.remember_character(took)
			_set_choosing(false)
			_take_character(took)
		return
	if k != null and k.pressed and not k.echo and k.keycode == HELP_KEY:
		_set_intro(true)
		return
	if k != null and k.pressed and not k.echo and PAUSE_KEYS.has(k.keycode):
		_toggle_pause()
		return
	# While the torch's offer is up, ← → (A D) move the focus between its cards and Enter or Space takes it
	# (src/picker.gd), as the same pick_N action a number key or a click on the card sends; they do not walk or swing.
	if k != null and k.pressed and not k.echo and world.phase == "pick" and bot == null and Picker.hears(k.keycode):
		var slot: int = ui.picker.key(k.keycode)
		if slot >= 0:
			pending["pick_%d" % (slot + 1)] = true
		return
	if k != null and k.pressed and world.phase == "pick" and k.keycode == Picker.REROLL_KEY:
		if not k.echo and bot == null and ui.picker.reroll_key(k.keycode):
			pending["reroll"] = true
		return
	if k == null or k.echo or not KEYS.has(k.keycode):
		return
	var action: String = KEYS[k.keycode]
	if not held.has(action):
		pending[action] = true
	held[action] = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held.clear()
		if touch != null:
			touch.release()


func _physics_process(_delta: float) -> void:
	var f := InputFrame.new()
	f.held = held.duplicate()
	f.held.merge(touch.held())
	f.stick = touch.steer()
	pending.merge(touch.take())
	f.pressed = pending
	pending = {}
	var holder := held_by(paused, intro, choosing, touch.upright(), winning)
	if holder == "screen": # keys still held count again once it goes on
		return
	if holder == "win": # the demo bot reads the box for a while and keeps going
		bot_looked += 1
		if bot != null and bot_looked >= BOT_LOOKS * 2:
			_win_answer("go_on")
		elif bot == null and (f.pressed.has("go_on") or f.pressed.has("restart")):
			_win_answer("go_on" if f.pressed.has("go_on") else "restart")
		return
	var again := asks_again(f.pressed, Ui.ENDINGS.has(world.phase), bot != null)
	if again != "":
		_again(again == "retry")
		return
	var holding: bool = juice.hold > 0 # hit-stop: the world is not stepped, so it is the same step a moment later
	juice.frame()
	position = juice.offset # the field and its lights; the HUD is on its own layer and stays put
	painter.shake = juice.offset
	if holding:
		perf_held += 1
		overlay.queue_redraw()
		return
	bot_looked = bot_looked + 1 if bot != null and world.phase == "pick" else 0
	ui.bot_looked = bot_looked
	if bot_looked > 0 and bot_looked < BOT_LOOKS:
		return
	if crowd > 0:
		world.crowd(crowd)
	var t0 := Time.get_ticks_usec()
	world.step(bot.frame(world) if bot != null else f)
	perf_step_us += Time.get_ticks_usec() - t0
	perf_steps += 1
	if bot == null: # the demo bot's runs are not the player's records
		records.step(world, seed_value, Time.get_datetime_string_from_system(false, true))
	painter.step(world)
	juice.step(world)
	for name in juice.sounds:
		if sfx.has(name):
			sfx[name].play()
		# a sting of the music's: only with the music on, once its sample is made, and the dawn's not under the win's
		var sting: AudioStreamPlayer = music_players.get(name) if Music.STINGS.has(name) else null
		if sting != null and sting.stream != null and records.music and music.may_play(OS.has_feature("web")) and not (name == "dawn" and juice.sounds.has("win")):
			sting.play()
	music.sounded(juice.sounds)
	if won_in(world.events):
		_set_winning(true)
	ui.after_step(world)
	queue_redraw()
	overlay.queue_redraw()


func _process(delta: float) -> void:
	if perf:
		_perf(delta)
	touch.mode = "off" if intro or choosing else "paused" if paused else "won" if winning else "ended" if Ui.ENDINGS.has(world.phase) else world.phase if world.phase == "pick" else "play"
	touch.targets = ui.targets(world)
	touch.music_on = records.music
	_music(delta)
	touch.dash_shown = world.mod("dash_every", 0.0) > 0.0
	touch.attack_icon = Looks.character(world.character).button
	touch.guide_controls = intro and ui.guide.page == Guide.CONTROLS
	touch.frame(delta)
	ui.touch = touch.on
	ui.frame(world, delta)
	overlay.queue_redraw() # the ui's dim, flights and flashes move on real time, also while the world is not stepped
	var day: float = painter.daylight(world)
	sky.color = painter.sky(world)
	if ground != null:
		ground.set_shader_parameter("day", day)
	var energy: float = lerpf(TORCH_ENERGY, DAY_ENERGY, day) * (Painter.flicker(world) + FLARE_ENERGY * painter.flare()) if world.fuel > 0.0 else 0.0
	for i in torch_lights.size(): # together as bright as one light; where only one ring's tongue reaches, half
		torch_lights[i].texture_scale = world.light_radius() * 2.0 / Painter.LIGHT_SIZE
		torch_lights[i].rotation = Painter.light_turn(world, i)
		torch_lights[i].energy = energy / torch_lights.size()
	# The keeper's ember (painter.gd) fades where the torch already lights them, so the two never add up to a white blot.
	var from_torch: float = world.player.pos.distance_to(Config.TORCH.pos) / world.light_radius()
	player_light.energy = painter.ember_glow(world) * (1.0 - day) * (clampf(from_torch, 0.0, 1.0) if world.fuel > 0.0 else 1.0)
	player_light.texture_scale = painter.ember_reach() * 2.0 / Painter.LIGHT_SIZE
	player_light.color = painter.ember_colour()
	player_light.position = world.player.pos
	var lit: Array = painter.ember_lights(world)
	for i in ember_lights.size():
		var light: PointLight2D = ember_lights[i]
		light.visible = i < lit.size() and day < 1.0
		if light.visible:
			light.position = lit[i][0]
			light.texture_scale = lit[i][1] * 2.0 / Painter.LIGHT_SIZE
			light.energy = lit[i][2] * (1.0 - day)


## The music, every drawn frame: a few milliseconds of making its samples until all are made (each player gets its
## sample when it is whole), then each loop's player turned to what the world asks for (src/audio/music.gd). A loop
## plays from the moment it may (after the first press, in a browser) and is only ever turned down, never stopped;
## the three of one length start on the same frame, so the tight one stays in step with the night's and the boss's.
func _music(delta: float) -> void:
	if music_players.is_empty():
		return
	if not music_makers.is_empty() and music_makers[0].work(Time.get_ticks_usec() + MUSIC_WORK_USEC):
		var made = music_makers.pop_front()
		music_players[made.name].stream = made.stream
	music.frame(delta, Music.state(world, intro or choosing), Music.urgency(world), records.music)
	if not music.may_play(OS.has_feature("web")):
		return
	var layers_made: bool = Music.LAYERED.all(func(name): return music_players[name].stream != null)
	for name in Music.LOOPS:
		var player: AudioStreamPlayer = music_players[name]
		if player.stream == null or (Music.LAYERED.has(name) and not layers_made):
			continue
		player.volume_db = MUSIC_DB + linear_to_db(maxf(music.gain(name), 0.0001))
		if not player.playing:
			player.play()


## --perf: once a second, how big the crowd is and what it costs. The draw calls are the last frame's.
func _perf(delta: float) -> void:
	perf_frames += 1
	perf_frame_max = maxf(perf_frame_max, delta)
	var now := Time.get_ticks_msec()
	if now - perf_since < 1000:
		return
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("perf: night %d, %d enemies, %d fps, frame max %.1f ms, step %.2f ms (%d steps), %d held, paint %.2f ms/frame, process %.1f ms, physics %.1f ms, %d draw calls" % [world.night, world.enemies.size(), perf_frames * 1000 / maxi(1, now - perf_since), perf_frame_max * 1000.0, perf_step_us / 1000.0 / maxi(1, perf_steps), perf_steps, perf_held, perf_paint_us / 1000.0 / maxi(1, perf_frames), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, calls])
	perf_since = now
	perf_frames = 0
	perf_frame_max = 0.0
	perf_step_us = 0
	perf_steps = 0
	perf_held = 0
	perf_paint_us = 0


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	painter.paint(self, world)
	perf_paint_us += Time.get_ticks_usec() - t0
