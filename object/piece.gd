class_name Piece extends PieceTiles

@export var canRotate:bool = true 
@export var canFlip:bool = true 
@export var can180:bool = true
@export var preferCCW:bool = false ## When rotate 180 is not allowed, chose which direction to spawn as with randomize orientations
@export var uniquePiece:bool = false
@export var isEntity:bool = false
@export var ghost:GhostPiece

class PieceDefinition:
	var tiles:Array[Vector2i]
	var colorId:int
	var canRotate:bool = true
	var canFlip:bool = true
	var can180:bool = true
	var preferCCW:bool = false
	var canVerticalFlip:bool = true
	var horizontallyAmbiguous:bool = false
	var offset:Vector2i
	static var _total:int
	func _init(_tiles:Array[Vector2i] = []) -> void:
		tiles = _tiles
		tiles.make_read_only()
		colorId = _total + 1
		_total += 1
	func setCanRotate(_canRotate:bool = true) -> PieceDefinition:
		canRotate = _canRotate
		if not canRotate:
			can180 = false
			canFlip = false
		return self
	func setOffset(_offset:Vector2i) -> PieceDefinition:
		offset = _offset
		return self
	func setCanFlip(_canFlip:bool = true) -> PieceDefinition:
		canFlip = _canFlip
		return self
	func setCan180(_can180:bool = true, _preferCCW:bool = false) -> PieceDefinition:
		can180 = _can180
		preferCCW = _preferCCW
		return self
	func setHorizontallyAmbiguous(_horizonallyAmbiguous:bool = true) -> PieceDefinition:
		horizontallyAmbiguous = _horizonallyAmbiguous
		return self

static var PIECES:Dictionary[StringName, PieceDefinition] = {
	"I Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT*2, Vector2i.RIGHT, Vector2i.RIGHT*2]).setCan180(false).setCanFlip(false),
	"U Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.RIGHT+Vector2i.UP, Vector2i.LEFT+Vector2i.UP]),
	"T Pentomino": PieceDefinition.new([Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN, Vector2i.ZERO, Vector2i.UP]),
	"X Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]).setCanRotate(false),
	"V Pentomino": PieceDefinition.new([Vector2i.LEFT+Vector2i.UP, Vector2i.LEFT, Vector2i.LEFT+Vector2i.DOWN, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]).setHorizontallyAmbiguous(),
	"W Pentomino": PieceDefinition.new([Vector2i.LEFT+Vector2i.UP, Vector2i.LEFT, Vector2i.ZERO, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]).setHorizontallyAmbiguous(),
	"L Pentomino": PieceDefinition.new([Vector2i.RIGHT, Vector2i.ZERO, Vector2i.RIGHT*2, Vector2i.LEFT, Vector2i(2,-1)]).setOffset(Vector2i.DOWN),
	"J Pentomino": PieceDefinition.new([Vector2i.RIGHT, Vector2i.ZERO, Vector2i.RIGHT*2, Vector2i.LEFT, Vector2i.LEFT+Vector2i.UP]).setOffset(Vector2i.LEFT+Vector2i.DOWN),
	"S Pentomino": PieceDefinition.new([Vector2i.LEFT+Vector2i.DOWN, Vector2i.DOWN, Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT+Vector2i.UP]).setCan180(false),
	"Z Pentomino": PieceDefinition.new([Vector2i.RIGHT+Vector2i.DOWN, Vector2i.DOWN, Vector2i.ZERO, Vector2i.UP, Vector2i.LEFT+Vector2i.UP]).setCan180(false),
	"F Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN]),
	"F' Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]),
	"N Pentomino": PieceDefinition.new([Vector2i.UP, Vector2i.LEFT+Vector2i.UP, Vector2i.ZERO, Vector2i.RIGHT, Vector2i.RIGHT*2]).setOffset(Vector2i.LEFT),
	"N' Pentomino": PieceDefinition.new([Vector2i.UP, Vector2i.RIGHT+Vector2i.UP, Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT*2]),
	"P Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT+Vector2i.UP]).setOffset(Vector2i.DOWN),
	"Q Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.RIGHT+Vector2i.UP]).setOffset(Vector2i.DOWN),
	"Y Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT*2]).setOffset(Vector2i.DOWN),
	"Y' Pentomino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.RIGHT*2]).setOffset(Vector2i.DOWN),

	"I Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT*2, Vector2i.RIGHT]).setCan180(false).setCanFlip(false),
	"S Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN]).setCan180(false, true),
	"Z Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT+Vector2i.DOWN]).setCan180(false),
	"O Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.DOWN, Vector2i.LEFT+Vector2i.DOWN]).setCanRotate(false),
	"L Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.RIGHT+Vector2i.UP]).setOffset(Vector2i.DOWN),
	"J Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.LEFT+Vector2i.UP, Vector2i.RIGHT]).setOffset(Vector2i.DOWN),
	"T Tetromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]).setOffset(Vector2i.DOWN),
	
	"I Tromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]).setCan180(false).setCanFlip(false),
	"L Tromino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP]).setOffset(Vector2i.DOWN).setHorizontallyAmbiguous(),

	"Domino": PieceDefinition.new([Vector2i.ZERO, Vector2i.LEFT]).setCan180(false).setCanFlip(false),

	"Monomino":  PieceDefinition.new([Vector2i.ZERO]).setCanRotate(false),
}

