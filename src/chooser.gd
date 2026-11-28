## The screen that picks who keeps the torch (Config.CHARACTERS): one card each, side by side. It opens once the start
## screen's guide is closed and again for every new run (R, or a tap on the end screen), with the last pick in focus,
## so Enter or a tap on the same card plays on as before. A card is taken by a tap or a click on it, by its number key
## (1, 2, 3), or by moving the focus with ← → and pressing Enter or Space. Like the guide (src/guide.gd), it hears
## nothing for WAIT seconds after it opens, so the tap that closed the guide or ended the last run does not also pick
## a card, and a tap counts only when it is let go on the card it landed on.
## This is the screen's state and what its input means; src/ui.gd draws the cards at rect(), src/main.gd feeds it the
## clicks (a touch arrives as a click, by Godot's mouse emulation) and keys. The demo bot and --char=ID skip it.
## A character that is not open yet (src/records.gd, Config.UNLOCKS) keeps its card, which says what opens it, and
## cannot be taken. Once a run has been won, a button under the cards (the L key) turns the long night on and off.
extends RefCounted

const Config := preload("res://src/sim/config.gd")

const WAIT := 0.6 # seconds after it opens before it hears anything
const CARD := Vector2(126.0, 194.0) # as tall as the card with the most words (the touch test lays each out)
const GAP := 10.0
const TOP := 30.0 # the cards' top edge; the heading is above it, the keys to press below
const PAD := 4.0 # a card answers this far past its drawn edge
const PICK_KEYS := [KEY_1, KEY_2, KEY_3]
const START_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const NEXT_KEYS := [KEY_RIGHT, KEY_D]
const BACK_KEYS := [KEY_LEFT, KEY_A]
const LONG_KEY := KEY_L
const LONG := Rect2(160.0, 244.0, 160.0, 16.0) # the long night's button, under the line of keys

var open := false
var focus := 0 # the card in focus, from 0
var quiet := 0.0 # real seconds until it listens
var _down := -1 # the card a press that began while it was listening landed on, -1 otherwise
var _down_long := false # that press landed on the long night's button
var locked: Array = [] # the characters that cannot be taken yet
var long_open := false # the long night can be chosen
var long := false # and is: the run started from here is won at Config.UNLOCKS.long.night's dawn


## The characters, in the order of their cards.
static func ids() -> Array:
	return Config.CHARACTERS.keys()


## Where card i is drawn and answers (before PAD), in game pixels: the three side by side in the middle.
static func rect(i: int) -> Rect2:
	var n := ids().size()
	var width := n * CARD.x + (n - 1) * GAP
	return Rect2(Vector2((Config.VIEW.x - width) / 2.0 + i * (CARD.x + GAP), TOP), CARD)


## The card at pos (a little past its edges counts), or -1.
static func card_at(pos: Vector2) -> int:
	for i in ids().size():
		if rect(i).grow(PAD).has_point(pos):
			return i
	return -1


## Opens with the card of last (a character id) in focus (the first open card, if that one is locked), and stops
## listening for WAIT seconds. locked_: the characters that cannot be taken; can_long: the long night can be chosen.
func show(last: String, locked_: Array = [], can_long := false) -> void:
	open = true
	locked = locked_
	long_open = can_long
	long = long and can_long
	focus = maxi(0, ids().find(last))
	if locked.has(ids()[focus]):
		focus = maxi(0, ids().find(ids().filter(func(id): return not locked.has(id)).front()))
	quiet = WAIT
	_down = -1
	_down_long = false


func frame(delta: float) -> void:
	quiet = maxf(0.0, quiet - delta)


func listening() -> bool:
	return open and quiet <= 0.0


## The mouse over a card brings it into focus.
func hover(pos: Vector2) -> void:
	var i := card_at(pos)
	if open and i >= 0:
		focus = i


## A press (a touch landing, a mouse button going down) at pos.
func press(pos: Vector2) -> void:
	_down = card_at(pos) if listening() else -1
	_down_long = listening() and long_open and LONG.grow(PAD).has_point(pos)


## The press let go at pos. Returns the character taken (and closes), or "".
func release(pos: Vector2) -> String:
	var was := _down
	var was_long := _down_long
	_down = -1
	_down_long = false
	if was_long and listening() and LONG.grow(PAD).has_point(pos):
		long = not long
	if was < 0 or not listening() or card_at(pos) != was:
		return ""
	return _take(was)


## A key pressed (not an echo). Returns the character taken (and closes), or "".
func key(keycode: int) -> String:
	if not listening():
		return ""
	if keycode == LONG_KEY and long_open:
		long = not long
	var n := PICK_KEYS.find(keycode)
	if n >= 0 and n < ids().size():
		return _take(n)
	if START_KEYS.has(keycode):
		return _take(focus)
	if NEXT_KEYS.has(keycode):
		focus = mini(focus + 1, ids().size() - 1)
	elif BACK_KEYS.has(keycode):
		focus = maxi(focus - 1, 0)
	return ""


func _take(i: int) -> String:
	if locked.has(ids()[i]):
		return ""
	open = false
	_down = -1
	focus = i
	return ids()[i]
