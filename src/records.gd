## What is kept on disk between plays, in one file (user://records.json) with one writer (save): the best runs (the
## top KEEP by score, then by how many nights were reached), which characters are open, how often each has won, and
## whether the music plays.
## It reads files and is handed the date, so it lives outside src/sim/ (S1, D2): the simulation only keeps the score.
## main.gd calls step() after every world step: a run is written once, on the step its ending begins (or when the
## player leaves a won run for a new one: close), a character opens on the dawn its row names (Config.UNLOCKS) and a
## win is counted on the step the world tells it ("won").
## Nothing a file holds is ever dropped for not being understood: a file that cannot be read (broken, or written by a
## later version) is set aside under another name before the first save, and where it cannot be, nothing is saved and
## a warning says so; a run without a score stays in the file as it was, and so do every key and field this version
## does not know, the entries of "open" and "wins" that name no character of this version, and the "char" of a run
## whose keeper it does not have (shown as the knight's, written back as read).
## A save never leaves half a file: it is written whole under another name beside the file (PART) and then renamed
## over it. Where the rename is not one step (Godot on Windows removes the old file, then moves the new one), a game
## stopped between the two leaves only the whole new file under its other name, and _load reads that.
## Beside them, in a file of its own, whether the start screen's guide has been read (src/guide.gd): once it has, its
## start button shows on every page and the first night's coaching (src/coach.gd) is not shown again; and, in another,
## who kept the torch last (src/chooser.gd opens on that card).
extends RefCounted

const Config := preload("res://src/sim/config.gd")

const KEEP := 10 # runs kept on disk
const SHOWN := 5 # runs listed under an ending
## Bump when the file's shape changes. 1: runs only, before characters (every run the knight's). 2: each run names
## its character. 3: beside the runs, "open" (character ids), "wins" (per character), "music"; a run may say "won"
## and its "mode".
const VERSION := 3
const READS := [1, 2, 3]
const FILE := "user://records.json"
const ENDINGS := ["out", "dead"] # the world's phases that end a run
const GUIDE_FILE := "user://guide.json"
const GUIDE_VERSION := 1 # bump when the guide changes enough to be worth showing again: a file of another version is unread
const CHARACTER_FILE := "user://character.json"
const ASIDE := "%s.unread%s.%s" # where a file that could not be read goes: its name, a number from the second on, its extension
const ASIDE_MOST := 99
const PART := "%s.part" # a save's own name until it is whole: the file's, with this after it
const LONG := "long" # in fresh: the long night (Config.UNLOCKS.long), which a first win opens
const AS_READ := "char as read" # in a run in memory only: its "char" in the file, when that is no character here

var path: String
var guide_path: String
var character_path: String
var runs: Array = [] # best first: { "score", "night", "seed", "picks", "date", "char", "won", "mode" }
var opened: Array = [] # the characters that can be chosen
var wins := {} # character id -> runs won with it
var music := true
var mode := "" # set by main.gd when a run starts: "" as usual or "long", kept in its record
var fresh: Array = [] # what this run opened, for the screen to say so: character ids, and LONG; emptied when the next run starts
var place := 0 # where the run that just ended landed, from 1; 0 if it missed the list or none has ended
var latest = null # that run, so the list can mark it
var saves := true # false when Main.keeps says this run may not write: nothing is written
var _over := false # whether the run was already recorded on the last step
var _raw := {} # the file as it was read, so that what this version does not know is written back
var _odd: Array = [] # the entries of its runs that are not runs to this version, written back as they were
var _unread := false # the file is there but could not be read: it is set aside before the first save
var _odd_open: Array = [] # the entries of its "open" that are no character of this version, written back as they were


func _init(file: String = FILE, guide_file: String = GUIDE_FILE, character_file: String = CHARACTER_FILE) -> void:
	path = file
	guide_path = guide_file
	character_path = character_file
	_load()


## The characters open before anything has been earned: those Config.UNLOCKS.opens does not name.
static func starters() -> Array:
	return Config.CHARACTERS.keys().filter(func(id): return not Config.UNLOCKS.opens.has(id))


func is_open(id: String) -> bool:
	return opened.has(id)


## Whether the long night (Config.UNLOCKS.long) can be chosen: after a first win with anyone.
func long_open() -> bool:
	return wins.values().any(func(n): return n > 0)


