## The score records (src/records.gd) hold to what they claim: best first, only the top ten, one entry per run
## however long its ending lasts, the same list after a save and a load, and a broken file is an empty list.
## Works on a file of its own under user://, never the player's.
extends RefCounted

const Records := preload("res://src/records.gd")
const World := preload("res://src/sim/world.gd")

const FILE := "user://records_test.json"
const GUIDE_FILE := "user://guide_test.json"


## Every failure as a message; empty when all hold.
static func run() -> Array:
	var out := []
	out.append_array(_order())
	out.append_array(_once_per_run())
	out.append_array(_files())
	out.append_array(_guide())
	DirAccess.remove_absolute(FILE)
	DirAccess.remove_absolute(GUIDE_FILE)
	return out


static func _run(score: int, night: int, date: String) -> Dictionary:
	return { "score": score, "night": night, "seed": 1, "picks": [], "date": date }


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
	r.add({ "score": 420, "night": 3, "seed": 9, "picks": ["spark", "dash"], "date": "2026-01-01 10:00:00" })
	r.add(_run(90, 1, "2026-01-02"))
	var back = Records.new(FILE)
	if str(back.runs) != str(r.runs):
		out.append("the list read back is not the list saved: %s vs %s" % [back.runs, r.runs])
	for broken in ["", "not json {", "[1, 2]", "{\"version\": 99, \"runs\": []}", "{\"version\": 1, \"runs\": [{\"score\": \"x\"}]}"]:
		var f := FileAccess.open(FILE, FileAccess.WRITE)
		f.store_string(broken)
		f.close()
		if not Records.new(FILE).runs.is_empty():
			out.append("a broken file is not an empty list: %s" % broken)
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
