extends Node

# Constants
var MANA_TO_ENERGY_RATIO:float = 1e6
var MANA_PER_BLOCK:float = 4
var MANA_PER_COIN:float = 20
var ENERGY_LINK_SHARE:float = 0.5

var DISPEL_MANA_COST:float = MANA_PER_BLOCK * 50 # 5 lines worth

# Colors
class COLOR:
	static var PROGUSEFUL =  Color8(0xFF, 0xAA, 0x00)
	static var PROGRESSION = Color8(0xAA, 0x55, 0xAA)
	static var USEFUL =      Color8(0x55, 0x55, 0xFF)
	static var FILLER =      Color8(0x55, 0xAA, 0xFF)
	static var TRAP =        Color8(0xFF, 0x55, 0x00)
	static var DEATH =       Color8(0xFF, 0x00, 0x00)
	static var SPECIAL =     Color8(0x55, 0xAA, 0x00)
	static var ERROR =       Color8(0xFF, 0x55, 0x00)

# Piece Color Ids
var LEGACY_PIECE_COLOR_MAPPINGS:Array[int] = [
	0,
	1,
	15,
	2,
	4,
	6,
	8,
	10,
	11,
	12,
	13,
	14,
]
var NUMBER_OF_PIECE_COLORS_MIN = 1
var NUMBER_OF_PIECE_COLORS_MAX = 16

# Item + Location Data
class Data:
	static var OBJECT_TYPES:PackedStringArray = [
		"shape",
		"ability",
		"on_spawn",
		"on_lock",
		"modifier",
		"line_clear",
		"item_pickup",
	]
	var id:int
	var prettyName:StringName
	var internalName:StringName
	var tags:Dictionary[StringName, bool]
	var type:StringName
	func _init(arr=[]):
		arr.resize(4)
		id = arr[0] as int
		prettyName = arr[1] as StringName
		internalName = (arr[2] if arr[2] else prettyName.to_snake_case()) as StringName
		for tag in arr[3] as Array:
			tags[tag as StringName] = true
		for tag in OBJECT_TYPES:
			if tags.get(tag, false):
				type = tag
				break

class ItemData extends Data: pass
class LocationData extends Data: pass

