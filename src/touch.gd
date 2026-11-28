## Touch controls for playing on a phone: a stick that appears where the left thumb lands and steers in any of
## Config.STICK_DIRECTIONS directions, a sword button on the right (a tap anywhere on the right half swings too) and
## (once the dash upgrade is held) a dash button beside it, a pause button, a "?" button beside it that brings the start
## screen back (the H key), a note button beside that for the music (the M key), a tap that restarts after the end
## (or, on its same-seed button, plays that run again), and the win box's two buttons (targets). Part of
## the bridge with src/main.gd: it turns screen touches into the same action names the keys give ("attack", "dash")
## and the stick into a direction number (InputFrame.stick), so the simulation reads no screen (S1), and each tap
## counts for exactly one step (D6: take()).
## The start screen and the cards are tapped through Godot's mouse emulation (src/main.gd, src/ui.gd).
## Shown once the screen is touched (or the device says it has a touch screen) and hidden again by a key press.
## Also decides how the 480x270 field is scaled to the window on web and mobile (stretch_for), and asks a phone held
## upright to be turned.
extends Node2D

const Sprites := preload("res://src/art/sprites.gd")
const Config := preload("res://src/sim/config.gd")
const Ui := preload("res://src/ui.gd")

signal pause_pressed # the pause button, or a tap anywhere while paused
signal help_pressed # the "?" button, while playing or paused: the start screen again
signal music_pressed # the note button, while playing or paused: the music on or off (the M key)

const VIEW: Vector2 = Config.VIEW
const DEAD := 4.0 # pixels the thumb moves from where it landed before the keeper walks
const DEAD_STOP := 2.5 # once walking, it stops only when the thumb comes back this close, so a still thumb does not stutter
const REACH := 16.0 # how far the knob goes from the ring's middle; past it the ring follows the thumb
const TURN_HOLD := 0.7 # a thumb must turn this many direction steps away before the direction changes
const EDGE := 8.0 # the buttons keep this far from the screen's edges, clear of rounded corners and the notch
const STICK_TOP := 60.0 # the stick starts only below the HUD's top-left panel, so it never covers it
const ATTACK := Vector2(VIEW.x - 40.0, VIEW.y - 40.0) # the sword button's middle: 45 pixels across, clear of the edges
const DASH := Vector2(VIEW.x - 100.0, VIEW.y - 26.0) # 33 across, left of the sword, low where the thumb rests
const PAUSE := Vector2(VIEW.x - 14.0, 44.0) # under the score and the night, clear of the "+10" that rises there
const HELP := PAUSE - Vector2(26.0, 0.0) # left of the pause button
const ATTACK_REACH := 34.0 # touch radius: well past the drawn button (and any tap on the right half swings anyway)
const DASH_REACH := 24.0 # past its drawn 16, short of the sword's: the two never both answer one tap
const PAUSE_REACH := 13.0
const HELP_REACH := 12.0 # a little smaller than the pause button's, so the two never both answer one tap
const MUSIC := HELP - Vector2(26.0, 0.0) # left of the "?" button
const MUSIC_REACH := 12.0
const TARGET_PAD := 4.0 # a button of a box in the middle (targets) answers this far past its drawn edge
const ICON_SCALE := 2 # the sword and dash pictures on their buttons are drawn twice their size
const LOOK := 0.45 # how solid the controls are while untouched
const LOOK_DOWN := 0.85 # and while pressed
const REST := 0.8 # seconds after the end before a tap restarts, so a thumb still swinging does not skip the end screen
## Integer scaling keeps every pixel the same size, but on some phones it leaves the field small inside wide borders
## (1280x720: 2x of 2.67x fits). Below this share of the size that would fit, scale by a fraction instead.
const WHOLE_ENOUGH := 0.85
const ROTATE := "가로로 돌려 주세요"
## The start screen's controls page (src/guide.gd) shows the stick and the buttons where they really are, named.
const DEMO_STICK := Vector2(46.0, 230.0) # the stick appears wherever the thumb lands; the page draws it here
const DEMO_PUSH := Vector2(9.0, -5.0) # its knob, pushed a little
const DEMO_WORDS := [["끌어서 이동", Vector2(74.0, 224.0)], ["누르면 베기", Vector2(412.0, 194.0)], ["돌진", Vector2(369.0, 213.0)]]

