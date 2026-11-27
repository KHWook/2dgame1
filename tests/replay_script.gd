## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 17 with slot 1 (the knight) passes seven dawns and is still standing at the end of the eighth night when the
## run stops. Its nights from the second have the omens harvest, sultry, dark_moon, harvest, still, harvest and
## dark_moon, and thirteen packs come, each warned of first (the third night's, under the sultry omen, is four moths).
## Its boss order is the boar chief, the shade lord, the slime king, so two bosses come, each told ahead: the chief on
## the third night (it runs its sets of charges, stands winded twice and once knocks a log out of the keeper's arms)
## and the shade lord (with its decoys) on the sixth. Of the kinds new with the chief it meets all three: thirteen
## moths burn up in the flame, spitters spit eighteen blobs (two hurt the keeper, two are burst by its blows), and
## drummers beat 273 times and drive 21 enemies. Stronger tiers come from the fifth night: tier 2 bats, boars, moths,
## shades, slimes and thieves. It takes the woodpile twice, momentum (the knight's own) and the sturdy body, the warm
## glow, the big torch twice, the bright fire, the quick hands, the ember ring, momentum again and the spin; with the
## big logs and the woodpile held, blast (a combined upgrade) at the seventh midnight, which throws enemies back from
## the fed fire 33 times, and with the ring and the glow scorch (combined) at the eighth dusk. It never rerolls (the
## bot does not). What a run does not meet (the slime king, tier 3, the guard, the rare dash, the other characters'
## rows, the other combined upgrades, fillers), the rules scenes hold.
const SEED := 17
const STEPS := 60 * 480
const PICK_SLOT := 1