## Who kept the torch last time ("knight" when nothing, or nothing sound, is on disk).
func last_character() -> String:
	if not FileAccess.file_exists(character_path):
		return "knight"
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(character_path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "knight"
	return character_id(json.data.get("char"))


## Remembers who keeps the torch now.
func remember_character(id: String) -> void:
	var f := FileAccess.open(character_path, FileAccess.WRITE) if saves else null
	if f != null:
		f.store_string(JSON.stringify({ "char": id }))


## A character id from a file: itself if it is one of Config.CHARACTERS, else the knight.
static func character_id(value) -> String:
	return value if typeof(value) == TYPE_STRING and Config.CHARACTERS.has(value) else "knight"


## Whether the guide has been read before. A missing, broken or other-version file is not read, never an error.
func guide_read() -> bool:
	if not FileAccess.file_exists(guide_path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(guide_path)) != OK:
		return false
	var data = json.data # a mismatched type compared with == is a script error, so each is compared by type first
	return typeof(data) == TYPE_DICTIONARY and is_same(data.get("version"), float(GUIDE_VERSION)) and is_same(data.get("read"), true)


## Remembers that the guide has been read.
func read_guide() -> void:
	var f := FileAccess.open(guide_path, FileAccess.WRITE) if saves else null
	if f != null:
		f.store_string(JSON.stringify({ "version": GUIDE_VERSION, "read": true }))


## Call after every world step. Opens what the step's dawn opens and counts its win; records the run the step it
## ends: an ending that lasts many steps is one run, and a new run arms it again.
func step(w, seed_value: int, date: String) -> void:
	var over: bool = ENDINGS.has(w.phase)
	if _over and not over:
		fresh = []
	var changed := false
	for ev in w.events:
		if ev.kind == "dawn":
			for id in Config.UNLOCKS.opens:
				if ev.night >= Config.UNLOCKS.opens[id] and not opened.has(id):
					opened.append(id)
					fresh.append(id)
					changed = true
		elif ev.kind == "won":
			if not long_open():
				fresh.append(LONG)
			wins[w.character] = wins.get(w.character, 0) + 1
			changed = true
	if over and not _over:
		add(_run(w, seed_value, date))
	elif changed:
		save()
	_over = over


## The player leaves a run that has not ended (from the win box, for a new one): it is recorded as it stands, once.
func close(w, seed_value: int, date: String) -> void:
	if not _over:
		add(_run(w, seed_value, date))
	_over = true


func _run(w, seed_value: int, date: String) -> Dictionary:
	var run := { "score": w.score, "night": w.night, "seed": seed_value, "picks": w.picks.duplicate(), "date": date, "char": w.character, "won": w.won }
	if mode != "":
		run["mode"] = mode
	return run


## Adds a finished run, keeps the best KEEP, saves them, and returns where the run landed (from 1; 0 if it missed).
func add(run: Dictionary) -> int:
	runs.append(run)
	runs.sort_custom(_better)
	place = 0
	latest = null
	for i in mini(runs.size(), KEEP):
		if is_same(runs[i], run):
			place = i + 1
			latest = run
	runs.resize(mini(runs.size(), KEEP))
	save()
	return place


## Stores what _load decided from a file of an older version (which characters are open), so that it is decided once.
## main.gd calls it when a person starts the game.
func settle() -> void:
	if not _raw.is_empty() and int(_raw.version) != VERSION:
		save()
		_raw["version"] = float(VERSION)


## Turns the music on or off, and remembers it.
func set_music(on: bool) -> void:
	music = on
	save()


## The best score so far, 0 when there is none.
func best() -> int:
	return runs[0].score if not runs.is_empty() else 0


## Higher score first; on a tie, the later night; then the older run, so a tie never takes a place from it.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	if a.night != b.night:
		return a.night > b.night
	return a.date < b.date


## Reads the file. A missing one is a first play: no runs, the starters open. One that cannot be read (broken, not
## this shape, a version this one does not read) is the same, and is marked to be set aside before anything is saved.
## A file from before characters could be locked (no "open" list: versions 1 and 2) opens every character if it
## holds a run, since its player has played them all already; the next save stores that.
## With no file but a save's part beside it (the game stopped inside a save's rename), the part is read: it is whole.
## A part that cannot be read was cut short while it was written: a first play, and the next save writes over it.
func _load() -> void:
	opened = starters()
	var from: String = path if FileAccess.file_exists(path) else PART % path
	if not FileAccess.file_exists(from):
		return
	var text := FileAccess.get_file_as_string(from)
	var json := JSON.new() # parse() reports a broken file by its return value; parse_string() also prints an error
	var data = json.data if json.parse(text) == OK else null
	# a mismatched type compared with == or != is a script error, so the type is checked first
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("version")) != TYPE_FLOAT or not READS.has(int(data.version)) \
			or float(int(data.version)) != data.version or typeof(data.get("runs")) != TYPE_ARRAY:
		_unread = from == path and text.strip_edges() != ""
		return
	_raw = data
	for r in data.runs:
		if typeof(r) != TYPE_DICTIONARY or typeof(r.get("score")) != TYPE_FLOAT or typeof(r.get("night")) != TYPE_FLOAT:
			_odd.append(r)
			continue
		var run: Dictionary = r.duplicate()
		run.merge({
			"score": int(r.score), "night": int(r.night), "seed": int(r.get("seed", 0)) if typeof(r.get("seed", 0)) == TYPE_FLOAT else 0,
			"picks": r.get("picks", []) if typeof(r.get("picks")) == TYPE_ARRAY else [], "date": str(r.get("date", "")),
			"char": character_id(r.get("char", "knight")), "won": is_same(r.get("won"), true),
		}, true)
		if r.has("char") and not is_same(r.char, run.char):
			run[AS_READ] = r.char
		runs.append(run)
	runs.sort_custom(_better)
	runs.resize(mini(runs.size(), KEEP))
	if typeof(data.get("open")) == TYPE_ARRAY:
		for id in data.open:
			if typeof(id) != TYPE_STRING or not Config.CHARACTERS.has(id):
				_odd_open.append(id)
			elif not opened.has(id):
				opened.append(id)
	elif not runs.is_empty():
		opened = Config.CHARACTERS.keys()
	if typeof(data.get("wins")) == TYPE_DICTIONARY:
		for id in data.wins:
			if Config.CHARACTERS.has(id) and typeof(data.wins[id]) == TYPE_FLOAT and data.wins[id] >= 1.0:
				wins[id] = int(data.wins[id])
	music = not is_same(data.get("music"), false)


