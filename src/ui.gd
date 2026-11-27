## The words on screen and how they move: the HUD's night, score, clock and fuel time; the torch's offer as cards
## that are dealt in, lift under the mouse (or under the slot the demo bot is about to take), and fly the taken icon
## to its HUD tile; a line naming what was just taken; a line about each new thing the first time it turns up; the
## pause screen and the end screen, which list the upgrades held by name.
## View only (D4): it reads the world and never writes to it. main.gd owns it, calls after_step() after each world
## step and frame() every drawn frame, and presses a card's key when chosen is emitted (a click on a card).
## Its motion runs on real time, not on simulation steps: it never holds the world, so the bot and the replay never
## wait for it. Words go in Labels (C1); the painter draws the pictures under them.
extends CanvasLayer

const World := preload("res://src/sim/world.gd")
const Config := preload("res://src/sim/config.gd")
const Painter := preload("res://src/art/painter.gd")
const Looks := preload("res://src/art/looks.gd")
const Records := preload("res://src/records.gd")
const Sprites := preload("res://src/art/sprites.gd")
const Guide := preload("res://src/guide.gd")
const Coach := preload("res://src/coach.gd")
const Chooser := preload("res://src/chooser.gd")

signal chosen(slot: int) # a card was clicked: main.gd presses that slot's key for the next step

## One palette and three sizes for every word. Each word has a dark outline so it reads over grass, light and day.
## The words are Galmuri (assets/fonts/, SIL OFL 1.1), a Korean pixel font. A pixel font is crisp only at its own
## size and its multiples, so each size is the size its file was drawn for, one font pixel per game pixel, and the
## font is drawn without smoothing: at any whole-number window scale its pixels land on the game's pixel grid.
const INK := Color("#1a1423") # outlines
const CREAM := Color("#f3ead2") # plain words
const MUTED := Color("#b4a993") # what labels a number: "점수", "새벽까지", how to press
const GOLD := Color("#ffd84a") # the score, keys, the clock's last seconds, a new record
const WARM := Color("#ffe6a8") # names: upgrades, enemies, headings
const RED := Color("#ff5a4a") # danger: low fuel, a boss
const FRESH := Color("#a6e36a") # an upgrade not held yet
const SIDE_COLOUR := { "torch": Color("#ffb05a"), "keeper": Color("#9cc8ff") }
const SMALL := 10 # Galmuri9 is drawn for 10px
const BIG := 12 # Galmuri11 Bold, 12px: the numbers and headings that should hit hardest
const HUGE := 15 # Galmuri14, 15px
const FONT_FILES := {
	SMALL: "res://assets/fonts/Galmuri9.woff",
	BIG: "res://assets/fonts/Galmuri11-Bold.woff",
	HUGE: "res://assets/fonts/Galmuri14.woff",
}
const OUTLINE_SIZE := 2
const LINE_SPACING := 2 # pixels between the lines of a wrapped text: the pixel font has none of its own
const PANEL := Color(0.1, 0.08, 0.14, 0.9) # behind the boxes in the middle of the screen
const PAUSE_PANEL := Color(0.08, 0.06, 0.11, 1.0) # the pause list covers the HUD, so nothing shows through it
const PANEL_EDGE := Color("#4a3d5c")
const ENDINGS := { "out": "횃불이 꺼졌다", "dead": "쓰러졌다" }
const LEVEL := " Lv.%d" # after a name from level 2: Roman numerals read as bars ("||") in the pixel font
const DAWN_SOON_SECONDS := 10.0
const BOSS_NAME_WIDTH := 70.0 # room for a boss's name left of its bar
const BOSS_NAME_GAP := 4.0

## The offer cards: size, gap, icon enlargement, colours.
const CARD := Vector2(112.0, 0.0) # as tall as the tallest card's words
const CARD_GAP := 6.0
const CARD_ICON := 2.0
const CARD_BACK := Color(0.16, 0.12, 0.2, 0.97)
const CARD_EDGE := Color("#c8862f")
const CARD_TEXT := Color("#e6dcc6")
## Dealing: each card rises this far into place, flipping open, this long after the one before; then it bobs.
const DEAL_TIME := 0.32
const DEAL_APART := 0.09
const DEAL_DROP := 26.0
const BOB := 1.0 # pixels
const BOB_SPEED := 2.4 # radians per second
const FOCUS_LIFT := 4.0 # pixels a card under the mouse rises
const FOCUS_GROW := 0.06 # and how much bigger it gets
const FOCUS_RATE := 14.0 # how fast it eases there, per second
const UNFOCUSED := 0.78 # how bright the other cards stay while one is lifted
## Taking: the taken card flashes and swells while the others fall away, then its icon flies to its HUD tile.
const TAKE_TIME := 0.42
const TAKE_FALL := 22.0
const FLY_FROM := 0.12 # seconds into the take the icon leaves the card
const FLY_TIME := 0.5
const FLY_ARC := 24.0 # pixels the flight bows up
const FLASH_TIME := 0.7 # the tile's ring after the icon lands
const TOLD_TIME := 3.2 # seconds the line naming what was taken stays
const TOLD_TOP := 27.0
const FADE := 0.2
## The score: it pops when it rises, and the gain floats up under it.
const POP_TIME := 0.3
const POP_GROW := 0.3
const GAIN_TIME := 0.9
const GAIN_RISE := 6.0
## Hints: along the bottom, under what glows (so a warning line shows through), faded when something is behind them.
const HINT_STEPS := 60 * 4 # simulation steps a hint stays up
const HINT_BOTTOM := 18.0 # from the bottom of the screen to the hint's bottom, clear of the treetops and edge arrows
const HINT_RISE := 8.0
const BEHIND := 0.3 # how solid a line is while the keeper or a warning is behind it
const BEHIND_ENEMY := 0.6 # and while an enemy is
const BEHIND_MARGIN := 14.0
const BOT_FOCUS_AT := 50 # steps into its look at an offer the demo bot's slot lifts, so you see which it takes
## The first screen: a guide of Guide.PAGES pages with pictures (src/guide.gd decides what input does). main.gd
## shows it when the game opens (not to the demo bot) and again whenever HELP or the "?" button is pressed. Each
## page is a title and rows of [sprites, name, what to know]; "→" between sprites in a row reads as an arrow.
const INTRO_TITLE := "횃불 지기"
const GUIDE_PAGES := [
	{ "title": INTRO_TITLE, "lead": "밤마다 횃불을 지켜 새벽까지 버텨라", "rows": [
		[["keeper_down_a", "→", "log", "→", "flame_l_a"], "", ""],
		[["flame_m_a"], "횃불", "밤새 타서 줄어든다. 꺼지면 끝이다"],
		[["log"], "장작", "주워서 횃불에 가져가면 불이 다시 산다"],
		[["icon_bright"], "새벽", "버티면 다음 밤. 밤마다 더 어려워진다"],
	] },
	{ "title": "어둠에서 오는 것들", "lead": "칼로 베어서 쫓아내라", "rows": [
		[["slime_a"], "슬라임", "횃불에 붙어 불을 덮는다. 먼저 베어라"],
		[["bat_a"], "박쥐", "너를 쫓는다. 빛 밖에서 더 빠르다"],
		[["shade_a"], "어둠", "빛 밖은 캄캄하다. 적은 눈빛으로만 보인다"],
		[["icon_spark"], "힘", "해 질 녘과 한밤중에 횃불이 셋 중 하나를 준다"],
	] },
	{ "title": "조작", "lead": "", "rows": [] }, # filled for keys or touch in frame()
]
const GUIDE_KEYS := [
	[["pad_knob"], "이동", "WASD · 방향키"],
	[["sword"], "베기", "Space · J · X (장작을 들었으면 내려놓기)"],
	[["icon_dash"], "돌진", "Shift · K (돌진 힘을 얻은 뒤)"],
	[["pause_bars"], "멈춤", "P · Esc     이 설명 다시 보기 H"],
]
## On a phone the controls page has few words: touch.gd draws the stick and the buttons where they really are.
const GUIDE_TOUCH := [
	[["pad_knob"], "이동", "왼쪽 아무 데나 누르고 끌기"],
	[["sword"], "베기", "오른쪽 아무 데나 누르기"],
	[["pause_bars"], "멈춤", "오른쪽 위 버튼, 그 옆 ?는 이 설명"],
]
const GUIDE_TURN_KEYS := "← → 넘기기 · Enter 시작"
const GUIDE_TURN_TOUCH := "옆으로 밀거나 눌러서 넘기기"
const GUIDE_NEXT := "다음 ▶"
const GUIDE_START := "시작"
const GUIDE_BACK := "돌아가기"
const GUIDE_DOT := "●"
const GUIDE_DOT_OFF := "○"
const GUIDE_BOX := Rect2(80.0, 8.0, 320.0, 204.0) # the page's panel: clear of where the controls page draws the stick and the buttons
const GUIDE_WAITING := 0.35 # how solid the buttons are while the guide does not listen yet
## The short lines under the cards, the end and the pause screen: for keys, and for a phone (src/touch.gd).
## The choosing screen (src/chooser.gd): a card per character, dealt in like the offer, the one in focus lifted.
const CHOOSE_TITLE := "누가 횃불을 지킬까"
const CHOOSE_KEYS := "1 · 2 · 3 키, ← → 와 Enter, 또는 클릭으로 고르기"
const CHOOSE_TOUCH := "카드를 눌러 고르기"
const CHOOSE_PORTRAIT := 3.0 # the character's picture on its card, this many times its size
const CHOOSE_PIPS := 5 # pips per bar
const CHOOSE_PIP := Vector2(9.0, 4.0)
const CHOOSE_PIP_OFF := Color("#3a3350")
const CHOOSE_BAR_NAME := 26.0 # the width kept for a bar's name, so the pips line up
const CHOOSE_HP := "체력"
const PICK_KEYS := "1 · 2 · 3 키 또는 클릭으로 고르기"
const PICK_TOUCH := "카드를 눌러 고르기"
const AGAIN_KEYS := "R 다시 하기"
const AGAIN_TOUCH := "눌러서 다시 하기"
const PAUSE_KEYS := "P / Esc 계속하기 · H 설명 보기"
const PAUSE_TOUCH := "눌러서 계속하기 · ? 설명 보기"
const INTRO_NAME := 34.0 # the width kept for a line's name, so what follows lines up
const INTRO_BLINK := 3.0 # radians per second the button that goes on breathes
const INTRO_SCRIM := 0.7
const COACH_ABOVE := 9.0 # pixels above the thing the coaching arrow's tip stays
const COACH_BOB := 1.5
const PAUSE_COLUMN := 210.0
const PAUSE_LINES := 22 # the pause list drops the upgrades' words past this many lines, keeping just the names

