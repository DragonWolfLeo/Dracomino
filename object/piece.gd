class_name Piece extends PieceTiles

@export var canRotate:bool = true 

class PieceDefinition:
	var tiles:Array[Vector2i]
	var id:int
	var canRotate:bool = true
	var offset:Vector2i
	static var _total:int
	func _init(_tiles:Array[Vector2i] = []) -> void:
		tiles = _tiles
		tiles.make_read_only()
		id = _total + 1
		_total += 1
	func setCanRotate(_canRotate:bool = true) -> PieceDefinition:
		canRotate = _canRotate
		return self
	func setOffset(_offset:Vector2i) -> PieceDefinition:
		offset = _offset
		return self

static var PIECES:Dictionary[StringName, PieceDefinition] = {
	"I Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT*2, Vector2i.RIGHT, Vector2i.RIGHT*2]),
	"U Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.RIGHT+Vector2i.UP, Vector2i.LEFT+Vector2i.UP]),
	"T Pentomino": PieceDefinition.new([Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN, Vector2i.ZERO, Vector2i.UP]),
	"X Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]).setCanRotate(false),
	"V Pentomino": PieceDefinition.new([Vector2i.LEFT+Vector2i.UP, Vector2i.LEFT, Vector2i.LEFT+Vector2i.DOWN, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]),
	"W Pentomino": PieceDefinition.new([Vector2i.LEFT+Vector2i.UP, Vector2i.LEFT, Vector2i.ZERO, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]),
	"L Pentomino": PieceDefinition.new([Vector2i.RIGHT, Vector2i.ZERO, Vector2i.RIGHT*2, Vector2i.LEFT, Vector2i(2,-1)]).setOffset(Vector2i.DOWN),
	"J Pentomino": PieceDefinition.new([Vector2i.RIGHT, Vector2i.ZERO, Vector2i.RIGHT*2, Vector2i.LEFT, Vector2i.LEFT+Vector2i.UP]).setOffset(Vector2i.LEFT+Vector2i.DOWN),
	"S Pentomino": PieceDefinition.new([Vector2i.LEFT+Vector2i.DOWN, Vector2i.DOWN, Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT+Vector2i.UP]),
	"Z Pentomino": PieceDefinition.new([Vector2i.RIGHT+Vector2i.DOWN, Vector2i.DOWN, Vector2i.ZERO, Vector2i.UP, Vector2i.LEFT+Vector2i.UP]),
	"F Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN]),
	"F' Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]),
	"N Pentomino": PieceDefinition.new([Vector2i.UP, Vector2i.LEFT+Vector2i.UP, Vector2i.ZERO, Vector2i.RIGHT, Vector2i.RIGHT*2]).setOffset(Vector2i.LEFT),
	"N' Pentomino": PieceDefinition.new([Vector2i.UP, Vector2i.RIGHT+Vector2i.UP, Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT*2]),
	"P Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT+Vector2i.UP]).setOffset(Vector2i.DOWN),
	"Q Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.RIGHT+Vector2i.UP]).setOffset(Vector2i.DOWN),
	"Y Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT*2]).setOffset(Vector2i.DOWN),
	"Y' Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.RIGHT*2]).setOffset(Vector2i.DOWN),

	"I Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT*2, Vector2i.RIGHT]),
	"S Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN]),
	"Z Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]),
	"O Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN]).setCanRotate(false),
	"L Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.RIGHT+Vector2i.UP]).setOffset(Vector2i.DOWN),
	"J Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT+Vector2i.UP, Vector2i.RIGHT]).setOffset(Vector2i.DOWN),
	"T Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]).setOffset(Vector2i.DOWN),
	
	"I Tromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]),
	"L Tromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP]).setOffset(Vector2i.DOWN),

	"Domino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT]),

	"Monomino":  PieceDefinition.new([Vector2i.ZERO]).setCanRotate(false),

	"Egg":  PieceDefinition.new([
		Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i.UP, Vector2i.LEFT+Vector2i.UP, Vector2i.RIGHT+Vector2i.UP,
		Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN,
		Vector2i.UP*2, Vector2i.LEFT+(Vector2i.UP*2), Vector2i.RIGHT+(Vector2i.UP*2),
	]).setCanRotate(false),
}

