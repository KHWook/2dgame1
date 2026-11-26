## Touch controls for playing on a phone: a stick that appears where the left thumb lands and steers in any of
## Config.STICK_DIRECTIONS directions, a sword button and (once the dash upgrade is held) a dash button on the right,
## a pause button, a "?" button beside it that brings the start
## screen back (the H key), and a tap that restarts after the end. Part of
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

const VIEW: Vector2 = Config.VIEW
const DEAD := 4.0 # pixels the thumb moves from where it landed before the keeper walks
const DEAD_STOP := 2.5 # once walking, it stops only when the thumb comes back this close, so a still thumb does not stutter
const REACH := 16.0 # how far the knob goes from the ring's middle; past it the ring follows the thumb
const TURN_HOLD := 0.7 # a thumb must turn this many direction steps away before the direction changes
const STICK_TOP := 60.0 # the stick starts only below the HUD's top-left panel, so it never covers it
const ATTACK := Vector2(VIEW.x - 34.0, VIEW.y - 36.0) # the sword button's middle
const DASH := Vector2(VIEW.x - 76.0, VIEW.y - 22.0)
const PAUSE := Vector2(VIEW.x - 14.0, 44.0) # under the score and the night, clear of the "+10" that rises there
const HELP := PAUSE - Vector2(26.0, 0.0) # left of the pause button
const ATTACK_REACH := 22.0 # touch radius: a little bigger than the drawn button, so a thumb that is close counts
const DASH_REACH := 17.0
const PAUSE_REACH := 13.0
const HELP_REACH := 12.0 # a little smaller than the pause button's, so the two never both answer one tap
const LOOK := 0.45 # how solid the controls are while untouched
const LOOK_DOWN := 0.85 # and while pressed
const REST := 0.8 # seconds after the end before a tap restarts, so a thumb still swinging does not skip the end screen
## Integer scaling keeps every pixel the same size, but on some phones it leaves the field small inside wide borders
## (1280x720: 2x of 2.67x fits). Below this share of the size that would fit, scale by a fraction instead.
const WHOLE_ENOUGH := 0.85
const ROTATE := "가로로 돌려 주세요"

var on := false # the controls are shown and listen
var mode := "off" # set by main.gd every frame: "play", "pick", "ended", "paused", or "off" (the start screen)
var dash_shown := false # set by main.gd: the dash upgrade is held
var stick := -1 # the touch index steering, -1 when none
var stick_from := Vector2.ZERO # the ring's middle
var stick_at := Vector2.ZERO # the thumb
var heading := -1 # the direction the stick gives now, one of Config.STICK_DIRECTIONS, -1 while it is not pushed
var buttons := {} # touch index -> the action it holds down: "attack" or "dash"
var help_touch := -1 # the touch index on the "?" button, -1 when none. It answers when lifted, so the tap that
# opens the start screen is not also the click that closes it (Godot turns a touch into a mouse click as it lands)
var presses := {} # actions pressed since main.gd last took them
var ended_for := 0.0 # real seconds in "ended"
var rotate_label: Label


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
	match mode:
		"paused":
			pause_pressed.emit()
		"ended":
			if ended_for >= REST:
				presses["restart"] = true
		"play":
			if t.position.distance_to(PAUSE) <= PAUSE_REACH:
				pause_pressed.emit()
			elif t.position.distance_to(ATTACK) <= ATTACK_REACH:
				_press(t.index, "attack")
			elif dash_shown and t.position.distance_to(DASH) <= DASH_REACH:
				_press(t.index, "dash")
			elif t.position.x < VIEW.x / 2.0 and t.position.y >= STICK_TOP and stick < 0:
				stick = t.index
				stick_from = t.position
				stick_at = t.position
				heading = -1
		_:
			return false # the start screen and the cards are tapped as mouse clicks
	return true


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
	ended_for = ended_for + delta if mode == "ended" else 0.0
	if mode != "play":
		var help := help_touch if mode == "paused" else -1 # the "?" button also answers on the pause screen
		release()
		help_touch = help
	if rotate_label != null: # made in _ready, so not there for a test that never adds this to a tree
		rotate_label.visible = upright()
	queue_redraw()


func _draw() -> void:
	if upright():
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.05, 0.04, 0.09, 0.92))
		return
	if not on or not (mode == "play" or mode == "paused"):
		return
	_sprite("button_small", PAUSE, mode == "paused")
	_sprite("pause_bars", PAUSE, mode == "paused")
	_sprite("button_small", HELP, help_touch >= 0)
	_sprite("help_mark", HELP, help_touch >= 0)
	if mode != "play":
		return
	var attacking := buttons.values().has("attack")
	_sprite("button", ATTACK, attacking)
	_sprite("sword", ATTACK + Vector2(1.0, 0.0), attacking)
	if dash_shown:
		var dashing := buttons.values().has("dash")
		_sprite("button_small", DASH, dashing)
		_sprite("icon_dash", DASH, dashing)
	if stick >= 0:
		_sprite("pad_ring", stick_from, true)
		var knob := stick_from + (stick_at - stick_from).limit_length(REACH)
		_sprite("pad_knob", knob, true)


## A sprite centred on a point, on whole pixels, see-through unless pressed (a pressed one also sits a pixel lower),
## drawn scale times its size (a whole number, so its pixels stay square).
func _sprite(name: String, at: Vector2, down: bool, scale := 1) -> void:
	var tex := Sprites.texture(name)
	var top := (at - tex.get_size() * scale / 2.0).round() + (Vector2(0.0, 1.0) if down and name != "pad_ring" and name != "pad_knob" else Vector2.ZERO)
	draw_texture_rect(tex, Rect2(top, tex.get_size() * scale), false, Color(1.0, 1.0, 1.0, LOOK_DOWN if down else LOOK))
