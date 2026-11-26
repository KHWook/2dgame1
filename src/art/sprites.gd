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
	"shadow_huge": [
		"....____________________....",
		".__________________________.",
		"____________________________",
		".__________________________.",
		"....____________________....",
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
		".............kkkkkkkkk.............",
		"..........kkkaaaaaaaaakkk..........",
		"........kkkaaaaaaaaaaaaakkk........",
		".......kkaaaaakkkkkkkaaaaakk.......",
		"......kaaaakkk.......kkkaaaak......",
		".....kaaakk.............kkaaak.....",
		"....kaaakk...............kkaaak....",
		"...kaaak...................kaaak...",
		"..kkaak.....................kAAkk..",
		"..kaakk.....................kkAAk..",
		".kkaak.......................kAAkk.",
		".kaak.........................kAAk.",
		".kaak.........................kAAk.",
		"kaaak.........................kAAAk",
		"kaak...........................kAAk",
		"kaak...........................kAAk",
		"kAAk...........................kAAk",
		"kAAk...........................kAAk",
		"kAAk...........................kAAk",
		"kAAk...........................kZZk",
		"kAAk...........................kZZk",
		"kAAAk.........................kZZZk",
		".kAAk.........................kZZk.",
		".kAAk.........................kZZk.",
		".kkAAk.......................kZZkk.",
		"..kAAkk.....................kkZZk..",
		"..kkAAk.....................kZZkk..",
		"...kZZZk...................kZZZk...",
		"....kZZZkk...............kkZZZk....",
		".....kZZZkk.............kkZZZk.....",
		"......kZZZZkkk.......kkkZZZZk......",
		".......kkZZZZZkkkkkkkZZZZZkk.......",
		"........kkkZZZZZZZZZZZZZkkk........",
		"..........kkkZZZZZZZZZkkk..........",
		".............kkkkkkkkk.............",
	],
	"pad_knob": [
		".....kkkkk.....",
		"...kkaaaAAkk...",
		"..kaaaaAAAAAk..",
		".kaaaaAAAAAAAk.",
		".kaaaAAAAAAAAk.",
		"kaaaAAAAAAAAAAk",
		"kaaAAAAAAAAAAZk",
		"kaAAAAAAAAAAZZk",
		"kAAAAAAAAAAZZZk",
		"kAAAAAAAAAZZZZk",
		".kAAAAAAAZZZZk.",
		".kAAAAAAZZZZZk.",
		"..kAAAAZZZZZk..",
		"...kkAZZZZkk...",
		".....kkkkk.....",
	],
	"button": [
		"...........kkkkkkk...........",
		"........kkkTTTTTTTkkk........",
		"......kkTTTKKKKKKKTTTkk......",
		".....kkTTKKKKKKKKKKKTTkk.....",
		"....kTTKKKKKKKKKKKKKKKTTk....",
		"...kTTKKKKKKKKKKKKKKKKKTTk...",
		"..kkTKKKKKKKKKKKKKKKKKKKTkk..",
		"..kTKKKKKKKKKKKKKKKKKKKKKTk..",
		".kTTKKKKKKKKKKKKKKKKKKKKKTTk.",
		".kTKKKKKKKKKKKKKKKKKKKKKKKTk.",
		".kZKKKKKKKKKKKKKKKKKKKKKKKZk.",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		"kZKKKKKKKKKKKKKKKKKKKKKKKKKZk",
		".kZKKKKKKKKKKKKKKKKKKKKKKKZk.",
		".kZKKKKKKKKKKKKKKKKKKKKKKKZk.",
		".kZZKKKKKKKKKKKKKKKKKKKKKZZk.",
		"..kZKKKKKKKKKKKKKKKKKKKKKZk..",
		"..kkZKKKKKKKKKKKKKKKKKKKZkk..",
		"...kZZKKKKKKKKKKKKKKKKKZZk...",
		"....kZZKKKKKKKKKKKKKKKZZk....",
		".....kkZZKKKKKKKKKKKZZkk.....",
		"......kkZZZKKKKKKKZZZkk......",
		"........kkkZZZZZZZkkk........",
		"...........kkkkkkk...........",
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
	"torch_out": ["torch", { 2: ".kZKzKKzKKzKKZk." }],
	"shade_b": ["shade_a", { 13: "..k888k888k88k..", 14: "..kkkk.kkk.kkk.." }],
	"big_slime_b": ["big_slime_a", {
		1: "........................", 2: "........kkkkkkkk........", 3: ".....kkkGGGGGGGGkkk.....",
		4: "...kkGGhhhGGGGGGGGGkk...", 6: ".kGGGkkGGGGGGGGGGkkGGGk.",
	}],
	"thief_b": ["thief_a", { 13: "..kkkkOOkkOOkk..", 14: "......kkk.kkk..." }],
	"boar_b": ["boar_a", { 13: "...kBkkBk.kBk...", 14: "...kk.kk...kk..." }],
}