class Enchantment:
	var rarity:StringName
	var prettyName:String:
		get():
			return RARITY_NAMES.get(rarity, "Enchanted")
	var modifiers:Array[Modifier] = []
	static var RARITY_NAMES:Dictionary[StringName, String] = {
		curse = "Cursed",
		uncommon = "Medium-Rare",
		rare = "Rare",
		epic = "Epic",
		legendary = "Legendary",
	}
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
	var alwaysActive:bool = false

	func _init(_type:StringName = "") -> void:
		type = _type

	func addCondition(fn:Callable) -> Modifier:
		isEligible = fn
		return self

	func setStrength(_strength:float) -> Modifier:
		strength = _strength
		return self

	func setAlwaysActive(_alwaysActive:bool = true) -> Modifier:
		alwaysActive = _alwaysActive
		return self

static var MODIFIERS:Dictionary[StringName, Modifier] = {
	gravity_curse = Modifier.new("gravity").setStrength(5.0),
	gravity_uncommon = Modifier.new("gravity").setStrength(0.7).addCondition(_canUseGravityEnchantment).setAlwaysActive(),
	gravity_rare = Modifier.new("gravity").setStrength(0.5).addCondition(_canUseGravityEnchantment).setAlwaysActive(),
	gravity_epic = Modifier.new("gravity").setStrength(0.25).addCondition(_canUseGravityEnchantment).setAlwaysActive(),
	gravity_legendary = Modifier.new("antigravity").setStrength(1).addCondition(_canUseGravityEnchantment).setAlwaysActive(),

	movement_curse = Modifier.new("movement").setStrength(4.0),
	movement_uncommon = Modifier.new("movement").setStrength(0.8).setAlwaysActive(),
	movement_rare = Modifier.new("movement").setStrength(0.75).setAlwaysActive(),
	movement_epic = Modifier.new("movement").setStrength(0.5).setAlwaysActive(),
	movement_legendary = Modifier.new("movement").setStrength(0.1),

	rotate_rare = Modifier.new("rotate").setStrength(1.0).addCondition(_canRotate),
	rotate_epic = Modifier.new("rotate").setStrength(0.7).addCondition(_canRotate),
	rotate_legendary = Modifier.new("rotate").setStrength(0.25),
}

static func _canUseGravityEnchantment() -> bool:
	return FlagManager.isFlagSet("gravity") and FlagManager.isFlagSet("soft_drop/hard_drop")