static var _fonts := {} # size -> its pixel font, loaded the first time it is asked for

var painter
var records
var bot_slot := 0 # the demo bot's slot, from 1; 0 without a bot
var bot_looked := 0 # set by main.gd: steps the demo bot has looked at this offer
var paused := false
var intro := false # set by main.gd: the first screen is up
var choosing := false # set by main.gd: the choosing screen is up
var chooser = Chooser.new() # what the choosing screen's input does; main.gd feeds it
var choose_title: Label
var choose_hint: Label
var choose_cards: Array = [] # per character, in Chooser.ids() order: { card, style, key_style, focus }
var choose_age := 0.0 # real seconds since the choosing screen opened
var guide = Guide.new() # what the first screen's input does; main.gd feeds it
var coach = Coach.new() # the first night's arrows, on for a player who has not read the guide
var guide_box: PanelContainer
var guide_pages: Array = [] # per page: its VBoxContainer
var guide_controls: VBoxContainer # the controls page's rows, rebuilt when touch changes
var guide_controls_touch := -1 # which rows guide_controls holds: 1 touch, 0 keys, -1 none yet
var guide_dots: Label
var guide_turn: Label
var guide_right: PanelContainer
var guide_right_label: Label
var guide_left: PanelContainer
var guide_left_label: Label
var coach_label: Label
var coach_arrow: TextureRect
var pause_keys: Label
var touch := false # set by main.gd: the touch controls are showing, so the words say tap instead of keys

var hint_box: PanelContainer
var hint_icon: TextureRect
var hint_name: Label
var hint_text: Label
var hints_told := {} # things already explained; each is explained once, however many nights are played
var hints_waiting: Array = [] # kinds queued behind the one that is showing
var hint_steps := 0
var hint_age := 0.0

var night_label: Label
var score_word: Label
var score_label: Label
var gain_label: Label
var clock_word: Label
var clock: Label
var fuel_time: Label
var boss_name: Label # a boss on its way, over the bars
var boss_names: Array = [] # the name of each boss on the field, left of its bar (Painter.boss_bar)

var box: PanelContainer
var heading: Label
var subheading: Label
var row: Control # the cards, placed by hand so they can move
var offers: Array = [] # per slot: { card, style, key, tag, icon, name, text, focus }
var press: Label
var foot: Label
var held_head: Label
var held_flow: HFlowContainer
var board: Label
var again: Label

var pause_box: PanelContainer
var pause_columns: HBoxContainer

var told_box: PanelContainer
var told_icon: TextureRect
var told_name: Label
var told_text: Label
var told_age := -1.0

var flier: TextureRect

var offer_key := ""
var last_offer: Array = []
var last_picks := 0
var deal := 0.0 # seconds since this offer was dealt
var taken := -1 # the slot just taken while its card plays out, -1 otherwise
var take_age := 0.0
var fly_id := ""
var fly_from := Vector2.ZERO
var flash_age := -1.0
var shown_score := 0
var pop := 0.0
var gain := 0
var gain_age := -1.0
var last_second := -1
var tick := 0.0
var clock_time := 0.0 # real seconds, for the bob and the blinking key


