## Every picture in the game, drawn as text: one character is one pixel and PALETTE says which colour it is.
## To change a sprite, edit its grid. ./verify rejects a ragged row or a character that is not in PALETTE (A1),
## and tools/art_sheet.gd saves all of them enlarged as one PNG to look at.
extends RefCounted

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"_": Color(0.05, 0.04, 0.09, 0.4), # ground shadow
	"k": Color("#1a1423"), "K": Color("#3a3350"), # outline, dark slate
	"w": Color("#e6dcc6"), "c": Color("#c4b498"), "d": Color("#8f7f72"), # the keeper's cloak
	"r": Color("#e0503f"), "R": Color("#a22f3a"), # scarf
	"s": Color("#f6c198"), "S": Color("#d0906c"), # skin
	"b": Color("#80522f"), "B": Color("#573620"), # boots
	"o": Color("#b0733f"), "O": Color("#855030"), "n": Color("#5a3621"), "y": Color("#ebc288"), # wood
	"f": Color("#fff6c0"), "F": Color("#ffc94a"), "x": Color("#f58230"), "X": Color("#c8432b"), # fire
	"h": Color("#d6f79a"), "g": Color("#9fdc55"), "G": Color("#66b03c"), "j": Color("#387a3a"), # slime
	"p": Color("#c07ee0"), "P": Color("#8a4fbd"), "q": Color("#55307f"), "e": Color("#ffe04a"), # bat
	"2": Color("#3f6644"), "3": Color("#223a2c"), "4": Color("#5a8a4c"), # grass blades
	"m": Color("#7a6650"), "M": Color("#5a4a3b"), "N": Color("#40342b"), # dirt
	"t": Color("#a3a6ae"), "T": Color("#6b6e7c"), "z": Color("#454759"), # stone
	"u": Color("#18281f"), "U": Color("#213a2a"), "v": Color("#2f5236"), # treetops
	"W": Color("#ffffff"), "Y": Color("#ffd84a"), # white, yellow
	"a": Color("#eef3f6"), "A": Color("#a9b6c4"), "Z": Color("#66708a"), # steel
	"i": Color("#ef4b5a"), "I": Color("#a82a45"), # hearts
	"l": Color("#b5e3ff"), "L": Color("#4a9be8"), # a cool flame for the slow burn icon; the shade's eyes
	"7": Color("#6f67a8"), "8": Color("#4a4378"), "9": Color("#241f3d"), # shade
	"1": Color("#e8934e"), "5": Color("#b35a2e"), "6": Color("#6e3222"), # the keeper's hair
	"C": Color("#86b6f2"), "D": Color("#4f84d8"), "E": Color("#2f4f98"), # the keeper's tunic
	"0": Color("#f4978e"), # the keeper's blush
	"Q": Color("#8a2f4a"), "V": Color("#55203a"), # the ember mage's robe
}