static func _canRotate() -> bool:
	return FlagManager.isFlagSet("rotate")

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
		MODIFIERS.rotate_rare,
	]),
	enchantment_epic = Enchantment.new("epic", [
		MODIFIERS.gravity_epic,
		MODIFIERS.movement_epic,
		MODIFIERS.rotate_epic,
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
	enchantment_random = Enchantment.new("random"),
	enchantment = Enchantment.new("enchantment"),
}
static var ENCHANTMENT_CHOICES:Array[Enchantment] = [
	ENCHANTMENTS.enchantment_uncommon,
	ENCHANTMENTS.enchantment_rare,
	ENCHANTMENTS.enchantment_epic,
	ENCHANTMENTS.enchantment_legendary,
]
static var ENCHANTMENT_RANDOM_CHOICES:Array[Enchantment] = [
	ENCHANTMENTS.enchantment_curse,
	ENCHANTMENTS.enchantment_uncommon,
	ENCHANTMENTS.enchantment_rare,
	ENCHANTMENTS.enchantment_epic,
	ENCHANTMENTS.enchantment_legendary,
]

@onready var horizontalTimer:Timer = $HorizontalTimer
@onready var softDropTimer:Timer = $SoftDropTimer
@onready var gravityTimer:Timer = $GravityTimer
@onready var rotateTimer:Timer = $RotateTimer

@onready var GRAVITY_WAIT_TIME:float = gravityTimer.wait_time
var HARD_DROP_WAIT_TIME:float = 0.01
@onready var SOFT_DROP_WAIT_TIME:float = softDropTimer.wait_time:
	get():
		return max(SOFT_DROP_REPEAT_WAIT_TIME, SOFT_DROP_WAIT_TIME * min(1.0, modifiers.get("movement", 1.0)) * Config.getSetting("softDrop_repeatDelay", 1.0))
var SOFT_DROP_REPEAT_WAIT_TIME:float = .04:
	get():
		return SOFT_DROP_REPEAT_WAIT_TIME * modifiers.get("movement", 1.0) / Config.getSetting("softDrop_speed", 1.0)
var SOFT_DROP_LOCK_DELAY:float = 0.4:
	get():
		return SOFT_DROP_LOCK_DELAY * Config.getSetting("lockDelay", 1.0)
var GRAVITY_LOCK_DELAY:float = 0.6:
	get():
		return max(getGravityDelay(), GRAVITY_LOCK_DELAY * Config.getSetting("lockDelay", 1.0) )
@onready var HORIZONTAL_WAIT_TIME:float = horizontalTimer.wait_time:
	get():
		return max(HORIZONTAL_REPEAT_WAIT_TIME, HORIZONTAL_WAIT_TIME * min(1.0, modifiers.get("movement", 1.0)) * Config.getSetting("horizontal_repeatDelay", 1.0))
var HORIZONTAL_REPEAT_WAIT_TIME:float = .075:
	get():
		return HORIZONTAL_REPEAT_WAIT_TIME * modifiers.get("movement", 1.0) / Config.getSetting("horizontal_speed", 1.0)
@onready var ROTATE_WAIT_TIME:float = rotateTimer.wait_time
var USE_ALT_ROTATE:bool = true # TODO: Make an option

enum MOVEMENT {
	NONE = -1,
	HORIZONTAL,
	SOFT_DROP,
	SOFT_DROP_LOCK,
	GRAVITY,
	GRAVITY_LOCK,
	HARD_DROP,
	SHOVE,
	FORCED_SHOVE,
}

var pieceDefinition:PieceDefinition
var localCells:Array[Vector2i] = []
var globalCells:Array[Vector2i] = []
var currentPosition:Vector2i: set = _setCurrentPosition
var origin:Vector2i
var colorId:int
var prettyName:String = "Piece"
var context:DracominoHandler.PieceContext = null
var stateItem:DracominoHandler.StateItem:
	get():
		if context: return context.stateItem
		return null
var attachedEffects:Dictionary[StringName, DracominoHandler.StateItem] = {}
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
var gravityLockDelayed:bool = false: ## Prevent from locking for a bit
	set(value):
		if gravityLockDelayed != value:
			gravityLockDelayed = value
			if gravityLockDelayed:
				if not moveLock: gravityTimer.start(GRAVITY_LOCK_DELAY)
var collidible:bool = false ## Enable when piece doesn't overlap with another
var placed:bool = false: ## When this is an entity that is placed on the board
	set(value):
		if placed == value: return
		placed = value
		if flagHolder:
			flagHolder.clearFlag("shapes_active" if placed else "entities_active")
			flagHolder.count("entities_active" if placed else "shapes_active", "amount", 1)
		if placed:
			if gravityTimer: gravityTimer.stop()
			if softDropTimer: softDropTimer.stop()
			if horizontalTimer: horizontalTimer.stop()
			if rotateTimer: rotateTimer.stop()
			isFocus = false
			ghost.queue_free()
			ghost = null
			piece_placed.emit()

var playHardDropSound:bool = false
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
signal trap_activated(stateItem:DracominoHandler.StateItem)
signal piece_placed()

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
		horizontalTimer.start(HORIZONTAL_WAIT_TIME)
		movement_requested.emit(self, Vector2i.LEFT, MOVEMENT.HORIZONTAL)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("moveRight") and Input.is_action_just_pressed("moveRight"):
		horizontalTimer.start(HORIZONTAL_WAIT_TIME)
		movement_requested.emit(self, Vector2i.RIGHT, MOVEMENT.HORIZONTAL)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("moveDown") and Input.is_action_just_pressed("moveDown") and FlagManager.isFlagSet("soft_drop"):
		softDropTimer.start(SOFT_DROP_WAIT_TIME)
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.SOFT_DROP_LOCK)
		# Avoid falling too soon
		resetGravityTimer()
		get_viewport().set_input_as_handled()
		return