static var _textures := {} # sprite name plus its flip and white marks -> texture, made the first time it is asked for


static func names() -> Array:
	return SPRITES.keys() + VARIANTS.keys()


## The finished rows of a sprite, with a variant's rows put in place.
static func rows(sprite: String) -> Array:
	if SPRITES.has(sprite):
		return SPRITES[sprite]
	var v: Array = VARIANTS[sprite]
	var out: Array = SPRITES[v[0]].duplicate()
	for i in v[1]:
		out[i] = v[1][i]
	return out


static func image(sprite: String) -> Image:
	var grid := rows(sprite)
	var img := Image.create_empty(grid[0].length(), grid.size(), false, Image.FORMAT_RGBA8)
	for y in grid.size():
		for x in grid[y].length():
			img.set_pixel(x, y, PALETTE[grid[y][x]])
	return img


## A sprite as a texture: mirrored left to right when flip, in its hit-flash white when white.
static func texture(sprite: String, flip := false, white := false) -> Texture2D:
	var key := "%s%s%s" % [sprite, "<" if flip else "", "!" if white else ""]
	if not _textures.has(key):
		var img := image(sprite)
		if flip:
			img.flip_x()
		_textures[key] = ImageTexture.create_from_image(whitened(img) if white else img)
	return _textures[key]


## A one-pixel ring just outside a sprite's shape, in white, one pixel bigger on every side: the painter tints it and
## draws it where the night does not dim it, so a thing on the ground keeps its silhouette in the dark.
static func rim(sprite: String) -> Texture2D:
	var key := sprite + "#rim"
	if not _textures.has(key):
		var img := image(sprite)
		var out := Image.create_empty(img.get_width() + 2, img.get_height() + 2, false, Image.FORMAT_RGBA8)
		for y in out.get_height():
			for x in out.get_width():
				if _solid(img, x - 1, y - 1):
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _solid(img, x - 1 + d.x, y - 1 + d.y):
						out.set_pixel(x, y, Color.WHITE)
						break
		_textures[key] = ImageTexture.create_from_image(out)
	return _textures[key]


## Only the pixels of a sprite drawn with one PALETTE key, in white: the painter tints them and draws them where the
## night does not dim them, so the eyes of a thing out in the dark still show, on whichever frame it is.
static func only(sprite: String, key: String, flip := false) -> Texture2D:
	var id := "%s#%s%s" % [sprite, key, "<" if flip else ""]
	if not _textures.has(id):
		var grid := rows(sprite)
		var img := Image.create_empty(grid[0].length(), grid.size(), false, Image.FORMAT_RGBA8)
		for y in grid.size():
			for x in grid[y].length():
				if grid[y][x] == key:
					img.set_pixel(x, y, Color.WHITE)
		if flip:
			img.flip_x()
		_textures[id] = ImageTexture.create_from_image(img)
	return _textures[id]


## How many rows down a sprite's lowest drawn pixel is, plus one: where it stands on the ground.
static func foot(sprite: String) -> int:
	var grid := rows(sprite)
	for y in range(grid.size() - 1, -1, -1):
		if grid[y].count(".") < grid[y].length():
			return y + 1
	return grid.size()


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


## Rule A1 over every sprite and variant.
static func problems() -> Array:
	var out := []
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
	return fails
