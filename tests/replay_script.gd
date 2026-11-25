## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 2 with slot 1 falls on the sixth night, so it passes five dawns, meets every usual enemy kind and the first
## boss night: the slime king comes, calls slimes and is killed, big slimes split, thieves take logs, blows pass
## through shades in the dark, berries are eaten. It takes upgrades to the third level (spark) and uses the dash
## and the vampire blade.
const SEED := 2
const STEPS := 60 * 360
const PICK_SLOT := 1