class Enchantment:
	var rarity:StringName
	var modifiers:Array[Modifier] = []
	func _init(_rarity:StringName = "", _modifiers:Array[Modifier] = []) -> void:
		rarity = _rarity
		modifiers.append_array(_modifiers)

	func addModifier(modifier:Modifier) -> Enchantment:
		modifiers.append(modifier)
		return self

class Modifier:
	var strength:float = 1
	var type:StringName
	var isEligible:Callable = func(): return true

	func _init(_type:StringName = "") -> void:
		type = _type

	func addCondition(fn:Callable) -> Modifier:
		isEligible = fn
		return self

	func setStrength(_strength:float) -> Modifier:
		strength = _strength
		return self

static var MODIFIERS:Dictionary[StringName, Modifier] = {
	gravity_curse = Modifier.new("gravity").setStrength(5.0),
	gravity_uncommon = Modifier.new("gravity").setStrength(0.7).addCondition(_canUseGravityEnchantment),
	gravity_rare = Modifier.new("gravity").setStrength(0.5).addCondition(_canUseGravityEnchantment),
	gravity_epic = Modifier.new("gravity").setStrength(0.25).addCondition(_canUseGravityEnchantment),
	gravity_legendary = Modifier.new("antigravity").setStrength(1).addCondition(_canUseGravityEnchantment),

	movement_curse = Modifier.new("movement").setStrength(3.0),
	movement_uncommon = Modifier.new("movement").setStrength(0.8),
	movement_rare = Modifier.new("movement").setStrength(0.7),
	movement_epic = Modifier.new("movement").setStrength(0.4),
	movement_legendary = Modifier.new("movement").setStrength(0.1),

	rotate_legendary = Modifier.new("rotate").setStrength(0.25),
}

static func _canUseGravityEnchantment() -> bool:
	return FlagManager.isFlagSet("gravity") and FlagManager.isFlagSet("soft_drop/hard_drop")

static var ENCHANTMENTS:Dictionary[StringName, Enchantment] = {
	enchantment_curse = Enchantment.new("curse", [
		MODIFIERS.gravity_curse,
		MODIFIERS.movement_curse,
	]),
	enchantment_uncommon = Enchantment.new("uncommon", [
		MODIFIERS.gravity_uncommon,
		MODIFIERS.movement_uncommon,
	]),
	enchantment_rare = Enchantment.new("rare", [
		MODIFIERS.gravity_rare,
		MODIFIERS.movement_rare,
	]),
	enchantment_epic = Enchantment.new("epic", [
		MODIFIERS.gravity_epic,
		MODIFIERS.movement_epic,
	]),
	enchantment_legendary = Enchantment.new("legendary", [
		MODIFIERS.gravity_legendary,
		MODIFIERS.movement_legendary,
		MODIFIERS.rotate_legendary,
	]),
	enchantment_curse_gravity = Enchantment.new("curse", [MODIFIERS.gravity_curse]),
	enchantment_curse_movement = Enchantment.new("curse", [MODIFIERS.movement_curse]),
	enchantment_legendary_movement = Enchantment.new("legendary", [MODIFIERS.movement_legendary]),
	enchantment_legendary_spin = Enchantment.new("legendary", [MODIFIERS.rotate_legendary]),
	enchantment = Enchantment.new(),
}

@onready var horizontalTimer:Timer = $HorizontalTimer
@onready var softDropTimer:Timer = $SoftDropTimer
@onready var gravityTimer:Timer = $GravityTimer
@onready var rotateTimer:Timer = $RotateTimer

@onready var GRAVITY_WAIT_TIME:float = gravityTimer.wait_time
var HARD_DROP_WAIT_TIME:float = 0.01
@onready var SOFT_DROP_WAIT_TIME:float = softDropTimer.wait_time
var SOFT_DROP_REPEAT_WAIT_TIME:float = .04
var SOFT_DROP_LOCK_DELAY:float = 0.4
@onready var HORIZONTAL_WAIT_TIME:float = horizontalTimer.wait_time
var HORIZONTAL_REPEAT_WAIT_TIME:float = .075
@onready var ROTATE_WAIT_TIME:float = rotateTimer.wait_time
var USE_ALT_ROTATE:bool = true # TODO: Make an option

