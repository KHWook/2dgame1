## Line rules over our own GDScript (src/ and tools/). Each rule id is explained in docs/PRINCIPLES.md.
## An exception needs "# check-ok: <reason>" at the end of that line; a bare "# check-ok" is not accepted.
extends RefCounted

const RULES := [
	{
		"id": "D1", "where": "^res://src/", "except": "^res://src/sim/rng\\.gd$",
		"re": "\\b(randf|randi|randf_range|randi_range|randfn|randomize|rand_from_seed)\\s*\\(|RandomNumberGenerator\\.new",
		"msg": "Randomness outside the seeded sim RNG.", "fix": "Use world.rng (src/sim/rng.gd).",
		"bad": "var r := randf()", "good": "var r: float = world.rng.next()",
	},
	{
		"id": "D2", "where": "^res://src/sim/", "except": "",
		"re": "\\b(Time\\.get_|OS\\.get_ticks|OS\\.get_unix)",
		"msg": "The simulation must not read the clock.", "fix": "Use Config.STEP and world.time.",
		"bad": "var t := Time.get_ticks_msec()", "good": "var t: float = world.time",
	},
	{
		"id": "D3", "where": "^res://src/sim/", "except": "",
		"re": "create_timer|Timer\\.new|\\bawait\\b",
		"msg": "No engine timers or await in the simulation.", "fix": "Use world.later(seconds, callable).",
		"bad": "await get_tree().create_timer(1.0).timeout", "good": "world.later(1.0, spawn.bind(\"slime\"))",
	},
	{
		"id": "S1", "where": "^res://src/sim/", "except": "",
		"re": "\\b(get_tree|get_node|get_viewport|Input\\.|extends\\s+Node)|\\$[A-Za-z\"]",
		"msg": "The simulation is pure data: no nodes, scene tree or engine input.",
		"fix": "Read input from the InputFrame passed to step(); let src/main.gd talk to the engine.",
		"bad": "if Input.is_action_pressed(\"jump\"):", "good": "if inp.is_pressed(\"jump\"):",
	},
	{
		"id": "C1", "where": "^res://src/", "except": "",
		"re": "\\b(draw_string|draw_char|draw_multiline_string)\\s*\\(",
		"msg": "Words are UI: don't draw text into the world.", "fix": "Use a Label or other Control node.",
		"bad": "draw_string(font, Vector2.ZERO, \"hi\")", "good": "hud.text = \"hi\"",
	},
	{
		"id": "C5", "where": "^res://(src|tools)/", "except": "^res://tools/checks\\.gd$",
		"re": "(?i)#.*\\b(hack|for now|workaround|kludge|temp fix)\\b",
		"msg": "A comment that excuses a shortcut.", "fix": "Fix the cause, or record the tradeoff in docs/DECISIONS.md and add a check.",
		"bad": "x += 1 # workaround for the jitter", "good": "x += 1",
	},
]

## File rule S1: every simulation file declares itself pure data.
const SIM_DIR := "res://src/sim/"
const SIM_EXTENDS := "extends RefCounted"


static func _compiled(rule: Dictionary) -> RegEx:
	var re := RegEx.new()
	re.compile(rule.re)
	return re


static func _applies(rule: Dictionary, path: String) -> bool:
	var where := RegEx.create_from_string(rule.where)
	if where.search(path) == null:
		return false
	return rule.except == "" or RegEx.create_from_string(rule.except).search(path) == null


static func scan(path: String, text: String) -> Array:
	var out := []
	var ok := RegEx.create_from_string("#\\s*check-ok:\\s*\\S")
	var lines := text.split("\n")
	for rule in RULES:
		if not _applies(rule, path):
			continue
		var re := _compiled(rule)
		for i in lines.size():
			if re.search(lines[i]) != null and ok.search(lines[i]) == null:
				out.append("%s:%d [%s] %s Fix: %s" % [path, i + 1, rule.id, rule.msg, rule.fix])
	if path.begins_with(SIM_DIR) and not text.contains(SIM_EXTENDS):
		out.append("%s:1 [S1] Simulation files must be pure data. Fix: start the file with \"%s\"." % [path, SIM_EXTENDS])
	return out


static func _files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out


static func run() -> Array:
	var out := []
	for path in _files("res://src") + _files("res://tools"):
		out.append_array(scan(path, FileAccess.get_file_as_string(path)))
		out.append_array(broken(path))
	return out


## Rule B1: every script of ours compiles. The replay loads only the simulation, so without this a script the
## replay never touches (src/main.gd, src/art/) could be broken and verify would still pass.
static func broken(path: String) -> Array:
	var script = ResourceLoader.load(path)
	if script != null and script.can_instantiate():
		return []
	return ["%s:1 [B1] The script does not compile. Fix: see Godot's parse error for this file in the output." % path]


## The checks check themselves (G4): each rule must catch its planted violation and pass its clean line.
static func selftest() -> Array:
	var fails := []
	for rule in RULES:
		var path: String = "res://src/sim/x.gd" if rule.where.begins_with("^res://src/sim/") or rule.where == "^res://src/" else "res://tools/x.gd"
		var head := SIM_EXTENDS + "\n" if path.begins_with(SIM_DIR) else ""
		if scan(path, head + rule.bad).filter(func(v): return v.contains("[%s]" % rule.id)).is_empty():
			fails.append("[%s] missed its planted violation: %s" % [rule.id, rule.bad])
		if not scan(path, head + rule.good).filter(func(v): return v.contains("[%s]" % rule.id)).is_empty():
			fails.append("[%s] flagged its clean line: %s" % [rule.id, rule.good])
		if not scan(path, head + rule.bad + " # check-ok: selftest").filter(func(v): return v.contains("[%s]" % rule.id)).is_empty():
			fails.append("[%s] ignored a check-ok with a reason" % rule.id)
		if scan(path, head + rule.bad + " # check-ok").filter(func(v): return v.contains("[%s]" % rule.id)).is_empty():
			fails.append("[%s] accepted a check-ok without a reason" % rule.id)
	if scan("res://src/sim/x.gd", "extends Object").filter(func(v): return v.contains("[S1]")).is_empty():
		fails.append("[S1] missed a sim file that is not RefCounted")
	return fails
