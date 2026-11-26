## The touch controls (src/touch.gd) give the actions they claim: the stick's eight directions and dead zone, the ring
## following the thumb, the sword held while a second thumb steers, each tap pressed once (D6), dash only with the
## upgrade, nothing steered while the cards are up, the tap that restarts only after the end has shown a moment, the
## "?" button bringing the start screen back (as H does) while playing or paused, a key press hiding it all, and the
## scaling chosen for common phone screens.
extends RefCounted

const Touch := preload("res://src/touch.gd")

const AT := Vector2(100.0, 180.0) # where the left thumb lands


## Every failure as a message; empty when all hold.
static func run() -> Array:
	var out := []
	out.append_array(_stick())
	out.append_array(_buttons())
	out.append_array(_modes())
	out.append_array(_help())
	out.append_array(_scaling())
	return out


static func _touch(t, index: int, at: Vector2, down := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = down
	t.handle(e)


static func _drag(t, index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	t.handle(e)


static func _fresh():
	var t = Touch.new()
	t.mode = "play"
	return t


static func _held(t) -> Array:
	var keys: Array = t.held().keys()
	keys.sort()
	return keys


static func _stick() -> Array:
	var out := []
	var t = _fresh()
	if t.on:
		out.append("the controls show before any touch on a device without a touch screen")
	var want := { Vector2(1, 0): ["right"], Vector2(1, 1): ["down", "right"], Vector2(0, 1): ["down"],
		Vector2(-1, 1): ["down", "left"], Vector2(-1, 0): ["left"], Vector2(-1, -1): ["left", "up"],
		Vector2(0, -1): ["up"], Vector2(1, -1): ["right", "up"] }
	for dir in want:
		_touch(t, 0, AT)
		_drag(t, 0, AT + dir.normalized() * 10.0)
		if _held(t) != want[dir]:
			out.append("the stick pushed %s holds %s, not %s" % [dir, _held(t), want[dir]])
		_touch(t, 0, AT, false)
	if not t.on:
		out.append("a touch does not show the controls")
	_touch(t, 0, AT)
	_drag(t, 0, AT + Vector2(Touch.DEAD - 1.0, 0.0))
	if not _held(t).is_empty():
		out.append("a thumb inside the dead zone walks: %s" % [_held(t)])
	_drag(t, 0, AT + Vector2(0.0, -10.0).rotated(0.3)) # a little right of straight up still reads as up
	if _held(t) != ["up"]:
		out.append("a thumb pushed nearly straight up holds %s" % [_held(t)])
	_drag(t, 0, AT + Vector2(60.0, 0.0)) # far right: the ring follows, so turning back answers at once
	_drag(t, 0, AT + Vector2(60.0 - Touch.REACH - Touch.DEAD - 1.0, 0.0))
	if _held(t) != ["left"]:
		out.append("after a long push right, turning back does not walk left at once: %s" % [_held(t)])
	_touch(t, 0, AT, false)
	if not _held(t).is_empty():
		out.append("letting go of the stick still walks: %s" % [_held(t)])
	_touch(t, 0, Vector2(100.0, Touch.STICK_TOP - 10.0)) # on the HUD's top-left panel
	_drag(t, 0, Vector2(130.0, Touch.STICK_TOP - 10.0))
	if not _held(t).is_empty():
		out.append("a thumb on the HUD panel starts the stick")
	_touch(t, 0, Vector2.ZERO, false)
	_touch(t, 0, Vector2(Touch.VIEW.x - 120.0, 150.0)) # the right half, away from the buttons
	_drag(t, 0, Vector2(Touch.VIEW.x - 150.0, 150.0))
	if not _held(t).is_empty():
		out.append("a thumb on the right half steers")
	_touch(t, 0, Vector2.ZERO, false)
	t.free()
	return out


static func _buttons() -> Array:
	var out := []
	var t = _fresh()
	_touch(t, 0, AT)
	_drag(t, 0, AT + Vector2(10.0, 0.0))
	_touch(t, 1, Touch.ATTACK + Vector2(5.0, 5.0))
	if _held(t) != ["attack", "right"]:
		out.append("walking and the sword at once hold %s" % [_held(t)])
	if t.take().keys() != ["attack"]:
		out.append("the sword's tap is not pressed")
	if not t.take().is_empty():
		out.append("one tap of the sword is pressed for more than one step")
	_touch(t, 1, Touch.ATTACK, false)
	if _held(t) != ["right"]:
		out.append("letting go of the sword stops the walk, or keeps the sword: %s" % [_held(t)])
	_touch(t, 2, Touch.DASH)
	if t.take().has("dash"):
		out.append("dash is pressed without the dash upgrade")
	_touch(t, 2, Touch.DASH, false)
	t.dash_shown = true
	_touch(t, 2, Touch.DASH)
	if not t.take().has("dash"):
		out.append("dash is not pressed with the dash upgrade")
	_touch(t, 2, Touch.DASH, false)
	var paused := [0]
	t.pause_pressed.connect(func(): paused[0] += 1)
	_touch(t, 3, Touch.PAUSE)
	if paused[0] != 1:
		out.append("the pause button does not pause")
	t.free()
	return out


static func _modes() -> Array:
	var out := []
	var t = _fresh()
	t.mode = "pick"
	_touch(t, 0, AT)
	_drag(t, 0, AT + Vector2(10.0, 0.0))
	_touch(t, 1, Touch.ATTACK)
	if not _held(t).is_empty() or not t.take().is_empty():
		out.append("touches steer or swing while the cards are up")
	_touch(t, 0, AT, false)
	_touch(t, 1, Touch.ATTACK, false)
	t.mode = "ended"
	t.frame(Touch.REST / 2.0)
	_touch(t, 0, AT)
	_touch(t, 0, AT, false)
	if t.take().has("restart"):
		out.append("a tap restarts before the end has shown for %.1f s" % Touch.REST)
	t.frame(Touch.REST)
	_touch(t, 0, AT)
	if t.take().keys() != ["restart"]:
		out.append("a tap after the end does not restart")
	_touch(t, 0, AT, false)
	t.mode = "paused"
	var resumed := [0]
	t.pause_pressed.connect(func(): resumed[0] += 1)
	_touch(t, 0, AT)
	if resumed[0] != 1:
		out.append("a tap while paused does not go on")
	t.mode = "play"
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	t.handle(key)
	if t.on:
		out.append("a key press does not hide the touch controls")
	if not _held(t).is_empty():
		out.append("the touch controls hold actions after a key press hid them")
	t.free()
	return out


## The "?" button: the start screen again when the tap is lifted on it, while playing or on the pause screen (where
## it does not also go on), not while the cards are up or the end shows; it holds no action and is not the pause button.
static func _help() -> Array:
	var out := []
	var t = _fresh()
	var helped := [0]
	var paused := [0]
	t.help_pressed.connect(func(): helped[0] += 1)
	t.pause_pressed.connect(func(): paused[0] += 1)
	if Touch.HELP.distance_to(Touch.PAUSE) <= Touch.HELP_REACH + Touch.PAUSE_REACH:
		out.append("a tap can reach both the \"?\" and the pause button")
	_touch(t, 0, Touch.HELP + Vector2(3.0, 3.0))
	if helped[0] != 0:
		out.append("the \"?\" button answers as it is touched, so the same tap's click would close the start screen again")
	t.frame(0.1)
	_touch(t, 0, Touch.HELP, false)
	if helped[0] != 1:
		out.append("lifting a tap on the \"?\" button does not bring the start screen back")
	if paused[0] != 0 or not t.take().is_empty() or not _held(t).is_empty():
		out.append("the \"?\" button also pauses or gives an action")
	_touch(t, 0, Touch.HELP)
	_touch(t, 0, Touch.HELP + Vector2(0.0, 40.0), false)
	if helped[0] != 1:
		out.append("a tap that slid off the \"?\" button before lifting still brings the start screen back")
	t.mode = "paused"
	_touch(t, 0, Touch.HELP)
	t.frame(0.1)
	_touch(t, 0, Touch.HELP, false)
	if helped[0] != 2 or paused[0] != 0:
		out.append("on the pause screen the \"?\" button does not bring the start screen back, or also goes on")
	_touch(t, 0, Touch.PAUSE)
	_touch(t, 0, Touch.PAUSE, false)
	if helped[0] != 2 or paused[0] != 1:
		out.append("the pause button on the pause screen does not go on, or brings the start screen back")
	for mode in ["pick", "ended", "off"]:
		t.mode = mode
		t.frame(0.1)
		_touch(t, 0, Touch.HELP)
		_touch(t, 0, Touch.HELP, false)
		if helped[0] != 2:
			out.append("the \"?\" button answers while %s" % mode)
		helped[0] = 2
	t.free()
	return out


## Integer scaling where it fills most of the screen, fractional where it would leave the field small.
static func _scaling() -> Array:
	var out := []
	var want := {
		Vector2(1440, 810): Window.CONTENT_SCALE_STRETCH_INTEGER, # the desktop window: 3x exactly
		Vector2(2340, 1080): Window.CONTENT_SCALE_STRETCH_INTEGER, # 4x fills the height
		Vector2(2532, 1170): Window.CONTENT_SCALE_STRETCH_INTEGER, # 4x of 4.33x
		Vector2(1600, 720): Window.CONTENT_SCALE_STRETCH_FRACTIONAL, # 2x of 2.67x would leave a quarter empty
		Vector2(1280, 720): Window.CONTENT_SCALE_STRETCH_FRACTIONAL,
		Vector2(400, 200): Window.CONTENT_SCALE_STRETCH_FRACTIONAL, # smaller than the field
	}
	for size in want:
		if Touch.stretch_for(size) != want[size]:
			out.append("a %dx%d screen scales %s" % [size.x, size.y, "by a fraction" if want[size] == Window.CONTENT_SCALE_STRETCH_INTEGER else "by whole pixels"])
	return out
