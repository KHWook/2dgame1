## Done = this passes (G1): rule checks, the checks' own selftest, the sprite grids (A1), and the deterministic
## replay against the golden.
## Run through ./verify (or ./verify --check for the rules only, ./verify --update-golden to re-record on purpose).
extends SceneTree

const Checks := preload("res://tools/checks.gd")
const Replay := preload("res://tools/replay_test.gd")
const Balance := preload("res://tools/balance.gd")
const Sprites := preload("res://src/art/sprites.gd")
const Looks := preload("res://src/art/looks.gd")
const RulesTest := preload("res://tools/rules_test.gd")
const RecordsTest := preload("res://tools/records_test.gd")


## Hears every script error while verify runs (G5). A GDScript function that hits a runtime error stops and hands
## back an empty value: a scene that crashed returns [] and looks like a scene that holds. So an error counts as a
## failure here, whatever part of verify it happened in.
class ScriptErrors extends Logger:
	var seen: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_lock.lock()
		seen.append("%s:%d in %s(): %s" % [file, line, function, rationale if rationale != "" else code])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	var args := OS.get_cmdline_user_args()
	if args.has("--balance"):
		print(Balance.run())
		print("verify: PASS")
		quit(0)
		return
	var failed := false
	var v := Checks.run()
	for line in v:
		printerr(line)
	var self_fails := Checks.selftest()
	for line in self_fails:
		printerr("selftest: " + line)
	if v.is_empty() and self_fails.is_empty():
		print("check: all rules pass (selftest ok)")
	else:
		failed = true
	var art: Array = Sprites.problems() + Looks.problems() + Sprites.selftest()
	for line in art:
		printerr("art: " + line)
	if art.is_empty():
		print("art: %d sprites are well formed" % Sprites.names().size())
	else:
		failed = true
	var rules: Array = RulesTest.run()
	for line in rules:
		printerr("rules: " + line)
	if rules.is_empty():
		print("rules: every scene holds")
	else:
		failed = true
	var records: Array = RecordsTest.run()
	for line in records:
		printerr("records: " + line)
	if records.is_empty():
		print("records: kept best first, once per run, and read back as saved")
	else:
		failed = true
	if not args.has("--check"):
		var r := Replay.run(args.has("--update-golden"))
		if r[0]:
			print(r[1])
		else:
			printerr(r[1])
			failed = true
	OS.remove_logger(errors)
	for e in errors.seen:
		printerr("script error: " + e)
	if not errors.seen.is_empty():
		printerr("script: %d runtime error(s) above; the part that hit one stopped early, so its result does not count (G5). Make that code not error, do not catch it." % errors.seen.size())
		failed = true
	print("verify: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
