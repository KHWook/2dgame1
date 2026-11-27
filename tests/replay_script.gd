## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 21 with slot 1 passes six dawns and is still standing on the seventh night when the run stops. Its nights
## from the second have the omens harvest, fog, harvest, dark_moon, dew and wind, and nine packs come, each warned
## of first: bats, shades, slimes, thieves and boars. Both bosses come, each told ahead: the slime king on the third
## night, the shade lord (with its decoys) on the sixth. It takes the big torch twice, the dash, the dry logs twice,
## the thorn cloak, the wide swing twice, the slow burn, the spin, the bright fire, the warm glow and the woodpile
## twice: both rare cards, and by the end both sides' slots are full (six of the torch's, four of the keeper's), so
## its last offers hold only levels of what it has. It never rerolls (the bot does not). What a run does not meet,
## the rules scenes hold.
const SEED := 21
const STEPS := 60 * 400
const PICK_SLOT := 1
