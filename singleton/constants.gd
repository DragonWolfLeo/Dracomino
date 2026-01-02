extends Node

# Item + Location Data
class Data:
	var id:int
	var prettyName:StringName
	var tags:Dictionary[StringName, bool]
	func _init(arr=[]):
		arr.resize(3)
		id = arr[0] as int
		prettyName = arr[1] as StringName
		for tag in arr[2] as Array:
			tags[tag as StringName] = true

class ItemData extends Data: pass
class LocationData extends Data: pass

@onready var ITEMS:Dictionary[int, ItemData] = [
	# Abilities (1-100)
	[1,   "Gravity",                  [ "useful", "ability" ] ],
	[2,   "Soft Drop",                [ "useful", "ability" ] ],
	[3,   "Hard Drop",                [ "useful", "ability" ] ],
	[4,   "Rotate Clockwise",         [ "progression", "ability", "rotate" ] ],
	[5,   "Rotate Counterclockwise",  [ "progression", "ability", "rotate" ] ],
	[6,   "Ghost Piece",              [ "useful", "ability" ] ],

	# Progressive Items (101-200)
	[101, "Next Piece Slot",          [ "useful", "ability", "progressive" ] ],
	[102, "Hold Slot",                [ "useful", "ability", "progressive" ] ],
	
	# Traps Items (201-300)
	[201, "UNIMPLEMENTED TRAP",         [ "trap" ] ],
	
	# Shapes (301-)
	[301, "Monomino",       [ "progression", "shape", "monomino" ] ],

	[302, "Domino",         [ "progression", "shape", "domino" ] ],

	[303, "I Tromino",      [ "progression", "shape", "tromino" ] ],
	[304, "L Tromino",      [ "progression", "shape", "tromino", "has_corner_gap" ] ],

	[305, "I Tetromino",    [ "progression", "shape", "tetromino" ] ],
	[306, "O Tetromino",    [ "progression", "shape", "tetromino" ] ],
	[307, "T Tetromino",    [ "progression", "shape", "tetromino", "has_corner_gap" ] ],
	[308, "J Tetromino",    [ "progression", "shape", "tetromino", "has_corner_gap", "has_second_tile_gap" ] ],
	[309, "L Tetromino",    [ "progression", "shape", "tetromino", "has_corner_gap", "has_second_tile_gap" ] ],
	[310, "S Tetromino",    [ "progression", "shape", "tetromino", "has_corner_gap" ] ],
	[311, "Z Tetromino",    [ "progression", "shape", "tetromino", "has_corner_gap" ] ],

	 [312, "I Pentomino",    [ "progression", "shape", "pentomino" ] ],
	 [313, "U Pentomino",    [ "progression", "shape", "pentomino", "has_second_tile_gap" ] ],
	 [314, "T Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [315, "X Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap" ] ],
	 [316, "V Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [317, "W Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [318, "L Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [319, "J Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [320, "S Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [321, "Z Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [322, "F Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [323, "F' Pentomino",   [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [324, "N Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [325, "N' Pentomino",   [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [326, "P Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap" ] ],
	 [327, "Q Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap" ] ],
	 [328, "Y Pentomino",    [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
	 [329, "Y' Pentomino",   [ "progression", "shape", "pentomino", "has_corner_gap", "has_second_tile_gap" ] ],
].reduce(_generateDataTable.bind(ItemData.new), {} as Dictionary[int, ItemData])

@onready var LOCATIONS:Dictionary[int, LocationData] = (_generateLocationConstants().reduce(_generateDataTable.bind(LocationData.new), {} as Dictionary[int, LocationData]))

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
		_addDLMessageTemplate("{player} held onto the {item} {sender} gifted them from {game}.").addContext("NONLOCAL_ITEM"),
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
		arr.append([i,        "Line %s Cleared"%i, [ "line_clear" ]])
	for i in range(1,10001):
		arr.append([i + 10000, "Coin %s"%i, [ "item_pickup" ]])
	return arr

static func _generateDataTable(dict:Dictionary, arr:Array, new_fn:Callable) -> Dictionary:
	var data:Data = new_fn.call(arr)
	dict[data.id] = data
	return dict