enum MOVEMENT {
	NONE = -1,
	HORIZONTAL,
	SOFT_DROP,
	SOFT_DROP_LOCK,
	GRAVITY,
	HARD_DROP,
	SHOVE,
	FORCED_SHOVE,
}

static var LEGACY_COLOR_MAPPINGS:Array[int] = [
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
static var NUMBER_OF_COLORS_MIN = 1
static var NUMBER_OF_COLORS_MAX = 16
var pieceDefinition:PieceDefinition
var localCells:Array[Vector2i] = []
var globalCells:Array[Vector2i] = []
var currentPosition:Vector2i: set = _setCurrentPosition
var origin:Vector2i
var id:int
var prettyName:String = "Piece"
var context:DracominoHandler.StateItem = null
var onLockEffect:DracominoHandler.StateItem = null
var onSpawnEffect:DracominoHandler.StateItem = null
var onSpawnTrapLinkToSend:StringName
var attachedModifier:DracominoHandler.StateItem = null
var moveLock:bool = false: ## Prevent moving this anymore
	set(value):
		moveLock = value
		if horizontalTimer: horizontalTimer.paused = value
		if softDropTimer: softDropTimer.paused = value
		if value:
			isFocus = false
			set_process_unhandled_input(false)
var holdLock:bool = false ## Prevent from holding this anymore
var lockDelayed:bool = false: ## Prevent from locking for a bit
	set(value):
		if lockDelayed != value:
			lockDelayed = value
			if lockDelayed:
				softDropTimer.start(SOFT_DROP_LOCK_DELAY)
var collidible:bool = false ## Enable when piece doesn't overlap with another
var playHardDropSound:bool = false
var ghost:GhostPiece
var isFocus:bool: ## Decides whether or not piece listens to inputs
	set(value):
		if isFocus == value: return
		isFocus = value
		set_process_unhandled_input(value)
		if not value: focus_lost.emit()
var rarity:StringName
var modifiers:Dictionary[StringName, float] = {}
var flagHolder:FlagHolder

static var GHOSTPIECE_SCENE:PackedScene = load("res://object/ghostpiece.tscn")

signal movement_requested(piece:Piece, direction:Vector2i, movementType:int)
signal new_cells_requested(piece:Piece, cells:Array[Vector2i])
signal ghost_cells_requested(piece:Piece, ghostPiece:GhostPiece)
signal focus_lost()

#==== Virtuals ======
func _ready() -> void:
	flagHolder = FlagHolder.new(FlagHolder.PRIORITY.OBJECT)
	flagHolder.count("shapes_active", "amount", 1)
	add_child(flagHolder)
	SignalBus.getSignal("setting_changed", "gravity").connect(_on_gravity_setting_changed)
	_on_gravity_setting_changed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rotateClockwise"):
		if FlagManager.isFlagSet("rotate_clockwise") or modifiers.get("rotate"):
			rotateClockwise()
			get_viewport().set_input_as_handled()
			if modifiers.get("rotate"): rotateTimer.start(ROTATE_WAIT_TIME*modifiers.get("rotate", 1.0))
		elif USE_ALT_ROTATE and FlagManager.isFlagSet("rotate_counterclockwise"):
			rotateCounterclockwise()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotateCounterclockwise"):
		if FlagManager.isFlagSet("rotate_counterclockwise") or modifiers.get("rotate"):
			rotateCounterclockwise()
			get_viewport().set_input_as_handled()
			if modifiers.get("rotate"): rotateTimer.start(ROTATE_WAIT_TIME*modifiers.get("rotate", 1.0))
		elif USE_ALT_ROTATE and FlagManager.isFlagSet("rotate_clockwise"):
			rotateClockwise()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("moveLeft") and Input.is_action_just_pressed("moveLeft"):
		horizontalTimer.start(HORIZONTAL_WAIT_TIME * modifiers.get("movement", 1))
		movement_requested.emit(self, Vector2i.LEFT, MOVEMENT.HORIZONTAL)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("moveRight") and Input.is_action_just_pressed("moveRight"):
		horizontalTimer.start(HORIZONTAL_WAIT_TIME * modifiers.get("movement", 1))
		movement_requested.emit(self, Vector2i.RIGHT, MOVEMENT.HORIZONTAL)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("moveDown") and Input.is_action_just_pressed("moveDown") and FlagManager.isFlagSet("soft_drop"):
		softDropTimer.start(SOFT_DROP_WAIT_TIME * modifiers.get("movement", 1))
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.SOFT_DROP_LOCK)
		# Avoid falling too soon
		gravityTimer.start()
		get_viewport().set_input_as_handled()
		return

