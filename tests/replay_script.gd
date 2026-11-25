## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 4 with slot 1 falls on the sixth night, so it passes five dawns and meets every enemy kind: big slimes
## split, thieves take logs, blows pass through shades in the dark, berries are eaten.
const SEED := 4
const STEPS := 60 * 360
const PICK_SLOT := 1
