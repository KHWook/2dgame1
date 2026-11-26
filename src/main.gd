## Boot, and the only bridge between the engine and the simulation. It turns key events into InputFrames, steps the
## world on Godot's fixed physics tick (D5), and shows the world by reading it (D4): src/art/painter.gd paints it.
## Words go in Control nodes such as Label, never into the world (C1).
extends Node2D

const World := preload("res://src/sim/world.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Config := preload("res://src/sim/config.gd")
const Bot := preload("res://src/bot.gd")
const Painter := preload("res://src/art/painter.gd")
const Looks := preload("res://src/art/looks.gd")
const Records := preload("res://src/records.gd")
const Juice := preload("res://src/art/juice.gd")
const Sfx := preload("res://src/audio/sfx.gd")

const KEYS := {
	KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right",
	KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down",
	KEY_X: "attack", KEY_J: "attack", KEY_SPACE: "attack",
	KEY_SHIFT: "dash", KEY_K: "dash",
	KEY_1: "pick_1", KEY_2: "pick_2", KEY_3: "pick_3", KEY_R: "restart",
}
const PAUSE_KEYS := [KEY_P, KEY_ESCAPE]
const SFX_DB := -12.0 # how loud the sound effects play: under the player's own music, if any
const ENDINGS := { "out": "횃불이 꺼졌다", "dead": "쓰러졌다" }
const TORCH_LIGHT := Color("#ffcf8a")
const TORCH_ENERGY := 1.0
const DAY_ENERGY := 0.3 # the torch still glows a little once the sun is up
const FLARE_ENERGY := 0.5 # how much brighter the torch burns for a moment when it is fed
const KEEPER_ENERGY := 0.45 # the keeper's own small glow, so you can see yourself out in the dark
const KEEPER_GLOW := 0.35 # its size, as a scale of the 128px glow texture
const PANEL := Color(0.1, 0.08, 0.14, 0.78) # behind the words in the middle of the screen
const BOX_TOP := 12.0 # where those words start, clear of the torch
const HINT_TOP := 30.0 # where the hints start, under the clock
const FONT_SIZE := 8
## The HUD's words: a dark outline so they read over grass and light, the clock until dawn bigger than the rest,
## and how long the torch lasts, which turns red when the fuel is low (Painter.fuel_low).
const OUTLINE := Color("#1a1423")
const OUTLINE_SIZE := 3
const CLOCK_SIZE := 12
const HUD_TEXT := Color("#f3ead2")
const DAWN_SOON := Color("#ffd84a") # the clock in the night's last seconds
const DAWN_SOON_SECONDS := 10.0
const FUEL_LOW := Color("#ff5a4a")
const KEY_TEXT := Color("#ffc94a") # the key to press, under an ending
## The upgrades on offer are cards side by side: their size, the gap between them, how much the icon is enlarged,
## and their colours (background, border, the key badge, the name, the text).
const CARD := Vector2(100.0, 0.0) # as tall as the tallest card's words
const CARD_GAP := 6
const CARD_ICON := 2.0
const CARD_BACK := Color(0.16, 0.12, 0.2, 0.95)
const CARD_EDGE := Color("#c8862f")
const CARD_KEY := Color("#ffc94a")
const CARD_NAME := Color("#ffe6a8")
const CARD_TEXT := Color("#e6dcc6")
const LEVELS := ["", "", " II", " III", " IV", " V"] # after an upgrade's name: the level it would be taken to
const HINT_STEPS := 60 * 4 # simulation steps a hint stays up
const BOT_LOOKS := 90 # steps a demo bot leaves an offer on screen before it picks, so a person watching can read it

var world
var painter
var bot = null # set by the --bot user arg: the bot plays instead of the keyboard
var bot_looked := 0 # steps the demo bot has spent on the offer in front of it
var held := {}
var pending := {} # presses since the last step; each counts for exactly one step (D6)
var sky: CanvasModulate
var overlay: Node2D # above the night and the lights: what glows by itself, and the HUD pictures
var hud: Label # the night and the score, top right
var clock: Label # time until dawn, top middle, over Painter.NIGHT_BAR
var fuel_time: Label # how long the torch lasts, just past the fuel bar
var records # src/records.gd: the best runs on disk
var seed_value := 1
var box: PanelContainer # the words in the middle of the screen: what the torch offers, or how the night ended
var title: Label
var cards: HBoxContainer # the offer cards, side by side
var offers: Array = [] # one per offer slot: { "card": PanelContainer, "key": Label, "icon": TextureRect, "name": Label, "text": Label }
var foot: Label # under an ending: this run's night and score, and where it landed among the records
var board: Label # under that: the best runs
var again: Label # last: how to play again
var boss_name: Label # over the boss's health bar while a boss is on the field
var hint_box: PanelContainer # one line about a thing, the first time it turns up
var hint: Label
var hints_told := {} # things already explained; each is explained once, however many nights are played
var hints_waiting: Array = [] # lines queued behind the one that is showing
var hint_steps := 0 # steps the showing hint has left
var torch_light: PointLight2D
var juice # src/art/juice.gd: hit-stop, shake, and which sounds the last step made
var sfx := {} # sound name -> its AudioStreamPlayer
var paused := false
var pause_label: Label
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
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 128
	glow.height = 128
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	glow.gradient = g
	torch_light = PointLight2D.new()
	torch_light.texture = glow
	torch_light.color = TORCH_LIGHT
	torch_light.position = Config.TORCH.pos
	add_child(torch_light)
	player_light = PointLight2D.new()
	player_light.texture = glow
	player_light.texture_scale = KEEPER_GLOW
	add_child(player_light)
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Node2D.new()
	overlay.draw.connect(func(): painter.paint_overlay(overlay, world))
	layer.add_child(overlay)
	hud = _label(layer, HORIZONTAL_ALIGNMENT_RIGHT)
	hud.position = Vector2(0, 2)
	hud.size = Vector2(Painter.VIEW.x - 4.0, 12.0)
	_outline(hud)
	clock = _label(layer, HORIZONTAL_ALIGNMENT_CENTER)
	clock.add_theme_font_size_override("font_size", CLOCK_SIZE)
	clock.position = Vector2(0, 0)
	clock.size = Vector2(Painter.VIEW.x, Painter.NIGHT_BAR.position.y - 1.0)
	_outline(clock)
	fuel_time = _label(layer, HORIZONTAL_ALIGNMENT_LEFT)
	fuel_time.size = Vector2(60.0, 10.0)
	_outline(fuel_time)
	box = PanelContainer.new()
	var back := StyleBoxFlat.new()
	back.bg_color = PANEL
	back.set_content_margin_all(4.0)
	box.add_theme_stylebox_override("panel", back)
	layer.add_child(box)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 1)
	box.add_child(lines)
	title = _label(lines, HORIZONTAL_ALIGNMENT_CENTER)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", CARD_GAP)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_child(cards)
	for i in Config.NIGHT.offer_size:
		offers.append(_card(i))
	foot = _label(lines, HORIZONTAL_ALIGNMENT_CENTER)
	foot.add_theme_font_size_override("font_size", CLOCK_SIZE)
	board = _label(lines, HORIZONTAL_ALIGNMENT_CENTER)
	board.add_theme_color_override("font_color", CARD_TEXT)
	again = _label(lines, HORIZONTAL_ALIGNMENT_CENTER)
	again.add_theme_color_override("font_color", KEY_TEXT)
	again.text = "R 다시 하기"
	hint_box = PanelContainer.new()
	hint_box.add_theme_stylebox_override("panel", back)
	layer.add_child(hint_box)
	hint = _label(hint_box, HORIZONTAL_ALIGNMENT_CENTER)
	boss_name = _label(layer, HORIZONTAL_ALIGNMENT_CENTER)
	boss_name.position = Vector2(Painter.BOSS_BAR.position.x, Painter.BOSS_BAR.position.y - 13.0)
	boss_name.size = Vector2(Painter.BOSS_BAR.size.x, 10.0)
	_outline(boss_name)
	pause_label = _label(layer, HORIZONTAL_ALIGNMENT_CENTER)
	pause_label.add_theme_font_size_override("font_size", CLOCK_SIZE)
	pause_label.text = "일시정지"
	pause_label.position = Vector2(0.0, roundf(Painter.VIEW.y / 2.0 - 8.0))
	pause_label.size = Vector2(Painter.VIEW.x, 16.0)
	pause_label.visible = false
	_outline(pause_label)


