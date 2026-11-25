## What the player does during one fixed step: actions held, and actions pressed in this step only (D6).
extends RefCounted

var held := {}
var pressed := {}


func is_held(action: String) -> bool:
	return held.has(action)


func is_pressed(action: String) -> bool:
	return pressed.has(action)