const SPRITES := {
	"keeper_down_a": [
		"........kk......",
		"....kkkkk1kk....",
		"...k11155111k...",
		"..k1155555115k..",
		"..k5555555555k..",
		"..k55s5ss5s55k..",
		"..k5ssssssss5k..",
		"..k5sWkssWks5k..",
		"..k50kksskk05k..",
		"...kSssssssSk...",
		"....krrRRrrk....",
		"...kDCDRDDCDk...",
		"...ksbbYbbbsk...",
		"....kEDDDDEk....",
		"....kBBkkBBk....",
		".....kk..kk.....",
	],
	"keeper_up_a": [
		"........kk......",
		"....kkkkk1kk....",
		"...k11155111k...",
		"..k1155555115k..",
		"..k5555555555k..",
		"..k5655565565k..",
		"..k5655565565k..",
		"..k6655665566k..",
		"..k6566566656k..",
		"...k6k66k66kk...",
		"....krrrrrrk....",
		"...kDwwRwwwDk...",
		"...kswwRwwwsk...",
		"....kcwwwwck....",
		"....kBBkkBBk....",
		".....kk..kk.....",
	],
	"keeper_side_a": [
		".......kk.......",
		"....kkkk1kk.....",
		"...k1115511k....",
		"..k1155555511k..",
		"..k5555555555k..",
		"..k55555s5ss5k..",
		"..k66555sssssk..",
		"..k6655sssWksk..",
		"..k6655s0skksk..",
		"...k665sssssk...",
		"...kRkrrrrk.....",
		"..kRk.kDDCDk....",
		"..kk..kbDbbk....",
		"......kEsEEk....",
		"......kBkkBk....",
		".......k..k.....",
	],
	"keeper_dead": [
		"................",
		"................",
		"................",
		"...kkkk.........",
		"..k1155kk.......",
		".k155555skkkkk..",
		".k15ssskkDDDDDkk",
		"k155s0ssrDCDDbBk",
		"k155ssssrDDDEbBk",
		".k15ssskkDDDDDkk",
		".k155555skkkkk..",
		"..k1155kk.......",
		"...kkkk.........",
		"................",
		"................",
		"................",
	],
	"woodcutter_down_a": [
		"......kkkk......",
		".....kwwwwk.....",
		"...kkkGGGGkkk...",
		"..kGGgGGgGGgGk..",
		"..kGgGGgGGgGGk..",
		"..kjjjjjjjjjjk..",
		"..k5ssssssss5k..",
		"..k5sWkssWks5k..",
		"..k60kksskk06k..",
		"...k66555566k...",
		"....kk6556kk....",
		"...krRrRRrRrk...",
		"...ksnnYnnnsk...",
		"....kEDDDDEk....",
		"....kBBkkBBk....",
		".....kk..kk.....",
	],
	"woodcutter_up_a": [
		"......kkkk......",
		".....kwwwwk.....",
		"...kkkGGGGkkk...",
		"..kGGgGGgGGgGk..",
		"..kGgGGgGGgGGk..",
		"..kjjjjjjjjjjk..",
		"..k5565565565k..",
		"..k6655665566k..",
		"..k6566566656k..",
		"...k6k66k66kk...",
		"....krRrRrRk....",
		"...krRrRRrRrk...",
		"...ksrRrRRrsk...",
		"....kEDDDDEk....",
		"....kBBkkBBk....",
		".....kk..kk.....",
	],
	"woodcutter_side_a": [
		"......kkk.......",
		".....kwwwk......",
		"...kkkGGGkkk....",
		"..kGGgGGgGGgk...",
		"..kGgGGgGGgGGk..",
		"..kjjjjjjjjjjk..",
		"..k6655ssssssk..",
		"..k6655sssWksk..",
		"..k6655s0skksk..",
		"...k66566666k...",
		"....kk6666k.....",
		"......krRrRk....",
		"......knYnnk....",
		"......kEsEEk....",
		"......kBkkBk....",
		".......k..k.....",
	],
	"woodcutter_dead": [
		"................",
		"................",
		"................",
		"...kkkk.........",
		"..kGGjjkk.......",
		".kGgGjj5skkkkk..",
		".kGjss66krRrRrkk",
		"kGgjs0s66RrRrnBk",
		"kGgjssss6rRrRnBk",
		".kGjss66krRrRrkk",
		".kGgGjj5skkkkk..",
		"..kGGjjkk.......",
		"...kkkk.........",
		"................",
		"................",
		"................",
	],
	"mage_down_a": [
		".......kk.......",
		"......kQQk......",
		".....kQQQQk.....",
		"....kQQYQQQk....",
		"..kkQQQQQQQQkk..",
		"..kQQVVVVVVQQk..",
		"..kQVssssssVQk..",
		"..kQsWkssWksQk..",
		"..kQ0kksskk0Qk..",
		"...kQssssssQk...",
		"....kQQYYQQk....",
		"...kQQQYQQQQk...",
		"...ksVQYQQVxk...",
		"...kQQQYQQQQk...",
		"...kVVVVVVVVk...",
		"....kBk..kBk....",
	],
	"mage_up_a": [
		".......kk.......",
		"......kQQk......",
		".....kQQQQk.....",
		"....kQQQQQQk....",
		"..kkQQQQQQQQkk..",
		"..kQQQQVQQQQQk..",
		"..kQQQVQQQQVQk..",
		"..kQQQVQQQQVQk..",
		"..kVQQVQQQQVQk..",
		"...kVQQQQQQVk...",
		"....kVQQQQVk....",
		"...kQQQQQQQQk...",
		"...kxQQQQQQsk...",
		"...kQQQQQQQQk...",
		"...kVVVVVVVVk...",
		"....kBk..kBk....",
	],
	"mage_side_a": [
		"......kk........",
		".....kQQk.......",
		"....kQQQQk......",
		"...kQQQYQQk.....",
		"..kkQQQQQQQk....",
		"..kQQQQQVVVVk...",
		"..kQQQVssssssk..",
		"..kQQQVsssWksk..",
		"..kQQQVs0skksk..",
		"...kQQVsssssk...",
		"....kQQYYQk.....",
		"....kQQQQYQk....",
		"....kQQQQsxk....",
		"...kQQQQQQQk....",
		"...kVVVVVVVk....",
		".....kBk.kBk....",
	],
	"mage_dead": [
		"................",
		"................",
		"................",
		"...kkkk.........",
		"..kQQQVkk.......",
		".kQQVsssVkkkkk..",
		".kQVssskkQQQQQkk",
		"kQQVs0ssYQQYQVBk",
		"kQQVssssYQQYQVBk",
		".kQVssskkQQQQQkk",
		".kQQVsssVkkkkk..",
		"..kQQQVkk.......",
		"...kkkk.........",
		"................",
		"................",
		"................",
	],
	"axe": [
		"...........kk...",
		"..........kaak..",
		".kk......kAAaak.",
		"ksskOoooOoAAaak.",
		".kk......kZAak..",
		"..........kkk...",
	],
	"axe_fire": [
		"...........kk...",
		"..........kffk..",
		".kk......kFFffk.",
		"ksskOoooOoFFffk.",
		".kk......kxFfk..",
		"..........kkk...",
	],
	"axe_long": [
		".................kk...",
		"................kaak..",
		".kk.............kAAak.",
		"ksskOooooooooOoAAaak..",
		".kk............kZAak..",
		"................kkk...",
	],
	"axe_long_fire": [
		".................kk...",
		"................kffk..",
		".kk.............kFFfk.",
		"ksskOooooooooOoFFffk..",
		".kk............kxFfk..",
		"................kkk...",
	],
	"bolt": [
		".F.",
		"FWF",
		".F.",
	],
	# the ember's core flickers through bolt, bolt_b, bolt_c (painter.gd's BOLT_CORES)
	"bolt_b": [
		"xFx",
		"FfF",
		"xFx",
	],
	"bolt_c": [
		".f.",
		"fWf",
		".f.",
	],
	# where a keeper's own blow lands (effects.gd's STRIKES): the knight's sword rings, the woodcutter's axe bites
	# chips out, the mage's ember pops; an ember that flies its whole range fizzles out
	"clang_a": [
		"..W..",
		"..a..",
		"WaWaW",
		"..a..",
		"..W..",
	],
	"clang_b": [
		"A...A",
		".a.a.",
		"..W..",
		".a.a.",
		"A...A",
	],
	"chop_a": [
		"...W...",
		".W.a.W.",
		"..aWa..",
		"WaWWWaW",
		"..aWa..",
		".W.a.W.",
		"...W...",
	],
	"chop_b": [
		"A..y..A",
		"...o...",
		"..o.o..",
		"yo...oy",
		"..o.o..",
		"...o...",
		"A..y..A",
	],
	"pop_a": [
		".......",
		"...F...",
		"..FfF..",
		".FfWfF.",
		"..FfF..",
		"...F...",
		".......",
	],
	"pop_b": [
		"...x...",
		".x.F.x.",
		"..F.F..",
		"xF.f.Fx",
		"..F.F..",
		".x.F.x.",
		"...x...",
	],
	"pop_c": [
		"X..X..X",
		".......",
		".......",
		"X.....X",
		".......",
		".......",
		"X..X..X",
	],
	"fizzle_a": [
		".....",
		"..x..",
		".xFx.",
		"..x..",
		".....",
	],
	"fizzle_b": [
		"..K..",
		".X.X.",
		"K.x.K",
		".X.X.",
		"..K..",
	],
	"fizzle_c": [
		".K.K.",
		".....",
		"K...K",
		".....",
		".K.K.",
	],
	"icon_long_blade_mage": [
		"......xFx",
		".....xFfF",
		"....x.xFx",
		"...x.....",
		"..x......",
		".x.......",
		"x........",
		".........",
		"YYYYYYYYY",
	],
	"icon_wide_swing_mage": [
		"...xxx...",
		"..xFFFx..",
		".xFfffFx.",
		".xFfWfFx.",
		".xFfffFx.",
		"..xFFFx..",
		"...xxx...",
		".........",
		".........",
	],
	"icon_swift_mage": [
		".........",
		"......xx.",
		"LL...xFFx",
		".....FfWF",
		"LLL..FffF",
		".....xFFx",
		"LL....xx.",
		".........",
		".........",
	],
	"icon_spin_mage": [
		"x...x...x",
		".x..x..x.",
		"..x.x.x..",
		"...xxx...",
		"....F....",
		"...FfF...",
		"...fWf...",
		"....Q....",
		"....Q....",
	],
	"thorns_down": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		".cPqqqqqqqqqqPc.",
		"ckPqqqqqqqqqqPkc",
		".kPqqqqqqqqqqPk.",
		"ckPPqqqqqqqqPPkc",
		".kkqkkqkkqkkqkk.",
	],
	"thorns_up": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"..ckPqqqqqqPkc..",
		"...kPqqcqqqPk...",
		"..ckPqqqqcqPkc..",
		"...kPqcqqqqPk...",
		"..ckqkqkkqkqkc..",
		"....c..cc..c....",
	],
	"thorns_side": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"....kkk.........",
		"..ckqqk.........",
		".ckPqqk.........",
		"ckPqqqk.........",
		".kPqqqk.........",
		"..kqkqk.........",
	],
	"slime_a": [
		"................",
		"................",
		"................",
		"................",
		".....kkkkkk.....",
		"...kkggggggkk...",
		"..kgghhggggggk..",
		"..kghhgggggggk..",
		".kggggggggggggk.",
		".kggWkggggWkggk.",
		".kggkkggggkkggk.",
		".kgggggggggggGk.",
		".kGggggggggGGGk.",
		"..kGGGGGGGGGGk..",
		"...kkkkkkkkkk...",
		"................",
	],
	"slime_b": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"....kkkkkkkk....",
		"..kkghhgggggkk..",
		".kgghhggggggggk.",
		"kggggggggggggggk",
		"kgggWkggggWkgggk",
		"kgggkkggggkkgggk",
		"kggggggggggggGGk",
		"kGGggggggggGGGGk",
		".kGGGGGGGGGGGGk.",
		"..kkkkkkkkkkkk..",
		"................",
	],
	"bat_a": [
		"................",
		"................",
		"................",
		".kk..........kk.",
		"kPPk.k....k.kPPk",
		"kPpPkPk..kPkPpPk",
		"kPppPPPkkPPPppPk",
		".kPpPPePPePPpPk.",
		".kPPqPPPPPPqPPk.",
		"..kkqkPPPPkqkk..",
		"....k.kPPk.k....",
		".......kk.......",
		"................",
		"................",
		"................",
		"................",
	],
	"bat_b": [
		"................",
		"................",
		"................",
		"................",
		".....k....k.....",
		"....kPk..kPk....",
		"..kkkPPkkPPkkk..",
		".kPPPPePPePPPPk.",
		"kPpPPPPPPPPPPpPk",
		"kPppqPPPPPPqppPk",
		"kPpk.kPPPPk.kpPk",
		"kPk...kPPk...kPk",
		".k.....kk.....k.",
		"................",
		"................",
		"................",
	],
	"torch": [
		"..kkkkkkkkkkkk..",
		".kZAAAAAAAAAAZk.",
		".kZXxFxFFxFxXZk.",
		"..kZZZZZZZZZZk..",
		"...kkzTTTTzkk...",
		".....kTttTk.....",
		".....kTttzk.....",
		"....kTTtttzk....",
		"...kTttttttzk...",
		"...kzzzzzzzzk...",
		"....kkkkkkkk....",
	],
	"flame_l_a": [
		"......x.....",
		".....xx.....",
		".....xFx....",
		"....xFFx....",
		"...xxFFxx...",
		"...xFFFFx.x.",
		"..xxFffFxxx.",
		"..xFFffFFx..",
		".xxFfffFFxx.",
		".xFFffffFFx.",
		".xFFffffFFx.",
		".xxFFffFFxx.",
		"..xxFFFFxx..",
		"...xxxxxx...",
	],
	"flame_l_b": [
		"............",
		".......x....",
		"......xx....",
		".....xFx....",
		".x..xFFxx...",
		".xx.xFFFx...",
		".xxxFFfFxx..",
		"..xFFffFFx..",
		".xxFFfffFxx.",
		".xFFffffFFx.",
		".xFFffffFFx.",
		".xxFFffFFxx.",
		"..xxFFFFxx..",
		"...xxxxxx...",
	],
	"flame_m_a": [
		"....x...",
		"...xx...",
		"...xFx..",
		"..xFFx..",
		"..xFFxx.",
		".xFffFx.",
		".xFffFx.",
		".xFffFx.",
		".xxFFxx.",
		"..xxxx..",
	],
	"flame_m_b": [
		"........",
		"....x...",
		"...xx...",
		"..xFx...",
		".xxFFx..",
		".xFFfFx.",
		".xFffFx.",
		".xFffFx.",
		".xxFFxx.",
		"..xxxx..",
	],
	"flame_s_a": [
		"..x...",
		"..xx..",
		".xFx..",
		".xFFx.",
		".xFFx.",
		"..xx..",
	],
	"flame_s_b": [
		"......",
		"...x..",
		"..xx..",
		".xFFx.",
		".xFFx.",
		"..xx..",
	],
	"log": [
		"..kkkkkkkkkkk.",
		".kyyyoyoooyook",
		"kyOyOoooonoook",
		"kyOyOnooooooOk",
		"kyyyOOOOOOOOOk",
		".kyynnnnnnnnk.",
		"..kkkkkkkkkk..",
	],
	"sword": [
		"....kk..........",
		".kk.kYaaaaaaaaa.",
		"ksskOYaaaaaaaaaa",
		".kk.kYAAAAAAAAA.",
		"....kk..........",
	],
	"sword_fire": [
		"....kk..........",
		".kk.kYfffffffff.",
		"ksskOYFFFFFFFFFF",
		".kk.kYxxxxxxxxx.",
		"....kk..........",
	],
	"sword_long": [
		"....kk..................",
		".kk.kYaaaaaaaaaaaaaaaaa.",
		"ksskOYaaaaaaaaaaaaaaaaaW",
		".kk.kYAAAAAAAAAAAAAAAAA.",
		"....kk..................",
	],
	"sword_long_fire": [
		"....kk..................",
		".kk.kYfffffffffffffffff.",
		"ksskOYFFFFFFFFFFFFFFFFFf",
		".kk.kYxxxxxxxxxxxxxxxxx.",
		"....kk..................",
	],
	"slime_king_a": [
		"................................",
		".............k..k..k............",
		"............kYkkYkkYk...........",
		"............kYYkYkYYk...........",
		"............kYYYiYYYk...........",
		"............kFYFYFYFk...........",
		"...........kkFFFFFFFk...........",
		".........kkgggggggggkk..........",
		".......kkgghggggggggggkk........",
		".....kkghhhhggggggggggggkk......",
		"....kgghhhhgggggggggggggggk.....",
		"...kgghhhggggggggggggggggggk....",
		"...kghhhgggggggggggggggggggk....",
		"..kgggggggggggggggggggggggggk...",
		"..kgggggggggggggggggggggggggk...",
		".kgggggggggggggggggggggggggggk..",
		".kggggggggWkggggggggWkgggggggk..",
		".kggggggggkkggggggggkkgggggggk..",
		".kgggggggggggggggggggggggggggk..",
		".kgggggggggggggggggggggggggggk..",
		"..kGGGGGGGGGGGkkkkGGGGGGGGGGk...",
		"...kjGGGGGGGGGGiiGGGGGGGGGjk....",
		"....kGGGGGGGGGGGGGGGGGGGGGk.....",
		".....kkjjjjjjjjjjjjjjjjjkk......",
		".......kkjjjjjjjjjjjjjkk........",
		".........kkkkkkkkkkkkk..........",
	],
	"slime_king_b": [
		"................................",
		"................................",
		"................................",
		"................................",
		".............k..k..k............",
		"............kYkkYkkYk...........",
		"............kYYkYkYYk...........",
		"............kYYYiYYYk...........",
		"............kFYFYFYFk...........",
		"...........kkFFFFFFFk...........",
		".......kkkkgggggggggkkkk........",
		".....kkggghhggggggggggggkk......",
		"....kgghhhhhggggggggggggggk.....",
		"...kghhhhggggggggggggggggggk....",
		"..kghhhgggggggggggggggggggggk...",
		".kgggggggggggggggggggggggggggk..",
		"kgggggggggggggggggggggggggggggk.",
		"kgggggggggggggggggggggggggggggk.",
		"kgggggggggWkggggggggWkggggggggk.",
		"kgggggggggkkggggggggkkggggggggk.",
		"kgggggggggggggggggggggggggggggk.",
		".kGGGGGGGGGGGGGGGGGGGGGGGGGGGk..",
		"..kjGGGGGGGGGGkkkkGGGGGGGGGjk...",
		"...kGGGGGGGGGGGiiGGGGGGGGGGk....",
		"....kkkjjjjjjjjjjjjjjjjjkkk.....",
		".......kkkkjjjjjjjjjkkkk........",
	],
	"shade_lord_a": [
		"...........kk...........",
		".......k..kYYk..k.......",
		"......kYkkkYYkkkYk......",
		"......kY8Y8YY8YkYk......",
		"......kYFYFYYFYFYk......",
		".....k77788888888k......",
		".....k88889998888k......",
		"....k8889999999888k.....",
		"....k8899999999988k.....",
		"....k7799l9999l988k.....",
		"....k8899L9999L988k.....",
		".....k88999999988k......",
		".....k88889998888k......",
		"....k7777888888888k.....",
		"....k8888888888888k.....",
		"...k888888888888888k....",
		"...k888888888888888k....",
		"..k77777788888888888k...",
		"..k88888888888899999k...",
		".k8888888888888999999k..",
		".k8888888888888999999k..",
		"k77k77k77k88k88k99k99k..",
		".kk.kk.kk.kk.kk.kk.kk...",
		"........................",
	],
	"shade_lord_b": [
		"...........kk...........",
		".......k..kYYk..k.......",
		"......kYkkkYYkkkYk......",
		"......kY8Y8YY8YkYk......",
		"......kYFYFYYFYFYk......",
		".....k77788888888k......",
		".....k88889998888k......",
		"....k8889999999888k.....",
		"....k8899999999988k.....",
		"....k7799l9999l988k.....",
		"....k8899L9999L988k.....",
		".....k88999999988k......",
		".....k88889998888k......",
		".....k777888888888k.....",
		"....k8888888888888k.....",
		"....k88888888888888k....",
		"...k8888888888888888k...",
		"...k7777788888888888k...",
		"..k888888888888999999k..",
		"..k8888888888889999999k.",
		".k88888888888889999999k.",
		"..k77k77k88k88k99k99k99k",
		"...kk.kk.kk.kk.kk.kk.kk.",
		"........................",
	],
	"shade_lord_eyes": [
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		".........l....l.........",
		".........L....L.........",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
	],
	"shade_decoy_eyes": [
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		".........7....7.........",
		".........8....8.........",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
	],
	"shadow_huge": [
		"....____________________....",
		".__________________________.",
		"____________________________",
		".__________________________.",
		"....____________________....",
	],
	"icon_guard": [
		".kkkkkkk.",
		"kaaaYaaAk",
		"kaaYYYAAk",
		"kaaaYaAAk",
		"kaaaaAAAk",
		".kaaAAAk.",
		"..kaAAk..",
		"...kAk...",
		"....k....",
	],
	"icon_momentum": [
		".........",
		"Y...F....",
		".Y...F...",
		"L.Y...F..",
		"LL.Y...F.",
		"L.Y...F..",
		".Y...F...",
		"Y...F....",
		".........",
	],
	"icon_splitter": [
		"...aAa...",
		"...aAa...",
		"....A....",
		".yo...oO.",
		"yoo...ooO",
		"yoO...onO",
		"yoo...ooO",
		".yo...oO.",
		".........",
	],
	"icon_big_pack": [
		"..yooO...",
		".yooooO..",
		"..yooO..b",
		".yooooO.b",
		"..yooO..b",
		".yooooO.b",
		"bbbbbbbbb",
		".b.....b.",
		".b.....b.",
	],
	"icon_piercing": [
		".........",
		"..G...G..",
		".GgG.GgG.",
		"xxFFFFFFf",
		"xFFFFFFfW",
		"xxFFFFFFf",
		".GgG.GgG.",
		"..G...G..",
		".........",
	],
	"icon_kindle": [
		"....x....",
		"..x...x..",
		".x.....x.",
		".........",
		"xFx.....x",
		"FfF....xF",
		"FWF.....x",
		"xFx......",
		".........",
	],
	"icon_scorch": [
		"..xFFFx..",
		".xF...Fx.",
		"xF.....Fx",
		"F..XxX..F",
		"F..xfx..F",
		"F..XxX..F",
		"xF.....Fx",
		".xF...Fx.",
		"..xFFFx..",
	],
	"icon_beacon": [
		"....F....",
		"..xxFxx..",
		".x..F..x.",
		".x.....x.",
		"FFF.W.FFF",
		".x.....x.",
		".x..F..x.",
		"..xxFxx..",
		"....F....",
	],
	"icon_bramble": [
		".........",
		".a.a.a...",
		"..A.A.a..",
		".......a.",
		"LLaaaaaaa",
		".......a.",
		"..A.A.a..",
		".a.a.a...",
		".........",
	],
	"icon_blast": [
		"x...F...x",
		".x..F..x.",
		"..x.f.x..",
		"....f....",
		".kkkkkkk.",
		"kyyOoooOk",
		"kyOyoonOk",
		"kyyyOOOOk",
		".kkkkkkk.",
	],
	"icon_dash": [
		".........",
		".....a...",
		"LL....a..",
		".......a.",
		"LLLaaaaaa",
		".......a.",
		"LL....a..",
		".....a...",
		".........",
	],
	"icon_swift": [
		"......aa.",
		"LLL..aaA.",
		"....aaA..",
		"LL.aaA...",
		"..aaA....",
		"LYaA.....",
		"..YY.....",
		".O..Y....",
		"O........",
	],
	"icon_kindling": [
		"....x....",
		"...xFx...",
		"...xFFx..",
		"..xFfFx..",
		"..xFfFx..",
		"o..xFx..o",
		".oy.x.yo.",
		"..oyoyo..",
		".oo...oo.",
	],
	"icon_rest": [
		".........",
		".ii...ii.",
		"iWiiiiiIi",
		"iiiiiiiIi",
		"iiiiiiiIi",
		".iiiiiIi.",
		"..iiiIi..",
		"...iIi...",
		"....i....",
	],
	"icon_spare_log": [
		".........",
		".........",
		"..yoooO..",
		".yooooooO",
		"yOooooonO",
		".yooooooO",
		"..yoooO..",
		".........",
		".........",
	],
	"icon_tale": [
		"....Y....",
		"....Y....",
		"...YfY...",
		"YYYfffYYY",
		".YfffffY.",
		"..YfffY..",
		".YffYffY.",
		".YY...YY.",
		".........",
	],
	"icon_spin": [
		"..aaaaa..",
		".a.....a.",
		"a.......a",
		"a...a...a",
		"a..aAa..a",
		"a...Y...a",
		".a.....A.",
		"..aa.AAA.",
		"......A..",
	],
	"icon_spark": [
		".......x.",
		"......FfF",
		".....xFWf",
		"....x.FfF",
		"...x...x.",
		"..x......",
		".x.......",
		"x........",
		".........",
	],
	"icon_vampire": [
		"......aa.",
		".....aaA.",
		"....aaA..",
		"...aaA...",
		".Y.aA..i.",
		"..YA..iIi",
		"...YY.iIi",
		"..O..Y.i.",
		".O.......",
	],
	"icon_big_torch": [
		"....x....",
		"...xFx...",
		"..xFfFx..",
		".xFffFFx.",
		".xFfffFx.",
		"ZAAAAAAAZ",
		".ZZZZZZZ.",
		"...TtT...",
		"..TttzT..",
	],
	"glint_a": [
		".W.",
		"WfW",
		".W.",
	],
	"glint_b": [
		"..W..",
		"..f..",
		"WfWfW",
		"..f..",
		"..W..",
	],
	"spark": [
		".xFx.",
		"xFfFx",
		"FfWfF",
		"xFfFx",
		".xFx.",
	],
	"shadow": [
		"..________..",
		".__________.",
		"____________",
		".__________.",
		"..________..",
	],
	"shadow_small": [
		".______.",
		"________",
		".______.",
	],
	"tuft_a": [
		".4...4.",
		".24.42.",
		"..242..",
		"..323..",
	],
	"tuft_b": [
		"..4..",
		"4.2.4",
		"24242",
		".323.",
	],
	"flower_a": [
		".W.",
		"WYW",
		".W.",
		".2.",
	],
	"flower_b": [
		".Y.",
		"YxY",
		".Y.",
		".2.",
	],
	"pebble": [
		".ttT.",
		"tttTz",
		".TTz.",
	],
	"mushroom": [
		".mmm.",
		"mcmcM",
		"MMMMM",
		"..c..",
		"..c..",
	],
	"hedge": [
		"uuuuuuuuuuuuuuuu",
		"uuUuuuuuuuUuuuuu",
		"uUUUuuuuuUUUuuuu",
		"uUvUUuuuUUvUUuuu",
		"UUUUUUuUUUUUUUuU",
		"UUvUUUUUUvUUUUUU",
		"kUUUUUkkUUUUUkkU",
		".kUUUk..kUUUk..k",
		"..kkk....kkk....",
	],
	"poof_a": [
		"................",
		"................",
		"................",
		"................",
		"......WWWW......",
		".....WWWWWW.....",
		"....WWWWWWWa....",
		"....WWWWWWaa....",
		"....WWWWWWaa....",
		"....WWWWWaaA....",
		".....WaaaaA.....",
		"......aaAA......",
		"................",
		"................",
		"................",
		"................",
	],
	"poof_b": [
		"................",
		"................",
		".....WWW.WW.....",
		"...WWWWWWWWWW...",
		"..WWWWWWWWWWWa..",
		"..WWWW....WWWa..",
		".WWWW......WWWa.",
		".WWW........WWa.",
		".WWW........WWa.",
		".WWWW......WWaa.",
		"..WWWW....WWaa..",
		"..WWWWWWWWWaaA..",
		"...aWWWaaaaaA...",
		".....aaa.AA.....",
		"................",
		"................",
	],
	"poof_c": [
		"................",
		"....WW....W.....",
		"...WWWW..WWW....",
		"...WWWa...Wa....",
		"....aa..........",
		".WW..........WW.",
		"WWWW........WWWa",
		"WWWa........WWaa",
		".aa..........aa.",
		"................",
		"..WW.......WW...",
		".WWWW.....WWWa..",
		".WWWa.....WWaa..",
		"..aa...WW..aa...",
		"......WWWa......",
		".......aa.......",
	],
	"poof_d": [
		"................",
		".....a....a.....",
		"....aa..........",
		"................",
		"................",
		".a............a.",
		"aa............aa",
		"................",
		"................",
		"................",
		"..a.........a...",
		".aa.........aa..",
		"................",
		".......a........",
		".......aa.......",
		"................",
	],
	"icon_slow_burn": [
		"....L....",
		"....LL...",
		"...LlL...",
		"...LllL..",
		"..LLllL..",
		"..LlllLL.",
		"..LlWlLL.",
		"..LLlLLL.",
		"...LLLL..",
	],
	"icon_big_logs": [
		".....Y...",
		"....YYY..",
		".....Y...",
		".kkkkkkk.",
		"kyyOoooOk",
		"kyOyoonOk",
		"kyyyOOOOk",
		".kkkkkkk.",
		".........",
	],
	"icon_ember_ring": [
		"...xFx...",
		".F.....x.",
		".x.....F.",
		"x...f...x",
		"F..fFf..F",
		"x...f...x",
		".F.....x.",
		".x.....F.",
		"...xFx...",
	],
	"icon_warm_glow": [
		".x..x..x.",
		"..x..x..x",
		".x..x..x.",
		"x..x..x..",
		".x..x..x.",
		".........",
		".XxFFFxX.",
		"..XxxxX..",
		".........",
	],
	"icon_woodpile": [
		"...kkk...",
		"..kyyyk..",
		"..kyOyk..",
		"..kyyyk..",
		".kkkkkkk.",
		"kyyykyyyk",
		"kyOykyOyk",
		"kyyykyyyk",
		".kkk.kkk.",
	],
	"icon_quick_hands": [
		"......WW.",
		"....WWWa.",
		"...WWWWa.",
		"..WWWWa..",
		".aWWWa...",
		".aWWa....",
		"..aa.....",
		".A.......",
		"A........",
	],
	"icon_long_blade": [
		".......aa",
		"......aaA",
		".....aaA.",
		"....aaA..",
		".Y.aaA...",
		"..YaA....",
		"...YY....",
		"..O..Y...",
		".O.......",
	],
	"icon_bright": [
		"....Y....",
		".Y..Y..Y.",
		"..Y.f.Y..",
		"...fff...",
		"YYfffffYY",
		"...fff...",
		"..Y.f.Y..",
		".Y..Y..Y.",
		"....Y....",
	],
	"ember": [
		".x.",
		"xFx",
		".x.",
	],
	"ember_hot": [
		"..F..",
		".FfF.",
		"FfffF",
		".FfF.",
		"..F..",
	],
	"shade_a": [
		"................",
		"................",
		".....kkkkkk.....",
		"....k888888k....",
		"...k87888888k...",
		"...k89999998k...",
		"...k8l9999l8k...",
		"...k89999998k...",
		"...k88999988k...",
		"...k88888888k...",
		"..k8888888888k..",
		"..k8788888888k..",
		"..k8888888888k..",
		"..k88k888k888k..",
		"..kkk.kkk.kkkk..",
		"................",
	],
	"bat_eyes": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"......i..i......",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	"shade_eyes": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		".....l....l.....",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	"big_slime_a": [
		"........................",
		"........kkkkkkkk........",
		"......kkGGGGGGGGkk......",
		"....kkGGhhGGGGGGGGkk....",
		"...kGGhhhGGGGGGGGGGGk...",
		"..kGGhhGGGGGGGGGGGGGGk..",
		"..kGGkkGGGGGGGGGGkkGGk..",
		".kGGGGGkkGGGGGGkkGGGGGk.",
		".kGGGGWkkGGGGGGWkkGGGGk.",
		".kGGGGkkkGGGGGGkkkGGGGk.",
		".kGGGGkkkGGGGGGkkkGGGGk.",
		"kGGGGGGGGGGGGGGGGGGGGGGk",
		"kGGGGGGGGGkkkkGGGGGGGGGk",
		"kGGGGGGGGkGGGGkGGGGGGGGk",
		"kGGGGGGGGGGGGGGGGGGGGjjk",
		"kjGGGGGGGGGGGGGGGGGGjjjk",
		"kjjGGGGGGGGGGGGGGGjjjjjk",
		".kjjjjjjjjjjjjjjjjjjjjk.",
		"..kkkkkkkkkkkkkkkkkkkk..",
		"........................",
	],
	"boar_a": [
		"................",
		"................",
		"................",
		"................",
		"..........kk....",
		"...k.k.k.kbk....",
		"..kBkBkBkbbBk...",
		".kBBbbbbBbbBBk..",
		"kBbbbbbbbBBiBBk.",
		"kBbbbbbbbBBBBkSk",
		"kBbbbbbbBBBBkSSS",
		"kBBbbbbBBBBWkSSk",
		".kBBBBBBBBBkWkk.",
		"..kBk.kBkkBk....",
		"..kk..kk..kk....",
		"................",
	],
	"moth_a": [
		"................",
		"................",
		"................",
		"................",
		".....k....k.....",
		"..kkk.k..k.kkk..",
		".kwwwkkYYkkwwwk.",
		".kwcwwkmmkwwcwk.",
		".kwwcckmmkccwwk.",
		"..kkdcckkccdkk..",
		"..kddkkmmkkddk..",
		"...kk.kmmk.kk...",
		".......kk.......",
		"................",
		"................",
		"................",
	],
	"moth_b": [
		"................",
		"................",
		"................",
		"................",
		".....k....k.....",
		"....k.k..k.k....",
		"...kkkkYYkkkk...",
		"..kwwckmmkcwwk..",
		"..kwccdmmdccwk..",
		"...kcdkmmkdck...",
		"....kkkmmkkk....",
		"......kmmk......",
		".......kk.......",
		"................",
		"................",
		"................",
	],
	"spitter_a": [
		"................",
		"................",
		"................",
		"................",
		"..kkk......kkk..",
		".keeekkkkkkeeek.",
		".kekekDDDDkekek.",
		".kDDDCCCCCCDDDk.",
		".kDCCCCCCCCCCDk.",
		"kDDCkkkkkkkkCDDk",
		"kDEyyyyyyyyyyEDk",
		"kEEDyyyyyyyyDEEk",
		".kEkkDDDDDDkkEk.",
		".kk..kkkkkk..kk.",
		"................",
		"................",
	],
	"drummer_a": [
		"................",
		"................",
		".......kk.......",
		"......kwwk......",
		"....kkkwwkkk....",
		"...kFFFFFFFFk...",
		"..kFFFFFFFFFFk..",
		"..kFWkFFFFWkFk..",
		"y.kFFFFkkFFFFk..",
		".y.kkkkkkkkkk...",
		"..FkwwwwwwwwkFy.",
		"...kwwwwwwwwk...",
		"...kOnOnnOnOk...",
		"...kOOnOOnOOk...",
		"...kkkkkkkkkk...",
		"....kk....kk....",
	],
	"boar_chief_a": [
		"........................",
		"...............kk.......",
		"....k..k..k..k.kbYk.....",
		"...kBk.kBkkBkkBkbbbBk...",
		"..kBBBbBBBbBBBbbbbbBBk..",
		".kBBbbbbbbbbbbbbBBBBBBk.",
		"kBBbbRRbbbRRbbBBBiiBBk..",
		"kBbbbbRRbbbRRbBBBiiBBBk.",
		"kBbbbbbRRbbbRRBBBBBBBkSk",
		"kBbbbbbbbbbbbBBBBBBBkSSS",
		"kBbbbbbbbbbbbBBBBBWWkSSk",
		"kBBbbbbbbbbbBBBBBWWkkkk.",
		"kBBBbbbbbbbBBBBBkWWk....",
		".kBBBBBBBBBBBBBBBkWk....",
		"..kBBBBBBBBBBBBBBkk.....",
		"..kBBk.kBBk..kBBkBBk....",
		"..kBBk.kBBk..kBBkBBk....",
		"..kkkk.kkkk..kkkkkkk....",
	],
	"drummed": [
		"Y.Y..",
		".Y.Y.",
		"Y.Y..",
	],
	"dazed": [
		".Y.....",
		"YWY..Y.",
		".Y..YWY",
		".....Y.",
	],
	"thief_a": [
		"................",
		"................",
		"................",
		"................",
		".........kkkk...",
		"........kOOOOk..",
		"......kkOOOOOOk.",
		"....kkOOOOkOOkOk",
		"...kOOOOOOOOOOok",
		".kkkOOOOOOOOokWk",
		"knnkOOOOOOOOOkk.",
		"knnnkOOoOOOOOk..",
		".knnkOOooOOOk...",
		"..kkkOkkOOkkOk..",
		"....kkk.kkk.kk..",
		"................",
	],
	"shadow_big": [
		"....____________....",
		".__________________.",
		"____________________",
		"____________________",
		".__________________.",
		"....____________....",
	],
	"berry": [
		"....44...",
		"...42....",
		"...2.2...",
		".kkk.kkk.",
		"kiWikiWik",
		"kiiIkiiIk",
		"kIIIkIIIk",
		".kkk.kkk.",
	],
	"icon_sturdy": [
		"......Y..",
		".ii.iYYY.",
		"iWiiiiY..",
		"iiiiiiI..",
		"iiiiiiI..",
		".iiiiI...",
		"..iiI....",
		"...I.....",
		".........",
	],
	"icon_thorns": [
		"....a....",
		".a..a..a.",
		"..aAAAa..",
		"..AzzzA..",
		"aaAzzzAaa",
		"..AzzzA..",
		"..aAAAa..",
		".a..a..a.",
		"....a....",
	],
	"icon_wide_swing": [
		".........",
		"..fffff..",
		".ffFFFff.",
		"ffF...Fff",
		"fF.....Ff",
		"F...a...F",
		"x..aAa..x",
		"....a....",
		".........",
	],
	"icon_fire_blade": [
		".......Ff",
		"......FfF",
		".....xFx.",
		"....xFx..",
		".Y.xFx...",
		"..YxX....",
		"...YY....",
		"..O..Y...",
		".O.......",
	],
	"heart": [
		".kkk.kkk.",
		"kiiikiiIk",
		"kiWiiiiIk",
		"kiiiiiiIk",
		".kiiiiIk.",
		"..kiiIk..",
		"...kIk...",
		"....k....",
	],
	"heart_empty": [
		".TTT.TTT.",
		"TzzzTzzzT",
		"TzzzzzzzT",
		"TzzzzzzzT",
		".TzzzzzT.",
		"..TzzzT..",
		"...TzT...",
		"....T....",
	],
	# The touch controls (src/touch.gd), drawn see-through over the field: the stick's ring and knob, the buttons.
	"pad_ring": [
		"....................kkkkkkkkk....................",
		".................kkkkaaaaaaakkkk.................",
		"..............kkkaaaaaaaaaaaaaAAkkk..............",
		"............kkkaaaaaaaaaaaaaaaAAAAkkk............",
		"...........kkaaaaaaaakkkkkkkaaAAAAAAkk...........",
		".........kkaaaaaakkkkkk...kkkkkkAAAAAAkk.........",
		"........kkaaaaakkk.............kkkAAAAAkk........",
		".......kkaaaakkk.................kkkAAAAkk.......",
		"......kkaaaakk.....................kkAAAAkk......",
		".....kkaaaakk.......................kkAAAAkk.....",
		".....kaaaakk.........................kkAAAAk.....",
		"....kaaaakk...........................kkAAAAk....",
		"...kkaaakk.............................kkAAAkk...",
		"...kaaakk...............................kkAAAk...",
		"..kkaaak.................................kAAAkk..",
		"..kaaakk.................................kkAAAk..",
		"..kaaak...................................kAAZk..",
		".kaaakk...................................kkZZZk.",
		".kaaak.....................................kZZZk.",
		".kaaak.....................................kZZZk.",
		"kkaaak.....................................kZZZkk",
		"kaaakk.....................................kkZZZk",
		"kaaakk.....................................kkZZZk",
		"kaaak.......................................kZZZk",
		"kaaak.......................................kZZZk",
		"kaaak.......................................kZZZk",
		"kaaakk.....................................kkZZZk",
		"kaaakk.....................................kkZZZk",
		"kkaaak.....................................kZZZkk",
		".kaaak.....................................kZZZk.",
		".kAAAk.....................................kZZZk.",
		".kAAAkk...................................kkZZZk.",
		"..kAAAk...................................kZZZk..",
		"..kAAAkk.................................kkZZZk..",
		"..kkAAAk.................................kZZZkk..",
		"...kAAAkk...............................kkZZZk...",
		"...kkAAAkk.............................kkZZZkk...",
		"....kAAAAkk...........................kkZZZZk....",
		".....kAAAAkk.........................kkZZZZk.....",
		".....kkAAAAkk.......................kkZZZZkk.....",
		"......kkAAAAkk.....................kkZZZZkk......",
		".......kkAAAAkkk.................kkkZZZZkk.......",
		"........kkAAAAAkkk.............kkkZZZZZkk........",
		".........kkAAAAAAkkkkkk...kkkkkkZZZZZZkk.........",
		"...........kkAAAAZZZZkkkkkkkZZZZZZZZkk...........",
		"............kkkAZZZZZZZZZZZZZZZZZZkkk............",
		"..............kkkZZZZZZZZZZZZZZZkkk..............",
		".................kkkkZZZZZZZkkkk.................",
		"....................kkkkkkkkk....................",
	],
	"pad_knob": [
		"........kkkkk........",
		".....kkkaaaaakkk.....",
		"....kkaaaaaaAAAkk....",
		"...kaaaaaaaAAAAAAk...",
		"..kaaaaaaaAAAAAAAAk..",
		".kkaaaaaaAAAAAAAAAkk.",
		".kaaaaaaAAAAAAAAAAAk.",
		".kaaaaaAAAAAAAAAAAAk.",
		"kaaaaaAAAAAAAAAAAAAZk",
		"kaaaaAAAAAAAAAAAAAZZk",
		"kaaaAAAAAAAAAAAAAZZZk",
		"kaaAAAAAAAAAAAAAZZZZk",
		"kaAAAAAAAAAAAAAZZZZZk",
		".kAAAAAAAAAAAAZZZZZk.",
		".kAAAAAAAAAAAZZZZZZk.",
		".kkAAAAAAAAAZZZZZZkk.",
		"..kAAAAAAAAZZZZZZZk..",
		"...kAAAAAAZZZZZZZk...",
		"....kkAAAZZZZZZkk....",
		".....kkkZZZZZkkk.....",
		"........kkkkk........",
	],
	"button": [
		"...................kkkkkkk...................",
		"...............kkkkTTTTTTTkkkk...............",
		".............kkTTTTTTTTTTTTTTTkk.............",
		"...........kkTTTTTTKKKKKKKTTTTTTkk...........",
		".........kkTTTTTKKKKKKKKKKKKKTTTTTkk.........",
		"........kkTTTKKKKKKKKKKKKKKKKKKKTTTkk........",
		".......kkTTTKKKKKKKKKKKKKKKKKKKKKTTTkk.......",
		"......kTTTKKKKKKKKKKKKKKKKKKKKKKKKKTTTk......",
		".....kkTTKKKKKKKKKKKKKKKKKKKKKKKKKKKTTkk.....",
		"....kkTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTkk....",
		"....kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk....",
		"...kTTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTTk...",
		"...kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk...",
		"..kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk..",
		"..kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk..",
		".kTTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTTk.",
		".kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk.",
		".kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk.",
		".kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk.",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk",
		"kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk",
		"kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk",
		".kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk.",
		".kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk.",
		".kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk.",
		".kZZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZZk.",
		"..kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk..",
		"..kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk..",
		"...kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk...",
		"...kZZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZZk...",
		"....kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk....",
		"....kkZZKKKKKKKKKKKKKKKKKKKKKKKKKKKKKZZkk....",
		".....kkZZKKKKKKKKKKKKKKKKKKKKKKKKKKKZZkk.....",
		"......kZZZKKKKKKKKKKKKKKKKKKKKKKKKKZZZk......",
		".......kkZZZKKKKKKKKKKKKKKKKKKKKKZZZkk.......",
		"........kkZZZKKKKKKKKKKKKKKKKKKKZZZkk........",
		".........kkZZZZZKKKKKKKKKKKKKZZZZZkk.........",
		"...........kkZZZZZZKKKKKKKZZZZZZkk...........",
		".............kkZZZZZZZZZZZZZZZkk.............",
		"...............kkkkZZZZZZZkkkk...............",
		"...................kkkkkkk...................",
	],
	"button_mid": [
		".............kkkkkkk.............",
		"..........kkkkTTTTTkkkk..........",
		"........kkTTTTTTTTTTTTTkk........",
		".......kkTTTTTKKKKKTTTTTkk.......",
		".....kkTTTTKKKKKKKKKKKTTTTkk.....",
		"....kkTTTKKKKKKKKKKKKKKKTTTkk....",
		"....kTTTKKKKKKKKKKKKKKKKKTTTk....",
		"...kTTTKKKKKKKKKKKKKKKKKKKTTTk...",
		"..kkTTKKKKKKKKKKKKKKKKKKKKKTTkk..",
		"..kTTKKKKKKKKKKKKKKKKKKKKKKKTTk..",
		".kTTTKKKKKKKKKKKKKKKKKKKKKKKTTTk.",
		".kTTKKKKKKKKKKKKKKKKKKKKKKKKKTTk.",
		".kTTKKKKKKKKKKKKKKKKKKKKKKKKKTTk.",
		"kkTTKKKKKKKKKKKKKKKKKKKKKKKKKTTkk",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kTTKKKKKKKKKKKKKKKKKKKKKKKKKKKTTk",
		"kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk",
		"kZZKKKKKKKKKKKKKKKKKKKKKKKKKKKZZk",
		"kkZZKKKKKKKKKKKKKKKKKKKKKKKKKZZkk",
		".kZZKKKKKKKKKKKKKKKKKKKKKKKKKZZk.",
		".kZZKKKKKKKKKKKKKKKKKKKKKKKKKZZk.",
		".kZZZKKKKKKKKKKKKKKKKKKKKKKKZZZk.",
		"..kZZKKKKKKKKKKKKKKKKKKKKKKKZZk..",
		"..kkZZKKKKKKKKKKKKKKKKKKKKKZZkk..",
		"...kZZZKKKKKKKKKKKKKKKKKKKZZZk...",
		"....kZZZKKKKKKKKKKKKKKKKKZZZk....",
		"....kkZZZKKKKKKKKKKKKKKKZZZkk....",
		".....kkZZZZKKKKKKKKKKKZZZZkk.....",
		".......kkZZZZZKKKKKZZZZZkk.......",
		"........kkZZZZZZZZZZZZZkk........",
		"..........kkkkZZZZZkkkk..........",
		".............kkkkkkk.............",
	],
	"button_small": [
		".......kkkkkkk.......",
		".....kkTTTTTTTkk.....",
		"....kTTTKKKKKTTTk....",
		"...kTTKKKKKKKKKTTk...",
		"..kTKKKKKKKKKKKKKTk..",
		".kTTKKKKKKKKKKKKKTTk.",
		".kTKKKKKKKKKKKKKKKTk.",
		"kZZKKKKKKKKKKKKKKKZZk",
		"kZKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKZk",
		"kZZKKKKKKKKKKKKKKKZZk",
		".kZKKKKKKKKKKKKKKKZk.",
		".kZZKKKKKKKKKKKKKZZk.",
		"..kZKKKKKKKKKKKKKZk..",
		"...kZZKKKKKKKKKZZk...",
		"....kZZZKKKKKZZZk....",
		".....kkZZZZZZZkk.....",
		".......kkkkkkk.......",
	],
	"pause_bars": [
		"kkk.kkk",
		"kwk.kwk",
		"kwk.kwk",
		"kwk.kwk",
		"kwk.kwk",
		"kwk.kwk",
		"kwk.kwk",
		"kkk.kkk",
	],
	# The first night's coaching arrow (src/ui.gd, src/coach.gd), pointing down at what to go to.
	"coach_arrow": [
		"..kkkkk..",
		"..kYYYk..",
		"..kYYYk..",
		"kkkYYYkkk",
		"kYYYYYYYk",
		".kYYYYYk.",
		"..kYYYk..",
		"...kYk...",
		"....k....",
	],
	"help_mark": [
		".kkkkk.",
		"kkwwwkk",
		"kwkkkwk",
		"kkk.kwk",
		"..kkwkk",
		"..kwkk.",
		"..kkk..",
		"..kwk..",
		"..kkk..",
	],
	# The music button (src/touch.gd): a note, and the stroke drawn across it while the music is off.
	"note_mark": [
		"...kkkkk.",
		"...kwwwk.",
		"...kwkwk.",
		"...kwkwk.",
		"...kwkwk.",
		".kkkwkwk.",
		"kwwwwkwk.",
		"kwwwwkkk.",
		".kkkk....",
	],
	"note_off": [
		".......kk",
		"......krk",
		".....krk.",
		"....krk..",
		"...krk...",
		"..krk....",
		".krk.....",
		"krk......",
		"kk.......",
	],
	# A locked character's card (src/ui.gd): a padlock over its picture.
	"lock": [
		"...kkkkk...",
		"..kkAAAkk..",
		".kkAkkkAkk.",
		".kAkk.kkAk.",
		".kAk...kAk.",
		"kkkkkkkkkkk",
		"kFFFFFFFFFk",
		"kFFFkkkFFFk",
		"kFxFkkkFxFk",
		"kFxFFkFFxFk",
		"kFxxFFFxxFk",
		"kkxxxxxxxkk",
		".kkkkkkkkk.",
	],
	# A win with this character (src/ui.gd, on its card and in the records): a small crown.
	"crown": [
		".k...k...k.",
		"kYk.kYk.kYk",
		"kYk.kYk.kYk",
		"kYYkYYYkYYk",
		"kYYYYYYYYYk",
		"kFiFFiFFiFk",
		"kFFFFFFFFFk",
		"kkkkkkkkkkk",
	],
}