## Builds every piece; overlay is the node the painter draws the HUD pictures on, layered over the hints.
func setup(the_painter, the_records, overlay: Node2D, slot: int, w) -> void:
	painter = the_painter
	records = the_records
	bot_slot = slot
	hint_box = _panel(self)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 4)
	hint_box.add_child(hint_row)
	hint_icon = _icon(hint_row)
	hint_name = _label(hint_row, SMALL, GOLD)
	hint_text = _label(hint_row, SMALL, CREAM)
	hint_box.visible = false
	add_child(overlay)
	night_label = _label(self, SMALL, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	score_word = _label(self, SMALL, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	score_word.text = "점수"
	score_label = _label(self, BIG, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	gain_label = _label(self, SMALL, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	clock_word = _label(self, SMALL, MUTED)
	clock_word.text = "새벽까지"
	clock = _label(self, BIG, CREAM)
	fuel_time = _label(self, SMALL, CREAM)
	boss_name = _label(self, SMALL, RED, HORIZONTAL_ALIGNMENT_CENTER)
	boss_name.size = Vector2(Painter.BOSS_BAR.size.x, 12.0)
	for i in Config.BOSS.counts.map(func(r): return r.count).max():
		var l := _label(self, SMALL, RED, HORIZONTAL_ALIGNMENT_RIGHT)
		var bar: Rect2 = Painter.boss_bar(i)
		l.size = Vector2(BOSS_NAME_WIDTH, 12.0)
		l.position = Vector2(bar.position.x - BOSS_NAME_GAP - BOSS_NAME_WIDTH, bar.get_center().y - 7.0)
		boss_names.append(l)

	box = _panel(self, PANEL, 6.0)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	box.add_child(lines)
	heading = _label(lines, BIG, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	subheading = _label(lines, SMALL, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	row = Control.new()
	lines.add_child(row)
	for i in Config.NIGHT.offer_size:
		offers.append(_card(i))
	press = _label(lines, SMALL, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	foot = _label(lines, BIG, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	held_head = _label(lines, SMALL, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	held_head.text = "고른 힘"
	held_flow = HFlowContainer.new()
	held_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	held_flow.add_theme_constant_override("h_separation", 8)
	held_flow.add_theme_constant_override("v_separation", 1)
	held_flow.custom_minimum_size = Vector2(300.0, 0.0)
	lines.add_child(held_flow)
	board = _label(lines, SMALL, CARD_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	again = _label(lines, SMALL, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.visible = false

	told_box = _panel(self)
	var told_row := HBoxContainer.new()
	told_row.add_theme_constant_override("separation", 4)
	told_box.add_child(told_row)
	told_icon = _icon(told_row)
	var told_lines := VBoxContainer.new()
	told_lines.add_theme_constant_override("separation", 0)
	told_row.add_child(told_lines)
	told_name = _label(told_lines, SMALL, WARM)
	told_text = _label(told_lines, SMALL, MUTED)
	told_box.visible = false

	pause_box = _panel(self, PAUSE_PANEL, 6.0)
	var pause_lines := VBoxContainer.new()
	pause_lines.add_theme_constant_override("separation", 3)
	pause_box.add_child(pause_lines)
	var pause_title := _label(pause_lines, HUGE, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	pause_title.text = "일시정지"
	pause_keys = _label(pause_lines, SMALL, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pause_columns = HBoxContainer.new()
	pause_columns.add_theme_constant_override("separation", 10)
	pause_lines.add_child(pause_columns)
	pause_box.visible = false

	guide_box = _panel(self, PAUSE_PANEL, 8.0)
	guide_box.position = GUIDE_BOX.position
	guide_box.custom_minimum_size = GUIDE_BOX.size
	var guide_lines := VBoxContainer.new()
	guide_box.add_child(guide_lines)
	for page in GUIDE_PAGES:
		var page_lines := VBoxContainer.new()
		page_lines.add_theme_constant_override("separation", 5)
		page_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
		guide_lines.add_child(page_lines)
		_label(page_lines, HUGE, WARM, HORIZONTAL_ALIGNMENT_CENTER).text = page.title
		if page.lead != "":
			_label(page_lines, SMALL, CREAM, HORIZONTAL_ALIGNMENT_CENTER).text = page.lead
		for line in page.rows:
			_guide_row(page_lines, line)
		guide_pages.append(page_lines)
	guide_controls = VBoxContainer.new()
	guide_controls.add_theme_constant_override("separation", 6)
	guide_pages[Guide.CONTROLS].add_child(guide_controls)
	guide_turn = _label(guide_lines, SMALL, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	guide_dots = _label(guide_lines, SMALL, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	guide_right = _guide_button()
	guide_right_label = guide_right.get_child(0)
	guide_left = _guide_button()
	guide_left_label = guide_left.get_child(0)
	guide_box.visible = false
	coach_arrow = TextureRect.new()
	coach_arrow.texture = Sprites.alone("coach_arrow")
	coach_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_arrow.visible = false
	add_child(coach_arrow)
	coach_label = _label(self, SMALL, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	coach_label.visible = false

	choose_title = _label(self, HUGE, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	choose_title.text = CHOOSE_TITLE
	choose_title.size = Vector2(Painter.VIEW.x, 18.0)
	choose_title.position = Vector2(0.0, Chooser.TOP - 22.0)
	choose_hint = _label(self, SMALL, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	choose_hint.size = Vector2(Painter.VIEW.x, 12.0)
	choose_hint.position = Vector2(0.0, Chooser.TOP + Chooser.CARD.y + 6.0)
	for i in Chooser.ids().size():
		choose_cards.append(_char_card(i, Chooser.ids()[i]))
	choose_title.visible = false
	choose_hint.visible = false

	flier = TextureRect.new()
	flier.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flier.stretch_mode = TextureRect.STRETCH_SCALE
	flier.visible = false
	add_child(flier)
	last_picks = w.picks.size()
	shown_score = w.score


## Call once after each world.step(): notices a pick, counts the hint down, notices new things.
func after_step(w) -> void:
	if w.picks.size() < last_picks or w.score < shown_score: # a new run
		last_picks = w.picks.size()
		shown_score = w.score
		gain_age = -1.0
	if w.picks.size() > last_picks:
		var id: String = w.picks[-1]
		var slot := last_offer.find(id)
		if slot >= 0:
			taken = slot
			take_age = 0.0
			fly_id = id
			var icon: TextureRect = offers[slot].icon
			fly_from = icon.get_global_rect().get_center()
		last_picks = w.picks.size()
	if w.score > shown_score:
		gain = (gain if gain_age >= 0.0 and gain_age < GAIN_TIME * 0.6 else 0) + w.score - shown_score
		gain_age = 0.0
		pop = 1.0
		shown_score = w.score
	coach.step(w)
	_hints(w)


func set_paused(on: bool, w) -> void:
	paused = on
	if on:
		_fill_pause(w)


## Call every drawn frame.
func frame(w, delta: float) -> void:
	clock_time += delta
	press.text = PICK_TOUCH if touch else PICK_KEYS
	again.text = AGAIN_TOUCH if touch else AGAIN_KEYS
	pause_keys.text = PAUSE_TOUCH if touch else PAUSE_KEYS
	_top(w, delta)
	if intro or choosing: # the offer waits under the first screen and the choosing, and is dealt once they are gone
		box.visible = false
	else:
		_offer(w, delta)
	_guide_frame(delta)
	_choose_frame(delta)
	_coach_frame(w)
	_flight(w, delta)
	_told(w, delta)
	_hint_frame(w, delta)
	pause_box.visible = paused
	if paused:
		pause_box.reset_size()
		pause_box.position = ((Painter.VIEW - pause_box.size) / 2.0).round()
	var ended: bool = ENDINGS.has(w.phase)
	var target := INTRO_SCRIM if intro or choosing else 0.55 if paused else (0.5 if ended else (0.45 if w.phase == "pick" else 0.0))
	if taken >= 0:
		target = 0.45 * (1.0 - take_age / TAKE_TIME)
	painter.scrim = move_toward(painter.scrim, target, delta * 3.0)


## The night, the score (popping as it rises), the clock until dawn, how long the torch lasts, the boss's name.
func _top(w, delta: float) -> void:
	var night: bool = w.phase == "night"
	night_label.text = "%d번째 밤" % w.night
	score_label.text = str(w.score)
	pop = maxf(0.0, pop - delta / POP_TIME)
	var right := Painter.VIEW.x - 4.0
	var score_w := _width(score_label)
	score_label.size = Vector2(score_w + 2.0, 14.0)
	score_label.position = Vector2(right - score_label.size.x, 1.0)
	score_label.pivot_offset = Vector2(score_label.size.x, 8.0)
	score_label.scale = Vector2.ONE * (1.0 + POP_GROW * pop * pop)
	score_label.add_theme_color_override("font_color", GOLD.lerp(Color.WHITE, pop))
	var word_w := _width(score_word)
	score_word.size = Vector2(word_w + 2.0, 12.0)
	score_word.position = Vector2(right - score_w * score_label.scale.x - 4.0 - score_word.size.x, 2.0)
	var night_w := _width(night_label)
	night_label.size = Vector2(night_w + 2.0, 12.0)
	night_label.position = Vector2(right - night_label.size.x, 13.0)
	painter.score_panel = Vector2(maxf(score_w + 4.0 + word_w, night_w), 25.0)
	gain_label.visible = gain_age >= 0.0 and gain_age < GAIN_TIME
	if gain_label.visible:
		gain_age += delta
		var k := gain_age / GAIN_TIME
		gain_label.text = "+%d" % gain
		gain_label.size = Vector2(_width(gain_label) + 2.0, 12.0)
		gain_label.position = Vector2(right - gain_label.size.x, 25.0 - GAIN_RISE * k)
		gain_label.modulate.a = 1.0 - k * k
	elif gain_age >= GAIN_TIME:
		gain_age = -1.0

	var left := maxf(0.0, Config.NIGHT.length - w.time)
	clock.visible = night
	clock_word.visible = night
	clock.text = _clock(left)
	var soon := left < DAWN_SOON_SECONDS
	var second := int(ceilf(left))
	if soon and second != last_second:
		tick = 1.0
	last_second = second
	tick = maxf(0.0, tick - delta / POP_TIME)
	clock.add_theme_color_override("font_color", GOLD if soon else CREAM)
	var cw := _width(clock)
	var ww := _width(clock_word)
	var x := roundf((Painter.VIEW.x - (cw + 4.0 + ww)) / 2.0)
	clock_word.size = Vector2(ww + 2.0, 12.0)
	clock_word.position = Vector2(x, 2.0)
	clock.size = Vector2(cw + 2.0, 16.0)
	clock.position = Vector2(x + ww + 4.0, 0.0)
	clock.pivot_offset = clock.size / 2.0
	clock.scale = Vector2.ONE * (1.0 + 0.25 * tick * tick)

	fuel_time.visible = night
	var bar: Rect2 = Painter.fuel_bar(w)
	fuel_time.position = Vector2(bar.end.x + Painter.HUD_FUEL_TEXT, bar.position.y + bar.size.y / 2.0 - 7.0)
	var smothered: bool = Painter.smothered(w)
	fuel_time.text = ("꺼짐 " + _clock(Painter.fuel_left(w)) + (" 덮였다!" if smothered else "")) if w.fuel > 0.0 else "꺼졌다"
	fuel_time.size = Vector2(_width(fuel_time) + 2.0, 12.0)
	fuel_time.add_theme_color_override("font_color", RED if Painter.fuel_low(w) or smothered else CREAM)
	painter.fuel_text_width = _width(fuel_time) if night else 0.0

	var here: Array = Painter.bosses(w)
	for i in boss_names.size():
		boss_names[i].visible = night and i < here.size()
		if boss_names[i].visible:
			boss_names[i].text = here[i].T.name
	var coming: Array = w.bosses_coming()
	boss_name.visible = night and not coming.is_empty()
	if boss_name.visible: # the painter points at the edge it comes from
		var who: String = Config.ENEMY_TYPES[coming[0].kind].name
		boss_name.text = "%s%s 다가온다!" % [who, _subject(who)]
		boss_name.position = Vector2(Painter.BOSS_BAR.position.x, Painter.boss_bar(here.size()).position.y - 5.0)


## The box in the middle: the offer while you pick (and the taken card playing out just after), or how it ended.
func _offer(w, delta: float) -> void:
	var picking: bool = w.phase == "pick"
	var ended: bool = ENDINGS.has(w.phase)
	if picking:
		var key := ",".join(w.offer) + "/%d/%d/%s" % [w.picks.size(), w.night, w.character]
		if key != offer_key:
			offer_key = key
			deal = 0.0
			taken = -1
			_fill_cards(w)
		last_offer = w.offer.duplicate()
		deal += delta
	else:
		offer_key = ""
	if taken >= 0:
		take_age += delta
		if take_age >= TAKE_TIME:
			taken = -1
	var cards_on := picking or taken >= 0
	box.visible = cards_on or ended
	if not box.visible:
		return
	heading.visible = true
	row.visible = cards_on and not ended
	press.visible = row.visible
	for n in [foot, held_head, held_flow, board, again]:
		n.visible = ended
	if ended:
		_fill_end(w)
	elif picking:
		heading.add_theme_font_size_override("font_size", BIG)
		heading.add_theme_color_override("font_color", WARM)
		if w.time == 0.0: # the offer at dusk, between two nights
			heading.text = "%d번째 밤이 온다" % w.night
			subheading.text = ("새벽이 왔다! " if w.night > 1 else "") + "횃불이 힘을 하나 내어 준다"
		else:
			heading.text = "한밤중"
			subheading.text = "횃불이 힘을 하나 더 내어 준다"
	subheading.visible = not ended
	var fade := 1.0
	if taken >= 0:
		fade = 1.0 - smoothstep(0.3, 1.0, take_age / TAKE_TIME)
	elif not ended:
		fade = clampf(deal / FADE, 0.0, 1.0)
	box.self_modulate.a = fade
	for n in [heading, subheading, press]:
		n.modulate.a = fade
	if row.visible:
		_cards(w, delta)
	box.reset_size()
	var top := roundf((Painter.VIEW.y - box.size.y) / 2.0)
	if (Painter.VIEW.x - box.size.x) / 2.0 < painter.hud_right(w): # keep clear of the HUD's top-left panel
		top = maxf(top, Painter.hud_bottom(w) + 3.0)
	top = minf(top, Painter.VIEW.y - box.size.y - 2.0)
	box.position = Vector2(roundf((Painter.VIEW.x - box.size.x) / 2.0), top)


## Each card's place and look this frame: dealt in, bobbing, lifted when focused, or taken.
func _cards(w, delta: float) -> void:
	var shown := []
	for i in offers.size():
		if offers[i].card.visible:
			shown.append(i)
	var hover := _hovered(shown)
	var focus := hover
	if focus < 0 and bot_slot > 0 and bot_looked >= BOT_FOCUS_AT and taken < 0:
		focus = mini(bot_slot, shown.size()) - 1
	if taken >= 0:
		focus = taken
	for i in shown:
		var o: Dictionary = offers[i]
		var card: PanelContainer = o.card
		var base: Vector2 = o.base
		var k := clampf((deal - i * DEAL_APART) / DEAL_TIME, 0.0, 1.0)
		o.focus = move_toward(o.focus, 1.0 if focus == i else 0.0, delta * FOCUS_RATE)
		var f: float = o.focus
		var pos := base + Vector2(0.0, (1.0 - _back(k)) * DEAL_DROP)
		if k >= 1.0:
			pos.y += sin(clock_time * BOB_SPEED + i * 1.7) * BOB * (1.0 - f)
		pos.y -= f * FOCUS_LIFT
		var size := Vector2(smoothstep(0.0, 1.0, k), 1.0) * (1.0 + FOCUS_GROW * f)
		var tint := Color(1.0, 1.0, 1.0, clampf(k * 2.5, 0.0, 1.0))
		if focus >= 0 and focus != i:
			tint = Color(UNFOCUSED, UNFOCUSED, UNFOCUSED, tint.a)
		if taken >= 0:
			var t := take_age / TAKE_TIME
			if i == taken:
				size *= 1.0 + 0.12 * sin(minf(t * 2.0, 1.0) * PI)
				var glow := 0.7 * (1.0 - t)
				tint = Color(1.0 + glow, 1.0 + glow, 1.0 + glow, 1.0 - smoothstep(0.55, 1.0, t))
			else:
				pos.y += TAKE_FALL * t * t
				tint.a *= 1.0 - minf(1.0, t * 3.0)
		card.position = pos.round() if k >= 1.0 and f == 0.0 and taken < 0 else pos
		card.scale = size
		card.modulate = tint
		var style: StyleBoxFlat = o.style
		style.border_color = CARD_EDGE.lerp(GOLD, f)
		style.set_border_width_all(2 if f > 0.5 else 1)
		style.shadow_color = Color(GOLD, 0.45 * f)
		style.shadow_size = int(round(5.0 * f))
		o.key_style.bg_color = CARD_EDGE.lerp(GOLD, f)


## The card slot under the mouse (or under at, a point on the screen, such as where a click or a tap landed), or -1.
func _hovered(shown: Array, at = null) -> int:
	if bot_slot > 0 or taken >= 0 or not row.is_visible_in_tree():
		return -1
	var m := row.get_local_mouse_position() if at == null else row.get_global_transform_with_canvas().affine_inverse() * (at as Vector2)
	for i in shown:
		var r := Rect2(offers[i].base, offers[i].card.size)
		if r.has_point(m) and deal >= i * DEAL_APART + DEAL_TIME * 0.5:
			return i
	return -1


func _input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed or b.button_index != MOUSE_BUTTON_LEFT or paused or intro or choosing or offer_key == "":
		return
	var shown := []
	for i in offers.size():
		if offers[i].card.visible:
			shown.append(i)
	var i := _hovered(shown, b.position) # a tap moves no mouse, so where it landed is the event's own place
	if i >= 0:
		chosen.emit(i)


## Puts this offer's words on its cards, makes them all as tall as the tallest, and lays them out.
func _fill_cards(w) -> void:
	var shown := 0
	for i in offers.size():
		var o: Dictionary = offers[i]
		var on: bool = i < w.offer.size()
		o.card.visible = on
		o.focus = 0.0
		if not on:
			continue
		shown += 1
		var id: String = w.offer[i]
		var next: int = w.level(id) + 1
		var u: Dictionary = World.upgrade(id, next, w.character)
		var icon: Texture2D = painter.icon(id, true, w.character)
		o.icon.texture = icon
		o.icon.custom_minimum_size = icon.get_size() * CARD_ICON
		o.name.text = u.name + (LEVEL % next if next > 1 else "")
		var most := World.max_level(id)
		o.tag.text = "새 힘" if next == 1 else ("%d단계 · 마지막" % next if next >= most else "%d단계 · 최대 %d" % [next, most])
		o.tag.add_theme_color_override("font_color", FRESH if next == 1 else GOLD)
		o.side.text = Looks.side_name(Looks.side(id), w.character)
		o.side.add_theme_color_override("font_color", SIDE_COLOUR[Looks.side(id)])
		o.text.text = _wrap(o.text, u.text, CARD.x - 8.0)
		o.card.custom_minimum_size = CARD
		o.card.size = Vector2.ZERO
	var tall := 0.0
	for o in offers:
		if o.card.visible:
			tall = maxf(tall, o.card.get_combined_minimum_size().y)
	var width := shown * CARD.x + (shown - 1) * CARD_GAP
	var full := offers.size() * CARD.x + (offers.size() - 1) * CARD_GAP
	row.custom_minimum_size = Vector2(full, tall + FOCUS_LIFT + 2.0)
	for i in shown:
		var o: Dictionary = offers[i]
		o.card.custom_minimum_size = Vector2(CARD.x, tall)
		o.card.size = Vector2(CARD.x, tall)
		o.card.pivot_offset = o.card.size / 2.0
		o.base = Vector2((full - width) / 2.0 + i * (CARD.x + CARD_GAP), FOCUS_LIFT + 1.0)


## One offer card: the key in a badge, new or which level, the icon enlarged, the name, its side, what it does.
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
	row.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	card.add_child(stack)
	var badge_row := CenterContainer.new()
	stack.add_child(badge_row)
	var key := _label(badge_row, SMALL, INK, HORIZONTAL_ALIGNMENT_CENTER)
	key.remove_theme_constant_override("outline_size")
	key.text = str(i + 1)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = CARD_EDGE
	key_style.set_corner_radius_all(2)
	key_style.content_margin_left = 4.0
	key_style.content_margin_right = 4.0
	key.add_theme_stylebox_override("normal", key_style)
	var tag := _label(stack, SMALL, FRESH, HORIZONTAL_ALIGNMENT_CENTER)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(icon)
	var name := _label(stack, SMALL, WARM, HORIZONTAL_ALIGNMENT_CENTER)
	var side := _label(stack, SMALL, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var text := _label(stack, SMALL, CARD_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	text.remove_theme_constant_override("outline_size")
	return { "card": card, "style": style, "key": key, "key_style": key_style, "tag": tag, "icon": icon, "name": name,
		"side": side, "text": text, "focus": 0.0, "base": Vector2.ZERO }


## The end: how it ended, the night and score and where it landed, the upgrades held by name, the best runs.
func _fill_end(w) -> void:
	heading.text = ENDINGS[w.phase]
	heading.add_theme_font_size_override("font_size", HUGE)
	heading.add_theme_color_override("font_color", RED if w.phase == "dead" else Color("#ff9a3c"))
	foot.text = "%s · %d번째 밤 · 점수 %d" % [Config.CHARACTERS[w.character].name, w.night, w.score] + (" · 새 기록!" if records.place == 1 else (" · %d위" % records.place if records.place > 1 else ""))
	foot.add_theme_color_override("font_color", GOLD if records.place == 1 else CREAM)
	var ids := Painter.held(w)
	held_head.visible = not ids.is_empty()
	held_flow.visible = not ids.is_empty()
	var key := ",".join(ids) + str(w.picks.size())
	if held_flow.get_meta("key", "") != key:
		held_flow.set_meta("key", key)
		for c in held_flow.get_children():
			c.queue_free()
		for side in Looks.SIDES:
			for id in ids:
				if Looks.side(id) == side:
					held_flow.add_child(_held_item(w, id, false))
	board.text = _board()
	board.visible = board.text != ""
	again.modulate.a = 0.65 + 0.35 * cos(clock_time * 4.0)


## An upgrade held, as a small row: its icon, its name and level in its side's colour, and (wide) what it does.
func _held_item(w, id: String, words: bool) -> Control:
	var level: int = w.level(id)
	var u: Dictionary = World.upgrade(id, level, w.character)
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 3)
	var icon := _icon(item)
	icon.texture = painter.icon(id, true, w.character)
	icon.custom_minimum_size = icon.texture.get_size()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	item.add_child(lines)
	var name := _label(lines, SMALL, SIDE_COLOUR[Looks.side(id)])
	name.text = u.name + (LEVEL % level if level > 1 else "") + (" (최대)" if words and level >= World.max_level(id) and World.max_level(id) > 1 else "")
	if id == "vampire": # the kills it wants grow every night: say how far along tonight's count is
		name.text += "  %d/%d" % [w.blade_kills, w.vamp_need()]
	if words:
		var text := _label(lines, SMALL, MUTED)
		text.remove_theme_constant_override("outline_size")
		text.text = _wrap(text, u.text, PAUSE_COLUMN - 14.0)
	return item


## The pause screen: the upgrades held, one column per side, with what each does (just the names when there are many).
func _fill_pause(w) -> void:
	for c in pause_columns.get_children():
		pause_columns.remove_child(c)
		c.queue_free()
	var ids := Painter.held(w)
	var lines := 0
	for id in ids:
		lines += 1 + int(ceilf(_text_width(World.upgrade(id, w.level(id), w.character).text) / (PAUSE_COLUMN - 14.0)))
	var per_side := {}
	for side in Looks.SIDES:
		per_side[side] = ids.filter(func(id): return Looks.side(id) == side)
	var words := lines <= PAUSE_LINES * 2 and per_side.values().all(func(a): return a.size() <= 6)
	_pause_rows(w, per_side, words)
	if words and pause_box.get_combined_minimum_size().y > Painter.VIEW.y - 4.0: # too tall with the words: names only
		for c in pause_columns.get_children():
			pause_columns.remove_child(c)
			c.queue_free()
		_pause_rows(w, per_side, false)


func _pause_rows(w, per_side: Dictionary, words: bool) -> void:
	if per_side.values().all(func(a): return a.is_empty()):
		var none := _label(pause_columns, SMALL, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		none.text = "아직 고른 힘이 없다"
		return
	for side in Looks.SIDES:
		if per_side[side].is_empty():
			continue
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(PAUSE_COLUMN, 0.0)
		column.add_theme_constant_override("separation", 3)
		pause_columns.add_child(column)
		var head := _label(column, SMALL, SIDE_COLOUR[side])
		head.text = Looks.side_name(side, w.character)
		for id in per_side[side]:
			column.add_child(_held_item(w, id, words))


## The icon of what was just taken flies from its card to its HUD tile, which then flashes.
func _flight(w, delta: float) -> void:
	painter.hidden_pick = ""
	if fly_id != "" and taken < 0 and take_age < FLY_FROM:
		take_age = FLY_FROM # the card was gone before the flight began (the box closed early)
	var t := (take_age - FLY_FROM) / FLY_TIME if fly_id != "" else -1.0
	if fly_id != "" and taken < 0:
		take_age += delta # keeps the clock running after the card is done
	if fly_id != "" and t < 1.0:
		painter.hidden_pick = fly_id
		flier.visible = t >= 0.0
		if t >= 0.0:
			var to := Painter.icon_spot(w, fly_id)
			var e := t * t * (3.0 - 2.0 * t)
			var at := fly_from.lerp(to, e) + Vector2(0.0, -FLY_ARC * sin(e * PI))
			var size := Painter.ICON_SIZE * lerpf(CARD_ICON, 1.0, e)
			flier.texture = painter.icon(fly_id, true, w.character)
			flier.size = Vector2(size, size)
			flier.position = at - flier.size / 2.0
	elif fly_id != "":
		flier.visible = false
		painter.flash_pick = fly_id
		flash_age = 0.0
		told_age = 0.0
		_fill_told(w, fly_id)
		fly_id = ""
	if flash_age >= 0.0:
		flash_age += delta
		painter.flash = maxf(0.0, 1.0 - flash_age / FLASH_TIME)
		if flash_age >= FLASH_TIME:
			flash_age = -1.0
			painter.flash_pick = ""


func _fill_told(w, id: String) -> void:
	var level: int = w.level(id)
	var u: Dictionary = World.upgrade(id, level, w.character)
	told_icon.texture = painter.icon(id, true, w.character)
	told_icon.custom_minimum_size = told_icon.texture.get_size() * CARD_ICON
	told_name.text = u.name + (LEVEL % level if level > 1 else "") + ("  얻었다!" if level == 1 else "  강해졌다!")
	told_text.text = u.text


## The line naming what was just taken, under the clock, for a few seconds.
func _told(w, delta: float) -> void:
	told_box.visible = told_age >= 0.0 and told_age < TOLD_TIME and w.phase == "night" and not paused
	if told_age >= 0.0:
		told_age += delta
		if told_age >= TOLD_TIME:
			told_age = -1.0
	if not told_box.visible:
		return
	told_box.reset_size()
	var k := minf(told_age / FADE, 1.0) * minf((TOLD_TIME - told_age) / (FADE * 2.0), 1.0)
	told_box.position = Vector2(roundf((Painter.VIEW.x - told_box.size.x) / 2.0), TOLD_TOP - (1.0 - minf(told_age / FADE, 1.0)) * HINT_RISE)
	told_box.modulate.a = k * _behind(w, Rect2(told_box.position, told_box.size))


## Notices each kind of thing the first time it turns up and queues a line about it; counts the showing one down.
func _hints(w) -> void:
	var here: Array = w.enemies.map(func(e): return Looks.thing(e.kind, e.tier))
	if not w.berries.is_empty():
		here.append("berry")
	for thing in here:
		if Looks.hint(thing) != "" and not hints_told.has(thing):
			hints_told[thing] = true
			hints_waiting.append(thing)
	if w.phase == "night":
		hint_steps = maxi(0, hint_steps - 1)
		if hint_steps == 0 and not hints_waiting.is_empty():
			var thing: String = hints_waiting.pop_front()
			var line: String = Looks.hint(thing)
			var cut := line.find(": ")
			hint_name.text = line.substr(0, cut) if cut > 0 else ""
			hint_text.text = line.substr(cut + 2) if cut > 0 else line
			var tex := Sprites.alone("berry" if thing == "berry" else Sprites.tiered(Looks.FRAMES[0] % thing.get_slice("~", 0), int(thing.get_slice("~", 1)) if "~" in thing else 1))
			hint_icon.texture = tex
			hint_icon.custom_minimum_size = tex.get_size() / (2.0 if tex.get_height() > 24 else 1.0)
			hint_steps = HINT_STEPS
			hint_age = 0.0


## The hint along the bottom (over the boss's name when one is here), rising in, faded when something is behind it.
func _hint_frame(w, delta: float) -> void:
	hint_box.visible = hint_steps > 0 and w.phase == "night"
	if not hint_box.visible:
		return
	hint_age += delta
	hint_box.reset_size()
	var bottom := Painter.VIEW.y - HINT_BOTTOM
	if boss_name.visible:
		bottom = boss_name.position.y - 2.0
	elif boss_names[0].visible:
		bottom = minf(bottom, Painter.boss_bar(Painter.bosses(w).size() - 1).position.y - 4.0)
	var k := minf(hint_age / FADE, 1.0)
	hint_box.position = Vector2(roundf((Painter.VIEW.x - hint_box.size.x) / 2.0), roundf(bottom - hint_box.size.y + (1.0 - k) * HINT_RISE))
	var out := minf(1.0, hint_steps / (60.0 * FADE * 2.0))
	hint_box.modulate.a = k * out * _behind(w, Rect2(hint_box.position, hint_box.size))


## How solid a line over the field should be: faint while the keeper, or something about to strike, is under it,
## and see-through while an enemy is.
func _behind(w, r: Rect2) -> float:
	var near := r.grow(BEHIND_MARGIN)
	if near.has_point(w.player.pos):
		return BEHIND
	var solid := 1.0
	for e in w.enemies:
		if e.move == "warn" and (near.has_point(e.pos) or near.has_point(e.move_to)):
			return BEHIND
		if r.grow(4.0).has_point(e.pos):
			solid = BEHIND_ENEMY
	return solid


## The best runs, one per line, the one that just ended marked; empty when there are none yet.
func _board() -> String:
	var lines := []
	for i in mini(records.runs.size(), Records.SHOWN):
		var r: Dictionary = records.runs[i]
		var mark := "  ◀ 이번" if is_same(r, records.latest) else ""
		lines.append("%d위   %d점 · %s · %d번째 밤 · %s%s" % [i + 1, r.score, Config.CHARACTERS[r.char].name, r.night, _day(r.date), mark])
	return ("최고 기록\n" + "\n".join(lines)) if not lines.is_empty() else ""


## A record's date as month and day, from the "YYYY-MM-DD hh:mm:ss" the clock gave.
static func _day(date: String) -> String:
	var parts := date.split(" ")[0].split("-")
	return "%d월 %d일" % [int(parts[1]), int(parts[2])] if parts.size() == 3 else ""


## The subject particle that goes after a Korean word: 이 after a final consonant, 가 after a vowel.
static func _subject(word: String) -> String:
	var last := word.unicode_at(word.length() - 1)
	return "이" if last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 != 0 else "가"


## Seconds as m:ss, rounded up so the clock reads 0:00 only when the time is really out.
static func _clock(seconds: float) -> String:
	if is_inf(seconds):
		return "-:--"
	var s := int(ceilf(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## Ease out with a small overshoot, 0 to 1.
static func _back(k: float) -> float:
	var s := 1.6
	var t := k - 1.0
	return 1.0 + t * t * ((s + 1.0) * t + s)


## The words broken into lines at spaces only, each no wider than width in label's font. The label's own autowrap
## would also break inside a Korean word.
func _wrap(label: Label, words: String, width: float) -> String:
	var font := label.get_theme_font("font")
	var lines: Array = []
	for word in words.split(" "):
		var longer: String = word if lines.is_empty() else lines[-1] + " " + word
		if not lines.is_empty() and font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x <= width:
			lines[-1] = longer
		else:
			lines.append(word)
	return "\n".join(lines)


func _text_width(words: String) -> float:
	return clock_word.get_theme_font("font").get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x


## How wide a label's words are on screen.
static func _width(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


## A label in the palette, with the dark outline every word has.
## The guide: the page that is up, its dots, and its buttons (the right one breathing once it listens).
func _guide_frame(delta: float) -> void:
	guide.frame(delta)
	guide_box.visible = intro
	guide_right.visible = intro
	guide_left.visible = intro and guide.start_shown() and not guide.last()
	if not intro:
		return
	if guide_controls_touch != int(touch):
		guide_controls_touch = int(touch)
		for child in guide_controls.get_children():
			child.free()
		for line in GUIDE_TOUCH if touch else GUIDE_KEYS:
			_guide_row(guide_controls, line)
	for i in guide_pages.size():
		guide_pages[i].visible = i == guide.page
	var dots := []
	for i in Guide.PAGES:
		dots.append(GUIDE_DOT if i == guide.page else GUIDE_DOT_OFF)
	guide_dots.text = " ".join(dots)
	guide_turn.text = GUIDE_TURN_TOUCH if touch else GUIDE_TURN_KEYS
	var start := GUIDE_BACK if guide.returning else GUIDE_START
	guide_right_label.text = start if guide.last() else GUIDE_NEXT
	guide_left_label.text = start
	var ready: bool = guide.listening()
	guide_right.position = Guide.RIGHT.position
	guide_right.size = Guide.RIGHT.size
	guide_left.position = Guide.LEFT.position
	guide_left.size = Guide.LEFT.size
	guide_right.modulate.a = (0.75 + 0.25 * sin(clock_time * INTRO_BLINK)) if ready else GUIDE_WAITING
	guide_left.modulate.a = 1.0 if ready else GUIDE_WAITING


## The choosing screen: the cards dealt in one after another, bobbing, the one in focus lifted and gold-edged, the
## heading over them and what to press under them; the cards are drawn at Chooser.rect(), where they answer.
func _choose_frame(delta: float) -> void:
	chooser.frame(delta)
	choose_age = choose_age + delta if choosing else 0.0
	choose_title.visible = choosing
	choose_hint.visible = choosing
	for i in choose_cards.size():
		choose_cards[i].card.visible = choosing
	if not choosing:
		return
	choose_hint.text = CHOOSE_TOUCH if touch else CHOOSE_KEYS
	var ready: bool = chooser.listening()
	choose_hint.modulate.a = (0.75 + 0.25 * sin(clock_time * INTRO_BLINK)) if ready else GUIDE_WAITING
	choose_title.modulate.a = clampf(choose_age / FADE, 0.0, 1.0)
	for i in choose_cards.size():
		var c: Dictionary = choose_cards[i]
		var card: PanelContainer = c.card
		var k := clampf((choose_age - i * DEAL_APART) / DEAL_TIME, 0.0, 1.0)
		c.focus = move_toward(c.focus, 1.0 if chooser.focus == i else 0.0, delta * FOCUS_RATE)
		var f: float = c.focus
		var pos: Vector2 = Chooser.rect(i).position + Vector2(0.0, (1.0 - _back(k)) * DEAL_DROP)
		if k >= 1.0:
			pos.y += sin(clock_time * BOB_SPEED + i * 1.7) * BOB * (1.0 - f)
		pos.y -= f * FOCUS_LIFT
		card.size = Chooser.CARD
		card.pivot_offset = Chooser.CARD / 2.0
		card.position = pos.round() if k >= 1.0 and f == 0.0 else pos
		card.scale = Vector2(smoothstep(0.0, 1.0, k), 1.0) * (1.0 + FOCUS_GROW * f)
		var shade := 1.0 if f > 0.5 else UNFOCUSED
		card.modulate = Color(shade, shade, shade, clampf(k * 2.5, 0.0, 1.0))
		var style: StyleBoxFlat = c.style
		style.border_color = CARD_EDGE.lerp(GOLD, f)
		style.set_border_width_all(2 if f > 0.5 else 1)
		style.shadow_color = Color(GOLD, 0.45 * f)
		style.shadow_size = int(round(5.0 * f))
		c.key_style.bg_color = CARD_EDGE.lerp(GOLD, f)


## One character's card: its key, its picture enlarged, its name, what it does, a bar for its hearts and its other
## bars (Config.CHARACTERS), and its weakness.
func _char_card(i: int, id: String) -> Dictionary:
	var row_: Dictionary = Config.CHARACTERS[id]
	var card := PanelContainer.new()
	card.custom_minimum_size = Chooser.CARD
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACK
	style.border_color = CARD_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4.0)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	var badge_row := CenterContainer.new()
	stack.add_child(badge_row)
	var key := _label(badge_row, SMALL, INK, HORIZONTAL_ALIGNMENT_CENTER)
	key.remove_theme_constant_override("outline_size")
	key.text = str(i + 1)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = CARD_EDGE
	key_style.set_corner_radius_all(2)
	key_style.content_margin_left = 4.0
	key_style.content_margin_right = 4.0
	key.add_theme_stylebox_override("normal", key_style)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = Sprites.alone(Looks.character(id).sprite + "_down_a")
	portrait.custom_minimum_size = portrait.texture.get_size() * CHOOSE_PORTRAIT
	stack.add_child(portrait)
	_label(stack, BIG, WARM, HORIZONTAL_ALIGNMENT_CENTER).text = row_.name
	var text := _label(stack, SMALL, CARD_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	text.remove_theme_constant_override("outline_size")
	text.text = _wrap(text, row_.text, Chooser.CARD.x - 10.0)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bars: Array = [[CHOOSE_HP, World.character_stats(id).hp]] + row_.bars
	for bar in bars:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 2)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_child(line)
		var bar_name := _label(line, SMALL, MUTED)
		bar_name.text = bar[0]
		bar_name.custom_minimum_size = Vector2(CHOOSE_BAR_NAME, 0.0)
		for n in CHOOSE_PIPS:
			var pip := ColorRect.new()
			pip.custom_minimum_size = CHOOSE_PIP
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = GOLD if n < bar[1] else CHOOSE_PIP_OFF
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(pip)
	_label(stack, SMALL, RED if row_.trait.begins_with("약점") else FRESH, HORIZONTAL_ALIGNMENT_CENTER).text = row_.trait
	return { "card": card, "style": style, "key_style": key_style, "focus": 0.0 }


## A row of a guide page: its pictures (a "→" among them is an arrow), a name, and what to know.
func _guide_row(parent: Node, line: Array) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 5)
	r.alignment = BoxContainer.ALIGNMENT_CENTER if line[1] == "" else BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(r)
	for sprite in line[0]:
		if sprite == "→":
			_label(r, BIG, MUTED).text = sprite
			continue
		var picture := _icon(r)
		var tex := Sprites.alone(sprite)
		picture.texture = tex
		# a row of pictures only shows them at twice their size; beside words, in a 16-pixel square
		picture.custom_minimum_size = tex.get_size() * 2.0 if line[1] == "" else Vector2(16.0, 16.0)
	if line[1] == "":
		return
	var line_name := _label(r, SMALL, GOLD)
	line_name.text = line[1]
	line_name.custom_minimum_size = Vector2(INTRO_NAME, 0.0)
	_label(r, SMALL, CREAM).text = line[2]


func _guide_button() -> PanelContainer:
	var b := _panel(self, CARD_BACK, 2.0)
	var back: StyleBoxFlat = b.get_theme_stylebox("panel")
	back.border_color = CARD_EDGE
	var l := _label(b, BIG, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.visible = false
	return b


## The first night's coaching (src/coach.gd): words over a bobbing arrow above what to go to, on the HUD's layer.
func _coach_frame(w) -> void:
	var show: Array = [] if intro or choosing or paused or taken >= 0 else coach.now(w)
	coach_arrow.visible = not show.is_empty()
	coach_label.visible = not show.is_empty()
	if show.is_empty():
		return
	var bob := roundf(COACH_BOB * sin(clock_time * BOB_SPEED * 2.0))
	var tip: Vector2 = show[1] - Vector2(0.0, COACH_ABOVE + bob)
	var tex: Texture2D = coach_arrow.texture
	coach_arrow.position = (tip - Vector2(tex.get_width() / 2.0, tex.get_height())).round()
	coach_label.text = show[0]
	coach_label.size = Vector2(_width(coach_label) + 4.0, 12.0)
	var at := Vector2(tip.x - coach_label.size.x / 2.0, tip.y - tex.get_height() - 13.0)
	coach_label.position = at.clamp(Vector2(2.0, 2.0), Painter.VIEW - coach_label.size - Vector2(2.0, 2.0)).round()


func _label(parent: Node, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	var f := font(size)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	l.add_theme_constant_override("line_spacing", LINE_SPACING)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## The pixel font drawn for this size (SMALL, BIG or HUGE), unsmoothed. It is read straight from its file, so the
## game runs without the editor having imported it. Each font's .import says "keep", so an export (the web build) holds
## the file itself, unimported (export_presets.cfg also lists them). Null if it is not there: Godot's own font.
static func font(size: int) -> Font:
	if not _fonts.has(size):
		var path: String = FONT_FILES[size]
		var f := FontFile.new()
		if f.load_dynamic_font(path) != OK:
			f = null
		if f != null:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			f.generate_mipmaps = false
			f.allow_system_fallback = true # a sign the font lacks, such as ◀, still shows
		_fonts[size] = f
	return _fonts[size]


## Rule A3: every character in a string in src/ that is not plain ASCII is in each pixel font (the fonts are cut down
## to what Korean text needs, docs/DECISIONS.md), so no word falls back to another font. Plus its own bad/good pair.
static func font_problems() -> Array:
	var out := []
	if not missing("가◀·").is_empty() or missing("\u0e01").is_empty():
		out.append("A3 selftest: the font check does not tell a covered character from a missing one.")
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	for path in _scripts("res://src"):
		for m in strings.search_all(FileAccess.get_file_as_string(path)):
			for c in missing(m.get_string()):
				out.append("%s: '%s' (U+%04X) is not in the pixel font. Fix: use another character, or add it to the font subset (docs/DECISIONS.md, Galmuri)." % [path, c, c.unicode_at(0)])
	return out


## The characters of text that some pixel font lacks, each once. ASCII control characters and spaces are skipped.
static func missing(text: String) -> Array:
	var out := []
	for i in text.length():
		var c := text.unicode_at(i)
		if c <= 0x20 or out.has(char(c)):
			continue
		for size in FONT_FILES:
			var f := font(size)
			if f == null or not f.has_char(c):
				out.append(char(c))
				break
	return out


static func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


func _icon(parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)
	return icon


func _panel(parent: Node, colour := Color(0.1, 0.08, 0.14, 0.82), margin := 4.0) -> PanelContainer:
	var p := PanelContainer.new()
	var back := StyleBoxFlat.new()
	back.bg_color = colour
	back.border_color = PANEL_EDGE
	back.set_border_width_all(1)
	back.set_corner_radius_all(3)
	back.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", back)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p