#==== Functions ======
func makeActive():
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process_unhandled_input(isFocus)
	if flagHolder: flagHolder.monitoring = true
	show()
	if FlagManager.isFlagSet("ghost_piece") and ghost:
		ghost.show()
	# Avoid falling too soon
	gravityTimer.start()
	# Wait for pieces to get out of this one
	collidible = false

	# Send trap link
	if onSpawnTrapLinkToSend and FlagManager.isFlagSet("trap_link"):
		var trapLinkAlias:String = CONSTANTS.TRAP_ALIASES.get(onSpawnTrapLinkToSend, "")
		if trapLinkAlias and Archipelago.conn:
			onSpawnTrapLinkToSend = ""
			Archipelago.conn.send_traplink(trapLinkAlias)
			print("Piece: Sending trap: ", trapLinkAlias)

func makeLimbo():
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process_unhandled_input(false)
	if flagHolder: flagHolder.monitoring = false
	hide()

func setPiece(pieceName, pieceContext:DracominoHandler.StateItem = null, effects:Dictionary[StringName, DracominoHandler.StateItem] = {}) -> void:
	prettyName = pieceName
	pieceDefinition = PIECES.get(pieceName)
	if FlagManager.isFlagSet("legacy_piece_colors"):
		id = LEGACY_COLOR_MAPPINGS[Board.random.randi_range(0, LEGACY_COLOR_MAPPINGS.size() - 1)]
	else:
		id = Board.random.randi_range(NUMBER_OF_COLORS_MIN, NUMBER_OF_COLORS_MAX - 1)
	var orientation:int = Board.rotate_random.randi_range(0,3)
	if pieceDefinition:
		if not ghost:
			ghost = GHOSTPIECE_SCENE.instantiate()
			add_child(ghost)
		localCells = pieceDefinition.tiles.duplicate()
		if FlagManager.isFlagSet("randomize_orientations"):
			if pieceDefinition.canRotate:
				match orientation:
					1: rotateClockwise(true)
					2: rotate180(true)
					3: rotateCounterclockwise(true)
					_: updateTiles()
		else:
			updateTiles()

		origin = pieceDefinition.offset
		context = pieceContext
		canRotate = pieceDefinition.canRotate
		
		# Prepare to send a trap link if this is a shape trap
		if context and context.data and context.data.tags.has("trap") and not context.usedTrapLink:
			onSpawnTrapLinkToSend = context.data.internalName
			context.usedTrapLink = true
		onLockEffect = effects.get("on_lock")
		onSpawnEffect = effects.get("on_spawn")
		attachedModifier = effects.get("modifier")
		if attachedModifier is DracominoHandler.StateItem and attachedModifier.data:
			applyEnchantmentByName(attachedModifier.data.internalName)
			if not attachedModifier.usedTrapLink:
				# Prepare to send a trap link if this is an enchantment. Will also conflict with shape traps, but those shouldn't be enchanted anyway
				onSpawnTrapLinkToSend = "enchantment_curse" if rarity == "curse" else "enchantment"
				attachedModifier.usedTrapLink = true
	else:
		printerr("Piece.setPiece:", pieceName, " does not exist!")
		queue_free()

func applyEnchantmentByName(enchantmentName:StringName):
	var enchantment:Enchantment = ENCHANTMENTS.get(enchantmentName)
	if enchantment is Enchantment:
		rarity = enchantment.rarity
		var eligibleMods:Array[Modifier] = []
		for mod in enchantment.modifiers:
			if mod.isEligible.call():
				eligibleMods.append(mod)
		if eligibleMods.size():
			var mod:Modifier = eligibleMods.pick_random()
			modifiers[mod.type] = mod.strength
			match mod.type:
				"gravity": _on_gravity_setting_changed.call_deferred()

func updateTiles():
	clear()
	clearOutline()
	renderPiece(self)
	
	globalCells = Board.getTranslatedCells(localCells, currentPosition)
	if ghost:
		ghost.setCells(localCells)
		ghost_cells_requested.emit(self, ghost)

