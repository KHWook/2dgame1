## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 12 with slot 1 passes six dawns and is still standing on the seventh night when the run stops. Its nights
## from the second have the omens harvest, still, dark_moon, still, dew and harvest, and nine packs come, each warned
## of first: bats, shades, slimes, thieves and boars. Both bosses come, each told ahead: the slime king on the third
## night, the shade lord (with its decoys) on the sixth. It takes the vampire blade, the spark twice, the thorn cloak
## twice, the warm glow, the dash twice, the bright fire twice, the wide swing, the slow burn, the spin and the fire
## blade. What a run does not meet, the rules scenes hold.
const SEED := 12
const STEPS := 60 * 400
const PICK_SLOT := 1
