## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 237 with slot 1 (the knight) passes six dawns and is still standing on the seventh night when the run stops.
## Its nights from the second have the omens still, harvest, still, dark_moon, wind and fog, and nine packs come,
## each warned of first: slimes, bats, thieves and shades. Both bosses come, each told ahead: the slime king on the
## third night, the shade lord (with its decoys) on the sixth. It takes momentum (the knight's own) as its first
## card, so most of the run is walked and swung in a kill's haste; the warm glow and the ember ring, and with both
## held scorch (a combined upgrade) at the third dusk, so the ring kills from then on; the spin twice and the dash
## (both rare cards); the bright fire, the wide swing twice, the woodpile and the dry logs, and with those two the
## blast (combined) at the seventh midnight, which throws the enemies back from the torch twice before the run
## stops. The keeper's four slots are full from the fourth night; the torch's end at five of six. It never rerolls
## (the bot does not). What a run does not meet (the guard, the other characters' rows, the other combined
## upgrades, fillers), the rules scenes hold.
const SEED := 237
const STEPS := 60 * 400
const PICK_SLOT := 1
