## The music, made in code beside the sound effects (src/audio/sfx.gd): each loop is a few voices written below as
## notes on a grid and turned into a sample once. No audio files.
## Three states, each a loop, which cross-fade: "calm" (dusk, the first screen and the choosing screen, an ending),
## "night" (a pulse) and "boss" (heavier, while a boss is on the field). Over the night and the boss lies a fourth
## loop, "tight", of the same length and started with them: it comes in as the torch runs low (urgency), so the pulse
## doubles without the loop changing. Two stings play once: "dawn" and "win".
## View only (D4): state() and urgency() read the world; nothing here is read by a rule. A Maker builds a sample a
## little at a time against a clock (work), so that no frame waits for a whole loop; main.gd owns the players.
extends RefCounted

const SimRng := preload("res://src/sim/rng.gd")

const RATE := 11025 # half the effects' rate: the loops are low and soft, and take half as long to make
const ATTACK := 0.008 # seconds a note takes to swell in, so it starts without a click
const CHUNK := 512 # samples made between two looks at the clock
const FADE := 1.2 # seconds a cross-fade takes
const DUCKS := ["warn", "coming", "boss"] # the sounds that warn (src/art/juice.gd): the music steps back for them
const DUCK := 0.3 # how much of the music is left while it steps back
const DUCK_TIME := 0.9 # for how long, in seconds; it comes back over the last third
const TIGHT_FROM := 20.0 # the tight loop starts to come in when the torch would go out within this many seconds
const TIGHT_FULL := 6.0 # and is all there from here
const ENDINGS := ["out", "dead"]
## A loop: bpm, beats (its length) and voices. A voice: wave ("tri", "square", "noise"), vol 0 to 1, step (beats
## between two notes), hold (beats a note lasts), env ("pluck" fades from its start, "pad" swells and fades), and seq,
## the notes in order, repeated to the loop's end: a MIDI number (69 is the A of 440 Hz), 0 for a rest. For noise the
## number is how many new random levels a second, in hundreds.
const LOOPS := {
	"calm": { "bpm": 72.0, "beats": 8, "voices": [
		{ "wave": "tri", "vol": 0.26, "step": 4.0, "hold": 4.0, "env": "pad", "seq": [45, 41] },
		{ "wave": "tri", "vol": 0.17, "step": 0.5, "hold": 1.0, "env": "pluck", "seq": [57, 60, 64, 60, 57, 60, 64, 67, 53, 57, 60, 57, 53, 57, 60, 64] },
	] },
	"night": { "bpm": 96.0, "beats": 8, "voices": [
		{ "wave": "tri", "vol": 0.3, "step": 1.0, "hold": 0.6, "env": "pluck", "seq": [45, 45, 45, 45, 43, 43, 43, 43] },
		{ "wave": "tri", "vol": 0.13, "step": 0.5, "hold": 1.5, "env": "pluck", "seq": [64, 0, 0, 0, 62, 0, 60, 0, 0, 0, 59, 0, 0, 0, 0, 0] },
	] },
	"tight": { "bpm": 96.0, "beats": 8, "voices": [
		{ "wave": "tri", "vol": 0.22, "step": 0.5, "hold": 0.3, "env": "pluck", "seq": [0, 57, 0, 57, 0, 57, 0, 57, 0, 55, 0, 55, 0, 55, 0, 55] },
		{ "wave": "noise", "vol": 0.08, "step": 0.5, "hold": 0.12, "env": "pluck", "seq": [40] },
	] },
	"boss": { "bpm": 96.0, "beats": 8, "voices": [
		{ "wave": "square", "vol": 0.15, "step": 0.5, "hold": 0.4, "env": "pluck", "seq": [45, 45, 57, 45, 45, 45, 55, 52, 41, 41, 53, 41, 43, 43, 55, 50] },
		{ "wave": "square", "vol": 0.07, "step": 1.0, "hold": 0.9, "env": "pluck", "seq": [69, 68, 69, 72, 65, 64, 67, 71] },
		{ "wave": "noise", "vol": 0.2, "step": 1.0, "hold": 0.2, "env": "pluck", "seq": [3, 25] },
	] },
}
## A sting is a loop played once: its last notes ring out before its end.
const STINGS := {
	"dawn": { "bpm": 120.0, "beats": 3, "voices": [
		{ "wave": "tri", "vol": 0.3, "step": 0.5, "hold": 2.0, "env": "pluck", "seq": [48, 55, 60, 0, 0, 0] },
	] },
	"win": { "bpm": 120.0, "beats": 6, "voices": [
		{ "wave": "tri", "vol": 0.26, "step": 0.5, "hold": 0.6, "env": "pluck", "seq": [60, 64, 67, 72, 0, 0, 0, 0, 0, 0, 0, 0] },
		{ "wave": "tri", "vol": 0.2, "step": 2.0, "hold": 4.0, "env": "pluck", "seq": [0, 72, 0] },
		{ "wave": "tri", "vol": 0.16, "step": 2.0, "hold": 4.0, "env": "pluck", "seq": [0, 76, 0] },
		{ "wave": "square", "vol": 0.06, "step": 2.0, "hold": 4.0, "env": "pluck", "seq": [0, 48, 0] },
	] },
}
const LAYERED := ["night", "tight", "boss"] # the loops of one length that start together, so that they stay in step

