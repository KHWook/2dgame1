## Coaching on the first night of the very first run: an arrow over the nearest log ("장작을 주워"), then over the
## torch ("횃불에 넣어") until a log is fed, and "적을 베어라" over the first enemy that comes close, until something
## is cut down. Each goes once it is done. It reads the world and never writes to it (D4); src/ui.gd draws it and
## turns it on only for a player who has not read the guide before (src/records.gd), never for the demo bot.
extends RefCounted

const Config := preload("res://src/sim/config.gd")

const NEAR := 60.0 # pixels from the keeper an enemy comes before "cut it" shows
const FIGHT_STEPS := 60 * 5 # simulation steps "cut it" stays at most, if nothing is cut down
const HAUL := "장작을 주워"
const FEED := "횃불에 넣어"
const FIGHT := "적을 베어라"

var on := false
var haul := "log" # "log" (go get one), "torch" (take it there), "done"
var fight := "wait" # "wait" (no enemy close yet), "show", "done"
var fight_steps := 0


## Call after every world step.
func step(w) -> void:
	if not on or w.phase != "night":
		return
	var kinds: Array = w.events.map(func(ev): return ev.kind)
	if haul != "done":
		if kinds.has("fed"):
			haul = "done"
		else:
			haul = "torch" if w.player.carrying else "log"
	if fight == "wait" and _nearest(w) != null:
		fight = "show"
	elif fight == "show":
		fight_steps += 1
		if kinds.has("kill") or fight_steps >= FIGHT_STEPS:
			fight = "done"
	if haul == "done" and fight == "done":
		on = false


## What to show now: [words, the world point the arrow points at], or [] for nothing. Cutting an enemy that has come
## close comes before hauling.
func now(w) -> Array:
	if not on or w.phase != "night":
		return []
	if fight == "show":
		var e = _nearest(w)
		if e != null:
			return [FIGHT, e.pos]
	if haul == "torch":
		return [FEED, Config.TORCH.pos]
	if haul == "log" and not w.logs.is_empty():
		var best: Vector2 = w.logs[0]
		for l in w.logs:
			if l.distance_to(w.player.pos) < best.distance_to(w.player.pos):
				best = l
		return [HAUL, best]
	return []


## The nearest living enemy within NEAR of the keeper, or null.
static func _nearest(w):
	var best = null
	for e in w.enemies:
		if not e.dead and e.pos.distance_to(w.player.pos) < NEAR and (best == null or e.pos.distance_to(w.player.pos) < best.pos.distance_to(w.player.pos)):
			best = e
	return best
