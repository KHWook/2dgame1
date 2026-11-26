## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 12 with slot 1 passes six dawns and is still standing on the seventh night when the run stops. On the way it
## meets every usual enemy kind: the slime king's coming is told ahead, it comes, leaps (the bot steps out of the
## marked landing) and is killed; from the sixth night boars line up, paw and charge 15 times (the bot steps out of
## every lane) and five are cut down; big slimes split, thieves take logs, blows pass through shades in the dark,
## bats fly faster out of the light, berries are eaten, logs come faster as the fire burns faster. It takes the
## sword's upgrades (the long blade and the woodpile to their second level, the wide swing, the fire blade, the
## vampire blade), the spark twice, the ember ring, the warm glow, quick hands, dry logs and the dash. The shade lord,
## the spin and the thorn cloak are not in this run; the rules scenes hold them.
const SEED := 12
const STEPS := 60 * 400
const PICK_SLOT := 1
