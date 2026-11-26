## Boot, and the only bridge between the engine and the simulation. It turns key events into InputFrames, steps the
## world on Godot's fixed physics tick (D5), and shows the world by reading it (D4): src/art/painter.gd paints it.
## Words go in Control nodes such as Label, never into the world (C1): src/ui.gd holds them all.
extends Node2D

const World := preload("res://src/sim/world.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")
const Bot := preload("res://src/bot.gd")
const Painter := preload("res://src/art/painter.gd")
const Records := preload("res://src/records.gd")
const Juice := preload("res://src/art/juice.gd")
const Sfx := preload("res://src/audio/sfx.gd")
const Ui := preload("res://src/ui.gd")

const KEYS := {
	KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right",
	KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down",
	KEY_X: "attack", KEY_J: "attack", KEY_SPACE: "attack",
	KEY_SHIFT: "dash", KEY_K: "dash",
	KEY_1: "pick_1", KEY_2: "pick_2", KEY_3: "pick_3", KEY_R: "restart",
}
const PAUSE_KEYS := [KEY_P, KEY_ESCAPE]
const HELP_KEY := KEY_H # brings the first screen back
const SFX_DB := -12.0 # how loud the sound effects play: under the player's own music, if any
const TORCH_LIGHT := Color("#ffcf8a")
const TORCH_ENERGY := 1.25 # the night is nearly black, so what you see by is all the torch's
const DAY_ENERGY := 0.3 # the torch still glows a little once the sun is up
const FLARE_ENERGY := 0.5 # how much brighter the torch burns for a moment when it is fed
const BOT_LOOKS := 90 # steps a demo bot leaves an offer on screen before it picks, so a person watching can read it

var world
var painter
var bot = null # set by the --bot user arg: the bot plays instead of the keyboard
var bot_looked := 0 # steps the demo bot has spent on the offer in front of it
var held := {}
var pending := {} # presses since the last step; each counts for exactly one step (D6)
var sky: CanvasModulate
var overlay: Node2D # above the night and the lights: what glows by itself, and the HUD pictures
var ui # src/ui.gd: every word on screen, and the offer cards
var records # src/records.gd: the best runs on disk
var seed_value := 1
var torch_lights: Array = [] # one PointLight2D per ring of tongues (Painter.LIGHT_RINGS), turning against each other
var juice # src/art/juice.gd: hit-stop, shake, and which sounds the last step made
var sfx := {} # sound name -> its AudioStreamPlayer
var paused := false
var intro := false # the first screen is up (src/ui.gd): the world waits, and the next key or click takes it away
var player_light: PointLight2D

func _ready() -> void:
	var skip := 0
	var slot := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		if a.begins_with("--skip="):
			skip = int(a.substr(7))
		if a.begins_with("--slot="): # which offer the bot always takes; --bot --seed=6 --slot=3 is the replay's night
			slot = int(a.substr(7))
	if OS.get_cmdline_user_args().has("--bot"):
		bot = Bot.new(slot)
	world = World.new(seed_value)
	records = Records.new()
	for i in skip if bot != null else 0: # --bot --skip=N: the bot plays N steps before the first frame, to look at a late night
		world.step(bot.frame(world))
	painter = Painter.new(seed_value)
	juice = Juice.new(seed_value)
	juice.seen(world)
	for name in Sfx.SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = Sfx.make(name)
		player.volume_db = SFX_DB
		add_child(player)
		sfx[name] = player
	sky = CanvasModulate.new()
	add_child(sky)
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
	overlay = Node2D.new()
	overlay.draw.connect(func(): painter.paint_overlay(overlay, world))
	ui = Ui.new()
	add_child(ui)
	ui.setup(painter, records, overlay, bot.pick if bot != null else 0, world)
	_set_intro(bot == null) # the demo bot starts at once
	ui.chosen.connect(func(slot: int): pending["pick_%d" % (slot + 1)] = true)


func _set_intro(on: bool) -> void:
	intro = on
	ui.intro = on


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	var click := event as InputEventMouseButton
	if intro: # the key or click that takes the first screen away does nothing else
		if (k != null and k.pressed and not k.echo) or (click != null and click.pressed):
			_set_intro(false)
		return
	if k != null and k.pressed and not k.echo and k.keycode == HELP_KEY:
		_set_intro(true)
		return
	if k != null and k.pressed and not k.echo and PAUSE_KEYS.has(k.keycode):
		paused = not paused
		ui.set_paused(paused, world)
		return
	if k == null or not KEYS.has(k.keycode):
		return
	var action: String = KEYS[k.keycode]
	if k.pressed and not k.echo:
		if not held.has(action):
			pending[action] = true
		held[action] = true
	elif not k.pressed:
		held.erase(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held.clear()


func _physics_process(_delta: float) -> void:
	var f := InputFrame.new()
	f.held = held.duplicate()
	f.pressed = pending
	pending = {}
	if paused or intro: # presses made while paused are dropped; keys still held count again once it goes on
		return
	var holding: bool = juice.hold > 0 # hit-stop: the world is not stepped, so it is the same step a moment later
	juice.frame()
	position = juice.offset # the field and its lights; the HUD is on its own layer and stays put
	painter.shake = juice.offset
	if holding:
		overlay.queue_redraw()
		return
	bot_looked = bot_looked + 1 if bot != null and world.phase == "pick" else 0
	ui.bot_looked = bot_looked
	if bot_looked > 0 and bot_looked < BOT_LOOKS:
		return
	world.step(bot.frame(world) if bot != null else f)
	if bot == null: # the demo bot's runs are not the player's records
		records.step(world, seed_value, Time.get_datetime_string_from_system(false, true))
	painter.step(world)
	juice.step(world)
	for name in juice.sounds:
		sfx[name].play()
	ui.after_step(world)
	queue_redraw()
	overlay.queue_redraw()


func _process(delta: float) -> void:
	ui.frame(world, delta)
	overlay.queue_redraw() # the ui's dim, flights and flashes move on real time, also while the world is not stepped
	var day: float = painter.daylight(world)
	sky.color = painter.sky(world)
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


func _draw() -> void:
	painter.paint(self, world)
