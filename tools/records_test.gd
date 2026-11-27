## The score records (src/records.gd) hold to what they claim: best first, only the top ten, one entry per run
## however long its ending lasts, the same list after a save and a load, and a broken file is an empty list.
## Works on a file of its own under user://, never the player's.
extends RefCounted

const Records := preload("res://src/records.gd")
const World := preload("res://src/sim/world.gd")

const FILE := "user://records_test.json"
const GUIDE_FILE := "user://guide_test.json"
const CHARACTER_FILE := "user://character_test.json"


## Every failure as a message; empty when all hold.
static func run() -> Array:
	var out := []
	out.append_array(_order())
	out.append_array(_once_per_run())
	out.append_array(_files())
	out.append_array(_guide())
	out.append_array(_characters())
	DirAccess.remove_absolute(FILE)
	DirAccess.remove_absolute(GUIDE_FILE)
	DirAccess.remove_absolute(CHARACTER_FILE)
	return out


static func _run(score: int, night: int, date: String) -> Dictionary:
	return { "score": score, "night": night, "seed": 1, "picks": [], "date": date, "char": "knight" }


static func _fresh():
	DirAccess.remove_absolute(FILE)
	return Records.new(FILE)


static func _order() -> Array:
	var out := []
	var r = _fresh()
	if r.add(_run(100, 2, "2026-01-01")) != 1:
		out.append("the first run is not first")
	if r.add(_run(300, 3, "2026-01-02")) != 1:
		out.append("a higher score does not go first")
	if r.add(_run(300, 4, "2026-01-03")) != 1:
		out.append("on a tie of score, the later night does not go first")
	if r.add(_run(300, 4, "2026-01-04")) != 2:
		out.append("an exact tie takes the place of the older run")
	if r.best() != 300:
		out.append("best is %d, not 300" % r.best())
	for i in 10:
		r.add(_run(1000 + i, 1, "2026-02-01"))
	if r.runs.size() != Records.KEEP:
		out.append("%d runs kept, not %d" % [r.runs.size(), Records.KEEP])
	if r.add(_run(5, 1, "2026-03-01")) != 0 or r.latest != null:
		out.append("a run below the list is given a place")
	if r.runs.size() != Records.KEEP:
		out.append("a run below the list grew it")
	for i in r.runs.size() - 1:
		if r.runs[i].score < r.runs[i + 1].score:
			out.append("the list is not best first")
			break
	return out


static func _once_per_run() -> Array:
	var out := []
	var r = _fresh()
	var w = World.new(1)
	for phase in ["pick", "night", "night", "dead", "dead", "dead", "pick", "night", "out", "out"]:
		w.phase = phase
		r.step(w, 7, "2026-01-01")
	if r.runs.size() != 2:
		out.append("two runs ended but %d were recorded" % r.runs.size())
	elif r.runs[0].seed != 7 or r.runs[0].night != w.night or r.runs[0].score != w.score:
		out.append("the recorded run is not the world's: %s" % r.runs[0])
	return out


static func _files() -> Array:
	var out := []
	var r = _fresh()
	r.add({ "score": 420, "night": 3, "seed": 9, "picks": ["spark", "dash"], "date": "2026-01-01 10:00:00", "char": "mage" })
	r.add(_run(90, 1, "2026-01-02"))
	var back = Records.new(FILE)
	if str(back.runs) != str(r.runs):
		out.append("the list read back is not the list saved: %s vs %s" % [back.runs, r.runs])
	for broken in ["", "not json {", "[1, 2]", "{\"version\": 99, \"runs\": []}", "{\"version\": 1, \"runs\": [{\"score\": \"x\"}]}",
			"{\"version\": \"2\", \"runs\": [{\"score\": 5, \"night\": 1}]}", "{\"version\": 1.5, \"runs\": [{\"score\": 5, \"night\": 1}]}",
			"{\"version\": null, \"runs\": [{\"score\": 5, \"night\": 1}]}"]:
		var f := FileAccess.open(FILE, FileAccess.WRITE)
		f.store_string(broken)
		f.close()
		if not Records.new(FILE).runs.is_empty():
			out.append("a broken file is not an empty list: %s" % broken)
	return out


## Each run keeps who kept the torch (a version 2 field): written from the world, read back as saved; a version 1 file
## (before characters) still loads, its runs the knight's; a character the game does not have, or none, reads as the
## knight. The last pick is remembered in its own file, and a missing or odd file is the knight.
static func _characters() -> Array:
	var out := []
	var r = _fresh()
	var w = World.new(1, "woodcutter")
	w.phase = "dead"
	r.step(w, 3, "2026-01-01")
	if r.runs.size() != 1 or r.runs[0].char != "woodcutter":
		out.append("a woodcutter's run is not recorded as the woodcutter's: %s" % [r.runs])
	if Records.new(FILE).runs[0].char != "woodcutter":
		out.append("the character is not read back as saved")
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"runs\": [{\"score\": 70, \"night\": 2, \"seed\": 4, \"picks\": [], \"date\": \"2026-01-01\"}]}")
	f.close()
	var old: Array = Records.new(FILE).runs
	if old.size() != 1 or old[0].score != 70 or old[0].char != "knight":
		out.append("a version 1 file does not load as the knight's runs: %s" % [old])
	for odd in ["\"dragon\"", "7", "null"]:
		f = FileAccess.open(FILE, FileAccess.WRITE)
		f.store_string("{\"version\": 2, \"runs\": [{\"score\": 70, \"night\": 2, \"char\": %s}]}" % odd)
		f.close()
		var got: Array = Records.new(FILE).runs
		if got.size() != 1 or got[0].char != "knight":
			out.append("a run whose character is %s does not read as the knight's: %s" % [odd, got])
	DirAccess.remove_absolute(CHARACTER_FILE)
	var c = Records.new(FILE, GUIDE_FILE, CHARACTER_FILE)
	if c.last_character() != "knight":
		out.append("with no file the last character is %s, not the knight" % c.last_character())
	c.remember_character("mage")
	if Records.new(FILE, GUIDE_FILE, CHARACTER_FILE).last_character() != "mage":
		out.append("the last character picked is not remembered")
	for text in ["{", "[]", "{\"char\": 3}", "{\"char\": \"dragon\"}"]:
		f = FileAccess.open(CHARACTER_FILE, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		if Records.new(FILE, GUIDE_FILE, CHARACTER_FILE).last_character() != "knight":
			out.append("a character file %s is not read as the knight" % text)
	return out


## The guide read once stays read, in its own file; missing, broken, other-version or odd files count as unread.
static func _guide() -> Array:
	var out := []
	DirAccess.remove_absolute(GUIDE_FILE)
	var r = Records.new(FILE, GUIDE_FILE)
	if r.guide_read():
		out.append("with no file the guide counts as read")
	r.read_guide()
	if not Records.new(FILE, GUIDE_FILE).guide_read():
		out.append("the guide read is not remembered")
	for text in ["{", "[]", "{\"version\": 2, \"read\": true}", "{\"version\": \"1\", \"read\": true}", "{\"version\": 1, \"read\": \"yes\"}"]:
		var f := FileAccess.open(GUIDE_FILE, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		if Records.new(FILE, GUIDE_FILE).guide_read():
			out.append("a guide file %s counts as read" % text)
	return out
