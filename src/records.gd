## The best runs, kept on disk between plays: the top KEEP by score, then by how many nights were reached.
## It reads files and is handed the date, so it lives outside src/sim/ (S1, D2): the simulation only keeps the score.
## main.gd calls step() after every world step; a run is written once, on the step its ending begins.
extends RefCounted

const KEEP := 10 # runs kept on disk
const SHOWN := 5 # runs listed under an ending
const VERSION := 1 # bump when a run's fields change; a file of another version starts a fresh list
const FILE := "user://records.json"
const ENDINGS := ["out", "dead"] # the world's phases that end a run

var path: String
var runs: Array = [] # best first: { "score", "night", "seed", "picks", "date" }
var place := 0 # where the run that just ended landed, from 1; 0 if it missed the list or none has ended
var latest = null # that run, so the list can mark it
var _over := false # whether the world was already in an ending on the last step


func _init(file: String = FILE) -> void:
	path = file
	runs = read(path)


## Call after every world step. Records the run the step it ends; an ending that lasts many steps is one run, and R
## starting a new run arms it again.
func step(w, seed_value: int, date: String) -> void:
	var over: bool = ENDINGS.has(w.phase)
	if over and not _over:
		add({ "score": w.score, "night": w.night, "seed": seed_value, "picks": w.picks.duplicate(), "date": date })
	_over = over


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
	write(path, runs)
	return place


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


## The runs in a file, best first. A missing, broken or other-version file is an empty list, never an error.
static func read(file: String) -> Array:
	if not FileAccess.file_exists(file):
		return []
	var json := JSON.new() # parse() reports a broken file by its return value; parse_string() also prints an error
	if json.parse(FileAccess.get_file_as_string(file)) != OK:
		return []
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or data.get("version") != float(VERSION) or typeof(data.get("runs")) != TYPE_ARRAY:
		return []
	var out := []
	for r in data.runs:
		if typeof(r) != TYPE_DICTIONARY or typeof(r.get("score")) != TYPE_FLOAT or typeof(r.get("night")) != TYPE_FLOAT:
			continue
		out.append({
			"score": int(r.score), "night": int(r.night), "seed": int(r.get("seed", 0)),
			"picks": r.get("picks", []) if typeof(r.get("picks")) == TYPE_ARRAY else [], "date": str(r.get("date", "")),
		})
	out.sort_custom(_better)
	out.resize(mini(out.size(), KEEP))
	return out


static func write(file: String, list: Array) -> void:
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({ "version": VERSION, "runs": list }, "\t"))