var levels := {} # loop -> how much of it sounds now, 0 to 1 (before the duck)
var duck_left := 0.0 # seconds the music still steps back for a warning
var heard := false # the player has pressed something: a browser lets a page sound only after that


func _init() -> void:
	for name in LOOPS:
		levels[name] = 0.0


## Which loop the world asks for. waiting: a screen is over the world (the first screen, the choosing).
static func state(w, waiting: bool) -> String:
	if waiting or ENDINGS.has(w.phase) or (w.phase == "pick" and w.time == 0.0):
		return "calm"
	for e in w.enemies:
		if e.T.get("boss", false) and not e.dead and not e.decoy:
			return "boss"
	return "night"


## How far the tight loop is in, 0 to 1: by how soon the torch goes out at the rate it burns now. Only at night.
static func urgency(w) -> float:
	var rate: float = w.burn_rate()
	if w.phase != "night" or rate <= 0.0:
		return 0.0
	return clampf((TIGHT_FROM - w.fuel / rate) / (TIGHT_FROM - TIGHT_FULL), 0.0, 1.0)


## How much of each loop should sound in a state: the state's own loop, and the tight one by the urgency.
static func targets(state_: String, urgency_: float, on: bool) -> Dictionary:
	var out := {}
	for name in LOOPS:
		out[name] = 0.0
	if on:
		out[state_] = 1.0
		if state_ != "calm":
			out["tight"] = urgency_
	return out


## Whether anything may sound yet: a page in a browser only after the first press.
func may_play(web: bool) -> bool:
	return heard or not web


## Call every drawn frame: moves each loop toward what the state asks for, a whole fade taking FADE seconds.
func frame(delta: float, state_: String, urgency_: float, on: bool) -> void:
	var want := targets(state_, urgency_, on)
	for name in levels:
		levels[name] = move_toward(levels[name], want[name], delta / FADE)
	duck_left = maxf(0.0, duck_left - delta)


## Call after each world step with what it sounded like (Juice.sounds): a warning among them makes the music step
## back for DUCK_TIME, so that it is heard over it.
func sounded(sounds: Array) -> void:
	if sounds.any(func(s): return DUCKS.has(s)):
		duck_left = DUCK_TIME


## What a loop's player is turned to now, 0 to 1.
func gain(name: String) -> float:
	return levels[name] * lerpf(1.0, DUCK, clampf(duck_left / (DUCK_TIME / 3.0), 0.0, 1.0))


static func row(name: String) -> Dictionary:
	return LOOPS[name] if LOOPS.has(name) else STINGS[name]


## How many samples a loop or a sting is.
static func length(name: String) -> int:
	var r := row(name)
	return int(round(r.beats * 60.0 / r.bpm * RATE))