var on := false # the controls are shown and listen
var mode := "off" # set by main.gd every frame: "play", "pick", "ended", "won" (the win box), "paused", or "off" (the start screen)
var targets := {} # set by main.gd every frame: the buttons of the box in the middle, action -> where it is drawn (Ui.targets)
var music_on := true # set by main.gd: how the note button is drawn
var dash_shown := false # set by main.gd: the dash upgrade is held
var attack_icon := "sword" # set by main.gd: the picture on the attack button, the keeper's own (Looks.CHARACTERS button)
var stick := -1 # the touch index steering, -1 when none
var stick_from := Vector2.ZERO # the ring's middle
var stick_at := Vector2.ZERO # the thumb
var heading := -1 # the direction the stick gives now, one of Config.STICK_DIRECTIONS, -1 while it is not pushed
var buttons := {} # touch index -> the action it holds down: "attack" or "dash"
var help_touch := -1 # the touch index on the "?" button, -1 when none. It answers when lifted, so the tap that
# opens the start screen is not also the click that closes it (Godot turns a touch into a mouse click as it lands)
var presses := {} # actions pressed since main.gd last took them
var ended_for := 0.0 # real seconds in "ended" or "won"
var rotate_label: Label
var guide_controls := false # set by main.gd: the start screen's guide is on its controls page
var demo_labels: Array = []


func _ready() -> void:
	on = DisplayServer.is_touchscreen_available()
	rotate_label = Label.new()
	var f: Font = Ui.font(Ui.BIG)
	if f != null:
		rotate_label.add_theme_font_override("font", f)
	rotate_label.add_theme_font_size_override("font_size", Ui.BIG)
	rotate_label.add_theme_color_override("font_color", Ui.WARM)
	rotate_label.add_theme_color_override("font_outline_color", Ui.INK)
	rotate_label.add_theme_constant_override("outline_size", Ui.OUTLINE_SIZE)
	rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_label.size = VIEW
	rotate_label.text = ROTATE
	rotate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotate_label.visible = false
	add_child(rotate_label)
	for words in DEMO_WORDS:
		var l := Label.new()
		if Ui.font(Ui.SMALL) != null:
			l.add_theme_font_override("font", Ui.font(Ui.SMALL))
		l.add_theme_font_size_override("font_size", Ui.SMALL)
		l.add_theme_color_override("font_color", Ui.GOLD)
		l.add_theme_color_override("font_outline_color", Ui.INK)
		l.add_theme_constant_override("outline_size", Ui.OUTLINE_SIZE)
		l.text = words[0]
		l.position = words[1]
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		add_child(l)
		demo_labels.append(l)


func _input(event: InputEvent) -> void:
	if handle(event):
		get_viewport().set_input_as_handled()


## Takes one input event; true when it was a touch this used. A key press hides the controls, a touch shows them.
func handle(event: InputEvent) -> bool:
	var k := event as InputEventKey
	if k != null and k.pressed:
		on = false
		release()
		return false
	var t := event as InputEventScreenTouch
	var d := event as InputEventScreenDrag
	if t == null and d == null:
		return false
	if t != null and t.pressed:
		on = true
	if d != null:
		if d.index != stick:
			return false
		stick_at = d.position
		var off := stick_at - stick_from
		if off.length() > REACH: # the ring follows the thumb, so turning back answers at once
			stick_from = stick_at - off.normalized() * REACH
		heading = direction(stick_at - stick_from, heading)
		return true
	if not t.pressed:
		if t.index == stick:
			stick = -1
			heading = -1
		buttons.erase(t.index)
		if t.index == help_touch:
			help_touch = -1
			if t.position.distance_to(HELP) <= HELP_REACH: # slid off the button first: nothing
				help_pressed.emit()
		return true
	if (mode == "play" or mode == "paused") and t.position.distance_to(HELP) <= HELP_REACH:
		help_touch = t.index
		return true
	if (mode == "play" or mode == "paused") and t.position.distance_to(MUSIC) <= MUSIC_REACH:
		music_pressed.emit()
		return true
	match mode:
		"paused":
			pause_pressed.emit()
		"ended": # a tap on a button does what it says; one anywhere else starts again, as it always has
			if ended_for >= REST:
				var on_button := target_at(t.position)
				presses[on_button if on_button != "" else "restart"] = true
		"won": # only its two buttons answer: a stray tap must not close the win
			if ended_for >= REST and target_at(t.position) != "":
				presses[target_at(t.position)] = true
		"play":
			if t.position.distance_to(PAUSE) <= PAUSE_REACH:
				pause_pressed.emit()
			elif dash_shown and t.position.distance_to(DASH) <= DASH_REACH:
				_press(t.index, "dash")
			elif t.position.distance_to(ATTACK) <= ATTACK_REACH or (t.position.x >= VIEW.x / 2.0 and t.position.y >= STICK_TOP):
				_press(t.index, "attack")
			elif t.position.x < VIEW.x / 2.0 and t.position.y >= STICK_TOP and stick < 0:
				stick = t.index
				stick_from = t.position
				stick_at = t.position
				heading = -1
		_:
			return false # the start screen and the cards are tapped as mouse clicks
	return true


## The action of the button (targets) at pos, a little past its edges counting, or "".
func target_at(pos: Vector2) -> String:
	for action in targets:
		if targets[action].grow(TARGET_PAD).has_point(pos):
			return action
	return ""


func _press(index: int, action: String) -> void:
	buttons[index] = action
	presses[action] = true


