## The play session the replay test runs: the bot (src/bot.gd) on a fixed seed for a fixed number of steps.
## Change the bot or these numbers to cover new mechanics, then re-record the golden on purpose:
## ./verify --update-golden (and add a docs/DECISIONS.md entry).
extends RefCounted

## Seed 142 with slot 1 (the knight) is still standing at the end of the eighth night, when the run stops (STEPS).
## Bosses: its order opens with the shade lord on the third night (stronger than another boss opening a run would
## be: BOSS.strength.opens; it splits off decoys) and brings the boar chief on the sixth (a set of charges, a winded
## stop, a log knocked out of the keeper's arms); both are told ahead.
## Kinds: all nine regular ones. Moths burn up in the flame, and a pack of them comes out one by one on the eighth
## night; spitters spit (a blob hurts the keeper); drummers beat and drive other enemies.
## Tiers: tier 2 from the fifth night (bats, big slimes, boars, drummers, moths, shades, slimes, thieves).
## Every night from the second has an omen and at least one pack, each pack warned of first.
## Upgrades: the guard (the knight's own; it throws enemies back), the rare dash, and scorch (combined, once the
## ember ring and the warm glow are held).
## Not met here, and held by the rules scenes: the slime king, tier 3, the other characters' rows, the other
## combined upgrades, fillers and rerolls (the bot never rerolls).
const SEED := 142
const STEPS := 60 * 480
const PICK_SLOT := 1