## The whole sample, made in one go (the tools and the tests; the game uses a Maker over many frames).
static func make(name: String) -> AudioStreamWAV:
	var m := Maker.new(name)
	m.work(-1)
	return m.stream


## Builds one loop or sting, a little at a time: work() until it says it is done, then stream holds the sample.
## A loop's notes wrap round its end, so that its last sample runs into its first.
class Maker:
	var name: String
	var loops: bool
	var count: int
	var mix: PackedFloat32Array
	var notes: Array = [] # [wave, pitch (Hz, or levels a second), first sample, samples, vol, pad]
	var note := 0 # the note being made
	var at := 0 # the sample of it to make next
	var phase := 0.0
	var level := 0.0 # noise: the level held now
	var held_for := 0.0 # noise: seconds left before the next random level
	var rng
	var packed := 0 # samples turned to bytes so far
	var data := PackedByteArray()
	var stream: AudioStreamWAV = null

	## row_: a row to make instead of the one name has in LOOPS or STINGS (as a loop; the tests' own).
	func _init(name_: String, row_: Dictionary = {}) -> void:
		name = name_
		loops = LOOPS.has(name) or not row_.is_empty()
		var r: Dictionary = row_ if not row_.is_empty() else LOOPS[name] if loops else STINGS[name]
		var beat: float = 60.0 / r.bpm * RATE
		count = int(round(r.beats * beat))
		mix.resize(count)
		mix.fill(0.0)
		data.resize(count * 2)
		rng = SimRng.new(name.hash()) # the same hiss every time
		for v in r.voices:
			var i := 0
			var t := 0.0
			while t < r.beats - 0.001:
				var n: int = v.seq[i % v.seq.size()]
				if n > 0:
					var pitch: float = n * 100.0 if v.wave == "noise" else 440.0 * pow(2.0, (n - 69) / 12.0)
					notes.append([v.wave, pitch, int(round(t * beat)), int(round(v.hold * beat)), v.vol, v.env == "pad"])
				i += 1
				t += v.step

	## Makes samples until the clock (Time.get_ticks_usec) passes until_usec; with a negative until_usec, all of them.
	## True once the sample is whole.
	func work(until_usec: int) -> bool:
		while stream == null:
			if note < notes.size():
				_voice()
			elif packed < count:
				_pack()
			else:
				stream = AudioStreamWAV.new()
				stream.format = AudioStreamWAV.FORMAT_16_BITS
				stream.mix_rate = RATE
				stream.stereo = false
				stream.data = data
				if loops:
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
					stream.loop_begin = 0
					stream.loop_end = count
			if until_usec >= 0 and Time.get_ticks_usec() >= until_usec:
				break
		return stream != null

	## The next CHUNK samples of the note being made, added to the mix.
	func _voice() -> void:
		var n: Array = notes[note]
		var wave: String = n[0]
		var pitch: float = n[1]
		var from: int = n[2]
		var long: int = n[3]
		var vol: float = n[4]
		var pad: bool = n[5]
		var swell := ATTACK * RATE
		var stop := mini(long, at + CHUNK)
		for i in range(at, stop):
			var v := 0.0
			if wave == "noise":
				held_for -= 1.0 / RATE
				if held_for <= 0.0:
					level = rng.range_f(-1.0, 1.0)
					held_for = 1.0 / pitch
				v = level
			else:
				phase = fmod(phase + pitch / RATE, 1.0)
				v = 4.0 * absf(phase - 0.5) - 1.0 if wave == "tri" else (1.0 if phase < 0.5 else -1.0)
			var k := float(i) / long
			var env := sin(PI * k) if pad else minf(1.0, i / swell) * (1.0 - k) * (1.0 - k)
			var j := from + i
			if j >= count:
				if not loops:
					break
				j -= count
			mix[j] += v * vol * env
		at = stop
		if at >= long:
			note += 1
			at = 0
			phase = 0.0
			held_for = 0.0

	## The next CHUNK samples of the mix as 16-bit bytes.
	func _pack() -> void:
		var stop := mini(count, packed + CHUNK)
		for i in range(packed, stop):
			data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
		packed = stop