@onready var ITEMS:Dictionary[int, ItemData] = [
	# Abilities (1-100)
	[1,   "Gravity",                  "gravity",                    [ "useful", "trap", "ability", "classic", "drop" ] ],
	[2,   "Soft Drop",                "soft_drop",                  [ "useful", "ability", "classic", "drop" ] ],
	[3,   "Hard Drop",                "hard_drop",                  [ "useful", "ability", "classic", "drop" ] ],
	[4,   "Rotate Clockwise",         "rotate_clockwise",           [ "progression", "useful", "ability", "classic", "rotate" ] ],
	[5,   "Rotate Counterclockwise",  "rotate_counterclockwise",    [ "progression", "useful", "ability", "classic", "rotate" ] ],
	[6,   "Ghost Piece",              "ghost_piece",                [ "useful", "ability", "classic" ] ],
	[7,   "Kick",                     "kick",                       [ "useful", "ability", "classic" ] ],
	# [8,   "Vertical Shove",           "vertical_shove",             [ "useful", "ability" ] ],
	# [9,   "Horizontal Shove",         "horizontal_shove",           [ "useful", "trap", "ability" ] ],
	[10,  "Lock Delay",               "lock_delay",                 [ "useful", "ability", "classic" ] ],

	# Progressive Items (101-200)
	[101, "Next Piece Slot",          "next_piece_slot",            [ "useful", "ability", "progressive" ] ],
	[102, "Hold Slot",                "hold_slot",                  [ "useful", "ability", "progressive" ] ],
	
	# Traps Items (201-300)
	[201, "Tutorial",                 "tutorial",                   [ "trap", "useful", "on_lock" ] ],
	[202, "Logic Tutorial",           "logic_tutorial",             [ "trap", "useful", "on_lock" ] ],
	[203, "Time to Fish!",            "fishing",                    [ "trap", "on_lock" ] ],
	[204, "Egg",                      "egg",                        [ "trap", "shape"] ],
	[205, "Curse",                    "enchantment_curse",          [ "trap", "modifier" ] ],
	[206, "Legendary Enchantment",    "enchantment_legendary",      [ "trap", "modifier" ] ],
	[207, "Epic Enchantment",         "enchantment_epic",           [ "trap", "modifier" ] ],
	[208, "Rare Enchantment",         "enchantment_rare",           [ "trap", "modifier"] ],
	[209, "Medium-Rare Enchantment",  "enchantment_uncommon",       [ "trap", "modifier"] ],
	[210, "Well Done!",               "welldone",                   [ "trap", "on_lock"] ],
	[211, "Crystal Trap",             "crystal_trap",               [ "trap", "on_spawn"] ],
	[212, "Random Trap",              "random_trap",                [ "trap", "on_spawn"] ],
	[213, "Water Trap",               "water_trap",                 [ "trap", "on_spawn" ] ],
	[214, "Pixellation Trap",         "pixellation_trap",           [ "trap", "on_spawn"] ],
	[215, "Fracture Trap",            "fracture_trap",              [ "trap", "on_spawn" ] ],
	[216, "Zoom Trap",                "zoom_trap",                  [ "trap", "on_lock" ] ],
	[217, "Impatience Trap",          "impatience_trap",            [ "trap", "on_spawn" ] ],
	[218, "In Space!",                "space_trap",                 [ "trap", "on_spawn"] ],

	# # Ones that might just be effects only, dunno
	# [000, "Premium Trap",             "", [ "trap" ] ],
	# [000, "Cutscene",                 "", [ "trap", "uncommon" ] ],
	# [000, "Transformation Trap",      "", [ "trap" ] ],
	# [000, "Momentum Trap",            "", [ "trap" ] ],
	# [000, "Glue Trap",                "", [ "trap" ] ],
	# [000, "Shatter Trap",             "", [ "trap" ] ],
	# [000, "Fire Trap",                "", [ "trap" ] ],
	# [000, "Camera Rotate Trap",       "", [ "trap" ] ],
	# [000, "Board Wipe Trap",          "", [ "trap" ] ],
	# [000, "Reverse Controls Trap",    "", [ "trap" ] ],
	# [000, "Latency Trap",             "", [ "trap" ] ],
	# [000, "Disable Rotate Trap",      "", [ "trap" ] ],
	# [000, "Disable Hold Trap",        "", [ "trap" ] ],
	# [000, "Dummy Trap",               "", [ "trap" ] ],
	# [000, "Flip Trap",                "", [ "trap" ] ],
	# [000, "Upside-Down Trap",         "", [ "trap" ] ],
	# [000, "Ice Trap",                 "", [ "trap" ] ],
	# [000, "Shuffle Trap",             "", [ "trap" ] ],
	# [000, "Ghost Trap",               "", [ "trap" ] ],
	# [000, "Static Trap",              "", [ "trap" ] ],
	# [000, "Quiz Trap",                "", [ "trap" ] ],
	# [000, "I Trap",                   "", [ "trap" ] ],
	# [000, "Sleep Trap",               "", [ "trap" ] ],
	# [000, "Wyrmino Trap",             "", [ "trap" ] ],
	# [000, "Tutorial",                 "", [ "trap" ] ],
	
	# Shapes (301-)                                                                     Last two values are poor height, safe height
	[301, "Monomino",       "", [ "progression_skip_balancing", "shape", "monomino" ],                                             1, 1],

	[302, "Domino",         "", [ "progression_skip_balancing", "shape", "domino" ],                                               1, 2],

	[303, "I Tromino",      "", [ "progression_skip_balancing", "shape", "tromino" ],                                              1, 3],
	[304, "L Tromino",      "", [ "progression_skip_balancing", "shape", "tromino", "has_corner_gap" ],                            1, 2],

	[305, "I Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino" ],                                            1, 4],
	[306, "O Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino" ],                                            2, 2],
	[307, "T Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino", "has_corner_gap" ],                          1, 3],
	[308, "J Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[309, "L Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[310, "S Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino", "has_corner_gap" ],                          1, 2],
	[311, "Z Tetromino",    "", [ "progression_skip_balancing", "shape", "tetromino", "has_corner_gap" ],                          1, 2],

	[312, "I Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino" ],                                            1, 5],
	[313, "U Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_second_tile_gap" ],                     2, 3],
	[314, "T Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   2, 3],
	[315, "X Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap" ],                          2, 2],
	[316, "V Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[317, "W Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   2, 3],
	[318, "L Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 4],
	[319, "J Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 4],
	[320, "S Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[321, "Z Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[322, "F Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[323, "F' Pentomino",   "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[324, "N Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[325, "N' Pentomino",   "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[326, "P Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap" ],                          2, 3],
	[327, "Q Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap" ],                          2, 3],
	[328, "Y Pentomino",    "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
	[329, "Y' Pentomino",   "",  [ "progression_skip_balancing", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ],   1, 3],
].reduce(_generateDataTable.bind(ItemData.new), {} as Dictionary[int, ItemData])

@onready var LOCATIONS:Dictionary[int, LocationData] = (_generateLocationConstants().reduce(_generateDataTable.bind(LocationData.new), {} as Dictionary[int, LocationData]))

@onready var ITEM_NAME_TO_ID:Dictionary[StringName, int] = ITEMS.values().reduce(
	func(acc:Dictionary[StringName, int], itemData:ItemData):
		acc[itemData.internalName] = itemData.id
		return acc,
	{} as Dictionary[StringName, int]
)

# === Trap Link ===
var TRAP_ALIASES:Dictionary[StringName, String] = {
	# DRACOMINO TRAPS 
	crystal_trap            = "Crystal Trap",
	egg                     = "Egg Trap",
	enchantment             = "Enchantment Trap",
	enchantment_curse       = "Curse Trap",
	fracture_trap           = "Fracture Trap",
	impatience_trap         = "Impatience Trap",
	# premium_trap           = "Premium Trap", # Might scrap
	space_trap              = "Space Trap",
	# unrandomization_trap    = "Unrandomization Trap",
	welldone                = "Well Done Trap",

	# EXISTING TRAPS
	fishing                 = "Fishing Trap",
	invertcolors_trap       = "Invert Colors Trap",
	logic_tutorial          = "Tutorial Trap",
	pixellation_trap        = "Pixellation Trap",
	# Random Cutscene         = "Cutscene Trap",
	tutorial                = "Tutorial Trap",
	water_trap              = "Underwater Trap",
	zoom_trap               = "Zoom Trap",

	# FAKE TRAPS (Shouldn't be sent, but giving them a display name)
	enchantment_curse_gravity        = "Curse Trap",
	enchantment_curse_movement       = "Curse Trap",
	enchantment_legendary_movement   = "Enchantment Trap",
	enchantment_legendary_spin       = "Enchantment Trap",
	enchantment_random               = "Random Enchantment",
	fade                             = "Fake Transition",
	mini_jumpscare                   = "Mini Jumpscare",
	random_trap                      = "Random Trap",
}
var RANDOM_TRAP_CHOICES:Array[StringName] = [
	"crystal_trap",
	"fracture_trap",
	"welldone",
	"fishing",
	# "invertcolors_trap",
	"water_trap",
	"pixellation_trap",
	"space_trap",
]
var TRAP_LINK_MAPPINGS:Dictionary[StringName, Variant] = {
	# DRACOMINO TRAPS
	"Crystal Trap"            : "crystal_trap",
	"Curse Trap"              : "curse",
	"Egg Trap"                : "egg",
	"Enchantment Trap"        : "enchantment",
	"Fracture Trap"           : "fracture_trap",
	"Impatience Trap"         : "impatience_trap",
	# "Premium Trap"            : "premium_trap",
	"Space Trap"              : "space_trap",
	# "Unrandomization Trap"    : "unrandomization_trap",
	"Well Done Trap"          : "welldone",

	# OTHER TRAPS
	"144p Trap"               : "pixellation_trap",
	"Aaa Trap"                : "mini_jumpscare",
	# "Animal Trap"             : "Transform Trap",
	"Animal Bonus Trap"       : "fishing",
	"Army Trap"               : "impatience_trap",
	"Bald Trap"               : "egg",
	# "Banana Peel Trap"        : "momemtum_trap",
	# "Banana Trap"             : "momemtum_trap",
	"Banner Trap"             : "enchantment",
	# "Bee Trap"                : "glue_trap",
	# "Blue Balls Curse"        : "shatter_trap",
	# "Bomb"                    : "shatter_trap",
	# "Bomb Trap"               : "shatter_trap",
	"Bonk Trap"               : "impatience_trap",
	"Breakout Trap"           : "fishing",
	"Bubble Trap"             : "water_trap",
	"Bullet Time Trap"        : "enchantment_curse_movement",
	# "Burn Trap"               : "fire_trap",
	"Buyon Trap"              : "egg",
	# "Camera Rotate Trap"      : "Camera Rotate Trap",
	"Chaos Trap"              : "crystal_trap",
	"Chaos Control Trap"      : "enchantment_curse_movement",
	"Chart Modifier Trap"     : "enchantment_random",
	# "Chaser Trap"             : "shatter_trap",
	# "Clear Image Trap"        : "Board Wipe Trap",
	# "Confound Trap"           : "Reverse Controls Trap",
	# "Confuse Trap"            : "Reverse Controls Trap",
	# "Confusion Trap"          : "Reverse Controls Trap",
	"Control Ball Trap"       : "zoom_trap",
	# "Controller Drift Trap"   : "Latency Trap",
	"Cursed Ball Trap"        : "enchantment_curse",
	"Cutscene Trap"           : "logic_tutorial", # "Random Cutscene",
	# "Damage Trap"             : "shatter_trap",
	# "Deisometric Trap"        : "Camera Rotate Trap",
	"Depletion Trap"          : "enchantment_curse",
	# "Disable A Trap"          : "Disable Rotate Trap",
	# "Disable B Trap"          : "Disable Rotate Trap",
	# "Disable C Up Trap"       : "Disable Rotate Trap",
	# "Disable Tag Trap"        : "Disable Hold Trap",
	# "Disable Z Trap"          : "Disable Hold Trap",
	# "Disarm Trap"             : "Disable Hold+Disable Rotate Trap",
	"Double Damage"           : "enchantment_curse_gravity",
	# "Dry Trap"                : "Board Wipe Trap",
	"Eject Ability"           : "impatience_trap",
	"Electrocution Trap"      : "enchantment_legendary_spin",
	# "Empty Item Box Trap"     : "Board Wipe Trap", # TODO: Empty Hold Slots
	"Enemy Ball Trap"         : "egg",
	"Energy Drain Trap"       : "enchantment_curse_movement",
	# "Expensive Stocks"        : "premium_trap",
	# "Explosion Trap"          : "shatter_trap",
	"Exposition Trap"         : "logic_tutorial", # "Random Cutscene",
	"Extreme Chaos Mode"      : ["crystal_trap", "fracture_trap"],
	"Fake Transition"         : "fade",
	"Fast Trap"               : "enchantment_legendary_movement",
	"Fear Trap"               : "zoom_trap",
	# "fire_trap"               : "fire_trap",
	"Fish Eye Trap"           : "zoom_trap",
	"Fishing Trap"            : "fishing",
	"Fishin' Boo Trap"        : "fishing",
	# "Flip Horizontal Trap"    : "Flip Trap",
	# "Flip Trap"               : "Flip/Upside-Down Trap",
	# "Flip Vertical Trap"      : "Upside-Down Trap",
	"Frame Slime Trap"        : "enchantment_curse_movement",
	# "Freeze Trap"             : "Ice Trap",
	"Frog Trap"               : "fishing",
	"Frost Trap"              : "water_trap", #"Ice Trap",
	# "Frozen Trap"             : "Ice Trap",
	"Fuzzy Trap"              : "pixellation_trap",
	# "Gadget Shuffle Trap"     : "unrandomization_trap",
	# "Gas Trap"                : "Reverse Controls Trap",
	"Get Out Trap"            : "enchantment_curse_gravity",
	# "Ghost"                   : "random_trap", #"Ghost Trap",
	# "Ghost Chat"              : "Dummy Trap",
	"Gooey Bag"               : "egg",
	"Gravity Trap"            : "enchantment_curse_gravity",
	"Help Trap"               : "tutorial",
	"Hey! Trap"               : "welldone",
	"Hiccup Trap"             : "impatience_trap",
	"Home Trap"               : "tutorial",
	# "Honey Trap"              : "glue_trap",
	# "Ice Floor Trap"          : "momemtum_trap",
	# "Ice Trap"                : "Ice Trap",
	"Icy Hot Pants Trap"      : "enchantment_legendary_movement",
	"Input Sequence Trap"     : "fishing",
	"Instant Crystal Trap"    : "crystal_trap",
	# "Instant Death Trap"      : "Board Wipe Trap",
	# "Invert Colors Trap"      : "random_trap",
	# "Inverted Mouse Trap"     : "Reverse Controls Trap",
	# "Invisiball Trap"         : "random_trap", #"Ghost Trap",
	# "Invisible Trap"          : "random_trap", #"Ghost Trap",
	# "Invisibility Trap"       : "random_trap", #"Ghost Trap",
	"Iron Boots Trap"         : "enchantment_curse_movement",
	# "Items to Bombs"          : "shatter_trap",
	"Jump Trap"               : "impatience_trap",
	"Jumping Jacks Trap"      : "impatience_trap",
	"Laughter Trap"           : "welldone",
	# "Light Up Path Trap"      : "Static Trap",
	"Literature Trap"         : "logic_tutorial", # "Random Cutscene",
	"Mana Drain Trap"         : "enchantment_curse",
	# "Market Crash Trap"       : "premium_trap",
	"Math Quiz Trap"          : "logic_tutorial",
	"Meteor Trap"             : "enchantment_curse_gravity",
	"Metronome Trap"          : "random_trap",
	# "Mirror Trap"             : "Flip Trap",
	"Monkey Mash Trap"        : "impatience_trap",
	"My Turn! Trap"           : "impatience_trap",
	"Ninja Trap"              : "egg",
	"No Guarding"             : "enchantment_curse",
	"No Petals"               : "enchantment_curse",
	"No Revivals"             : "enchantment_curse",
	"No Stocks"               : "enchantment_curse",
	# "No Vac Trap"             : "Disable Hold+Disable Rotate Trap",
	"Number Sequence Trap"    : "fishing",
	# "Nut Trap"                : "shatter_trap",
	"OmoTrap"                 : "tutorial",
	"One Hit KO"              : "enchantment_curse_gravity",
	# "Paper Trap"              : "I Trap",
	"Paralyze Trap"           : "enchantment_curse_movement",
	"Paralysis Trap"          : "enchantment_curse_movement",
	"Person Trap"             : "impatience_trap",
	"Phone Trap"              : "tutorial",
	"Pie Trap"                : "egg",
	"Pinball Trap"            : "egg",
	"Pixelate Trap"           : "pixellation_trap",
	"Pixellation Trap"        : "pixellation_trap",
	"Poison Mushroom"         : "enchantment_curse",
	"Poison Trap"             : "enchantment_curse",
	"Pokemon Count Trap"      : "logic_tutorial",
	"Pokemon Trivia Trap"     : "logic_tutorial",
	"Police Trap"             : "impatience_trap",
	"PONG Challenge"          : "egg",
	"Pong Trap"               : "egg",
	# "Posession Trap"          : "Reverse Controls Trap",
	"PowerPoint Trap"         : "enchantment_curse_movement",
	"Push Trap"               : "impatience_trap",
	# "Radiation Trap"          : "fire_trap",
	# "Rail Trap"               : "momemtum_trap",
	"Ranch Trap"              : "tutorial",
	"Random Status Trap"      : "enchantment_random",
	"Resistance Trap"         : "enchantment_curse",
	# "Reversal Trap"           : "Reverse Controls Trap",
	# "Reverse Controls Trap"   : "Reverse Controls Trap",
	# "Reverse Trap"            : "Reverse Controls Trap",
	"Rockfall Trap"           : "impatience_trap",
	"Sandstorm Trap"          : "fracture_trap",
	# "Screen Flip Trap"        : "Flip Trap",
	"Shake Trap"              : "fracture_trap",
	"Shuffle Trap"            : "unrandomization_trap",
	# "Sleep Trap"              : "Sleep Trap",
	"Slip Trap"               : "impatience_trap",
	"Slow Trap"               : "enchantment_curse_movement",
	"Slowness Trap"           : "enchantment_curse_movement",
	# "Snake Trap"              : "Wyrmino Trap",
	"Spam Trap"               : "tutorial",
	# "Spike Ball Trap"         : "shatter_trap",
	# "Spooky Time"             : "random_trap",
	"Spotlight Trap"          : "zoom_trap",
	"Spring Trap"             : "impatience_trap",
	# "Squash Trap"             : "I Trap",
	# "Sticky Floor Trap"       : "glue_trap",
	# "Sticky Hands Trap"       : "Disable Hold Trap",
	"Stun Trap"               : "enchantment_curse_movement",
	"SvC Effect"              : "enchantment_random",
	# "Swap Trap"               : "Swap Trap",
	"Syntax Jumpscare Trap"   : "mini_jumpscare",
	# "Tarr Trap"               : "glue_trap",
	"Teleport Trap"           : "impatience_trap",
	"Text Trap"               : "tutorial", # "Random Cutscene",
	"Thwimp Trap"             : "enchantment_curse_gravity",
	"Time Limit"              : "enchantment_curse_gravity",
	"Time Warp Trap"          : "enchantment_curse_gravity",
	"Timer Trap"              : "enchantment_curse_gravity",
	"Tiny Trap"               : "zoom_trap",
	"Tip Trap"                : "tutorial",
	# "TNT Barrel Trap"         : "shatter_trap",
	# "TNT Trap"                : "shatter_trap",
	# "Tool Swap Trap"          : "Swap Trap",
	"Trivia Trap"             : "logic_tutorial",
	"Tutorial Trap"           : "tutorial",
	"Underwater Trap"         : "water_trap",
	# "Undo Trap"               : "Dummy Trap",
	"UNO Challenge"           : "fishing",
	# "W I D E Trap"            : "I Trap",
	"Whirlpool Trap"          : "enchantment_legendary_spin",
	"Whoops! Trap"            : "impatience_trap",
	"Zoom In Trap"            : "zoom_trap",
	"Zoom Out Trap"           : "zoom_trap",
	"Zoom Trap"               : "zoom_trap",
}

# === Death Link Messages ===
func _addDLMessageTemplate(message:String) -> DracominoUtil.DeathLinkMessageTemplate:
	return DracominoUtil.DeathLinkMessageTemplate.new(message)

var CONTEXT_TAGS:Dictionary[StringName, Dictionary] = {
	GENERIC = { # This gets added automatically
		player = "Dracomino Player",
		his_her_their = "their",
		him_her_them = "them",
		he_she_they = "they",
		totalpieces = "[some number]",
		boardheight = "[some number]",
	},
	NONLOCAL_ITEM = {
		item = "Piece",
		sender = "someone",
		location = "somewhere",
		game = "another game",
	},
	LOCAL_ITEM = {
		a_an = "a",
		item = "Piece",
		location = "somewhere",
	},
	BARELY_GET_ITEM = { # Not implemented, because I'm too lazy
		obtaineditem = "thing",
		receiver = "someone",
		checkedlocation = "somewhere",
		game = "another game",
	},
	ITEM_STREAK = {
		item = "Piece",
		streaksize = "a lot of",
	},
	WAITED = {
		waittime = "[some number]",
	},
	NO_ROTATE = {},
	NONLOCAL_ROTATE = {
		sender_rotate = "someone",
		location_rotate = "somewhere",
		game_rotate = "another game",
	},
}

@onready var DEATHLINK_MESSAGE_TEMPLATES:Dictionary[StringName, Array] = {
	TOP = [
		# Generic
		_addDLMessageTemplate("{player} reached the top of {his_her_their} screen."),
		_addDLMessageTemplate("{player}'s board is only {boardheight} tiles high."),
		# Nonlocal item
		_addDLMessageTemplate("{player} did not have a good place to put the {item} found in {sender}'s {location}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} was crushed by the {item} {sender} flung at {him_her_them} from {game}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player}'s board toppled as soon as {he_she_they} placed a {item} from {game}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} couldn't handle the {item} {sender} found in {location}.").addContext("NONLOCAL_ITEM"),
		# Local item
		_addDLMessageTemplate("{player} did not have a good place to put {his_her_their} {item}.").addContext("LOCAL_ITEM"),
		_addDLMessageTemplate("{player}'s board toppled as soon as {he_she_they} placed {his_her_their} {item}.").addContext("LOCAL_ITEM"),
		_addDLMessageTemplate("{player} put a {item} on the very tippy-top of {his_her_their} screen.").addContext("LOCAL_ITEM"),
		# No rotate
		_addDLMessageTemplate("{player} is having a tough time clearing lines without the rotate ability.").addContext("NO_ROTATE"),
		_addDLMessageTemplate("{player} rotated things in {sender_rotate}'s {game_rotate} rather than {his_her_their} own game.").addContext("NO_ROTATE").addContext("NONLOCAL_ROTATE"),
		# Item streak
		_addDLMessageTemplate("{player} was met by an inconvenient streak of {streaksize} {item}s.").addContext("ITEM_STREAK"),
		_addDLMessageTemplate("{player} was not prepared for {streaksize} consecutive {item}s.").addContext("ITEM_STREAK"),
		# Barely get item
		_addDLMessageTemplate("{player} paid the ultimate price to get {receiver}'s {obtaineditem}.").addContext("BARELY_GET_ITEM"),
		_addDLMessageTemplate("{player} sacrificed {his_her_their} board's stability trying to get {receiver}'s {obtaineditem}.").addContext("BARELY_GET_ITEM"),
		_addDLMessageTemplate("{player} got {receiver}'s {obtaineditem} and immediately fell over.").addContext("BARELY_GET_ITEM"),
	],
	TOP_NO_INPUT = [
		# Generic
		_addDLMessageTemplate("{player} was not paying attention to {his_her_their} screen."),
		_addDLMessageTemplate("{player} might have been AFK. Anyway, {he_she_they} got a game over for it."),
		_addDLMessageTemplate("{player} was playing an idle building game, but was met by the {boardheight} block height limit."),
		# Nonlocal item
		_addDLMessageTemplate("{player} got snuck up on by a {item} that came from {game}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} forgot to pause {his_her_their} game waiting for {sender}'s {item}.").addContext("NONLOCAL_ITEM"),
		# Item streak
		_addDLMessageTemplate("{player}'s {streaksize} {item}s automatically formed a tower to the top of the screen.").addContext("ITEM_STREAK"),
	],
	RESTART = [
		# Generic
		_addDLMessageTemplate("{player} ran out of pieces and restarted {his_her_their} game."),
		_addDLMessageTemplate("{player} used up all {totalpieces} of their pieces and restarted {his_her_their} game."),
		# Waited
		_addDLMessageTemplate("{player} got tired of waiting for new pieces and restarted {his_her_their} game.").addContext("WAITED"),
		_addDLMessageTemplate("{player} waited an entire {waittime} before deciding to just restart {his_her_their} game.").addContext("WAITED"),
		_addDLMessageTemplate("{player} restarted {his_her_their} game after {waittime} of having no more pieces.").addContext("WAITED"),
		# Barely get item
		_addDLMessageTemplate("{player} restarted {his_her_their} game after using {his_her_their} last piece to get {receiver}'s {obtaineditem}.").addContext("BARELY_GET_ITEM"),
		# Barely get item + Waited
		_addDLMessageTemplate("{player} used {his_her_their} last piece to get {receiver}'s {obtaineditem}, and waited {waittime} to get nothing in return.").addContext("BARELY_GET_ITEM").addContext("WAITED"),
	],
	RESTART_HELD_PIECE = [
		# Nonlocal item
		_addDLMessageTemplate("{player} held the {item} {he_she_they} received from {sender} so they wouldn't be without any pieces. Forever.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} gave {his_her_their} {item} a home in {his_her_their} Hold Slot after being lost in {game}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player}'s {item} migrated from {sender}'s {location} to {player}'s Hold Slot.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} held onto the {item} {sender} gifted {him_her_them} from {game}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} adopted a {item} from {location} of {game}.").addContext("NONLOCAL_ITEM"),
		# Local item
		_addDLMessageTemplate("{player} held {his_her_their} last {item} and couldn't do anything else besides restarting.").addContext("LOCAL_ITEM"),
		_addDLMessageTemplate("{player}'s {item} entered {his_her_their} Hold Slot, but nothing came out...").addContext("LOCAL_ITEM"),
		# Waited + Nonlocal item
		_addDLMessageTemplate("{player} admired the {item} {he_she_they} received from {sender} for {waittime} before deciding to move on.").addContext("WAITED").addContext("NONLOCAL_ITEM"),
		# Waited + Local item
		_addDLMessageTemplate("{player}'s final {item} was trapped eternally in {his_her_their} Hold Slot rather than being placed.").addContext("WAITED").addContext("LOCAL_ITEM"),
	],
	RESTART_WITH_PIECES = [
		# Generic
		_addDLMessageTemplate("{player} restarted {his_her_their} game before using all {his_her_their} pieces."),
		_addDLMessageTemplate("{player} did not like how {his_her_their} run was going and reset {his_her_their} game early."),
		# Nonlocal item
		_addDLMessageTemplate("{player} restarted before placing the {item} from {sender}'s {location}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} was too afraid to place the {item} that came from {sender}'s {location}.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player}'s {item} reeked of {game} and was not given the privilege of being placed this run.").addContext("NONLOCAL_ITEM"),
		_addDLMessageTemplate("{player} refused to place a {item} from {sender}'s {game} against their wishes.").addContext("NONLOCAL_ITEM"),
		# Local item
		_addDLMessageTemplate("{player} restarted before placing {his_her_their} {item}.").addContext("LOCAL_ITEM"),
	],
	RESTART_NEAR_GAME_OVER = [
		# Near game over
		_addDLMessageTemplate("{player} restarted {his_her_their} game to avoid getting a game over."),
		_addDLMessageTemplate("{player} almost got a game over, yet still sent a death by restarting."),
		# Near game over + no rotate
		_addDLMessageTemplate("{player} restarted {his_her_their} game after trying {his_her_their} best without rotating.").addContext("NO_ROTATE"),
		_addDLMessageTemplate("{player} rotated things in {sender_rotate}'s {game_rotate} rather than {his_her_their} own game.").addContext("NO_ROTATE").addContext("NONLOCAL_ROTATE"),
		# Near game over + Nonlocal item
		_addDLMessageTemplate("{player} would rather restart {his_her_their} game than to let the {item} from {sender} end {him_her_them}.").addContext("NONLOCAL_ITEM"),
		# Near game over + Local item
		_addDLMessageTemplate("{player} would rather restart {his_her_their} game than to top out with {his_her_their} own {item}.").addContext("LOCAL_ITEM"),
		# Near game over + Item streak
		_addDLMessageTemplate("{player} did not want to deal with {streaksize} {item}s in a row and started over.").addContext("ITEM_STREAK"),
		_addDLMessageTemplate("{player}'s board was deemed unmanageable after receiving {streaksize} consecutive {item}s.").addContext("ITEM_STREAK"),
	],
	OFFLINE = [
		_addDLMessageTemplate("{player} earned a game over while offline.")
	]
}
# Private functions
static func _generateLocationConstants() -> Array:
	var arr = []
	for i in range(1,1001):
		arr.append([i,        "Line %s Cleared"%i, "", [ "line_clear" ]])
	for i in range(1,10001):
		arr.append([i + 10000, "Coin %s"%i, "", [ "item_pickup" ]])
	return arr

static func _generateDataTable(dict:Dictionary, arr:Array, new_fn:Callable) -> Dictionary:
	var data:Data = new_fn.call(arr)
	dict[data.id] = data
	return dict

	
# Storage space for mods to use if they want to facilitate compatibility stuff
var CUSTOM_DATA:Dictionary = {}

### Constants
func _IconLabel(id:String, label:String="") -> String:
	return "[img]res://assets/art/emoji/{id}.png[/img]{label}".format({
		id = id,
		label = "[b]"+label+"[/b]" if label.length() else "",
	})
var	DIALOGUE_FORMAT_TEMPLATE = {
	heart = _IconLabel("heart"),
	coin = _IconLabel("coin"),
	mana = _IconLabel("mana"),
	COIN = _IconLabel("coin","Coin"),
	MANA = _IconLabel("mana","Mana"),
}

