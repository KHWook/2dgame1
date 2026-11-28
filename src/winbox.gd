## The box a won run shows, on the dawn that wins it (World.won, Config.GOAL): what was kept, and two ways on. "go_on"
## keeps the run going, endless as it always was; "restart" records it and starts a new one. While it is up main.gd
## does not step the world, as on the pause screen, so the run is the same steps with or without it.
## This is its state and what its input means; src/ui.gd draws it (the box an ending uses), src/main.gd feeds it keys,
## and src/touch.gd its two buttons (Ui.targets). Like the choosing screen it hears nothing for WAIT seconds after it
## opens: the keeper was swinging a moment ago, and Space must not close the win unread.
extends RefCounted

const WAIT := 1.0 # seconds after it opens before it hears a key (a tap waits Touch.REST)
const GO_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const NEW_KEYS := [KEY_R]

var open := false
var quiet := 0.0 # real seconds until it listens


func show() -> void:
	open = true
	quiet = WAIT


func frame(delta: float) -> void:
	quiet = maxf(0.0, quiet - delta)


func listening() -> bool:
	return open and quiet <= 0.0


## A key pressed (not an echo): "go_on", "restart", or "" for a key that is neither or one pressed too soon.
func key(keycode: int) -> String:
	if not listening():
		return ""
	return "go_on" if GO_KEYS.has(keycode) else "restart" if NEW_KEYS.has(keycode) else ""


## The answer was given: the box is gone.
func close() -> void:
	open = false