## A second frame that is another sprite with a few rows redrawn: name -> [base sprite, { row index: new row }].
const VARIANTS := {
	"keeper_down_b": ["keeper_down_a", { 12: "...kDbbYbbbsk...", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"keeper_up_b": ["keeper_up_a", { 12: "...kDwwRwwwsk...", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"keeper_side_b": ["keeper_side_a", { 12: "..kk..kbbDbk....", 13: "......kEEsEk....", 14: ".....kBk.kBk....", 15: ".....kk...kk...." }],
	"keeper_down_lift_a": ["keeper_down_a", { 1: ".k..kkkkk1kk..k.", 2: "ksk.k11155111ksk", 3: "kDk1155555115kDk", 4: "kDk5555555555kDk", 5: "kDk55s5ss5s55kDk", 6: ".kk5ssssssss5kk.", 11: "....kCDRDDCk....", 12: "....kbbYbbbk...." }],
	"keeper_down_lift_b": ["keeper_down_a", { 1: ".k..kkkkk1kk..k.", 2: "ksk.k11155111ksk", 3: "kDk1155555115kDk", 4: "kDk5555555555kDk", 5: "kDk55s5ss5s55kDk", 6: ".kk5ssssssss5kk.", 11: "....kCDRDDCk....", 12: "....kbbYbbbk....", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"keeper_up_lift_a": ["keeper_up_a", { 1: ".k..kkkkk1kk..k.", 2: "ksk.k11155111ksk", 3: "kDk1155555115kDk", 4: "kDk5555555555kDk", 5: "kDk5655565565kDk", 6: ".kk5655565565kk.", 11: "....kwwRwwwk....", 12: "....kwwRwwwk...." }],
	"keeper_up_lift_b": ["keeper_up_a", { 1: ".k..kkkkk1kk..k.", 2: "ksk.k11155111ksk", 3: "kDk1155555115kDk", 4: "kDk5555555555kDk", 5: "kDk5655565565kDk", 6: ".kk5655565565kk.", 11: "....kwwRwwwk....", 12: "....kwwRwwwk....", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"keeper_side_lift_a": ["keeper_side_a", { 0: ".......kk...ksk.", 1: "....kkkk1kk.kDk.", 2: "...k1115511kkDk.", 3: "..k1155555511kDk", 4: "..k5555555555kDk", 5: "..k55555s5ss5kk.", 11: "..kRk.kDDCDk....", 12: "..kk..kbbbbk....", 13: "......kEEEEk...." }],
	"keeper_side_lift_b": ["keeper_side_a", { 0: ".......kk...ksk.", 1: "....kkkk1kk.kDk.", 2: "...k1115511kkDk.", 3: "..k1155555511kDk", 4: "..k5555555555kDk", 5: "..k55555s5ss5kk.", 11: "..kRk.kDDCDk....", 12: "..kk..kbbbbk....", 13: "......kEEEEk....", 14: ".....kBk.kBk....", 15: ".....kk...kk...." }],
	"keeper_down_atk": ["keeper_down_a", { 11: "....kCDRDDCDk...", 12: "....kbbYbbbsk...", 13: "...kEDDkDDEk....", 14: "..kBBk..kBBk....", 15: "...kk....kk....." }],
	"keeper_up_atk": ["keeper_up_a", { 11: "...kDwwRwwwk....", 12: "...kswwRwwwk....", 13: "...kcwwkwwck....", 14: "...kBBk..kBBk...", 15: "....kk....kk...." }],
	"keeper_side_atk": ["keeper_side_a", { 12: "..kk..kbbbbk....", 13: ".....kEEkEEk....", 14: "....kBk..kBk....", 15: "....kk....kk...." }],
	"woodcutter_down_b": ["woodcutter_down_a", { 12: "...krnnYnnnsk...", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"woodcutter_up_b": ["woodcutter_up_a", { 12: "...krrRrRRrsk...", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"woodcutter_side_b": ["woodcutter_side_a", { 12: "......knnnnk....", 13: "......kEEsEk....", 14: ".....kBk.kBk....", 15: ".....kk...kk...." }],
	"woodcutter_down_lift_a": ["woodcutter_down_a", { 1: ".k...kwwwwk...k.", 2: "kskkkkGGGGkkkksk", 3: "krkGGgGGgGGgGkrk", 4: "krkGgGGgGGgGGkrk", 5: "kRkjjjjjjjjjjkRk", 6: ".kk5ssssssss5kk.", 11: "....kRrRRrRk....", 12: "....knnYnnnk...." }],
	"woodcutter_down_lift_b": ["woodcutter_down_a", { 1: ".k...kwwwwk...k.", 2: "kskkkkGGGGkkkksk", 3: "krkGGgGGgGGgGkrk", 4: "krkGgGGgGGgGGkrk", 5: "kRkjjjjjjjjjjkRk", 6: ".kk5ssssssss5kk.", 11: "....kRrRRrRk....", 12: "....knnYnnnk....", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"woodcutter_up_lift_a": ["woodcutter_up_a", { 1: ".k...kwwwwk...k.", 2: "kskkkkGGGGkkkksk", 3: "krkGGgGGgGGgGkrk", 4: "krkGgGGgGGgGGkrk", 5: "kRkjjjjjjjjjjkRk", 6: ".kk5565565565kk.", 11: "....krRrRrRk....", 12: "....kRrRrRrk...." }],
	"woodcutter_up_lift_b": ["woodcutter_up_a", { 1: ".k...kwwwwk...k.", 2: "kskkkkGGGGkkkksk", 3: "krkGGgGGgGGgGkrk", 4: "krkGgGGgGGgGGkrk", 5: "kRkjjjjjjjjjjkRk", 6: ".kk5565565565kk.", 11: "....krRrRrRk....", 12: "....kRrRrRrk....", 14: "....kBBkkkk.....", 15: ".....kk........." }],
	"woodcutter_side_lift_a": ["woodcutter_side_a", { 0: "......kkk...ksk.", 1: ".....kwwwk..krk.", 2: "...kkkGGGkkkkrk.", 3: "..kGGgGGgGGgkkrk", 4: "..kGgGGgGGgGGkRk", 5: "..kjjjjjjjjjjkk.", 13: "......kEEEEk...." }],
	"woodcutter_side_lift_b": ["woodcutter_side_a", { 0: "......kkk...ksk.", 1: ".....kwwwk..krk.", 2: "...kkkGGGkkkkrk.", 3: "..kGGgGGgGGgkkrk", 4: "..kGgGGgGGgGGkRk", 5: "..kjjjjjjjjjjkk.", 12: "......knnnnk....", 13: "......kEEEEk....", 14: ".....kBk.kBk....", 15: ".....kk...kk...." }],
	"woodcutter_down_atk": ["woodcutter_down_a", { 11: "....krRrRRrRk...", 12: "....knnYnnnsk...", 13: "...kEDDkDDEk....", 14: "..kBBk..kBBk....", 15: "...kk....kk....." }],
	"woodcutter_up_atk": ["woodcutter_up_a", { 11: "...krRrRRrRk....", 12: "...ksRrRRrRk....", 13: "...kEDDkDDEk....", 14: "...kBBk..kBBk...", 15: "....kk....kk...." }],
	"woodcutter_side_atk": ["woodcutter_side_a", { 12: "......knnnnk....", 13: ".....kEEkEEk....", 14: "....kBk..kBk....", 15: "....kk....kk...." }],
	# the chop's wind-up (painter.gd's _keeper): both arms up with the axe raised over the head, feet planted wide
	"woodcutter_down_raise": ["woodcutter_down_a", { 1: ".k...kwwwwk...k.", 2: "kskkkkGGGGkkkksk", 3: "krkGGgGGgGGgGkrk", 4: "krkGgGGgGGgGGkrk", 5: "kRkjjjjjjjjjjkRk", 6: ".kk5ssssssss5kk.", 11: "....kRrRRrRk....", 12: "....knnYnnnk....", 13: "...kEDDkkDDEk...", 14: "..kBBk....kBBk..", 15: "..kk........kk.." }],
	"woodcutter_up_raise": ["woodcutter_up_a", { 1: ".k...kwwwwk...k.", 2: "kskkkkGGGGkkkksk", 3: "krkGGgGGgGGgGkrk", 4: "krkGgGGgGGgGGkrk", 5: "kRkjjjjjjjjjjkRk", 6: ".kk5565565565kk.", 11: "....krRrRrRk....", 12: "....kRrRrRrk....", 13: "...kEDDkkDDEk...", 14: "..kBBk....kBBk..", 15: "..kk........kk.." }],
	"woodcutter_side_raise": ["woodcutter_side_a", { 0: ".ksk..kkk.......", 1: ".krk.kwwwk......", 2: ".krkkkGGGkkk....", 3: ".kRkGgGGgGGgk...", 13: "......kEEEEk....", 14: ".....kBk.kBk....", 15: "....kk....kk...." }],
	"mage_down_b": ["mage_down_a", { 12: "...kxVQYQQVsk...", 14: "...kVVVVVVVVk...", 15: "....kBk...kk...." }],
	"mage_up_b": ["mage_up_a", { 12: "...ksQQQQQQxk...", 15: "....kk...kBk...." }],
	"mage_side_b": ["mage_side_a", { 12: "....kQQQQQxk....", 13: "...kQQQQQQQQk...", 14: "...kVVVVVVVVk...", 15: "....kBk...kBk..." }],
	"mage_down_lift_a": ["mage_down_a", { 1: ".k....kQQk....k.", 2: "ksk..kQQQQk..ksk", 3: "kQk.kQQYQQQk.kQk", 4: "kQkkQQQQQQQQkkQk", 5: "kQkQQVVVVVVQQkQk", 6: ".kkQVssssssVQkk.", 11: "....kQQYQQQk....", 12: "....kQQYQQQk...." }],
	"mage_down_lift_b": ["mage_down_a", { 1: ".k....kQQk....k.", 2: "ksk..kQQQQk..ksk", 3: "kQk.kQQYQQQk.kQk", 4: "kQkkQQQQQQQQkkQk", 5: "kQkQQVVVVVVQQkQk", 6: ".kkQVssssssVQkk.", 11: "....kQQYQQQk....", 12: "....kQQYQQQk....", 15: "....kBk...kk...." }],
	"mage_up_lift_a": ["mage_up_a", { 1: ".k....kQQk....k.", 2: "ksk..kQQQQk..ksk", 3: "kQk.kQQQQQQk.kQk", 4: "kQkkQQQQQQQQkkQk", 5: "kQkQQQQVQQQQQkQk", 6: ".kkQQQVQQQQVQkk.", 11: "....kQQQQQQk....", 12: "....kQQQQQQk...." }],
	"mage_up_lift_b": ["mage_up_a", { 1: ".k....kQQk....k.", 2: "ksk..kQQQQk..ksk", 3: "kQk.kQQQQQQk.kQk", 4: "kQkkQQQQQQQQkkQk", 5: "kQkQQQQVQQQQQkQk", 6: ".kkQQQVQQQQVQkk.", 11: "....kQQQQQQk....", 12: "....kQQQQQQk....", 15: "....kk...kBk...." }],
	"mage_side_lift_a": ["mage_side_a", { 0: "......kk....ksk.", 1: ".....kQQk...kQk.", 2: "....kQQQQk..kQk.", 3: "...kQQQYQQk.kQk.", 4: "..kkQQQQQQQkkQk.", 5: "..kQQQQQVVVVkk..", 12: "....kQQQQQQk...." }],
	"mage_side_lift_b": ["mage_side_a", { 0: "......kk....ksk.", 1: ".....kQQk...kQk.", 2: "....kQQQQk..kQk.", 3: "...kQQQYQQk.kQk.", 4: "..kkQQQQQQQkkQk.", 5: "..kQQQQQVVVVkk..", 12: "....kQQQQQQk....", 13: "...kQQQQQQQQk...", 14: "...kVVVVVVVVk...", 15: "....kBk...kBk..." }],
	"mage_down_atk": ["mage_down_a", { 10: "....kQxFFxQk....", 11: "...kQxFfWfxQk...", 12: "...ksQxFFxQsk...", 13: "...kQQQYQQQQk..." }],
	"mage_up_atk": ["mage_up_a", { 10: "..kxFVQQQQVFxk..", 11: "...kxQQQQQQxk...", 12: "...ksQQQQQQsk..." }],
	"mage_side_atk": ["mage_side_a", { 11: "....kQQQQYQkxFx.", 12: "....kQQQQQsxFfF.", 13: "...kQQQQQQQkxFx." }],
	"torch_out": ["torch", { 2: ".kZKzKKzKKzKKZk." }],
	"shade_b": ["shade_a", { 13: "..k888k888k88k..", 14: "..kkkk.kkk.kkk.." }],
	"big_slime_b": ["big_slime_a", {
		1: "........................", 2: "........kkkkkkkk........", 3: ".....kkkGGGGGGGGkkk.....",
		4: "...kkGGhhhGGGGGGGGGkk...", 6: ".kGGGkkGGGGGGGGGGkkGGGk.",
	}],
	"thief_b": ["thief_a", { 13: "..kkkkOOkkOOkk..", 14: "......kkk.kkk..." }],
	"boar_b": ["boar_a", { 13: "...kBkkBk.kBk...", 14: "...kk.kk...kk..." }],
	"spitter_b": ["spitter_a", { 10: "kDyyyyyyyyyyyyDk", 11: "kEyyyyyyyyyyyyEk", 12: ".kEkkyyyyyykkEk." }],
	"drummer_b": ["drummer_a", { 8: "..kFFFFkkFFFFk.y", 9: "...kkkkkkkkkk.y.", 10: ".yFkwwwwwwwwkF.." }],
	"boar_chief_b": ["boar_chief_a", { 15: ".kBBk..kBBk.kBBk.kBBk...", 16: ".kBBk..kBBk.kBBk.kBBk...", 17: ".kkkk..kkkk.kkkk.kkkk..." }],
	# the shade lord's decoys: its shape under a plain hood, no crown, no eyes (Looks.DECOYS)
	"shade_decoy_a": ["shade_lord_a", { 0: "........................", 1: "........................", 2: "..........kkkkkk........", 3: "........kk888888kk......", 4: "......kk8888888888k.....", 9: "....k7799999999988k.....", 10: "....k8899999999988k....." }],
	"shade_decoy_b": ["shade_lord_b", { 0: "........................", 1: "........................", 2: "..........kkkkkk........", 3: "........kk888888kk......", 4: "......kk8888888888k.....", 9: "....k7799999999988k.....", 10: "....k8899999999988k....." }],
}


## The stronger tiers of the regular enemy kinds (Config.TIERS) are the same grids in other colours, made when the
## atlas is: kind -> one map per tier from 2, PALETTE key -> the colour its pixels take there. The outline, the
## empty pixel and white (TIER_KEEP) stay as they are; a map names every other colour of the kind's frames, so no
## pixel keeps its tier-1 colour by being forgotten (A1 checks). A tier's picture is its frame's name with "~" and
## the tier after it: "slime_a~2". Tier 2 is a colour of the kind's own; tier 3 is red for every kind, so the
## strongest read the same whatever they are.
const TIER_KEEP := [".", "_", "k", "W"]
const TIER_FRAMES := ["%s_a", "%s_b"] # the frames that get tiers: an enemy kind's walking frames (Looks.FRAMES)
const TIERS := {
	"slime": [
		{ "h": "#ffe3a3", "g": "#ffa63f", "G": "#d9742a" }, # orange
		{ "h": "#ffb4a4", "g": "#f2584a", "G": "#bd2f3b" }, # red
	],
	"big_slime": [
		{ "h": "#ffe3a3", "G": "#d9742a", "j": "#97461f" },
		{ "h": "#ffb4a4", "G": "#bd2f3b", "j": "#7a1a2c" },
	],
	"bat": [
		{ "p": "#fff09a", "P": "#e3b232", "q": "#8c6219", "e": "#ef4b5a" }, # gold
		{ "p": "#ff8296", "P": "#cc3049", "q": "#7c1832", "e": "#ffe04a" }, # red
	],
	"shade": [
		{ "7": "#63b3a6", "8": "#3b7f77", "9": "#173d3a", "l": "#b5e3ff" }, # teal
		{ "7": "#c25c74", "8": "#8a2f4c", "9": "#3d1022", "l": "#b5e3ff" }, # red
	],
	"thief": [
		{ "o": "#b3b3bd", "O": "#7f7f8e", "n": "#54546a" }, # ash
		{ "o": "#e2603f", "O": "#ab3528", "n": "#6e1f1d" }, # red
	],
	"boar": [
		{ "b": "#9c9caa", "B": "#666677", "S": "#d4a48e", "i": "#ef4b5a" }, # ash
		{ "b": "#cf4a36", "B": "#8a2424", "S": "#f0a080", "i": "#ffd84a" }, # red
	],
	"moth": [
		{ "w": "#fff2a8", "c": "#e8c95a", "d": "#a8862e", "m": "#6a5320", "Y": "#ef4b5a" }, # yellow
		{ "w": "#ffb4a4", "c": "#f2584a", "d": "#bd2f3b", "m": "#6e1f1d", "Y": "#ffe04a" }, # red
	],
	"spitter": [
		{ "C": "#c9a0f0", "D": "#9360c9", "E": "#5b3690", "y": "#f3dcae", "e": "#fff09a" }, # violet
		{ "C": "#ff8f80", "D": "#d9443c", "E": "#8a1f2c", "y": "#ffd9a0", "e": "#fff6c0" }, # red
	],
	"drummer": [
		{ "F": "#7fb6f0", "w": "#dfe6f2", "y": "#d9c9a0", "O": "#6f6f88", "n": "#45455e" }, # blue
		{ "F": "#f2584a", "w": "#f6e0d0", "y": "#ffd0a0", "O": "#8a3a30", "n": "#5a1f1d" }, # red
	],
}


## Every picture the game paints comes out of one shared texture, the atlas, packed at the start from the grids
## above (art stays text: nothing is saved as a file). Godot draws runs of pictures from the same texture as one
## batch, so a crowd sorted by depth with kinds mixed costs a few draw calls instead of one or more per enemy.
## Each sprite is there four times (as is, mirrored, white, mirrored white) and with its rim; pictures asked for
## later (an enemy's eyes, the painter's hedges and clearing) go into room kept free under them.
const ATLAS_WIDTH := 1024
const ATLAS_SPARE := 256 # rows kept free under what is packed at the start
const ATLAS_PAD := 1 # empty pixels round each picture, so none samples its neighbour

static var _textures := {} # picture key -> its region of the atlas (an AtlasTexture), or its own texture when the atlas is full
static var _atlas: Image
static var _alone := {} # sprite -> its own texture (alone())
static var _feet := {} # sprite -> foot(), found once
static var _atlas_texture: ImageTexture
static var _shelf := Vector2i.ZERO # where the next picture goes on the shelf being filled
static var _shelf_height := 0


static func names() -> Array:
	return SPRITES.keys() + VARIANTS.keys()


## Every tier's picture of every frame TIERS colours, by name ("slime_a~2").
static func tier_names() -> Array:
	var out := []
	for kind in TIERS:
		for frame in TIER_FRAMES:
			for t in TIERS[kind].size():
				out.append(tiered(frame % kind, t + 2))
	return out


## The picture of a sprite at an enemy tier: the sprite itself at tier 1.
static func tiered(sprite: String, tier: int) -> String:
	return sprite if tier <= 1 else "%s~%d" % [sprite, tier]


## The finished rows of a sprite, with a variant's rows put in place. A tier's rows are its frame's.
static func rows(sprite: String) -> Array:
	if "~" in sprite:
		sprite = sprite.get_slice("~", 0)
	if SPRITES.has(sprite):
		return SPRITES[sprite]
	var v: Array = VARIANTS[sprite]
	var out: Array = SPRITES[v[0]].duplicate()
	for i in v[1]:
		out[i] = v[1][i]
	return out


static func image(sprite: String) -> Image:
	var grid := rows(sprite)
	var colours := tier_colours(sprite)
	var img := Image.create_empty(grid[0].length(), grid.size(), false, Image.FORMAT_RGBA8)
	for y in grid.size():
		for x in grid[y].length():
			var key: String = grid[y][x]
			img.set_pixel(x, y, Color(colours[key]) if colours.has(key) else PALETTE[key])
	return img


## The colour map a tier's picture is painted with ({} for a sprite that is no tier's): from its name, "<kind>_a~2".
static func tier_colours(sprite: String) -> Dictionary:
	if not "~" in sprite:
		return {}
	var frame := sprite.get_slice("~", 0)
	return TIERS[frame.substr(0, frame.rfind("_"))][int(sprite.get_slice("~", 1)) - 2]


## A sprite as a texture: mirrored left to right when flip, in its hit-flash white when white.
static func texture(sprite: String, flip := false, white := false) -> Texture2D:
	return picture("%s%s%s" % [sprite, "<" if flip else "", "!" if white else ""])


## A sprite as a texture of its own, outside the atlas, for the words' layer (src/ui.gd): a Control there scales its
## picture to sizes that fall between screen pixels, and only a texture of its own samples its edge exactly as it
## always has. The field and the HUD pictures, drawn on whole pixels, come from the atlas.
static func alone(sprite: String) -> Texture2D:
	if not _alone.has(sprite):
		_alone[sprite] = ImageTexture.create_from_image(image(sprite))
	return _alone[sprite]


## A one-pixel ring just outside a sprite's shape, in white, one pixel bigger on every side: the painter tints it and
## draws it where the night does not dim it, so a thing on the ground keeps its silhouette in the dark.
static func rim(sprite: String) -> Texture2D:
	return picture(sprite + "#rim")


## Only the pixels of a sprite drawn with one PALETTE key, in white: the painter tints them and draws them where the
## night does not dim them, so the eyes of a thing out in the dark still show, on whichever frame it is.
static func only(sprite: String, key: String, flip := false) -> Texture2D:
	var id := "%s#%s%s" % [sprite, key, "<" if flip else ""]
	if not _textures.has(id):
		prepare_only([[sprite, key, flip]])
	return _textures[id]


## Packs the only() pictures of these [sprite, key, flip] all at once, so the atlas is sent to the screen once at the
## start instead of once for each the first time it shows.
static func prepare_only(wanted: Array) -> void:
	var images := {}
	for w in wanted:
		images["%s#%s%s" % [w[0], w[1], "<" if w[2] else ""]] = _only_image(w[0], w[1], w[2])
	pack(images)


## A picture already packed (pack(), or a sprite's key: name, then "<" mirrored, "!" white, or "#rim").
static func picture(key: String) -> Texture2D:
	if _atlas == null:
		_start_atlas()
	return _textures[key]


## Packs more pictures into the atlas's free room, under their keys, and sends the atlas to the screen once. One
## that does not fit gets a texture of its own: right, only not batched.
static func pack(images: Dictionary) -> void:
	if _atlas == null:
		_start_atlas()
	images = images.duplicate()
	for key in images.keys():
		if _textures.has(key): # packed before (a second painter asks for the same hedges)
			images.erase(key)
	if images.is_empty():
		return
	var spots := _shelve(images)
	for key in images:
		var img: Image = images[key]
		var spot: Vector2i = spots[key]
		if spot.y + img.get_height() + ATLAS_PAD > _atlas.get_height():
			_textures[key] = ImageTexture.create_from_image(img)
			continue
		_atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), spot)
		_textures[key] = _region(spot, img.get_size())
	_atlas_texture.update(_atlas)


## The atlas as an image: what pack() has put where so far (tools/art_sheet.gd saves it to look at).
static func atlas_image() -> Image:
	if _atlas == null:
		_start_atlas()
	return _atlas


## Every sprite four ways and its rim, in names() order and then every tier's, shelf by shelf.
static func _start_atlas() -> void:
	var images := {}
	for sprite in names() + tier_names():
		var img := image(sprite)
		var mirrored: Image = img.duplicate()
		mirrored.flip_x()
		images[sprite] = img
		images[sprite + "<"] = mirrored
		images[sprite + "!"] = whitened(img)
		images[sprite + "<!"] = whitened(mirrored)
		images[sprite + "#rim"] = _rim_image(img)
	var spots := _shelve(images)
	var height := _shelf.y + _shelf_height + ATLAS_SPARE
	_atlas = Image.create_empty(ATLAS_WIDTH, height, false, Image.FORMAT_RGBA8)
	for key in images:
		var img: Image = images[key]
		_atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), spots[key])
	_atlas_texture = ImageTexture.create_from_image(_atlas)
	for key in images:
		_textures[key] = _region(spots[key], images[key].get_size())


## Where each picture goes: left to right along a shelf, a new shelf under it when the row is full.
static func _shelve(images: Dictionary) -> Dictionary:
	var spots := {}
	for key in images:
		var size: Vector2i = images[key].get_size() + Vector2i(ATLAS_PAD, ATLAS_PAD) * 2
		if _shelf.x + size.x > ATLAS_WIDTH:
			_shelf = Vector2i(0, _shelf.y + _shelf_height)
			_shelf_height = 0
		spots[key] = _shelf + Vector2i(ATLAS_PAD, ATLAS_PAD)
		_shelf.x += size.x
		_shelf_height = maxi(_shelf_height, size.y)
	return spots


static func _region(at: Vector2i, size: Vector2i) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = _atlas_texture
	t.region = Rect2(at, size)
	return t


static func _rim_image(img: Image) -> Image:
	var out := Image.create_empty(img.get_width() + 2, img.get_height() + 2, false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			if _solid(img, x - 1, y - 1):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _solid(img, x - 1 + d.x, y - 1 + d.y):
					out.set_pixel(x, y, Color.WHITE)
					break
	return out


static func _only_image(sprite: String, key: String, flip: bool) -> Image:
	var grid := rows(sprite)
	var img := Image.create_empty(grid[0].length(), grid.size(), false, Image.FORMAT_RGBA8)
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] == key:
				img.set_pixel(x, y, Color.WHITE)
	if flip:
		img.flip_x()
	return img


## How many rows down a sprite's lowest drawn pixel is, plus one: where it stands on the ground.
static func foot(sprite: String) -> int:
	if _feet.has(sprite):
		return _feet[sprite]
	var grid := rows(sprite)
	_feet[sprite] = grid.size()
	for y in range(grid.size() - 1, -1, -1):
		if grid[y].count(".") < grid[y].length():
			_feet[sprite] = y + 1
			break
	return _feet[sprite]


static func _solid(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5


## The same picture with everything inside its outline turned white, for the moment something is hit.
static func whitened(img: Image) -> Image:
	var out: Image = img.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.5 and not c.is_equal_approx(PALETTE["k"]):
				out.set_pixel(x, y, Color.WHITE)
	return out


## What is wrong with one grid, as messages; empty when it is fine.
static func grid_problems(sprite: String, grid: Array) -> Array:
	var out := []
	if grid.is_empty():
		return ["%s: no rows" % sprite]
	for y in grid.size():
		var row: String = grid[y]
		if row.length() != grid[0].length():
			out.append("%s row %d is %d wide, row 0 is %d. Fix: make every row the same width." % [sprite, y, row.length(), grid[0].length()])
		for x in row.length():
			if not PALETTE.has(row[x]):
				out.append("%s row %d col %d: '%s' is not in PALETTE. Fix: use a PALETTE key or add the colour." % [sprite, y, x, row[x]])
	return out


## What is wrong with the colour maps of one kind's tiers, given the grids of the frames they paint: a colour of the
## frames that a map does not name (it would keep its tier-1 colour), a key a map names that no frame uses (it was
## meant for some other picture), or a colour that is not a colour.
static func tier_problems(kind: String, maps: Array, frames: Array) -> Array:
	var used := {}
	for grid in frames:
		for row in grid:
			for c in row:
				if not TIER_KEEP.has(c):
					used[c] = true
	var out := []
	for t in maps.size():
		for c in used:
			if not maps[t].has(c):
				out.append("TIERS %s tier %d does not colour '%s', which its frames use. Fix: give '%s' a colour in that map in src/art/sprites.gd." % [kind, t + 2, c, c])
		for c in maps[t]:
			if not used.has(c):
				out.append("TIERS %s tier %d colours '%s', which none of its frames use. Fix: remove it from that map in src/art/sprites.gd." % [kind, t + 2, c])
			elif not Color.html_is_valid(maps[t][c]):
				out.append("TIERS %s tier %d: '%s' is not a colour. Fix: write it as \"#rrggbb\"." % [kind, t + 2, maps[t][c]])
	return out


## Rule A1 over every sprite and variant, and over the tiers' colour maps.
static func problems() -> Array:
	var out := []
	for kind in TIERS:
		var frames := TIER_FRAMES.map(func(f): return f % kind)
		if not missing(frames).is_empty():
			out.append("TIERS names '%s', which has no frames %s. Fix: name an enemy kind." % [kind, frames])
			continue
		out.append_array(tier_problems(kind, TIERS[kind], frames.map(func(f): return rows(f))))
	for sprite in VARIANTS:
		var v: Array = VARIANTS[sprite]
		if not SPRITES.has(v[0]):
			out.append("%s: base sprite '%s' does not exist." % [sprite, v[0]])
			continue
		for i in v[1]:
			if i < 0 or i >= SPRITES[v[0]].size():
				out.append("%s: row %d is outside its base sprite '%s'." % [sprite, i, v[0]])
	if not out.is_empty():
		return out
	for sprite in names():
		out.append_array(grid_problems(sprite, rows(sprite)))
	return out


## Rule A2: which of these sprite names is not drawn, as messages. The painter asks for some sprites by a name
## built from rule data (an upgrade's icon), and a missing one would only fail once that upgrade shows up in a game.
static func missing(wanted: Array) -> Array:
	var out := []
	for sprite in wanted:
		if not names().has(sprite):
			out.append("'%s' is not drawn. Fix: add a grid with that name to SPRITES." % sprite)
	return out


## A1 and A2 check themselves (G4): a ragged grid, an unknown character and a missing sprite must be caught,
## a clean grid and a drawn sprite must pass.
static func selftest() -> Array:
	var fails := []
	if missing(["no such sprite"]).is_empty():
		fails.append("[A2] missed a sprite that is not drawn")
	if not missing([SPRITES.keys()[0]]).is_empty():
		fails.append("[A2] flagged a sprite that is drawn")
	if grid_problems("x", ["kk", "k"]).is_empty():
		fails.append("[A1] missed a ragged grid")
	if grid_problems("x", ["k?"]).is_empty():
		fails.append("[A1] missed a character that is not in PALETTE")
	if not grid_problems("x", ["k.", ".k"]).is_empty():
		fails.append("[A1] flagged a clean grid")
	if tier_problems("x", [{ "g": "#ff0000" }], [["kgW"], ["kGg"]]).is_empty():
		fails.append("[A1] missed a tier map that leaves a colour of its frames out")
	if tier_problems("x", [{ "g": "#ff0000", "G": "#00ff00", "h": "#0000ff" }], [["kgW"], ["kGg"]]).is_empty():
		fails.append("[A1] missed a tier map naming a colour its frames do not use")
	if tier_problems("x", [{ "g": "red-ish", "G": "#00ff00" }], [["kgW"], ["kGg"]]).is_empty():
		fails.append("[A1] missed a tier colour that is not a colour")
	if not tier_problems("x", [{ "g": "#ff0000", "G": "#00ff00" }], [["kgW"], ["kGg"]]).is_empty():
		fails.append("[A1] flagged a tier map that colours every colour of its frames")
	return fails
