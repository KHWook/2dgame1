## The torch's offer (the cards at dusk and at midnight) as the keys see it: a card in focus, moved with ← → (and
## A D), taken with Enter or Space, the way the choosing screen (src/chooser.gd) does it, so both screens feel the
## same. The number keys (1, 2, 3) and a tap or a click on a card take theirs as before, through the pick_N actions
## main.gd already sends; they are never play keys, so they need no wait. The arrows, A D and Space are: a player
## still pressing toward something or swinging when the cards come up must not move the focus or take a card, so
## like the chooser it hears nothing for WAIT seconds after an offer opens (and again after the first screen, the
## choosing screen or the pause screen was over it). A held key never counts: only a new press (not an echo) does.
## A card taken here becomes the same pick_N action for the next step, so the world, the bot and the replay never
## see this; src/ui.gd draws the focus, main.gd feeds the keys.
extends RefCounted

const Chooser := preload("res://src/chooser.gd")

const WAIT := Chooser.WAIT
const TAKE_KEYS := Chooser.START_KEYS
const NEXT_KEYS := Chooser.NEXT_KEYS
const BACK_KEYS := Chooser.BACK_KEYS

## The reroll button (the R key's): one under the cards for the mouse and a thumb. It is drawn at reroll_rect() and
## answers REROLL_PAD past it, once the offer listens (as the key does: reroll_key) (so the tap that drew an offer again is not also the next
## reroll). It sits in the middle, REROLL_BELOW under the cards' bottom edge with the line of keys between, so a
## thumb that lands low on a card, or just under one, takes neither.
const REROLL_KEY := KEY_R
const REROLL := Vector2(118.0, 16.0)
const REROLL_BELOW := 14.0
const REROLL_PAD := 4.0

var open := false
var cards := 0 # how many cards this offer has
var focus := 0 # the card in focus, from 0
var quiet := 0.0 # real seconds until it listens


## Whether this key belongs to the offer while it is up (it then never reaches play as a move or a swing).
static func hears(keycode: int) -> bool:
	return TAKE_KEYS.has(keycode) or NEXT_KEYS.has(keycode) or BACK_KEYS.has(keycode)


## Where the reroll button is, in the frame its cards are in: across is how wide the row of cards is, bottom their
## bottom edge.
static func reroll_rect(across: float, bottom: float) -> Rect2:
	return Rect2(Vector2(roundf((across - REROLL.x) / 2.0), bottom + REROLL_BELOW), REROLL)


## Whether a click or a tap at pos (in that frame) is on the reroll button, while it listens.
func reroll_at(pos: Vector2, across: float, bottom: float) -> bool:
	return listening() and reroll_rect(across, bottom).grow(REROLL_PAD).has_point(pos)


## Whether this key, pressed now, draws the offer again: the reroll key, once the offer listens (so the R that
## restarted a run from its end screen, pressed twice, does not also spend a reroll on the new run's first offer).
func reroll_key(keycode: int) -> bool:
	return listening() and keycode == REROLL_KEY


## A new offer of n cards: the middle one in focus, deaf for WAIT seconds.
func show(n: int) -> void:
	open = n > 0
	cards = n
	focus = maxi(0, (n - 1) / 2)
	quiet = WAIT


func close() -> void:
	open = false


## Something covered the offer (the first screen, the choosing screen, the pause screen): deaf again for WAIT once
## it is gone, so the key that closed it does not also move or take a card.
func hold() -> void:
	quiet = WAIT


func frame(delta: float) -> void:
	quiet = maxf(0.0, quiet - delta)


func listening() -> bool:
	return open and quiet <= 0.0


## The mouse over card i brings it into focus.
func hover(i: int) -> void:
	if open and i >= 0 and i < cards:
		focus = i


## A key pressed (not an echo). Returns the slot taken (from 0, and closes), or -1.
func key(keycode: int) -> int:
	if not listening():
		return -1
	if TAKE_KEYS.has(keycode):
		open = false
		return focus
	if NEXT_KEYS.has(keycode):
		focus = mini(focus + 1, cards - 1)
	elif BACK_KEYS.has(keycode):
		focus = maxi(focus - 1, 0)
	return -1
