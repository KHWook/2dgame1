## The only source of randomness in the simulation (D1). Seeded, so the same seed gives the same game.
extends RefCounted

var _r := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_r.seed = seed_value


func next() -> float:
	return _r.randf()


func range_f(a: float, b: float) -> float:
	return _r.randf_range(a, b)


func chance(p: float) -> bool:
	return _r.randf() < p


## A whole number from 0 to count - 1, for picking one of count things.
func index(count: int) -> int:
	return mini(int(_r.randf() * count), count - 1)


func state() -> int:
	return _r.state