#==== Functions ======
func makeActive():
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process_unhandled_input(isFocus)
	if flagHolder: flagHolder.monitoring = true
	show()
	# Avoid falling too soon
	resetGravityTimer()
	# Wait for pieces to get out of this one
	collidible = false

	# Send trap link
	if FlagManager.isFlagSet("trap_link"):
		# Prepare to send a trap link if this is a shape trap
		if stateItem and stateItem.data and stateItem.data.tags.has("trap") and not stateItem.usedTrapLink:
			_sendTrapLink(stateItem.data.internalName)
			stateItem.usedTrapLink = true
			trap_activated.emit(stateItem)
		var attachedModifier:DracominoHandler.StateItem = attachedEffects.get("modifier")
		if attachedModifier is DracominoHandler.StateItem and not attachedModifier.usedTrapLink:
			# Prepare to send a trap link if this is an enchantment
			_sendTrapLink("enchantment_curse" if rarity == "curse" else "enchantment")
			attachedModifier.usedTrapLink = true
			trap_activated.emit(attachedModifier)

func _sendTrapLink(trapInternalName:StringName) -> void:
	var trapLinkAlias:String = CONSTANTS.TRAP_ALIASES.get(trapInternalName, "")
	if trapLinkAlias and Archipelago.conn:
		Archipelago.conn.send_traplink(trapLinkAlias)
		print("Piece: Sending trap: ", trapLinkAlias)

func makeLimbo():
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process_unhandled_input(false)
	if flagHolder: flagHolder.monitoring = false
	hide()

func setPiece(pieceContext:DracominoHandler.PieceContext) -> void:
	prettyName = pieceContext.name
	pieceDefinition = PIECES.get(pieceContext.name)
	colorId = pieceContext.colorId
	if pieceDefinition:
		localCells = pieceDefinition.tiles.duplicate()
		canRotate = pieceDefinition.canRotate
		canFlip = pieceDefinition.canFlip
		can180 = pieceDefinition.can180
		origin = pieceDefinition.offset
		preferCCW = pieceDefinition.preferCCW
	elif uniquePiece:
		localCells = get_used_cells()
	else:
		printerr("Piece.setPiece:", pieceContext.name, " does not exist!")
		queue_free()
		return

	if not ghost:
		ghost = GHOSTPIECE_SCENE.instantiate()
		add_child(ghost)
	context = pieceContext
	if FlagManager.isFlagSet("randomize_orientations"):
		match pieceContext.orientationId:
			1:
				if can180:
					rotateClockwise(true)
				elif preferCCW:
					rotateCounterclockwise(true)
				else:
					rotateClockwise(true)
			2: rotate180(true)
			3: 
				if can180:
					rotateCounterclockwise(true)
				elif preferCCW:
					rotateCounterclockwise(true)
				else:
					rotateClockwise(true)
			_: updateTiles()
	elif pieceDefinition and pieceDefinition.horizontallyAmbiguous and not FlagManager.isFlagSet("legacy_orientations"):
		match pieceContext.orientationId:
			1, 3: flipHorizontal(true)
			_: updateTiles()
	else:
		updateTiles()

	attachedEffects.merge(pieceContext.effects, true)
	var attachedModifier:DracominoHandler.StateItem = attachedEffects.get("modifier")
	if attachedModifier is DracominoHandler.StateItem and attachedModifier.data:
		applyEnchantmentByName(attachedModifier.data.internalName)

func applyEnchantmentByName(enchantmentName:StringName) -> Enchantment:
	var enchantment:Enchantment = ENCHANTMENTS.get(enchantmentName)
	if enchantment is Enchantment:
		match enchantment.rarity:
			"", "random":
				enchantment = ENCHANTMENT_RANDOM_CHOICES.pick_random() as Enchantment
			"enchantment":
				enchantment = ENCHANTMENT_CHOICES.pick_random() as Enchantment
		rarity = enchantment.rarity
		if context:
			context.prettyName = enchantment.prettyName + " " + context.name
		var eligibleMods:Array[Modifier] = []
		for mod in enchantment.modifiers:
			if mod.isEligible.call():
				if mod.alwaysActive:
					applyModifer(mod)
				else:
					eligibleMods.append(mod)
		if eligibleMods.size():
			applyModifer(eligibleMods.pick_random())
		updateTiles()
		return enchantment
	return null

