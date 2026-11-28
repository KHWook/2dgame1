## The score records (src/records.gd) hold to what they claim: best first, only the top ten, one entry per run
## however long its ending lasts, the same list after a save and a load, and a broken file is an empty list; a save
## never leaves half a file, and says so when it cannot be made.
## Works on a file of its own under user://, never the player's.
extends RefCounted

const Records := preload("res://src/records.gd")
const World := preload("res://src/sim/world.gd")
const Config := preload("res://src/sim/config.gd")
const Bot := preload("res://src/bot.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

const FILE := "user://records_test.json"
const GUIDE_FILE := "user://guide_test.json"
const CHARACTER_FILE := "user://character_test.json"
const PART := "user://records_test.json.part" # Records.PART of FILE: where a save is written before it is whole


## Every failure as a message; empty when all hold.
static func run() -> Array:
	var out := []
	out.append_array(_order())
	out.append_array(_once_per_run())
	out.append_array(_files())
	out.append_array(_guide())
	out.append_array(_characters())
	out.append_array(_unlocks())
	out.append_array(_grandfather())
	out.append_array(_won())
	out.append_array(_never_lost())
	out.append_array(_unknown_kept())
	out.append_array(_whole_saves())
	out.append_array(_settings())
	out.append_array(_no_writes())
	_wipe()
	DirAccess.remove_absolute(GUIDE_FILE)
	DirAccess.remove_absolute(CHARACTER_FILE)
	return out


## Where a file that could not be read is set aside: the first name, the second.
static func _aside(n := 1) -> String:
	return Records.ASIDE % [FILE.get_basename(), "" if n == 1 else str(n), FILE.get_extension()]


## Removes the test's records file and everything set aside from it.
static func _wipe() -> void:
	DirAccess.remove_absolute(FILE)
	DirAccess.remove_absolute(PART)
	for n in range(1, 6):
		DirAccess.remove_absolute(_aside(n))


static func _put(text: String) -> void:
	_wipe()
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## The test's records file as it is on disk now ({} when it is not there or not a dictionary).
static func _on_disk() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	return data if typeof(data) == TYPE_DICTIONARY else {}


## A world that tells these events on a step, for a store to read.
static func _told(w, events: Array):
	w.events = events
	return w


## Characters open on a dawn: the knight from the start, the woodcutter on the first dawn that ends night 4 or a
## later one, the mage on night 7's, with anyone; each once, told to the screen (fresh) for that run only, and kept.
static func _unlocks() -> Array:
	var out := []
	if Config.UNLOCKS.opens != { "woodcutter": 4, "mage": 7 } or Records.starters() != ["knight"]:
		out.append("the rows are not the knight from the start, the woodcutter at dawn 4 and the mage at dawn 7: %s, %s" % [Records.starters(), Config.UNLOCKS.opens])
	var r = _fresh()
	var w = World.new(1)
	if r.opened != ["knight"] or r.is_open("woodcutter") or r.is_open("mage") or not r.is_open("knight"):
		out.append("a first play does not open the knight alone: %s" % [r.opened])
	for night in [1, 2, 3]:
		r.step(_told(w, [{ "kind": "dawn", "night": night }]), 1, "2026-01-01")
	if r.opened != ["knight"]:
		out.append("a dawn before night 4's opens someone: %s" % [r.opened])
	r.step(_told(w, [{ "kind": "dawn", "night": 4 }]), 1, "2026-01-01")
	if r.opened != ["knight", "woodcutter"] or r.fresh != ["woodcutter"]:
		out.append("the dawn that ends night 4 does not open the woodcutter (and only it): open %s, new %s" % [r.opened, r.fresh])
	if Records.new(FILE).opened != ["knight", "woodcutter"]:
		out.append("the woodcutter opened is not kept on disk: %s" % [Records.new(FILE).opened])
	for night in [5, 6]:
		r.step(_told(w, [{ "kind": "dawn", "night": night }]), 1, "2026-01-01")
	if r.opened != ["knight", "woodcutter"] or r.fresh != ["woodcutter"]:
		out.append("a dawn before night 7's opens the mage, or the woodcutter twice: open %s, new %s" % [r.opened, r.fresh])
	r.step(_told(w, [{ "kind": "dawn", "night": 7 }]), 1, "2026-01-01")
	if r.opened != ["knight", "woodcutter", "mage"] or r.fresh != ["woodcutter", "mage"] or Records.new(FILE).opened != r.opened:
		out.append("the dawn that ends night 7 does not open the mage and keep it: open %s, new %s" % [r.opened, r.fresh])
	w.phase = "dead"
	r.step(_told(w, []), 1, "2026-01-01")
	w.phase = "pick"
	r.step(_told(w, []), 1, "2026-01-01")
	if not r.fresh.is_empty():
		out.append("the next run still says what the last one opened: %s" % [r.fresh])
	r = _fresh()
	r.step(_told(World.new(1, "knight"), [{ "kind": "dawn", "night": 9 }]), 1, "2026-01-01")
	if r.opened != ["knight", "woodcutter", "mage"]:
		out.append("a first dawn seen past night 7 (a late start) does not open both: %s" % [r.opened])
	return out


## A player with any saved record from before characters could be locked (a version 1 or 2 file) has played them
## all: everyone is open, decided from that file once and stored (settle). With no record (no file, an empty one,
## an old one without runs) only the knight is. Once stored it is not decided again, whatever the runs say.
static func _grandfather() -> Array:
	var out := []
	var everyone: Array = Config.CHARACTERS.keys()
	var old := {
		"version 1 with a run": "{\"version\": 1, \"runs\": [{\"score\": 70, \"night\": 2, \"seed\": 4, \"picks\": [], \"date\": \"2026-01-01\"}]}",
		"version 2 with runs": "{\"version\": 2, \"runs\": [{\"score\": 70, \"night\": 2, \"seed\": 4, \"picks\": [\"spark\"], \"date\": \"2026-01-01\", \"char\": \"mage\"}, {\"score\": 5, \"night\": 1, \"char\": \"knight\"}]}",
	}
	for what in old:
		_put(old[what])
		var r = Records.new(FILE)
		if r.opened != everyone:
			out.append("a %s does not open everyone: %s" % [what, r.opened])
		var runs: Array = r.runs.duplicate(true)
		r.settle()
		var disk := _on_disk()
		if disk.get("version") != float(Records.VERSION) or disk.get("open") != everyone or disk.get("runs", []).size() != r.runs.size():
			out.append("a %s is not stored as this version with everyone open and its runs: %s" % [what, disk])
		var back = Records.new(FILE)
		if back.opened != everyone or back.runs != runs:
			out.append("a %s reads back otherwise once stored: open %s, runs %s (were %s)" % [what, back.opened, back.runs, runs])
	_wipe()
	var none = Records.new(FILE)
	none.settle()
	if none.opened != ["knight"] or FileAccess.file_exists(FILE):
		out.append("with no file the knight alone is not open, or a file was made before anything was earned: %s" % [none.opened])
	for empty in ["", "{\"version\": 2, \"runs\": []}", "{\"version\": 1, \"runs\": []}"]:
		_put(empty)
		var r = Records.new(FILE)
		r.settle()
		if r.opened != ["knight"] or Records.new(FILE).opened != ["knight"]:
			out.append("a file without a record (%s) opens more than the knight: %s" % [empty, r.opened])
	_put("{\"version\": 3, \"open\": [\"knight\"], \"runs\": [{\"score\": 70, \"night\": 2, \"char\": \"knight\"}]}")
	if Records.new(FILE).opened != ["knight"]:
		out.append("a file of this version with a run and only the knight open is decided again: %s" % [Records.new(FILE).opened])
	_put("{\"version\": 3, \"open\": [\"knight\", \"mage\", \"dragon\", 7], \"runs\": []}")
	if Records.new(FILE).opened != ["knight", "mage"]:
		out.append("the open list is not read as the characters it names: %s" % [Records.new(FILE).opened])
	_put("{\"version\": 3, \"open\": [\"mage\"], \"runs\": []}")
	if Records.new(FILE).opened != ["knight", "mage"]:
		out.append("the knight is not open whatever the file says: %s" % [Records.new(FILE).opened])
	return out


## A win is counted for its character on the step the world tells it, once, and kept; the run that won and then
## ended is recorded as won, once; a run left from the win box for a new one (close) is recorded as it stands, once;
## a run that never won is not marked. The first win opens the long night, and a run's mode is kept with it.
static func _won() -> Array:
	var out := []
	var r = _fresh()
	var w = World.new(142)
	w.goal = 1
	var bot = Bot.new(1)
	for s in 60 * 70:
		w.step(bot.frame(w))
		r.step(w, 142, "2026-01-01")
		if w.won:
			break
	if not w.won or r.wins != { "knight": 1 } or not r.runs.is_empty() or Records.new(FILE).wins != { "knight": 1 } or not r.long_open():
		out.append("the dawn that wins does not count one win for the knight, kept, with no run recorded yet and the long night open: won %s, wins %s, runs %s" % [w.won, r.wins, r.runs])
	for s in 30: # the player keeps going
		w.step(bot.frame(w))
		r.step(w, 142, "2026-01-01")
	w.fuel = 0.0
	w.phase = "night"
	for s in 5: # and the torch goes out
		w.step(InputFrame.new())
		r.step(w, 142, "2026-01-02")
	var back = Records.new(FILE)
	if w.phase != "out" or r.runs.size() != 1 or r.runs[0].get("won") != true or r.wins != { "knight": 1 } or back.runs.size() != 1 or back.runs[0].won != true or back.wins != { "knight": 1 }:
		out.append("a run that won, went on and ended is not one won run and one win: %s, runs %s, wins %s; on disk %s, %s" % [w.phase, r.runs, r.wins, back.runs, back.wins])
	r = _fresh()
	r.mode = "long"
	w = World.new(1, "mage")
	w.won = true
	w.score = 900
	r.step(_told(w, [{ "kind": "dawn", "night": 10 }, { "kind": "won", "night": 10 }]), 9, "2026-01-01")
	r.close(w, 9, "2026-01-01")
	r.close(w, 9, "2026-01-01")
	var fresh_world = World.new(2, "mage")
	for s in 3:
		r.step(_told(fresh_world, []), 2, "2026-01-01")
	back = Records.new(FILE)
	if r.runs.size() != 1 or r.runs[0].won != true or r.runs[0].score != 900 or r.runs[0].get("mode") != "long" or back.runs.size() != 1 or back.runs[0].get("mode") != "long" or back.wins != { "mage": 1 }:
		out.append("a won run left for a new one is not recorded once, as won, with its mode: %s; on disk %s, wins %s" % [r.runs, back.runs, back.wins])
	r = _fresh()
	w = World.new(1)
	w.phase = "dead"
	r.step(_told(w, []), 1, "2026-01-01")
	if r.runs[0].won != false or r.runs[0].has("mode") or Records.new(FILE).runs[0].won != false or r.long_open():
		out.append("a run that never won is marked as won, or as played some other way, or opens the long night: %s" % [r.runs])
	return out


## Nothing in a file is lost for not being understood. A file that cannot be read (broken, or of a later version) is
## set aside whole under another name before the first save, a second one under the next name. In a file that can,
## a runs entry that is no run, a key this version does not know and a run's unknown field are all still there after
## a save; a file of an older version keeps every run it had.
static func _never_lost() -> Array:
	var out := []
	var broken := ["not json { \"runs\": [1, 2, 3]", "{\"version\": 99, \"runs\": [{\"score\": 5, \"night\": 1}], \"later\": true}", "[1, 2]"]
	for i in broken.size():
		_put(broken[0])
		for n in i: # earlier asides are already there: the next name is used, none is written over
			var r = Records.new(FILE)
			r.add(_run(1, 1, "2026-01-01"))
			var f := FileAccess.open(FILE, FileAccess.WRITE)
			f.store_string(broken[n + 1])
			f.close()
		var r = Records.new(FILE)
		if not r.runs.is_empty():
			out.append("a file that cannot be read is not an empty list: %s" % broken[i])
		r.add(_run(300, 3, "2026-01-02"))
		var kept: Array = range(1, i + 2).map(func(n): return FileAccess.get_file_as_string(_aside(n)) if FileAccess.file_exists(_aside(n)) else "(none)")
		if kept != broken.slice(0, i + 1):
			out.append("%d unreadable files in a row are not each set aside whole before a save: %s" % [i + 1, kept])
		if Records.new(FILE).runs.size() != 1 or Records.new(FILE).runs[0].score != 300:
			out.append("after an unreadable file was set aside, the new run is not what the file holds: %s" % [Records.new(FILE).runs])
	_put("{\"version\": 2, \"note\": \"mine\", \"runs\": [{\"score\": 70, \"night\": 2, \"seed\": 4, \"picks\": [\"spark\"], \"date\": \"2026-01-01\", \"char\": \"mage\", \"extra\": 7}, {\"score\": \"x\", \"what\": \"not a run\"}, {\"score\": 50, \"night\": 1, \"char\": \"woodcutter\"}, 12]}")
	var r = Records.new(FILE)
	if r.runs.size() != 2:
		out.append("the two runs of a version 2 file with two odd entries are not read: %s" % [r.runs])
	r.add(_run(60, 1, "2026-01-03"))
	var disk := _on_disk()
	var runs: Array = disk.get("runs", [])
	var mage: Array = runs.filter(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("char") == "mage")
	if disk.get("note") != "mine" or disk.get("version") != float(Records.VERSION):
		out.append("a key this version does not know is lost on a save, or the version is not this one: %s" % [disk.keys()])
	if not runs.has(12.0) or runs.filter(func(e): return typeof(e) == TYPE_DICTIONARY and e.get("what") == "not a run").size() != 1:
		out.append("the entries that are no runs are lost on a save: %s" % [runs])
	if mage.size() != 1 or mage[0].get("extra") != 7.0 or mage[0].get("score") != 70.0 or mage[0].get("picks") != ["spark"] or mage[0].get("seed") != 4.0:
		out.append("a run of an older file, or its unknown field, is lost on a save: %s" % [mage])
	if runs.filter(func(e): return typeof(e) == TYPE_DICTIONARY and typeof(e.get("score")) == TYPE_FLOAT).size() != 3:
		out.append("the older file's two runs and the new one are not all on disk: %s" % [runs])
	var again = Records.new(FILE)
	again.add(_run(61, 1, "2026-01-04"))
	if _on_disk().get("runs", []).size() != 6 or FileAccess.file_exists(_aside()):
		out.append("a second save loses or doubles the entries that are no runs, or sets a readable file aside: %s" % [_on_disk().get("runs")])
	return out


## What a file names that this version does not have stays in it through a save: an entry of "open" or of "wins"
## that is no character here (or no count), and the keeper of a run, which is shown as the knight's and written back
## as it was read. What this version does know is read and counted as ever beside them.
static func _unknown_kept() -> Array:
	var out := []
	_put('{"version": 3, "runs": [{"score": 50, "night": 2, "char": "archer", "note": "hi", "won": true}, {"score": 40, "night": 1, "char": "mage"}], "open": ["knight", "archer", 7, "mage"], "wins": {"archer": 2, "mage": 1, "knight": "x"}}')
	var r = Records.new(FILE)
	if r.opened != ["knight", "mage"] or r.wins != { "mage": 1 } or r.runs.map(func(run): return run.char) != ["knight", "mage"]:
		out.append("a file naming a character this version does not have is not read as what it does have: open %s, wins %s, runs %s" % [r.opened, r.wins, r.runs])
	r.step(_told(World.new(1, "mage"), [{ "kind": "won", "night": 10 }]), 1, "2026-01-01")
	r.add(_run(60, 3, "2026-01-02"))
	for pass_ in 2: # after a save, and after a load and another save
		var disk := _on_disk()
		var runs: Array = disk.get("runs", [])
		if disk.get("open") != ["knight", "mage", "archer", 7.0]:
			out.append("an entry of open that is no character here is lost on save %d: %s" % [pass_ + 1, disk.get("open")])
		if disk.get("wins") != { "archer": 2.0, "mage": 2.0, "knight": "x" }:
			out.append("an entry of wins that is no character here, or no count, is lost on save %d (the mage's two are counted): %s" % [pass_ + 1, disk.get("wins")])
		if runs.map(func(run): return run.get("char")) != ["knight", "archer", "mage"] or runs[1].get("note") != "hi" or runs.any(func(run): return run.has(Records.AS_READ)):
			out.append("the run of a keeper this version does not have is not written back as it was read on save %d: %s" % [pass_ + 1, runs])
		r = Records.new(FILE)
		r.set_music(not r.music)
	return out


## A save never leaves half a file: it is written under another name beside the file and renamed over it, also where
## the file is already there. A part cut short beside a whole file is passed over and written over by the next save;
## with no file (the game stopped inside the rename) a whole part is read, and a half one is a first play. Where the
## part cannot be written, or a file that cannot be read cannot be set aside (every name taken), write says so and
## the file is byte for byte as it was.
static func _whole_saves() -> Array:
	var out := []
	var good := '{"version": 3, "runs": [], "open": ["knight", "mage"], "wins": {"mage": 2}, "music": true}'
	var put_part := func(text: String) -> void:
		var f := FileAccess.open(PART, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	for part in ["", good.substr(0, 40)]:
		_put(good)
		if part != "":
			put_part.call(part)
		var r = Records.new(FILE)
		if r.opened != ["knight", "mage"] or r.wins != { "mage": 2 }:
			out.append("a whole file beside %s is not what is read: open %s, wins %s" % ["half a part" if part != "" else "no part", r.opened, r.wins])
		r.set_music(false)
		if _on_disk().get("music") != false or _on_disk().get("wins") != { "mage": 2.0 } or FileAccess.file_exists(PART) or FileAccess.file_exists(_aside()):
			out.append("a save over a file that is there (beside %s) does not put the new one whole in its place and leave nothing else: %s" % ["half a part" if part != "" else "no part", _on_disk()])
	_wipe()
	put_part.call(good)
	var stopped = Records.new(FILE)
	if stopped.opened != ["knight", "mage"] or stopped.wins != { "mage": 2 }:
		out.append("with no file and a whole part beside it (a save stopped inside its rename), the part is not read: open %s, wins %s" % [stopped.opened, stopped.wins])
	stopped.set_music(false)
	if _on_disk().get("wins") != { "mage": 2.0 } or _on_disk().get("music") != false or FileAccess.file_exists(PART):
		out.append("the save after a part was read does not put the file in its place: %s" % [_on_disk()])
	_wipe()
	put_part.call(good.substr(0, 40))
	var first = Records.new(FILE)
	first.set_music(false)
	if first.opened != ["knight"] or not first.wins.is_empty() or _on_disk().get("music") != false or FileAccess.file_exists(PART) or FileAccess.file_exists(_aside()):
		out.append("with no file and half a part, the game does not start as a first play and save over the part: open %s, on disk %s" % [first.opened, _on_disk()])
	_put(good)
	DirAccess.make_dir_absolute(PART) # a folder of the part's name: the part cannot be written
	var blocked = Records.new(FILE)
	blocked.music = false
	var said: String = blocked.write()
	if said == "" or FileAccess.get_file_as_string(FILE) != good:
		out.append("a save whose part cannot be written does not say so (%s) and leave the file as it was: %s" % [said, FileAccess.get_file_as_string(FILE)])
	DirAccess.remove_absolute(PART)
	if blocked.write() != "" or _on_disk().get("music") != false:
		out.append("the save after one that could not be made is not made")
	_put("broken {")
	for n in range(1, Records.ASIDE_MOST + 1):
		FileAccess.open(_aside(n), FileAccess.WRITE).store_string("taken")
	var stuck = Records.new(FILE)
	stuck.music = false
	said = stuck.write()
	if said == "" or FileAccess.get_file_as_string(FILE) != "broken {" or FileAccess.file_exists(PART):
		out.append("a file that cannot be read or set aside is written over, or the save does not say that it was not made (%s)" % said)
	DirAccess.remove_absolute(_aside(40))
	if stuck.write() != "" or FileAccess.get_file_as_string(_aside(40)) != "broken {" or _on_disk().get("music") != false:
		out.append("once a name is free, the file that cannot be read is not set aside under it and the save made")
	for n in range(1, Records.ASIDE_MOST + 1):
		DirAccess.remove_absolute(_aside(n))
	return out


## The music setting is kept: on at first, off once turned off, on again once turned on; anything but false is on.
static func _settings() -> Array:
	var out := []
	var r = _fresh()
	if not r.music:
		out.append("the music is not on at first")
	r.set_music(false)
	if Records.new(FILE).music:
		out.append("the music turned off is on again after a restart")
	r = Records.new(FILE)
	r.add(_run(10, 1, "2026-01-01"))
	if Records.new(FILE).music or Records.new(FILE).runs.size() != 1:
		out.append("a run recorded turns the music back on, or is lost with the setting")
	r.set_music(true)
	if not Records.new(FILE).music:
		out.append("the music turned on again is off after a restart")
	for odd in ["\"no\"", "0", "null"]:
		_put("{\"version\": 3, \"runs\": [], \"music\": %s}" % odd)
		if not Records.new(FILE).music:
			out.append("a music setting of %s is read as off" % odd)
	return out


## A store told not to save (Main.keeps) writes nothing: no file where there
## was none, and a file there byte for byte as it was, whatever is recorded, opened, won, set or settled.
static func _no_writes() -> Array:
	var out := []
	for before in ["", "{\"version\": 2, \"runs\": [{\"score\": 70, \"night\": 2, \"char\": \"mage\"}]}", "broken {"]:
		_wipe()
		DirAccess.remove_absolute(GUIDE_FILE)
		DirAccess.remove_absolute(CHARACTER_FILE)
		if before != "":
			_put(before)
		var r = Records.new(FILE, GUIDE_FILE, CHARACTER_FILE)
		r.saves = false
		r.settle()
		var w = World.new(1)
		r.step(_told(w, [{ "kind": "dawn", "night": 7 }, { "kind": "won", "night": 7 }]), 1, "2026-01-01")
		w.phase = "dead"
		r.step(_told(w, []), 1, "2026-01-01")
		r.set_music(false)
		r.read_guide()
		r.remember_character("mage")
		if r.runs.is_empty() or r.opened.size() != 3 or r.music:
			out.append("a store that does not save does not keep in memory what happened")
		var now: String = FileAccess.get_file_as_string(FILE) if FileAccess.file_exists(FILE) else ""
		if now != before or FileAccess.file_exists(_aside()) or FileAccess.file_exists(GUIDE_FILE) or FileAccess.file_exists(CHARACTER_FILE):
			out.append("a store told not to save wrote to disk (the file was %s, is %s)" % [before, now])
	return out


static func _run(score: int, night: int, date: String) -> Dictionary:
	return { "score": score, "night": night, "seed": 1, "picks": [], "date": date, "char": "knight" }


static func _fresh():
	_wipe()
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
	var same: bool = back.runs.size() == r.runs.size()
	for i in back.runs.size() if same else 0: # a run saved without saying it won reads back as not won; the rest as saved
		var saved: Dictionary = r.runs[i].duplicate()
		saved["won"] = false
		same = same and back.runs[i] == saved
	if not same:
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
