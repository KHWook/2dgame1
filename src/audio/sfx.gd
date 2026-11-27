## Sound effects made in code, the way the sprites are text: each sound is a short list of tones written below and
## turned into a sample when the game starts. No audio files to import.
## View only (D4): main.gd plays what src/art/juice.gd says the last step sounded like.
extends RefCounted

const SimRng := preload("res://src/sim/rng.gd")

const RATE := 22050
const ATTACK := 0.004 # seconds each part takes to swell in, so it starts without a click
## Each sound is parts played one after the other: [wave, pitch at the start and at the end (Hz), seconds, loudness
## 0 to 1]. Waves: "square", "tri" (softer), "noise" (a new random level pitch times a second: high is a hiss, low
## a rumble). Each part fades out over its length.
const SOUNDS := {
	"swing": [["noise", 6000.0, 1500.0, 0.07, 0.18]],
	"hit": [["square", 260.0, 140.0, 0.05, 0.3], ["noise", 2500.0, 1000.0, 0.03, 0.2]],
	"kill": [["noise", 3000.0, 400.0, 0.14, 0.35], ["square", 180.0, 60.0, 0.08, 0.2]],
	"fed": [["noise", 1200.0, 3000.0, 0.12, 0.25], ["tri", 330.0, 660.0, 0.12, 0.35]],
	"hurt": [["square", 220.0, 80.0, 0.18, 0.4]],
	"boss": [["square", 90.0, 55.0, 0.45, 0.35], ["noise", 300.0, 100.0, 0.3, 0.3]],
	"dawn": [["tri", 523.0, 523.0, 0.12, 0.35], ["tri", 659.0, 659.0, 0.12, 0.35], ["tri", 784.0, 784.0, 0.3, 0.35]],
	"warn": [["square", 440.0, 880.0, 0.12, 0.2], ["square", 440.0, 880.0, 0.12, 0.2]],
	"landed": [["noise", 400.0, 60.0, 0.3, 0.45], ["square", 70.0, 40.0, 0.2, 0.3]],
	"coming": [["square", 110.0, 110.0, 0.35, 0.3], ["square", 98.0, 98.0, 0.35, 0.3], ["square", 82.0, 70.0, 0.6, 0.3]],
	"pick": [["square", 660.0, 660.0, 0.05, 0.2], ["square", 990.0, 990.0, 0.1, 0.2]],
	"sizzle": [["noise", 5000.0, 900.0, 0.22, 0.3]],
	"spit": [["square", 500.0, 180.0, 0.07, 0.2], ["noise", 1800.0, 700.0, 0.05, 0.15]],
	"splat": [["noise", 900.0, 300.0, 0.08, 0.25]],
	"drum": [["tri", 120.0, 70.0, 0.09, 0.3]],
}


static func make(name: String) -> AudioStreamWAV:
	var rng := SimRng.new(name.hash()) # the same hiss every time the game starts
	var data := PackedByteArray()
	for part in SOUNDS[name]:
		var count := int(part[3] * RATE)
		var phase := 0.0
		var level := 0.0
		var held_for := 0.0 # noise: seconds left before the next random level
		var at := data.size()
		data.resize(at + count * 2)
		for i in count:
			var k := float(i) / count
			var pitch: float = lerpf(part[1], part[2], k)
			phase = fmod(phase + pitch / RATE, 1.0)
			var v := 0.0
			match part[0]:
				"square":
					v = 1.0 if phase < 0.5 else -1.0
				"tri":
					v = 4.0 * absf(phase - 0.5) - 1.0
				"noise":
					held_for -= 1.0 / RATE
					if held_for <= 0.0:
						level = rng.range_f(-1.0, 1.0)
						held_for = 1.0 / pitch
					v = level
			var swell := minf(1.0, float(i) / (ATTACK * RATE))
			var fade := (1.0 - k) * (1.0 - k)
			data.encode_s16(at + i * 2, int(clampf(v * part[4] * swell * fade, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
