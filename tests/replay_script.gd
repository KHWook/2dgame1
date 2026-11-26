## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 8 with slot 1 is still standing at the end of the sixth night, so it passes five dawns, meets every usual
## enemy kind and the first boss night: the slime king comes, calls slimes and is killed, big slimes split, thieves
## take logs, blows pass through shades in the dark, bats fly faster out of the light, berries are eaten. It takes
## upgrades to the second level (bright fire, spark, thorn cloak, warm glow) and uses bright fire's quicker steps in
## the light, the warm glow slowing bats in it, and the thorn cloak pricking. The ember ring and the big torch are not
## in this run; the rules scenes hold them.
const SEED := 8
const STEPS := 60 * 360
const PICK_SLOT := 1