## Saves everything kept (write), and warns when it could not be.
func save() -> void:
	var trouble := write()
	if trouble != "":
		push_warning(trouble)


## Writes everything kept, in this version's shape, over what the file held that this version does not know. A file
## that could not be read is first moved to a name of its own (ASIDE), so nothing in it is lost. The new file is
## written whole beside the old one (PART) and renamed over it, so the old one is there until the new one is whole.
## Returns what went wrong, "" when it is written (or this store does not save).
func write() -> String:
	if not saves:
		return ""
	if _unread:
		var trouble := _set_aside()
		if trouble != "":
			return trouble
		_unread = false
	var all_wins: Dictionary = _raw.wins.duplicate() if typeof(_raw.get("wins")) == TYPE_DICTIONARY else {}
	all_wins.merge(wins, true)
	var data: Dictionary = _raw.duplicate()
	data.merge({ "version": VERSION, "runs": runs.map(_as_read) + _odd, "open": opened + _odd_open, "wins": all_wins, "music": music }, true)
	var part := PART % path
	var f := FileAccess.open(part, FileAccess.WRITE)
	if f == null:
		return "records: %s cannot be written (error %d): nothing is saved, and %s is as it was" % [part, FileAccess.get_open_error(), path]
	var whole := f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if not whole:
		return "records: %s was not written whole: nothing is saved, and %s is as it was" % [part, path]
	var moved := DirAccess.rename_absolute(part, path)
	return "" if moved == OK else "records: %s could not be renamed to %s (error %d): the save is in the first, and is read from there while the second is missing" % [part, path, moved]


## Moves the file that could not be read to the first name of its own that is free. Returns what went wrong: then it
## is still where it was, and must not be written over.
func _set_aside() -> String:
	for i in range(1, ASIDE_MOST + 1):
		var aside := ASIDE % [path.get_basename(), "" if i == 1 else str(i), path.get_extension()]
		if not FileAccess.file_exists(aside):
			var moved := DirAccess.rename_absolute(path, aside)
			return "" if moved == OK else "records: %s cannot be read and could not be set aside as %s (error %d): nothing is saved, so that it is not written over" % [path, aside, moved]
	return "records: %s cannot be read and every name to set it aside under is taken (%d of them): nothing is saved, so that it is not written over" % [path, ASIDE_MOST]


## A run as it is written: as in memory, but for a keeper this version does not have, which is written back as read.
static func _as_read(run: Dictionary) -> Dictionary:
	if not run.has(AS_READ):
		return run
	var out := run.duplicate()
	out["char"] = out[AS_READ]
	out.erase(AS_READ)
	return out
