## The start screen's guide: a few pages with pictures (what the game is, what comes out of the dark, how to play),
## turned with a tap, a swipe or the arrow keys, and closed only on purpose: with its start button, or Enter or Space.
## For a moment after it opens it hears nothing, so the tap that opened the page (or made it full screen, or brought
## it back with "?") does not close it again; and again for a moment after each turn, longest on coming to the last
## page, so tapping fast on "다음" cannot run on to "시작" in the same spot. Until the guide has been read once (src/records.gd remembers it), the
## start button shows only on the last page; after that, and when it is opened again during a run, on every page.
## This is the guide's state and what its input means; src/ui.gd draws its pages, src/main.gd feeds it the clicks
## (a touch arrives as a click, by Godot's mouse emulation) and keys, and src/touch.gd draws the controls page.
extends RefCounted

const PAGES := 3
const CONTROLS := 2 # the page that shows the controls
const WAIT := 1.0 # seconds after it opens, or comes to its last page, before it hears anything
const TURN_WAIT := 0.35 # seconds after it turns to any other page: quick taps on the spot of "다음" cannot run
# through the pages onto the start button, which is in that same spot on the last page
const SWIPE := 30.0 # pixels a press must slide sideways, more than up or down, to turn the page instead of tapping
const PAD := 6.0 # the buttons answer this far past their drawn edges
## The buttons, the same on every page, at the bottom between where the stick and the sword are drawn: the right
## one goes on (the next page, or the start on the last one), the left one starts at once once the guide is read.
const RIGHT := Rect2(246.0, 236.0, 84.0, 24.0)
const LEFT := Rect2(150.0, 236.0, 84.0, 24.0)
const START_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const NEXT_KEYS := [KEY_RIGHT, KEY_D]
const BACK_KEYS := [KEY_LEFT, KEY_A]

var open := false
var page := 0
var quiet := 0.0 # real seconds until it listens again
var read := false # read once before (on disk): the start button shows on every page
var returning := false # opened during a run, to look again: its button says "돌아가기"
var _down = null # where a press that began while it was listening began; null otherwise


## Opens on the first page and stops listening for WAIT seconds.
func show(read_before: bool, during_run: bool) -> void:
	open = true
	page = 0
	quiet = WAIT
	read = read_before
	returning = during_run
	_down = null


func frame(delta: float) -> void:
	quiet = maxf(0.0, quiet - delta)


func listening() -> bool:
	return open and quiet <= 0.0


func last() -> bool:
	return page == PAGES - 1


## Whether a start button shows on this page, and where: on the last page it is the right button.
func start_shown() -> bool:
	return read or returning or last()


func start_rect() -> Rect2:
	return RIGHT if last() else LEFT


## A press (a touch landing, a mouse button going down) at pos.
func press(pos: Vector2) -> void:
	_down = pos if listening() else null


## The press let go at pos. Returns what it did: "start" (the guide closed), "next", "back", or "".
func release(pos: Vector2) -> String:
	if _down == null or not listening():
		_down = null
		return ""
	var slide: Vector2 = pos - _down
	_down = null
	if absf(slide.x) >= SWIPE and absf(slide.x) > absf(slide.y):
		return _turn(1 if slide.x < 0.0 else -1)
	if start_shown() and start_rect().grow(PAD).has_point(pos):
		return _close()
	if not last(): # the next button, or a tap anywhere else, turns the page; on the last page only start closes
		return _turn(1)
	return ""


## A key pressed (not an echo). Returns what it did, as release() does.
func key(keycode: int) -> String:
	if not listening():
		return ""
	if START_KEYS.has(keycode):
		return _close()
	if NEXT_KEYS.has(keycode):
		return _turn(1)
	if BACK_KEYS.has(keycode):
		return _turn(-1)
	return ""


func _turn(by: int) -> String:
	var to := clampi(page + by, 0, PAGES - 1)
	if to == page:
		return ""
	page = to
	quiet = WAIT if last() and not start_shown_before(by) else TURN_WAIT
	_down = null
	return "next" if by > 0 else "back"


## Whether the start button already showed on the page it came from (by pages back), so arriving on the last page
## does not put it under a thumb that was not there for it.
func start_shown_before(by: int) -> bool:
	return read or returning or page - by == PAGES - 1


func _close() -> String:
	open = false
	_down = null
	return "start"
