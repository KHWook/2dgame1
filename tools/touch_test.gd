## The touch controls (src/touch.gd) give the actions they claim: the stick's directions (all of
## Config.STICK_DIRECTIONS, not snapped to eight), its dead zone and the way it holds a direction and a walk against a
## trembling thumb, the ring following the thumb, the keeper walking at full speed the way it points, the big sword
## button and any tap on the right half below the HUD swinging, the dash button beside it, the sword held
## while a second thumb steers, each tap pressed once (D6), dash only with the upgrade, nothing steered while the cards
## are up, the tap that restarts only after the end has shown a moment, the "?" button bringing the start screen back
## (as H does) while playing or paused, a key press hiding it all, and the scaling chosen for common phone screens.
extends RefCounted

const Touch := preload("res://src/touch.gd")
const Config := preload("res://src/sim/config.gd")
const World := preload("res://src/sim/world.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const Guide := preload("res://src/guide.gd")
const Ui := preload("res://src/ui.gd")
const Chooser := preload("res://src/chooser.gd")
const Picker := preload("res://src/picker.gd")
const Main := preload("res://src/main.gd")

const AT := Vector2(100.0, 180.0) # where the left thumb lands


## Every failure as a message; empty when all hold.
static func run() -> Array:
	var out := []
	out.append_array(_stick())
	out.append_array(_buttons())
	out.append_array(_modes())
	out.append_array(_help())
	out.append_array(_guide())
	out.append_array(_chooser())
	out.append_array(_picker())
	out.append_array(_reroll())
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
	var n: int = Config.STICK_DIRECTIONS
	if t.on:
		out.append("the controls show before any touch on a device without a touch screen")
	for i in n: # every direction the stick has, pushed straight at it
		_touch(t, 0, AT)
		_drag(t, 0, AT + Vector2.from_angle(TAU * i / n) * 10.0)
		if t.steer() != i:
			out.append("the stick pushed at direction %d steers %d" % [i, t.steer()])
		if not _held(t).is_empty():
			out.append("the stick also holds actions: %s" % [_held(t)])
		_touch(t, 0, AT, false)
	if not t.on:
		out.append("a touch does not show the controls")
	_touch(t, 0, AT)
	_drag(t, 0, AT + Vector2(Touch.DEAD - 1.0, 0.0))
	if t.steer() != -1:
		out.append("a thumb inside the dead zone walks: %d" % t.steer())
	_drag(t, 0, AT + Vector2(0.0, -10.0).rotated(0.3)) # a little right of straight up: that way, not snapped to up
	var up_right := posmod(roundi((-PI / 2.0 + 0.3) / (TAU / n)), n)
	if t.steer() != up_right:
		out.append("a thumb pushed a little right of straight up steers %d, not %d" % [t.steer(), up_right])
	_drag(t, 0, AT + Vector2(Touch.DEAD_STOP + 0.5, 0.0)) # back nearly to the middle, but past DEAD_STOP: still walks
	if t.steer() != 0:
		out.append("a walking thumb drawn back inside the start dead zone stops (or turns): %d" % t.steer())
	_drag(t, 0, AT + Vector2(Touch.DEAD_STOP - 0.5, 0.0))
	if t.steer() != -1:
		out.append("a thumb back inside DEAD_STOP still walks: %d" % t.steer())
	_drag(t, 0, AT + Vector2(10.0, 0.0))
	var step := TAU / n
	_drag(t, 0, AT + Vector2(10.0, 0.0).rotated(step * 0.55)) # past the half-way line to the next, short of TURN_HOLD
	if t.steer() != 0:
		out.append("a thumb resting just past the boundary to the next direction flips to it: %d" % t.steer())
	_drag(t, 0, AT + Vector2(10.0, 0.0).rotated(step * (Touch.TURN_HOLD + 0.1)))
	if t.steer() != 1:
		out.append("a thumb turned past TURN_HOLD does not turn: %d" % t.steer())
	_drag(t, 0, AT + Vector2(60.0, 0.0)) # far right: the ring follows, so turning back answers at once
	_drag(t, 0, AT + Vector2(60.0 - Touch.REACH - Touch.DEAD - 1.0, 0.0))
	if t.steer() != n / 2:
		out.append("after a long push right, turning back does not walk left at once: %d" % t.steer())
	_touch(t, 0, AT, false)
	if t.steer() != -1:
		out.append("letting go of the stick still walks: %d" % t.steer())
	_touch(t, 0, Vector2(100.0, Touch.STICK_TOP - 10.0)) # on the HUD's top-left panel
	_drag(t, 0, Vector2(130.0, Touch.STICK_TOP - 10.0))
	if t.steer() != -1:
		out.append("a thumb on the HUD panel starts the stick")
	_touch(t, 0, Vector2.ZERO, false)
	_touch(t, 0, Vector2(Touch.VIEW.x - 120.0, 150.0)) # the right half, away from the buttons
	_drag(t, 0, Vector2(Touch.VIEW.x - 150.0, 150.0))
	if t.steer() != -1:
		out.append("a thumb on the right half steers")
	_touch(t, 0, Vector2.ZERO, false)
	t.mode = "pick"
	_touch(t, 0, AT)
	_drag(t, 0, AT + Vector2(10.0, 0.0))
	if t.steer() != -1:
		out.append("the stick steers while the cards are up")
	_touch(t, 0, AT, false)
	t.free()
	# The simulation: the stick walks the keeper at full speed exactly the way it points, and faces it there; the
	# keys are read as before when it is not pushed.
	for i in [0, 5, 21, 40]:
		var w = World.new(1)
		w.phase = "night"
		w.offer = []
		var from: Vector2 = w.player.pos
		var f := InputFrame.new()
		f.stick = i
		w.step(f)
		var want := Vector2.from_angle(TAU * i / n)
		if not (w.player.pos - from).normalized().is_equal_approx(want) or not is_equal_approx((w.player.pos - from).length(), Config.PLAYER.speed * Config.STEP) or not w.player.face.is_equal_approx(want):
			out.append("the stick at %d moves the keeper by %s facing %s, not %s at full speed" % [i, w.player.pos - from, w.player.face, want])
	var k = World.new(1)
	k.phase = "night"
	k.offer = []
	var kf := InputFrame.new()
	kf.held["left"] = true
	var kfrom: Vector2 = k.player.pos
	k.step(kf)
	if not (k.player.pos - kfrom).is_equal_approx(Vector2.LEFT * Config.PLAYER.speed * Config.STEP):
		out.append("with the stick let go, the keys no longer walk the keeper as before")
	return out


static func _buttons() -> Array:
	var out := []
	var t = _fresh()
	_touch(t, 0, AT)
	_drag(t, 0, AT + Vector2(10.0, 0.0))
	_touch(t, 1, Touch.ATTACK + Vector2(5.0, 5.0))
	if _held(t) != ["attack"] or t.steer() != 0:
		out.append("walking and the sword at once hold %s steering %d" % [_held(t), t.steer()])
	if t.take().keys() != ["attack"]:
		out.append("the sword's tap is not pressed")
	if not t.take().is_empty():
		out.append("one tap of the sword is pressed for more than one step")
	_touch(t, 1, Touch.ATTACK, false)
	if not _held(t).is_empty() or t.steer() != 0:
		out.append("letting go of the sword stops the walk, or keeps the sword: %s" % [_held(t)])
	for spot in [Touch.ATTACK + Vector2(-30.0, 20.0), Vector2(Touch.VIEW.x / 2.0 + 4.0, Touch.STICK_TOP + 2.0), Vector2(Touch.VIEW.x - 60.0, 120.0)]:
		_touch(t, 1, spot) # anywhere on the right half below the HUD swings, past the drawn button too
		if not t.take().has("attack"):
			out.append("a tap on the right half at %s does not swing" % spot)
		_touch(t, 1, spot, false)
	_touch(t, 1, Vector2(Touch.VIEW.x - 60.0, Touch.STICK_TOP - 8.0)) # up by the score: not a swing
	if t.take().has("attack"):
		out.append("a tap on the HUD's top-right swings")
	_touch(t, 1, Vector2.ZERO, false)
	var big: Texture2D = Touch.Sprites.texture("button")
	if big.get_width() < 40 or Touch.ATTACK_REACH < big.get_width() / 2.0:
		out.append("the sword button is %d pixels across (want 40 or more) and answers %d from its middle" % [big.get_width(), Touch.ATTACK_REACH])
	var mid: Texture2D = Touch.Sprites.texture("button_mid")
	if mid.get_width() < 30 or Touch.DASH_REACH < mid.get_width() / 2.0:
		out.append("the dash button is %d pixels across (want 30 or more) and answers %d from its middle" % [mid.get_width(), Touch.DASH_REACH])
	if Touch.ATTACK.distance_to(Touch.DASH) <= Touch.ATTACK_REACH + Touch.DASH_REACH:
		out.append("a tap can reach both the sword and the dash button")
	for b in [[Touch.ATTACK, big], [Touch.DASH, mid]]:
		var r: float = b[1].get_width() / 2.0
		if b[0].x + r > Touch.VIEW.x - Touch.EDGE or b[0].y + r > Touch.VIEW.y - Touch.EDGE or b[0].y - r < Touch.STICK_TOP or b[0].x - r < Touch.VIEW.x / 2.0:
			out.append("a button at %s comes within %d pixels of the screen's edge, onto the HUD, or onto the stick's half" % [b[0], Touch.EDGE])
	_touch(t, 2, Touch.DASH)
	if t.take().keys() != ["attack"]:
		out.append("without the dash upgrade a tap where its button would be is a swing, as anywhere on the right half")
	_touch(t, 2, Touch.DASH, false)
	t.dash_shown = true
	_touch(t, 2, Touch.DASH)
	if t.take().keys() != ["dash"]:
		out.append("dash is not pressed (alone) with the dash upgrade")
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


## The start screen's guide: deaf for Guide.WAIT seconds after it opens (the tap that opened it, or a press begun
## before, does nothing); then a tap anywhere turns the page, a swipe turns it either way, and only the start button
## (on the last page until the guide has been read; on every page once it has, or when opened during a run) or
## Enter / Space closes it. Its buttons and panel stay clear of the controls the touch page draws.
static func _guide() -> Array:
	var out := []
	var g = Guide.new()
	var mid := Vector2(240.0, 120.0)
	var right: Vector2 = Guide.RIGHT.get_center()
	var left: Vector2 = Guide.LEFT.get_center()
	g.show(false, false)
	g.press(right)
	g.frame(Guide.WAIT * 0.9)
	if g.release(right) != "" or g.key(KEY_ENTER) != "" or not g.open or g.page != 0:
		out.append("the guide answers a tap or a key in its first %.1f s" % Guide.WAIT)
	g.press(right) # pressed while deaf, let go once it listens: still nothing
	g.frame(Guide.WAIT * 0.2)
	if g.release(right) != "" or g.page != 0:
		out.append("a press begun before the guide listens turns or closes it when let go")
	for at in [mid, left, Vector2(20.0, 260.0)]: # anywhere, the left button too while unread: the next page
		g.page = 0
		g.quiet = 0.0
		g.press(at)
		if g.release(at) != "next" or g.page != 1 or not g.open:
			out.append("a quick tap at %s on the first page does not just turn to the next page" % at)
	g.page = 0
	g.quiet = 0.0
	for i in 4: # tapping fast on the spot of "다음": the pages turn, but the start button in that spot is not reached
		g.press(right)
		g.release(right)
		g.frame(Guide.TURN_WAIT + 0.05)
	if not g.open or g.page != Guide.PAGES - 1:
		out.append("tapping fast on the next button runs on through the start button (open %s, page %d)" % [g.open, g.page])
	g.frame(Guide.WAIT)
	g.page = Guide.PAGES - 1
	for at in [mid, left]:
		g.quiet = 0.0
		g.press(at)
		if g.release(at) != "" or not g.open:
			out.append("a tap at %s on the last page closes the guide, or turns it" % at)
	g.quiet = 0.0
	g.press(mid)
	if g.release(mid + Vector2(Guide.SWIPE + 5.0, 4.0)) != "back" or g.page != Guide.PAGES - 2:
		out.append("a swipe to the right does not turn back a page")
	g.quiet = 0.0
	g.press(mid)
	if g.release(mid - Vector2(Guide.SWIPE + 5.0, 0.0)) != "next" or g.page != Guide.PAGES - 1:
		out.append("a swipe to the left does not turn to the next page")
	g.quiet = 0.0
	g.press(mid)
	if g.release(mid + Vector2(Guide.SWIPE + 5.0, Guide.SWIPE + 20.0)) != "" or g.page != Guide.PAGES - 1:
		out.append("a press slid mostly up or down turns the page, or closes it")
	g.quiet = 0.0
	if g.key(KEY_W) != "" or g.key(KEY_X) != "" or not g.open:
		out.append("a key other than Enter, Space or the arrows does something in the guide")
	g.quiet = 0.0
	g.press(right + Vector2(Guide.PAD - 1.0, 0.0) + Vector2(Guide.RIGHT.size.x / 2.0, 0.0))
	if g.release(right + Vector2(Guide.PAD - 1.0, 0.0) + Vector2(Guide.RIGHT.size.x / 2.0, 0.0)) != "start" or g.open:
		out.append("the start button on the last page (or just past its edge) does not close the guide")
	for keycode in [KEY_ENTER, KEY_SPACE]:
		g.show(false, false)
		g.frame(Guide.WAIT)
		var turned: String = g.key(KEY_RIGHT)
		g.frame(Guide.TURN_WAIT)
		var back: String = g.key(KEY_LEFT)
		g.frame(Guide.TURN_WAIT)
		if turned != "next" or back != "back" or g.key(keycode) != "start" or g.open:
			out.append("the arrow keys do not turn the guide, or key %d does not start" % keycode)
	for how in [[true, false], [false, true]]: # read before, or opened during a run: start on the first page
		g.show(how[0], how[1])
		g.frame(Guide.WAIT)
		g.press(left)
		if not g.start_shown() or g.release(left) != "start":
			out.append("the guide read before (%s) or opened during a run (%s) cannot be started from its first page" % how)
	g.show(false, false)
	if g.start_shown():
		out.append("a guide never read shows its start button before the last page")
	var spots: Array = [[Touch.ATTACK, 22.5], [Touch.DASH, 16.5], [Touch.DEMO_STICK, 24.5]]
	for b in [Guide.RIGHT, Guide.LEFT, Ui.GUIDE_BOX]:
		if not Rect2(Vector2.ZERO, Touch.VIEW).encloses(b):
			out.append("a part of the guide at %s is off the screen" % b)
		for spot in spots:
			var near: Vector2 = spot[0].clamp(b.position, b.end)
			if near.distance_to(spot[0]) < spot[1]:
				out.append("the guide's %s covers the control drawn at %s" % [b, spot[0]])
	if Guide.RIGHT.intersects(Guide.LEFT.grow(Guide.PAD * 2.0)):
		out.append("the guide's two buttons are too close to tell apart")
	return out


## The choosing screen: deaf for Chooser.WAIT seconds after it opens (a tap, a press begun before, or a key does
## nothing); then a tap let go on the card it landed on takes that character, a press slid onto another card takes
## none, the number keys take theirs, ← → move the focus (no further than the ends) and Enter or Space takes it; it
## opens on the last pick. Its cards are on the screen, apart, as big as a thumb, and the bot's world never sees it.
static func _chooser() -> Array:
	var out := []
	var ids: Array = Chooser.ids()
	var c = Chooser.new()
	c.show("mage")
	if c.focus != ids.find("mage"):
		out.append("the choosing screen does not open on the last pick")
	var mid: Vector2 = Chooser.rect(0).get_center()
	c.press(mid)
	c.frame(Chooser.WAIT * 0.9)
	if c.release(mid) != "" or c.key(KEY_1) != "" or c.key(KEY_ENTER) != "" or not c.open:
		out.append("the choosing screen answers a tap or a key in its first %.1f s" % Chooser.WAIT)
	c.press(mid) # pressed while deaf, let go once it listens
	c.frame(Chooser.WAIT * 0.2)
	if c.release(mid) != "" or not c.open:
		out.append("a press begun before the choosing screen listens takes a card when let go")
	for i in ids.size():
		c.show("knight")
		c.frame(Chooser.WAIT)
		var at: Vector2 = Chooser.rect(i).get_center() + Vector2(0.0, 40.0)
		c.press(at)
		if c.release(at) != ids[i] or c.open:
			out.append("a tap on card %d does not take %s" % [i + 1, ids[i]])
	c.show("knight")
	c.frame(Chooser.WAIT)
	c.press(Chooser.rect(0).get_center())
	if c.release(Chooser.rect(1).get_center()) != "" or not c.open:
		out.append("a press slid from one card onto another takes a card")
	c.press(Vector2(Chooser.rect(0).position.x - Chooser.PAD - 2.0, 120.0))
	if c.release(Vector2(Chooser.rect(0).position.x - Chooser.PAD - 2.0, 120.0)) != "" or not c.open:
		out.append("a tap beside the cards takes one")
	var edge := Vector2(Chooser.rect(2).end.x + Chooser.PAD - 1.0, 100.0)
	c.press(edge)
	if c.release(edge) != ids[2]:
		out.append("a tap just past a card's drawn edge does not take it")
	for i in ids.size():
		c.show("knight")
		c.frame(Chooser.WAIT)
		if c.key([KEY_1, KEY_2, KEY_3][i]) != ids[i]:
			out.append("key %d does not take %s" % [i + 1, ids[i]])
	c.show("knight")
	c.frame(Chooser.WAIT)
	var walked := [c.key(KEY_RIGHT), c.focus, c.key(KEY_RIGHT), c.key(KEY_RIGHT), c.focus, c.key(KEY_LEFT), c.focus]
	if walked != ["", 1, "", "", ids.size() - 1, "", ids.size() - 2]:
		out.append("the arrow keys do not move the focus card by card, stopping at the ends: %s" % [walked])
	if c.key(KEY_X) != "" or not c.open:
		out.append("a key other than the numbers, the arrows, Enter or Space takes a card")
	for keycode in [KEY_ENTER, KEY_SPACE]:
		c.show("woodcutter")
		c.frame(Chooser.WAIT)
		if c.key(keycode) != "woodcutter":
			out.append("key %d does not take the card in focus" % keycode)
	for i in ids.size():
		var r: Rect2 = Chooser.rect(i)
		if not Rect2(Vector2.ZERO, Touch.VIEW).encloses(r.grow(Chooser.PAD)):
			out.append("card %d is (partly) off the screen: %s" % [i + 1, r])
		if r.size.x < 40.0 or r.size.y < 40.0:
			out.append("card %d is smaller than a thumb: %s" % [i + 1, r.size])
		if i > 0 and r.grow(Chooser.PAD).intersects(Chooser.rect(i - 1).grow(Chooser.PAD)):
			out.append("cards %d and %d are too close to tell apart" % [i, i + 1])
	if Chooser.TOP + Chooser.CARD.y + 18.0 > Touch.VIEW.y:
		out.append("the words under the cards are off the screen")
	return out


## The reroll button (Picker.reroll_rect, REROLL_PAD): in the middle, thumb-sized, answering CLEAR pixels or more
## under the cards and deaf for Picker.WAIT; R rerolls while an offer is up and stays restart in main.gd's KEYS.
static func _reroll() -> Array:
	var out := []
	const CLEAR := 8.0
	var across: float = Config.NIGHT.offer_size * Ui.CARD.x + (Config.NIGHT.offer_size - 1) * Ui.CARD_GAP
	for tall in [80.0, 120.0, 160.0]:
		var button := Picker.reroll_rect(across, tall)
		var answers := button.grow(Picker.REROLL_PAD)
		if answers.position.y - tall < CLEAR:
			out.append("the reroll button answers %.0f pixels under cards %d tall (want %d or more)" % [answers.position.y - tall, tall, CLEAR])
		if answers.size.x < 80.0 or answers.size.y < 20.0:
			out.append("the reroll button answers on %s pixels: small for a thumb (want 80 by 20 or more)" % answers.size)
		if absf(button.get_center().x - across / 2.0) > 0.5 or button.position.x < 0.0 or button.end.x > across:
			out.append("the reroll button is not in the middle under the cards: %s of %d across" % [button, across])
		var p = Picker.new()
		p.show(Config.NIGHT.offer_size)
		var early: bool = p.reroll_at(button.get_center(), across, tall)
		p.frame(Picker.WAIT)
		var cards := []
		for i in Config.NIGHT.offer_size:
			var card := Rect2(i * (Ui.CARD.x + Ui.CARD_GAP), 0.0, Ui.CARD.x, tall)
			cards.append_array([p.reroll_at(card.get_center(), across, tall), p.reroll_at(Vector2(card.get_center().x, tall - 1.0), across, tall), p.reroll_at(Vector2(card.get_center().x, tall + CLEAR - 1.0), across, tall)])
		var on: bool = p.reroll_at(button.get_center(), across, tall)
		p.close()
		if [early, cards.has(true), on, p.reroll_at(button.get_center(), across, tall)] != [false, false, true, false]:
			out.append("the reroll button (cards %d tall) answers too early, on or just under a card, not on itself, or with no offer up: %s" % [tall, [early, cards, on]])
	if Picker.REROLL_KEY != KEY_R or Picker.hears(KEY_R) or Main.KEYS.get(KEY_R, "") != "restart":
		out.append("R is not the reroll key while the offer is up and the restart key otherwise")
	# The key waits as the button does: the second R of a double press on an end screen lands on the new run's first
	# offer before it listens, and must not spend a reroll there.
	var keys = Picker.new()
	var closed: bool = keys.reroll_key(KEY_R)
	keys.show(Config.NIGHT.offer_size)
	var early_key: bool = keys.reroll_key(KEY_R)
	keys.frame(Picker.WAIT)
	if [closed, early_key, keys.reroll_key(KEY_R), keys.reroll_key(KEY_1)] != [false, false, true, false]:
		out.append("the R key rerolls with no offer up, before the offer listens, not once it does, or another key does: %s" % [[closed, early_key, keys.reroll_key(KEY_R), keys.reroll_key(KEY_1)]])
	if not FileAccess.get_file_as_string("res://src/main.gd").contains("ui.picker.reroll_key(k.keycode)"):
		out.append("main.gd does not ask the picker whether the R key rerolls now (Picker.reroll_key): a key pressed before the offer listens would spend a reroll")
	return out


## The torch's offer by the keys (src/picker.gd), as the choosing screen does it: it opens on the middle card and is
## deaf for Picker.WAIT seconds (a move or swing key pressed as the cards come up neither moves the focus nor takes
## one), and again after something covered it; then ← → and A D move the focus card by card, stopping at the ends,
## Enter or Space takes the card in focus, and the mouse onto a card focuses it. The number keys stay pick_N in
## main.gd's KEYS (they are never play keys), and the slot taken, sent as pick_N, takes exactly that card.
static func _picker() -> Array:
	var out := []
	var p = Picker.new()
	p.show(3)
	if p.focus != 1:
		out.append("the offer does not open on its middle card: %d" % p.focus)
	p.frame(Picker.WAIT * 0.9)
	var early := [p.key(KEY_RIGHT), p.focus, p.key(KEY_SPACE), p.key(KEY_ENTER), p.open]
	if early != [-1, 1, -1, -1, true]:
		out.append("the offer answers a move or the attack key in its first %.1f s: %s" % [Picker.WAIT, early])
	p.frame(Picker.WAIT * 0.2)
	var walked := [p.key(KEY_RIGHT), p.focus, p.key(KEY_RIGHT), p.focus, p.key(KEY_LEFT), p.key(KEY_A), p.focus, p.key(KEY_LEFT), p.focus, p.key(KEY_D), p.focus]
	if walked != [-1, 2, -1, 2, -1, -1, 0, -1, 0, -1, 1]:
		out.append("← → and A D do not move the offer's focus card by card, stopping at the ends: %s" % [walked])
	if p.key(KEY_X) != -1 or p.key(KEY_W) != -1 or not p.open:
		out.append("a key other than the arrows, A D, Enter or Space moves or takes an offer card")
	for keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		p.show(3)
		p.frame(Picker.WAIT)
		p.key(KEY_LEFT)
		if p.key(keycode) != 0 or p.open:
			out.append("key %d does not take the offer card in focus" % keycode)
		if p.key(keycode) != -1:
			out.append("a taken offer takes again on key %d" % keycode)
	p.show(3)
	p.frame(Picker.WAIT)
	p.hold() # the pause screen (or the first screen) was over it
	p.frame(Picker.WAIT * 0.5)
	if p.key(KEY_ENTER) != -1 or not p.open:
		out.append("the key that closes a screen over the offer also takes a card")
	p.show(1)
	p.frame(Picker.WAIT)
	if [p.focus, p.key(KEY_RIGHT), p.focus] != [0, -1, 0]:
		out.append("a one-card offer moves its focus off its card")
	p.show(3)
	p.hover(2)
	p.hover(-1)
	p.hover(5)
	if p.focus != 2:
		out.append("the mouse onto a card does not focus it (or off the cards moves it): %d" % p.focus)
	for keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_ENTER, KEY_SPACE]:
		if not Picker.hears(keycode):
			out.append("key %d moves the keeper or swings while the offer is up" % keycode)
	for keycode in [KEY_1, KEY_2, KEY_3]:
		if Picker.hears(keycode) or Main.KEYS.get(keycode, "") != "pick_%d" % ([KEY_1, KEY_2, KEY_3].find(keycode) + 1):
			out.append("number key %d no longer takes its offer card" % keycode)
	var w = World.new(3)
	var offered: Array = w.offer.duplicate()
	p.show(offered.size())
	p.frame(Picker.WAIT)
	p.key(KEY_RIGHT)
	var slot: int = p.key(KEY_ENTER)
	var f := InputFrame.new()
	f.pressed["pick_%d" % (slot + 1)] = true
	w.step(f)
	if w.phase != "night" or w.picks != [offered[mini(slot, offered.size() - 1)]]:
		out.append("the offer card taken by the keys is not the one the world takes: %s of %s" % [w.picks, offered])
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