## One offer card: the key that takes it in a badge at the top, the icon enlarged, the name, then what it does.
func _card(i: int) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACK
	style.border_color = CARD_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3.0)
	card.add_theme_stylebox_override("panel", style)
	cards.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	card.add_child(stack)
	var key := _label(stack, HORIZONTAL_ALIGNMENT_CENTER)
	key.text = "[ %d ]" % (i + 1)
	key.add_theme_color_override("font_color", CARD_KEY)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(icon)
	var heading := _label(stack, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override("font_color", CARD_NAME)
	var text := _label(stack, HORIZONTAL_ALIGNMENT_CENTER)
	text.add_theme_color_override("font_color", CARD_TEXT)
	return { "card": card, "key": key, "icon": icon, "name": heading, "text": text }


## The words broken into lines at spaces only, each no wider than width in label's font. The label's own autowrap
## would also break inside a Korean word.
func _wrap(label: Label, words: String, width: float) -> String:
	var font := label.get_theme_font("font")
	var lines: Array = []
	for word in words.split(" "):
		var longer: String = word if lines.is_empty() else lines[-1] + " " + word
		if not lines.is_empty() and font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x <= width:
			lines[-1] = longer
		else:
			lines.append(word)
	return "\n".join(lines)


func _label(parent: Node, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and PAUSE_KEYS.has(k.keycode):
		paused = not paused
		pause_label.visible = paused
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
	if paused: # presses made while paused are dropped; keys still held count again once it goes on
		return
	var holding: bool = juice.hold > 0 # hit-stop: the world is not stepped, so it is the same step a moment later
	juice.frame()
	position = juice.offset # the field and its lights; the HUD is on its own layer and stays put
	painter.shake = juice.offset
	if holding:
		overlay.queue_redraw()
		return
	bot_looked = bot_looked + 1 if bot != null and world.phase == "pick" else 0
	if bot_looked > 0 and bot_looked < BOT_LOOKS:
		return
	world.step(bot.frame(world) if bot != null else f)
	if bot == null: # the demo bot's runs are not the player's records
		records.step(world, seed_value, Time.get_datetime_string_from_system(false, true))
	painter.step(world)
	juice.step(world)
	for name in juice.sounds:
		sfx[name].play()
	_hints()
	queue_redraw()
	overlay.queue_redraw()


func _process(_delta: float) -> void:
	var left := maxf(0.0, Config.NIGHT.length - world.time)
	hud.text = "%d번째 밤   점수 %d" % [world.night, world.score]
	var night: bool = world.phase == "night"
	clock.visible = night
	clock.text = "새벽까지 " + _clock(left)
	clock.add_theme_color_override("font_color", DAWN_SOON if left < DAWN_SOON_SECONDS else HUD_TEXT)
	fuel_time.visible = night
	var bar: Rect2 = Painter.fuel_bar(world)
	fuel_time.position = Vector2(bar.end.x + 4.0, bar.position.y + bar.size.y / 2.0 - 6.0)
	var smothered: bool = Painter.smothered(world)
	fuel_time.text = ("꺼지기까지 " + _clock(Painter.fuel_left(world)) + ("  덮였다!" if smothered else "")) if world.fuel > 0.0 else "꺼졌다"
	fuel_time.add_theme_color_override("font_color", FUEL_LOW if Painter.fuel_low(world) or smothered else HUD_TEXT)
	painter.fuel_text_width = _width(fuel_time) if night else 0.0
	painter.score_text_width = _width(hud)
	_words()
	var b = Painter.boss(world)
	var coming: bool = world.boss_from != null
	boss_name.visible = (b != null or coming) and world.phase == "night"
	if b != null:
		boss_name.text = b.T.name
	elif coming: # the painter points at the edge it comes from
		var who: String = Config.ENEMY_TYPES[world.boss_kind()].name
		boss_name.text = "%s%s 다가온다!" % [who, _subject(who)]
	var day: float = painter.daylight(world)
	sky.color = painter.sky(world)
	torch_light.texture_scale = world.light_radius() * 2.0 / 128.0
	torch_light.energy = lerpf(TORCH_ENERGY, DAY_ENERGY, day) * (1.0 + FLARE_ENERGY * painter.flare()) if world.fuel > 0.0 else 0.0
	# The keeper's glow fades where the torch already lights them, so the two never add up to a white blot.
	var from_torch: float = world.player.pos.distance_to(Config.TORCH.pos) / world.light_radius()
	player_light.energy = KEEPER_ENERGY * (1.0 - day) * (clampf(from_torch, 0.0, 1.0) if world.fuel > 0.0 else 1.0)
	player_light.position = world.player.pos


## The subject particle that goes after a Korean word: 이 after a final consonant, 가 after a vowel.
static func _subject(word: String) -> String:
	var last := word.unicode_at(word.length() - 1)
	return "이" if last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 != 0 else "가"


## Says what each kind of thing does the first time it turns up, one line at a time.
func _hints() -> void:
	var here: Array = world.enemies.map(func(e): return e.kind)
	if not world.berries.is_empty():
		here.append("berry")
	for thing in here:
		if Looks.HINTS.has(thing) and not hints_told.has(thing):
			hints_told[thing] = true
			hints_waiting.append(Looks.HINTS[thing])
	if world.phase == "night":
		hint_steps = maxi(0, hint_steps - 1)
		if hint_steps == 0 and not hints_waiting.is_empty():
			hint.text = hints_waiting.pop_front()
			hint_steps = HINT_STEPS
	hint_box.visible = hint_steps > 0 and world.phase == "night"
	hint_box.reset_size()
	hint_box.position = Vector2(roundf((Painter.VIEW.x - hint_box.size.x) / 2.0), HINT_TOP)


## Fills the box in the middle of the screen: what the torch offers while you pick, the result once the night is over.
func _words() -> void:
	var picking: bool = world.phase == "pick"
	var ended: bool = ENDINGS.has(world.phase)
	box.visible = picking or ended
	if picking:
		var dusk := ""
		if world.time == 0.0: # the offer at dusk, between two nights; the one in the middle of a night has no heading
			dusk = ("새벽이 왔다! " if world.night > 1 else "") + "%d번째 밤이 온다\n" % world.night
		title.text = dusk + "횃불이 힘을 하나 내어 준다"
	elif ended:
		title.text = ENDINGS[world.phase]
		foot.text = "%d번째 밤 · 점수 %d" % [world.night, world.score] + (" · 새 기록!" if records.place == 1 else (" · %d위" % records.place if records.place > 1 else ""))
		foot.add_theme_color_override("font_color", KEY_TEXT if records.place == 1 else HUD_TEXT)
		board.text = _board()
	title.add_theme_font_size_override("font_size", CLOCK_SIZE if ended else FONT_SIZE)
	foot.visible = ended
	board.visible = ended and board.text != ""
	again.visible = ended
	cards.visible = picking
	for i in offers.size():
		var shown: bool = picking and i < world.offer.size()
		offers[i].card.visible = shown
		if shown:
			var next: int = world.level(world.offer[i]) + 1
			var u: Dictionary = World.upgrade(world.offer[i], next)
			var icon: Texture2D = painter.icon(world.offer[i])
			offers[i].icon.texture = icon
			offers[i].icon.custom_minimum_size = icon.get_size() * CARD_ICON
			offers[i].name.text = u.name + LEVELS[mini(next, LEVELS.size() - 1)]
			offers[i].text.text = _wrap(offers[i].text, u.text, CARD.x - 8.0)
	box.reset_size()
	box.position = Vector2(roundf((Painter.VIEW.x - box.size.x) / 2.0), BOX_TOP)


## Seconds as m:ss, rounded up so the clock reads 0:00 only when the time is really out.
static func _clock(seconds: float) -> String:
	if is_inf(seconds):
		return "-:--"
	var s := int(ceilf(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## How wide a label's words are on screen.
static func _width(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


func _outline(label: Label) -> void:
	label.add_theme_color_override("font_color", HUD_TEXT)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)


## The best runs, one per line, the one that just ended marked; empty when there are none yet.
func _board() -> String:
	var lines := []
	for i in mini(records.runs.size(), Records.SHOWN):
		var r: Dictionary = records.runs[i]
		var mark := "  ◀ 이번" if is_same(r, records.latest) else ""
		lines.append("%d위   %d점 · %d번째 밤 · %s%s" % [i + 1, r.score, r.night, _day(r.date), mark])
	return ("최고 기록\n" + "\n".join(lines)) if not lines.is_empty() else ""


## A record's date as month and day, from the "YYYY-MM-DD hh:mm:ss" the clock gave.
static func _day(date: String) -> String:
	var parts := date.split(" ")[0].split("-")
	return "%d월 %d일" % [int(parts[1]), int(parts[2])] if parts.size() == 3 else ""


func _draw() -> void:
	painter.paint(self, world)
