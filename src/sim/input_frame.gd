## What the player does during one fixed step: actions held, and actions pressed in this step only (D6).
extends RefCounted

var held := {}
var pressed := {}
## The touch stick (src/touch.gd): the way it steers, one of Config.STICK_DIRECTIONS counted clockwise on the screen
## from right, or -1 when it is not pushed. A whole number, so a run steered by touch replays exactly. While it is
## pushed it steers instead of the direction keys.
var stick := -1


func is_held(action: String) -> bool:
	return held.has(action)


func is_pressed(action: String) -> bool:
	return pressed.has(action)