## Lets go of everything, as when the window loses focus.
func release() -> void:
	stick = -1
	heading = -1
	buttons.clear()
	help_touch = -1


## The actions held right now: the buttons down.
func held() -> Dictionary:
	var out := {}
	if not on or mode != "play":
		return out
	for action in buttons.values():
		out[action] = true
	return out


## The way the stick steers right now, for InputFrame.stick: one of Config.STICK_DIRECTIONS, -1 when it is not pushed.
func steer() -> int:
	return heading if on and mode == "play" and stick >= 0 else -1


## The actions pressed since the last call, each once (D6).
func take() -> Dictionary:
	var out := presses
	presses = {}
	return out if on else {}


## The direction a stick pushed this far gives, counted clockwise on the screen from right, or -1 inside the dead
## zone. was is the direction it gave last: it keeps walking down to DEAD_STOP, and keeps its direction until the
## thumb has turned TURN_HOLD steps from it, so a thumb resting on a boundary does not flicker between two.
static func direction(off: Vector2, was := -1) -> int:
	if off.length() < (DEAD_STOP if was >= 0 else DEAD):
		return -1
	var n: int = Config.STICK_DIRECTIONS
	var step := TAU / n
	if was >= 0 and absf(angle_difference(was * step, off.angle())) < TURN_HOLD * step:
		return was
	return posmod(roundi(off.angle() / step), n)


## How to scale the field to a window this size: integer while that fills enough of it, else fractional.
static func stretch_for(window: Vector2) -> int:
	var fits := minf(window.x / VIEW.x, window.y / VIEW.y)
	var whole := floorf(fits)
	return Window.CONTENT_SCALE_STRETCH_INTEGER if whole >= 1.0 and whole / fits >= WHOLE_ENOUGH else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## A touch device held upright: the field would be a thin strip, so the game waits and asks to be turned.
func upright() -> bool:
	if not on or not is_inside_tree():
		return false
	var s := get_tree().root.size
	return s.y > s.x


## Call every drawn frame, after main.gd has set mode.
func frame(delta: float) -> void:
	ended_for = ended_for + delta if mode == "ended" or mode == "won" else 0.0
	if mode != "play":
		var help := help_touch if mode == "paused" else -1 # the "?" button also answers on the pause screen
		release()
		help_touch = help
	if rotate_label != null: # made in _ready, so not there for a test that never adds this to a tree
		rotate_label.visible = upright()
	for l in demo_labels:
		l.visible = _demo()
	queue_redraw()


func _draw() -> void:
	if upright():
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.05, 0.04, 0.09, 0.92))
		return
	if _demo():
		_sprite("pad_ring", DEMO_STICK, true)
		_sprite("pad_knob", DEMO_STICK + DEMO_PUSH, true)
		_sprite("button", ATTACK, true)
		_sprite(attack_icon, ATTACK + Vector2(1.0, 0.0), true, ICON_SCALE)
		_sprite("button_mid", DASH, false)
		_sprite("icon_dash", DASH, false, ICON_SCALE)
		return
	if not on or not (mode == "play" or mode == "paused"):
		return
	_sprite("button_small", PAUSE, mode == "paused")
	_sprite("pause_bars", PAUSE, mode == "paused")
	_sprite("button_small", HELP, help_touch >= 0)
	_sprite("help_mark", HELP, help_touch >= 0)
	_sprite("button_small", MUSIC, false)
	_sprite("note_mark", MUSIC, false)
	if not music_on:
		_sprite("note_off", MUSIC, false)
	if mode != "play":
		return
	var attacking := buttons.values().has("attack")
	_sprite("button", ATTACK, attacking)
	_sprite(attack_icon, ATTACK + Vector2(1.0, 0.0), attacking, ICON_SCALE)
	if dash_shown:
		var dashing := buttons.values().has("dash")
		_sprite("button_mid", DASH, dashing)
		_sprite("icon_dash", DASH, dashing, ICON_SCALE)
	if stick >= 0:
		_sprite("pad_ring", stick_from, true)
		var knob := stick_from + (stick_at - stick_from).limit_length(REACH)
		_sprite("pad_knob", knob, true)


## Whether the guide's controls page is up on a touch screen, so the controls are drawn there to be seen.
func _demo() -> bool:
	return on and guide_controls and mode == "off" and not upright()


## A sprite centred on a point, on whole pixels, see-through unless pressed (a pressed one also sits a pixel lower),
## drawn scale times its size (a whole number, so its pixels stay square).
func _sprite(name: String, at: Vector2, down: bool, scale := 1) -> void:
	var tex := Sprites.texture(name)
	var top := (at - tex.get_size() * scale / 2.0).round() + (Vector2(0.0, 1.0) if down and name != "pad_ring" and name != "pad_knob" else Vector2.ZERO)
	draw_texture_rect(tex, Rect2(top, tex.get_size() * scale), false, Color(1.0, 1.0, 1.0, LOOK_DOWN if down else LOOK))
