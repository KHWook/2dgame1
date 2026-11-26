## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 14 with slot 1 passes six dawns and falls on the seventh night (the keeper dies). On the way it meets every
## usual enemy kind: the slime king's coming is told ahead, it comes, leaps (the bot steps out of the marked landing)
## and is killed; from the sixth night boars line up, paw and charge 13 times (the bot steps out of every lane) and
## five are cut down while dazed; big slimes split, thieves take logs, blows pass through shades in the dark, bats fly
## faster out of the light, berries are eaten, logs come faster as the fire burns faster. It takes the ember ring to
## its third level, bright fire, big torch and slow burn to the second, the spark, spin, thorn cloak, dry logs and
## the dash. The shade lord, the warm glow and the vampire blade are not in this run; the rules scenes hold them.
const SEED := 14
const STEPS := 60 * 400
const PICK_SLOT := 1
