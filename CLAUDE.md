# era-game

A small top-down night survival game: keep the torch burning night after night by hauling logs to it while fighting
what comes out of the dark. Each dawn starts a harder night with new enemies; at dusk and at midnight the torch
offers three random upgrades. Godot 4 (GDScript). The folder name is
left over from an earlier, larger concept (see `docs/DECISIONS.md`).

Rules are enforced by code, not by this file: `docs/PRINCIPLES.md` explains each rule id that `tools/checks.gd` and the
replay test report. Hooks run them for you (see `.claude/settings.json`).

- Done = `./verify` passes. Show the output, not a claim. `./verify --balance` shows which night the bot falls on over 20 seeds.
- A new enemy kind, upgrade or pickup: a row in `src/sim/config.gd`, its sprites (`<kind>_a`, `<kind>_b` or `icon_<id>`) in `src/art/sprites.gd`, and a scene in `tools/rules_test.gd` that shows the rule doing what it says.
- A change meant to alter gameplay: `./verify --update-golden`, then add an entry to `docs/DECISIONS.md`. Never make the golden match by editing it.
- A mistake that happened twice becomes a rule in `tools/checks.gd` (with the fix in its message and a `bad`/`good` selftest pair), not a new line here.
- Decisions and their reasons go in `docs/DECISIONS.md`, nowhere else.
- Run the game: `godot --path .` (editor: `godot -e --path .`; `-- --bot` lets the bot play, `-- --seed=N` picks the night, `-- --bot --skip=N` has the bot play N steps first, `-- --bot --slot=N` picks which offer it takes, `-- --night=N` starts at night N, `-- --crowd=K --perf` keeps K enemies on the field and prints the cost once a second). Look at visual changes before calling them done; `godot --path . --write-movie /tmp/f.png --fixed-fps 60 --quit-after 200` renders frames to check.
- Art is text: each sprite is a character grid in `src/art/sprites.gd` (one character = one pixel), and `src/art/painter.gd` decides what is painted where. After editing a sprite, look at it: `godot --headless --path . --script res://tools/art_sheet.gd -- /tmp/sprites.png`.

## pstack
pstack (`pstack@cursor-plugins`) is enabled for this project. Start rigorous work with `/pstack:poteto-mode`.
When pstack and `docs/PRINCIPLES.md` disagree, the checks in this repo win.