func applyModifer(modifier:Modifier) -> void:
	modifiers[modifier.type] = modifier.strength
	match modifier.type:
		"gravity": _on_gravity_setting_changed.call_deferred()

func updateTiles():
	if not uniquePiece:
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
	if can180:
		var newCells:Array[Vector2i] = localCells.duplicate()
		for i in newCells.size():
			newCells[i] *= -1
		if force:
			setCells(newCells)
		else:
			new_cells_requested.emit(self, newCells)

func flipHorizontal(force:bool = false):
	if canFlip:
		var newCells:Array[Vector2i] = localCells.duplicate()
		for i in newCells.size():
			newCells[i].x = -newCells[i].x
		if force:
			setCells(newCells)
		else:
			new_cells_requested.emit(self, newCells)

func flipVertical(force:bool = false):
	if canFlip:
		var newCells:Array[Vector2i] = localCells.duplicate()
		for i in newCells.size():
			newCells[i].y = -newCells[i].y
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
		if gravityTimer:
			var gravityDelay = getGravityDelay()
			gravityTimer.start(min(gravityTimer.time_left, gravityDelay))
			gravityTimer.wait_time = gravityDelay
		if gravityLockDelayed:
			movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.GRAVITY_LOCK)

func move(direction:Vector2i, isRotate:bool = false):
	currentPosition += direction
	if moveLock:
		playHardDropSound = true
	if isRotate:
		# Avoid falling/locking too soon
		if lockDelayed or gravityLockDelayed:
			gravityTimer.start(GRAVITY_LOCK_DELAY if gravityLockDelayed else -1.0)
			softDropTimer.start(SOFT_DROP_LOCK_DELAY)
			lockDelayed = false
			gravityLockDelayed = false

func resetGravityTimer() -> void:
	if not moveLock and gravityTimer:
		gravityTimer.wait_time = getGravityDelay()
		gravityTimer.start()

func getGravityDelay() -> float:
	var gravSpeed = Config.getSetting("gravity", 1.0)* (1.0 if moveLock else modifiers.get("gravity", 1.0))
	return GRAVITY_WAIT_TIME/gravSpeed

# Events
func _on_HorizontalTimer_timeout():
	if not isFocus: return
	var moved = Vector2i.ZERO
	if Input.is_action_pressed("moveLeft"):
		moved = Vector2i.LEFT
	elif Input.is_action_pressed("moveRight"):
		moved = Vector2i.RIGHT
	else:
		horizontalTimer.wait_time = HORIZONTAL_WAIT_TIME
		return
	horizontalTimer.wait_time = HORIZONTAL_REPEAT_WAIT_TIME
	horizontalTimer.start()
	movement_requested.emit(self, moved, MOVEMENT.HORIZONTAL)

func _on_SoftDropTimer_timeout():
	if not isFocus: return
	if Input.is_action_pressed("moveDown") and FlagManager.isFlagSet("soft_drop"):
		softDropTimer.start(SOFT_DROP_REPEAT_WAIT_TIME)
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.SOFT_DROP_LOCK if lockDelayed else MOVEMENT.SOFT_DROP)
		# Avoid falling too soon
		gravityTimer.start()
	else:
		softDropTimer.wait_time = SOFT_DROP_WAIT_TIME
		lockDelayed = false

func _on_GravityTimer_timeout():
	if moveLock or (
		(FlagManager.isFlagSet("gravity") and not modifiers.get("antigravity")) # Antigravity cancels out gravity
		or modifiers.get("gravity", 1) > 1 # Otherwise if gravity is set at all, it's enabled whether it's unlocked or not
	) or not isFocus:
		movement_requested.emit(
			self,
			Vector2i.DOWN,
			MOVEMENT.HARD_DROP if playHardDropSound
			else MOVEMENT.GRAVITY_LOCK if gravityLockDelayed or moveLock
			else MOVEMENT.GRAVITY
		)

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
	resetGravityTimer()