func rotateClockwise(force:bool = false):
	if canRotate:
		var newCells:Array[Vector2i] = localCells.duplicate()
		for i in newCells.size():
			var new_x = -newCells[i].y
			newCells[i].y = newCells[i].x
			newCells[i].x = new_x
		if force:
			setCells(newCells)
		else:
			new_cells_requested.emit(self, newCells)

func rotateCounterclockwise(force:bool = false):
	if canRotate:
		var newCells:Array[Vector2i] = localCells.duplicate()
		for i in newCells.size():
			var new_y = -newCells[i].x
			newCells[i].x = newCells[i].y
			newCells[i].y = new_y
		if force:
			setCells(newCells)
		else:
			new_cells_requested.emit(self, newCells)

func rotate180(force:bool = false):
	if canRotate:
		var newCells:Array[Vector2i] = localCells.duplicate()
		for i in newCells.size():
			newCells[i] *= -1
		if force:
			setCells(newCells)
		else:
			new_cells_requested.emit(self, newCells)

func setCells(cells:Array[Vector2i]) -> void:
	localCells = cells
	if ghost:
		ghost.setCells(cells)
	updateTiles()

func hardDrop():
	if not moveLock:
		moveLock = true
		canRotate = false
		gravityTimer.wait_time = HARD_DROP_WAIT_TIME * modifiers.get("movement", 1)
		gravityTimer.start()

func gravityDrop():
	if not moveLock:
		moveLock = true
		canRotate = false

func move(direction:Vector2i, isRotate:bool = false):
	currentPosition += direction
	if moveLock:
		playHardDropSound = true
	if isRotate:
		# Avoid falling/locking too soon
		if lockDelayed:
			gravityTimer.start()
			lockDelayed = false
			softDropTimer.start(SOFT_DROP_LOCK_DELAY)

# Events
func _on_HorizontalTimer_timeout():
	if not isFocus: return
	var moved = Vector2i.ZERO
	if Input.is_action_pressed("moveLeft"):
		moved = Vector2i.LEFT
	elif Input.is_action_pressed("moveRight"):
		moved = Vector2i.RIGHT
	else:
		horizontalTimer.wait_time = HORIZONTAL_WAIT_TIME * modifiers.get("movement", 1)
		return
	horizontalTimer.wait_time = HORIZONTAL_REPEAT_WAIT_TIME * modifiers.get("movement", 1)
	horizontalTimer.start()
	movement_requested.emit(self, moved, MOVEMENT.HORIZONTAL)

func _on_SoftDropTimer_timeout():
	if not isFocus: return
	if Input.is_action_pressed("moveDown") and FlagManager.isFlagSet("soft_drop"):
		softDropTimer.start(SOFT_DROP_REPEAT_WAIT_TIME * modifiers.get("movement", 1))
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.SOFT_DROP_LOCK if lockDelayed else MOVEMENT.SOFT_DROP)
		# Avoid falling too soon
		gravityTimer.start()
	else:
		softDropTimer.wait_time = SOFT_DROP_WAIT_TIME * modifiers.get("movement", 1)
		lockDelayed = false

func _on_GravityTimer_timeout():
	if moveLock or (
		(FlagManager.isFlagSet("gravity") and not modifiers.get("antigravity")) # Antigravity cancels out gravity
		or modifiers.get("gravity", 1) > 1 # Otherwise if gravity is set at all, it's enabled whether it's unlocked or not
	) or not isFocus:
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.HARD_DROP if playHardDropSound else MOVEMENT.GRAVITY)

func _on_RotateTimer_timeout() -> void:
	if not isFocus and not modifiers.get("rotate"): return
	if Input.is_action_pressed("rotateClockwise"):
		rotateClockwise()
	elif Input.is_action_pressed("rotateCounterclockwise"):
		rotateCounterclockwise()

func _setCurrentPosition(value:Vector2i):
	currentPosition = value
	position = currentPosition * tile_set.tile_size
	updateTiles()

func _on_gravity_setting_changed():
	if not moveLock and gravityTimer:
		var gravSpeed = Config.getSetting("gravity", 1.0)*modifiers.get("gravity", 1.0)
		gravityTimer.wait_time = GRAVITY_WAIT_TIME/gravSpeed
		gravityTimer.start()
