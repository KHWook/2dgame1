## Saves every loop and sting of the music (src/audio/music.gd) as a WAV file, so it can be listened to without
## running the game, and prints what each measures: its length, its peak and RMS level, its last and first samples
## (a loop runs from the one into the other) and how long it took to make.
## godot --headless --path . --script res://tools/music_wav.gd -- <out dir>
extends SceneTree

const Music := preload("res://src/audio/music.gd")
const GoalsTest := preload("res://tools/goals_test.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("music_wav: name a folder to write to: godot --headless --path . --script res://tools/music_wav.gd -- <out dir>")
		quit(1)
		return
	var dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var total_usec := 0
	var bytes := 0
	for name in Music.LOOPS.keys() + Music.STINGS.keys():
		var t0 := Time.get_ticks_usec()
		var stream := Music.make(name)
		var took := Time.get_ticks_usec() - t0
		total_usec += took
		bytes += stream.data.size()
		stream.save_to_wav(dir.path_join(name + ".wav"))
		var l: Dictionary = GoalsTest.level(stream)
		var s: PackedFloat32Array = GoalsTest._floats(stream)
		var steps := 0.0 # the biggest step between two samples next to each other, inside the sample
		for i in range(1, s.size()):
			steps = maxf(steps, absf(s[i] - s[i - 1]))
		print("music_wav: %s (%s): %.3f s, %d samples at %d Hz, peak %.3f (%.1f dB), RMS %.1f dB, last %.4f -> first %.4f (step %.4f; the biggest inside is %.4f), made in %.1f ms, %d bytes" % [
			name, "loop" if Music.LOOPS.has(name) else "sting", float(l.samples) / Music.RATE, l.samples, Music.RATE, l.peak, linear_to_db(l.peak), l.rms_db,
			l.last, l.first, absf(l.first - l.last), steps, took / 1000.0, stream.data.size()])
	print("music_wav: all %d made in %.1f ms, %d bytes of samples, written to %s" % [Music.LOOPS.size() + Music.STINGS.size(), total_usec / 1000.0, bytes, dir])
	quit(0)
