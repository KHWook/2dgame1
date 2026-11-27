## How hard the last step hit: a short hold of the whole game on a kill or when the keeper is hurt (hit-stop), a
## shake of the field, and which sounds to play (src/audio/sfx.gd). It reads world.events, and the keeper's health,
## swing and upgrades, which no event tells.
## View only (D4): it reads the world and never writes to it. main.gd holds the world by not stepping it while
## hold > 0, the way it waits for the demo bot to read an offer: the world never knows, so a held step is the same
## step a moment later and the replay (which never runs main.gd) is untouched. Its own seeded generator keeps D1.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const SimRng := preload("res://src/sim/rng.gd")
const Effects := preload("res://src/art/effects.gd")

## Frames the game holds still after a thing happens. The largest wins; they do not add up.
const STOP := { "kill": 3, "hurt": 5, "boss": 6, "boss_kill": 10, "landed": 4 }
## Frames between two kill holds. Only the keeper's own blows hold the game (a kill while the swing is under way):
## on a late night the ember ring, the sparks and the thorns kill several times a second, and holding for each of
## those froze the game three frames in every eighteen, which read as stutter, not as a hit.
const KILL_STOP_APART := 40
## How far the field shakes (pixels, at its start) and for how long (frames). Whole pixels only, at 480x270.
const SHAKE := { "hurt": [2.0, 12], "boss": [3.0, 30], "boss_kill": [3.0, 24], "landed": [2.0, 16], "crush": [1.0, 4] }
## A keeper's own blow never shakes the field by itself: on every hit that read as the whole screen wobbling. The
## weight is in the axe's chips, the dust of its landing and the struck enemy's flash. Only a chop that kills at
## least CRUSH's kills enemies in one step (src/art/effects.gd's blow()) jolts the field a pixel, and not again for
## apart frames: a crowd mown down at once, not every blow.
const CRUSH := { "woodcutter": { "kills": 3, "apart": 90 } }
const SHAKE_EVERY := 2 # frames between new shake offsets: every frame is a buzz, this is a jolt
const MARGIN := 4.0 # painter.gd paints the edge this far past the view, so a shake never shows the void

var rng
var hold := 0 # frames left to hold the world still
var since_kill_stop := KILL_STOP_APART
var shake_size := 0.0
var shake_left := 0
var shake_frames := 1
var offset := Vector2.ZERO # where the field is drawn, against the HUD which stays put
var sounds: Array = [] # what the last step sounded like, each once
var last_hp := 0
var last_picks := 0
var swinging := false
var since_crush := 1 << 20 # frames since the last crush shake


func _init(seed_value: int) -> void:
	rng = SimRng.new(seed_value)


## Take the world as it is as the starting point, without answering anything (after --skip, or at the start).
func seen(w) -> void:
	last_hp = w.player.hp
	last_picks = w.picks.size()
	swinging = w.player.attack_t >= 0.0


## Call once after each world.step().
func step(w) -> void:
	sounds = []
	var p = w.player
	var stop := 0
	if p.attack_t >= 0.0 and not swinging:
		_sound("swing")
	if p.hp < last_hp:
		_sound("hurt")
		stop = maxi(stop, STOP.hurt)
		_shake("hurt")
	if w.picks.size() > last_picks:
		_sound("pick")
	var crushed := 0
	for ev in w.events:
		match ev.kind:
			"hit":
				_sound("hit")
			"kill":
				_sound("kill")
				if CRUSH.has(w.character) and Effects.blow(w, ev):
					crushed += 1
				if Config.ENEMY_TYPES[ev.enemy].get("boss", false):
					stop = maxi(stop, STOP.boss_kill)
					_shake("boss_kill")
				elif since_kill_stop >= KILL_STOP_APART and p.attack_t >= 0.0:
					stop = maxi(stop, STOP.kill)
			"fed":
				_sound("fed")
			"boss":
				_sound("boss")
				stop = maxi(stop, STOP.boss)
				_shake("boss")
			"dawn":
				_sound("dawn")
			"warn": # a boss is about to strike
				_sound("warn")
			"landed":
				_sound("landed")
				stop = maxi(stop, STOP.landed)
				_shake("landed")
			"coming": # a boss is on its way
				_sound("coming")
	if CRUSH.has(w.character) and crushed >= CRUSH[w.character].kills and since_crush >= CRUSH[w.character].apart:
		_shake("crush")
		since_crush = 0
	if stop > 0:
		hold = maxi(hold, stop)
		since_kill_stop = 0
	seen(w)


## Call once every physics frame, held or not: the shake runs on while the world holds still.
func frame() -> void:
	hold = maxi(0, hold - 1)
	since_kill_stop += 1
	since_crush += 1
	if shake_left <= 0:
		offset = Vector2.ZERO
		return
	if shake_left % SHAKE_EVERY == 0:
		var a := roundf(shake_size * shake_left / shake_frames)
		offset = Vector2(roundf(rng.range_f(-a, a)), roundf(rng.range_f(-a, a)))
	shake_left -= 1


func _sound(name: String) -> void:
	if not sounds.has(name):
		sounds.append(name)


func _shake(kind: String) -> void:
	var s: Array = SHAKE[kind]
	if s[0] * s[1] >= shake_size * shake_left: # a bigger shake takes over; a smaller one does not cut it short
		shake_size = s[0]
		shake_left = s[1]
		shake_frames = s[1]
