## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 264 with slot 1 (the knight) passes six dawns and is still standing on the seventh night when the run stops.
## Its nights from the second have the omens harvest, fog, harvest, dark_moon, still and dark_moon, and nine packs
## come, each warned of first. Both bosses come, each told ahead: the slime king on the third night, the shade lord
## (with its decoys) on the sixth. It takes the woodpile, the fire blade twice and the spark, then the guard (the
## knight's own) at the third dusk, which throws back what stands round it seven times; the big torch, the ember
## ring and the warm glow; with the spark and the fire blade held the beacon (a combined upgrade) at the fifth
## dusk, which fires 21 sparks of its own from then on, and with the ring and the glow scorch (combined) at the
## fifth midnight, whose slow burn finishes an enemy once; the thorns twice, the quick hands and the spark again.
## The keeper's four slots are full from the sixth night; the torch's end at five of six. It never rerolls (the bot
## does not). What a run does not meet (momentum, the rare cards, the other characters' rows, the other combined
## upgrades, a full torch side, fillers), the rules scenes hold.
const SEED := 264
const STEPS := 60 * 400
const PICK_SLOT := 1
