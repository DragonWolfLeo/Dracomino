class_name Board extends TileMapLayer

@onready var PIECE_SCENE:PackedScene = load("res://object/piece.tscn")
@onready var LINENUMBER_SCENE:PackedScene = load("res://ui/linenumber.tscn")
@onready var ITEMPICKUP_SCENE:PackedScene = load("res://object/itempickup.tscn")
@onready var ACTIVATEDTILE_SCENE:PackedScene = load("res://object/activatedtile.tscn")

const BOUNDS := Rect2i(0, 0, 10, 20)
const SPAWN_POINT := BOUNDS.position + Vector2i(BOUNDS.size.x / 2, 0)
var DANGER_ZONE := BOUNDS.grow_individual(-2, 0, -2, -17)
var ALLOW_GRAVITY_DROP:bool = true # TODO: Make an option
var OPACITY_REDUCTION_PER_GHOST:float = 1/3 # 
var MAX_PIECES:int = 8
var EFFECT_IMPATIENCE_NUM_PIECES_TO_SPAWN:int = 3
var DELAYED_EFFECT_CONTEXT_DURATION:float = 1.3

static var ACTIVE_TILE_ATLAS_ROW:int = 0
static var SET_TILE_ATLAS_ROW:int = 1

@export var previewStorage:PieceStorage:
	set(value):
		if previewStorage == value: return
		if previewStorage and previewStorage.storageSlots_updated.is_connected(fillPreview):
			previewStorage.storageSlots_updated.disconnect(fillPreview)
		previewStorage = value
		if previewStorage and not previewStorage.storageSlots_updated.is_connected(fillPreview):
			previewStorage.storageSlots_updated.connect(fillPreview)

@export var holdStorage:PieceStorage:
	set(value):
		if holdStorage == value: return
		if holdStorage and holdStorage.slot_triggered.is_connected(hold):
			holdStorage.slot_triggered.disconnect(hold)
		holdStorage = value
		if holdStorage and not holdStorage.slot_triggered.is_connected(hold):
			holdStorage.slot_triggered.connect(hold)

@onready var activatedTileHandler:ActivatedTileHandler = $ActivatedTileHandler
@onready var masterCoin:Node2D = $MasterCoin
@onready var focusCamera:Camera2D = $FocusCamera

var activePieces:Array[Piece] = []

var clearingChunks:Array[ClearingChunk] = []
var isGameOver:bool = false:
	set(value):
		isGameOver = value
		if flagHolder:
			if value:
				flagHolder.setFlag("gameover")
			else:
				flagHolder.clearFlag("gameover")
var sendDeathOnRestart:bool = false
var boardIsFresh:bool = true
var hasOfflineDeath:bool = false
var lineNumberLabels:Array[Label] = []
var itemPickups:Dictionary[Vector2i, ItemPickupContext] = {} 
var linesCleared:int = 0:
	set(value):
		linesCleared = value
		if flagHolder: flagHolder.setFlag("lines_cleared", linesCleared)
		linesCleared_updated.emit(linesCleared)
var flagHolder:FlagHolder
var effectHandler:EffectHandler

var _lastHeldPieceContext:DracominoHandler.StateItem ## For deathlink message context; TODO: Obsolete

var _linemappings:Dictionary[int, int] = {}
var _missinglines:Dictionary[int, bool] = {}
var _missingpickups:Dictionary[Vector2i, int] = {}
var _mappedpickups:Dictionary[Vector2i, ItemPickupContext] = {}

var _waitingForPieceToGetOutOfTopRow:Piece = null

static var random:RandomNumberGenerator = RandomNumberGenerator.new()
static var randomSaveState:int = random.state
static var rotate_random:RandomNumberGenerator = RandomNumberGenerator.new()
static var rotate_randomSaveState:int = rotate_random.state

signal lines_cleared(lines:Array)
signal linesCleared_updated(num:int)
signal game_over_earned()
signal game_started()
signal pieces_requested(callback:Callable, num:int)
signal item_pickedup(loc_id:int)
signal deathlink_earned(deathContext:DracominoUtil.DeathContext)
signal activePieces_changed()
signal effect_activated(item:DracominoHandler.StateItem) ## Relayed from EffectHandler

class ItemPickupContext:
	var node:Node2D
	var coord:Vector2i
	var loc_id:int

class ClearingChunk:
	signal completed()
	signal tile_shattered(cell:Vector2i)
	var row:int
	var tilesToActivate:Array[Vector2i]
	var mappedLine:int
	static var flip:bool = false
	func _init(_row:int) -> void:
		row = _row
		var arr:Array = range(BOUNDS.position.x, BOUNDS.end.x).map(func(x): return Vector2i(x, row))
		if flip: arr.reverse() # Make alternating chunks flip
		flip = !flip
		tilesToActivate.append_array(arr)
		mappedLine = BOUNDS.end.y - row - 1
	func pushDown() -> void:
		# Remap data when rows get pushed down
		row += 1
		for i in range(tilesToActivate.size()):
			tilesToActivate[i].y += 1
		mappedLine -= 1

var inputTimer:ActivityTimer ## For death context
var pieceTimer:ActivityTimer ## For death context

@onready var holdSlotCycleTimer:Timer = $HoldSlotCycleTimer

#===== Static Functions ======
static func getTranslatedCells(cells:Array[Vector2i], offset:Vector2i) -> Array[Vector2i]:
	var ret:Array[Vector2i] = []
	ret.append_array(cells.map(func(cell:Vector2i): return cell + offset))
	return ret

static func mergeCells(destination:Array[Vector2i], cells:Array[Vector2i]) -> void:
	for cell in cells:
		if not destination.has(cell):
			destination.append(cell)

#===== Virtuals ======
func _ready():
	# Set up flag holder
	resetFlagHolder()
	# Set up effect handler
	effectHandler = EffectHandler.new()
	add_child(effectHandler)
	effectHandler.effect_activated.connect(effect_activated.emit)
	effectHandler.effect_activated.connect(_on_effected_activated)
	 # Master coin is just a reference for the rest of the coins and should be hidden 
	masterCoin.visible = false
	# Set up input timers
	inputTimer = ActivityTimer.new(); add_child(inputTimer)
	inputTimer.afk_threshold = 10.0
	pieceTimer = ActivityTimer.new(); add_child(pieceTimer)
	#
	game_started.emit.call_deferred()
	
	Archipelago.connected.connect(_on_connected)
	SignalBus.getSignal("restartGame").connect(resetGame)
	SignalBus.getSignal("deathOnRestart_enabled").connect(set.bind("sendDeathOnRestart", true))
	SignalBus.getSignal("deathOnRestart_disabled").connect(set.bind("sendDeathOnRestart", false))
	SignalBus.getSignal("stateflag_changed", "shapes").connect(_on_newPieceObtained, CONNECT_DEFERRED)
	activePieces_changed.connect(_on_activePieces_changed)
	var mode:Mode = DracominoUtil.getParentMode(self)
	if mode:
		mode.mode_enabled.connect(_on_mode_enabled)
	# Effect signals
	SignalBus.getSignal("effect_impatience").connect(_on_effect_impatience)

	# Make line numbers labels
	for i:int in range(BOUNDS.end.y):
		var scn:Node2D = LINENUMBER_SCENE.instantiate()
		var label:Label = scn.get_node("Label") as Label
		lineNumberLabels.append(label)
		label.text = str(i + 1)
		scn.position = map_to_local(Vector2i(BOUNDS.position.x, BOUNDS.end.y-i ))
		$LineNumberBar.add_child(scn)


#===== Functions ======
func resetFlagHolder():
	if flagHolder: flagHolder.queue_free()
	flagHolder = FlagHolder.new(FlagHolder.PRIORITY.LEVEL)
	FlagManager.HANDLERS.LEVEL.setAsFlagHolder(flagHolder)
	add_child(flagHolder)

func getFocusPiece() -> Piece:
	for piece in activePieces:
		if piece.isFocus:
			return piece
	return null

func chooseNewFocusPiece(requestIfNone:bool = false) -> void:
	var focusPiece:Piece = null
	for piece in activePieces:
		if not piece.moveLock and not focusPiece:
			piece.isFocus = true
			focusPiece = piece
			# Make focus camera follow with a bit of a delay
			if piece == activePieces.front():
				var tween:Tween = piece.create_tween()
				var delay:float = 1.0 if clearingChunks.size() else 0.5
				tween.tween_callback(focusCamera.set.bind("global_position", piece.global_position)).set_delay(delay)
				piece.movement_requested.connect(tween.kill.unbind(3), CONNECT_ONE_SHOT)
		else:
			piece.isFocus = false
	if requestIfNone and not focusPiece:
		requestPiece(true)

func countNonlockedPieces() -> int:
	var num = activePieces.reduce(
		func(accum:int, piece:Piece):
			return accum + (0 if piece.moveLock else 1),
			0
		)
	return num

func processClearingChunk(chunk:ClearingChunk) -> void:	
	chunk.tile_shattered.connect(set_cell)
	activatedTileHandler.activateChunk(chunk, 
		func():					
			clearingChunks.erase(chunk)
			chunk.completed.emit()
			pushDownRows(chunk)
			lines_cleared.emit([chunk.mappedLine])
			if not clearingChunks.size():
				checkForEvent(["line_clear"])
	)

func checkForEvent(context:Array[StringName] = []):
	var nextEffect = effectHandler.tryToTriggerNextEffect(context)
	if not effectHandler.willBlockRequestPiece(nextEffect, true):
		requestPiece()

func requestPiece(allowMultiplePieces:bool = false):
	if (
		isGameOver # Obviously don't make pieces when game over'd
		or activePieces.size() > MAX_PIECES # No making pieces when the max is reached
		or (countNonlockedPieces() and not allowMultiplePieces) # No making multiple pieces if disallowed
	):
		return
	if effectHandler.hasValidBufferedEvent():
		if clearingChunks.size():
			return
		checkForEvent()
		return
	
	# Try to spawn delayed thing
	var tween:Tween = effectHandler.create_tween()
	tween.tween_callback(effectHandler.tryToTriggerNextEffect.bind(["delayed"] as Array[StringName]))\
	.set_delay(DELAYED_EFFECT_CONTEXT_DURATION/Config.getSetting("gravity", 1.0))

	fillPreview(2) # Generate one extra because we're gonna use it, and another so gravity drop can work
	if clearingChunks.size() or (activePieces.size() and activePieces[0].moveLock):
		var nextPiece = previewStorage.nextPiece()
		if not nextPiece or not canSafelySpawnPiece(nextPiece):
			return
	var poppedPiece:Piece
	if previewStorage:
		poppedPiece = previewStorage.popPiece()
	if poppedPiece:
		print("Spawned {pieceName} from {sender}'s {location} in {game}".format({
			pieceName = poppedPiece.prettyName,
			sender = "self" if poppedPiece.context.isLocal else poppedPiece.context.senderName,
			location = poppedPiece.context.locationName,
			game = poppedPiece.context.gameName,
		}))
		spawnPiece(poppedPiece)
		var onSpawnEffect:DracominoHandler.StateItem = poppedPiece.attachedEffects.get("on_spawn")
		if onSpawnEffect: effectHandler.tryToTriggerEffect(onSpawnEffect)

func fillPreview(buffer:int = 0): ## This functions usually leads into createPiece being called, if there's pieces available
	if isGameOver: return

	var availableSpace:int = 0
	if previewStorage: availableSpace += previewStorage.getAvailableSpace(buffer)

	if availableSpace <= 0: return

	pieces_requested.emit(createPiece, availableSpace)

func createPiece(pieceName:StringName = "", pieceContext:DracominoHandler.StateItem = null, effects:Dictionary = {}) -> void:
	if pieceName.is_empty():
		return

	var piece:Piece = PIECE_SCENE.instantiate()
	piece.setPiece(pieceName, pieceContext, effects)
	add_child(piece)
	game_started.connect(piece.queue_free)
	
	if previewStorage:
		previewStorage.pushPiece(piece, true)

func spawnPiece(piece:Piece):
	if not activePieces.has(piece):
		activePieces.append(piece)
		piece.movement_requested.connect(_on_Piece_movement_requested)
		piece.new_cells_requested.connect(_on_Piece_new_cells_requested)
		piece.ghost_cells_requested.connect(_on_Piece_ghost_cells_requested)
		piece.focus_lost.connect(_on_Piece_focus_lost.bind(piece))
		piece.tree_exiting.connect(_on_Piece_tree_exiting.bind(piece))
		piece.makeActive()
		piece.currentPosition = SPAWN_POINT + piece.origin
		pieceTimer.reset()
		placeOnHighestRow(piece)
		if not checkForFailure(piece):
			activePieces_changed.emit()
			if piece == activePieces.front():
				focusCamera.global_position = piece.global_position
			if piece.isFocus:
				forceShoveOtherPiecesDown(piece)
			else:
				placeAboveOtherPieces(piece)
				sortActivePieces()
			tryToMakePiecesCollible()

func deletePiece(piece:Piece): ## Remove a piece without emitting activePieces_changed
	if piece.focus_lost.is_connected(_on_Piece_focus_lost):
		piece.focus_lost.disconnect(_on_Piece_focus_lost)
	activePieces.erase(piece)
	piece.queue_free()

func hold(index:int = -1):
	var piece:Piece = getFocusPiece()
	if piece and (piece.moveLock or piece.holdLock):
		# Don't hold if hard dropping or hold-locked
		return
	if holdStorage:
		var succeeded:bool = piece != null
		var popped:Piece
		if piece:
			piece.holdLock = true # Prevent from being held again
			# Cleanup
			if piece.movement_requested.is_connected(_on_Piece_movement_requested):
				piece.movement_requested.disconnect(_on_Piece_movement_requested)
			if piece.new_cells_requested.is_connected(_on_Piece_new_cells_requested):
				piece.new_cells_requested.disconnect(_on_Piece_new_cells_requested)
			if piece.ghost_cells_requested.is_connected(_on_Piece_ghost_cells_requested):
				piece.ghost_cells_requested.disconnect(_on_Piece_ghost_cells_requested)
			if piece.focus_lost.is_connected(_on_Piece_focus_lost):
				piece.focus_lost.disconnect(_on_Piece_focus_lost)
			if piece.tree_exiting.is_connected(_on_Piece_tree_exiting):
				piece.tree_exiting.disconnect(_on_Piece_tree_exiting)
			popped = holdStorage.pushPiece(piece, false, index)
			activePieces.erase(piece)
		else:
			popped = holdStorage.popPiece(index)
		if popped:
			succeeded = true
			spawnPiece(popped)
		else:
			requestPiece(true)
		if succeeded:
			activePieces_changed.emit()
			SoundManager.play("hold")

func isTileOccupied(coords:Vector2i) -> bool:
	return get_cell_source_id(coords) != -1

func placeOnHighestRow(piece:Piece):
	var greatestY:int = 0
	for cell in piece.globalCells:
		if greatestY < cell.y:
			greatestY = cell.y
	if greatestY > 0:
		# If reach below top-most row, nudge up
		piece.move(Vector2i.UP)
		placeOnHighestRow(piece)

func getCellsTranslatedOntoHighestRow(cells:Array[Vector2i]) -> Array[Vector2i]:
	var greatestY:int = 0
	for cell in cells:
		if greatestY < cell.y:
			greatestY = cell.y
	if greatestY > 0:
		# If reach below top-most row, nudge up
		cells = getTranslatedCells(cells, Vector2i.UP)
		return getCellsTranslatedOntoHighestRow(cells)
	return cells

func placeRandomHorizontally(piece:Piece):
	var rect:Rect2i
	rect.position = piece.currentPosition
	for cell:Vector2i in piece.globalCells:
		rect = rect.expand(cell)
	piece.move(Vector2i(randi_range(-rect.position.x, BOUNDS.end.x-rect.end.x-1),0))

func placeAboveOtherPieces(piece:Piece):
	placeRandomHorizontally(piece)
	for cell:Vector2i in piece.globalCells:
		for activePiece:Piece in activePieces:
			if activePiece != piece and not activePiece.moveLock:
				if activePiece.globalCells.has(cell):
					piece.move(Vector2i.UP)
					placeAboveOtherPieces(piece)
					return

func forceShoveOtherPiecesDown(piece:Piece):
	var lowerPieces:Array[Piece] = []
	for activePiece:Piece in activePieces:
		if activePiece == piece:
			break
		lowerPieces.append(activePiece)
	for lowerPiece:Piece in activePieces:
		if lowerPiece != piece and lowerPiece.moveLock:
			var nudgeResult:bool = nudgePiece(piece.globalCells, lowerPiece, Vector2i.DOWN, true)
			if nudgeResult:
				# Can't move, so lock pieces, and instantly lose
				lockPiece(piece)
				lockPiece(lowerPiece)

func nudgePiece(cells:Array[Vector2i], piece:Piece, direction:Vector2i, force:bool = false) -> bool: ## false = unblocked; true = blocked
	for cell:Vector2i in cells:
		if piece.globalCells.has(cell):
			var blocked:bool = tryMovePiece(piece, direction, Piece.MOVEMENT.FORCED_SHOVE if force else Piece.MOVEMENT.SHOVE)
			if activePieces.has(piece) and not blocked:
				return nudgePiece(cells, piece, direction, force)
			return blocked
	return false

func tryMovePiece(piece:Piece, direction:Vector2i, movementType:int) -> bool: ## false = unblocked; true = blocked
	# Check if a non-collidible piece isn't inside another piece
	if not piece.collidible and getCollidingPiece(piece.globalCells, piece) != null:
		return true
	# Check tiles the piece want to move
	var translatedCells := getTranslatedCells(piece.globalCells, direction)
	if areCellsOpen(translatedCells, [], true):
		var blocked:bool = false
		# Prevent going through activated lines
		if direction == Vector2i.DOWN:
			var lowestY:int = BOUNDS.position.y
			for cell in translatedCells:
				if cell.y > lowestY:
					lowestY = cell.y
			if isRowClearing(lowestY):
				return true
		var forceful:bool = movementType == Piece.MOVEMENT.FORCED_SHOVE or Piece.MOVEMENT.HARD_DROP
		piece.collidible = true # Allow collision now that we know it's in a free space
		var collidingPieces:Array[Piece] = getAllCollidingPieces(translatedCells, piece)
		if collidingPieces.size():
			match movementType:
				Piece.MOVEMENT.HORIZONTAL: 
					if not FlagManager.isFlagSet("horizontal_shove"):
						blocked = true
				Piece.MOVEMENT.SOFT_DROP, Piece.MOVEMENT.SOFT_DROP_LOCK:
					if not FlagManager.isFlagSet("vertical_shove"):
						blocked = true
			if not blocked:
				for collidingPiece:Piece in collidingPieces:
					var nudgeResult = nudgePiece(translatedCells, collidingPiece, direction, forceful)
					if nudgeResult: blocked = true
		if not blocked:
			piece.move(direction)
			if piece == activePieces.front():
				focusCamera.global_position = piece.global_position
			tryToMakePiecesCollible()
			checkIfWaitingToChooseNewFocusPiece()
			match movementType:
				Piece.MOVEMENT.HORIZONTAL:
					SoundManager.play("move")
				Piece.MOVEMENT.SOFT_DROP, Piece.MOVEMENT.SOFT_DROP_LOCK:
					SoundManager.play("move_down")
		return blocked
	elif direction == Vector2i.DOWN:
		# Lock piece
		match movementType:
			Piece.MOVEMENT.HARD_DROP, Piece.MOVEMENT.SHOVE, Piece.MOVEMENT.FORCED_SHOVE:

				lockPiece(piece)
				SoundManager.play("harddrop")
			Piece.MOVEMENT.SOFT_DROP:
				if FlagManager.isFlagSet("lock_delay"):
					piece.lockDelayed = true
				else:
					lockPiece(piece)
					SoundManager.play("drop")
			_:
				lockPiece(piece)
				SoundManager.play("drop")
	return true

func tryToMakePiecesCollible() -> void: ## Check if all noncollible pieces are in a free space to turn them collidible
	for piece:Piece in activePieces:
		if not piece.collidible and getCollidingPiece(piece.globalCells, piece) == null:
			piece.collidible = true

func checkIfWaitingToChooseNewFocusPiece() -> void: ## Wait for a dropped piece to get out the way before spawning a new one
	if not _waitingForPieceToGetOutOfTopRow:
		return
	for piece:Piece in activePieces:
		if isPieceOnTopRow(piece):
			return
	if is_instance_valid(_waitingForPieceToGetOutOfTopRow):
		chooseNewFocusPiece(not effectHandler.willBlockRequestPiece(_waitingForPieceToGetOutOfTopRow.attachedEffects.get("on_lock")))
	else:
		chooseNewFocusPiece(true)

	_waitingForPieceToGetOutOfTopRow = null

func sortActivePieces():
	activePieces.sort_custom(
		func(a:Piece, b:Piece):
			if a.isFocus: return true
			if b.isFocus: return false
			if a.moveLock and not b.moveLock:
				return true
			if b.moveLock and not a.moveLock:
				return false
			return a.currentPosition.y >= b.currentPosition.y
	)

func checkForFailure(piece:Piece) -> bool:
	for cell in piece.globalCells:
		if isTileOccupied(cell):
			# Trigger game over
			var deathContext := DracominoUtil.DeathContext.new(
				"TOP_NO_INPUT" if inputTimer.isAFK() else "TOP",
				piece.context
			)
			gameOver(deathContext)
			return true
	return false

func canSafelySpawnPiece(piece:Piece) -> bool:
	if not piece: return false
	var cells:Array[Vector2i] = getCellsTranslatedOntoHighestRow(getTranslatedCells(piece.localCells, SPAWN_POINT + piece.origin))
	for cell in cells:
		if isTileOccupied(cell):
			return false
	return true

func gameOver(deathContext:DracominoUtil.DeathContext = null):
	if isGameOver:
		print("You already died!")
		return
	SoundManager.play("gameover")
	isGameOver = true
	for piece in activePieces:
		lockPiece(piece)
	game_over_earned.emit()
	if deathContext and Archipelago.is_deathlink():
		if Archipelago.conn:
			sendDeathLink(deathContext)
		else:
			hasOfflineDeath = true

func sendDeathLink(deathContext:DracominoUtil.DeathContext):
	if Archipelago.is_deathlink() and Archipelago.conn:
		deathlink_earned.emit(deathContext) # For DracominoHandler to handle

func resetGame():
	var focusPiece:Piece = getFocusPiece()
	# Send deathlink message
	if sendDeathOnRestart and not isGameOver and not boardIsFresh:
		SoundManager.play("gameover")
		var deathContext := DracominoUtil.DeathContext.new(
			# category
			"RESTART_NEAR_GAME_OVER" if focusPiece and isInDanger()
			else "RESTART_WITH_PIECES" if focusPiece
			else "RESTART_HELD_PIECE" if _lastHeldPieceContext # TODO: Not possible anymore
			else "RESTART",
			# itemContext
			focusPiece.context if focusPiece
			else _lastHeldPieceContext
		)
		if not deathContext.itemContext and pieceTimer.isAFK():
			deathContext.addContext("WAITED")
			deathContext.formatValues.merge({waittime = pieceTimer.toPrettyTime()})
		sendDeathLink(deathContext)

	# Delete pickups
	for k in itemPickups.keys():
		if itemPickups[k] and itemPickups[k].node:
			itemPickups[k].node.queue_free()
			itemPickups[k].node = null
		itemPickups.erase(k)

	# Clear effects and queue
	effectHandler.on_board_reset()

	# Delete current pieces
	for piece in activePieces:
		deletePiece(piece)
	activePieces_changed.emit()
	activePieces.clear() # Clear now to avoid weird race condition

	# Clear previews and hold
	if previewStorage: previewStorage.clear()
	if holdStorage: holdStorage.clear()

	# Reset variables
	isGameOver = false
	boardIsFresh = true
	linesCleared = 0
	random.state = randomSaveState
	rotate_random.state = rotate_randomSaveState
	clearingChunks.clear()
	resetFlagHolder()

	# Clear board
	activatedTileHandler.clear()
	clear()
	game_started.emit()

	# Create new piece
	requestPiece.call_deferred()

func lockPiece(piece:Piece):
	var pickedUpItem:bool = false
	for cell in piece.globalCells:
		if BOUNDS.has_point(cell):
			var mapCoord:Vector2i = cell
			set_cell(mapCoord, 0, Vector2i(piece.id, SET_TILE_ATLAS_ROW))
			var pickup:ItemPickupContext = _mappedpickups.get(mapCoord)
			if pickup:
				pickedUpItem = true
				if pickup.node:
					pickup.node.queue_free()
					pickup.node = null
				item_pickedup.emit(pickup.loc_id)
	if pickedUpItem:
		SoundManager.play("itempickup")

	boardIsFresh = false
	
	var onLockEffect:DracominoHandler.StateItem = piece.attachedEffects.get("on_lock")
	if not isGameOver:
		var fullRows:Array[int] = getFullRows()
		if fullRows.size() > 0:
			if onLockEffect: effectHandler.bufferEffect(onLockEffect)
			linesCleared += fullRows.size()
			for row:int in fullRows:
				var chunk := ClearingChunk.new(row)
				clearingChunks.append(chunk)
				processClearingChunk(chunk)
		else:
			if onLockEffect: effectHandler.tryToTriggerEffect(onLockEffect)
	
	deletePiece(piece)
	var fx = effectHandler.getEffectObject(onLockEffect)
	if fx and fx.blockRequestPiece and not isGameOver:
		pass
	else:
		activePieces_changed.emit()

	SignalBus.getSignal("effect_duration_down").emit() # Used to count down effect duration

func getFullRows() -> Array[int]:
	var fullRows:Array[int] = []
	for y in range(BOUNDS.position.y, BOUNDS.end.y):
		# Ignore chunks that are already recognized as clearing
		if isRowClearing(y):
			continue
		# Check if row is full
		var full:bool = true
		for x in range(BOUNDS.position.x, BOUNDS.end.x):
			if not isTileOccupied(Vector2i(x, y)):
				full = false
				break
		if full:
			fullRows.append(y)
	if fullRows.size():
		# Figure out if this is a check or not so we can play the correct sound
		var isMissingLineCheck:bool = false
		for i in fullRows:
			var line:int = _linemappings.get(BOUNDS.end.y - i - 1, 0) 
			isMissingLineCheck = _missinglines.get(line, false)
		SoundManager.play("lineclear_check" if isMissingLineCheck else "lineclear")
	return fullRows

func isRowClearing(row:int) -> bool:
	for chunk in clearingChunks:
		if chunk.row == row:
			return true
	return false

func isPieceOnTopRow(piece:Piece) -> bool:
	for cell in piece.globalCells:
		if cell.y <= BOUNDS.position.y:
			return true
	return false

func isInDanger() -> bool:
	for y in range(DANGER_ZONE.position.y, DANGER_ZONE.end.y):
		for x in range(DANGER_ZONE.position.x, DANGER_ZONE.end.x):
			if isTileOccupied(Vector2i(x,y)):
				return true
	return false

func pushDownRows(clearedChunk:ClearingChunk) -> void:
	# Move tiles down
	for y in range(clearedChunk.row, BOUNDS.position.y -1, -1):
		for x in range(BOUNDS.position.x, BOUNDS.end.x):
			set_cell(Vector2i(x,y), 0, get_cell_atlas_coords(Vector2i(x, y - 1)))

	activatedTileHandler.pushDownRows(clearedChunk.row)
			
	# Move clearing chunks down
	for chunk in clearingChunks:
		if chunk.row < clearedChunk.row:
			chunk.pushDown()

	# Update ghosts
	updateAllGhosts()

func areCellsOpen(cells:Array[Vector2i], invalidCells:Array[Vector2i] = [], clearingRowsAreOpen:bool = false) -> bool:
	for cell in cells:
		if clearingRowsAreOpen and isRowClearing(cell.y):
			continue
		if (
			isTileOccupied(cell)
			or cell.x < BOUNDS.position.x or cell.x >= BOUNDS.end.x # Check horizontal bounds
			or cell.y >= BOUNDS.end.y # Check if reached bottom
			or invalidCells.has(cell)
		):
			return false
	return true

func getCollidingPiece(cells:Array[Vector2i], sourcePiece:Piece) -> Piece:
	for piece:Piece in activePieces:
		if piece != sourcePiece and piece.collidible:
			for cell:Vector2i in cells:
				if piece.globalCells.has(cell):
					return piece
	return null

func getAllCollidingPieces(cells:Array[Vector2i], sourcePiece:Piece) -> Array[Piece]:
	var ret:Array[Piece] = []
	for piece:Piece in activePieces:
		if piece != sourcePiece and piece.collidible:
			for cell:Vector2i in cells:
				if piece.globalCells.has(cell):
					ret.append(piece)
					break
	return ret

func setAnimBasedOnMasterCoinAndLine(node:Node2D, line:int = 0) -> void:
	var animPlayer:AnimationPlayer = node.get_node_or_null("AnimationPlayer")
	var animPlayer_master:AnimationPlayer = masterCoin.get_node_or_null("AnimationPlayer")
	if not animPlayer or not animPlayer_master: printerr("setAnimBasedOnMasterCoinAndLine error: No AnimationPlayer!"); return
	var WAVE_CYCLE:float = 40
	var targetSeek:float = -(line/WAVE_CYCLE)*animPlayer_master.current_animation_length
	targetSeek += animPlayer_master.current_animation_position
	while targetSeek < 0: targetSeek += animPlayer_master.current_animation_length
	animPlayer.seek(targetSeek)

func updateAllGhosts():
	var floatingPieces:Array[Piece] = []
	var invalidCells:Array[Vector2i] = []
	var relativePosition:Vector2i = Vector2i.ZERO
	for piece in activePieces:
		if piece.ghost:
			floatingPieces.append(piece)
	while floatingPieces.size():
		var somethingLanded:bool = false
		for piece:Piece in floatingPieces.duplicate():
			if not areCellsOpen(getTranslatedCells(piece.globalCells, relativePosition + Vector2i.DOWN), invalidCells, false):
				piece.ghost.relativePosition = relativePosition
				floatingPieces.erase(piece)
				mergeCells(invalidCells, getTranslatedCells(piece.globalCells, piece.ghost.relativePosition))
				somethingLanded = true
		if not somethingLanded:
			relativePosition += Vector2i.DOWN

#==== Events =====
func _input(event: InputEvent) -> void:
	if event.is_action_type():
		inputTimer.reset()

func _unhandled_input(event: InputEvent) -> void:
	var focusPiece:Piece = getFocusPiece()
	if not isGameOver:
		if Config.getSetting("debug", false) and event.is_action_pressed("spawn"):
			requestPiece(true)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("hold"):
			if FlagManager.isFlagSet("hold_slot"):
				hold()
				get_viewport().set_input_as_handled()
				return
		elif not focusPiece:
			if event.is_action_pressed("ui_accept"):
				requestPiece.call_deferred()
				get_viewport().set_input_as_handled()
				return
		
		# Cycle hold slots
		if holdStorage and holdStorage.storageSlots > 1 and (event.is_action("scrollUp") or event.is_action("scrollDown")):
			var strength:float = Input.get_action_strength("scrollDown") - Input.get_action_strength("scrollUp")
			if strength == 0:
				holdSlotCycleTimer.stop()
				if holdSlotCycleTimer.timeout.is_connected(_on_holdSlotCycleTimer_timeout):
					holdSlotCycleTimer.timeout.disconnect(_on_holdSlotCycleTimer_timeout)
			elif holdSlotCycleTimer.is_stopped():
				var fn:Callable = holdStorage.cycleUp if strength < 0 else holdStorage.cycleDown
				fn.call()
				holdSlotCycleTimer.start()
				if not holdSlotCycleTimer.timeout.is_connected(_on_holdSlotCycleTimer_timeout):
					holdSlotCycleTimer.timeout.connect(_on_holdSlotCycleTimer_timeout.bind(fn))
			get_viewport().set_input_as_handled()
			return

	if focusPiece == null: return
	
	# Stuff that requires an active piece
	if event.is_action_pressed("hardDrop") and Input.is_action_just_pressed("hardDrop"): # Double check to ignore events from slight axis movement
		if FlagManager.isFlagSet("hard_drop"):
			focusPiece.hardDrop()
		elif (
			ALLOW_GRAVITY_DROP 
			and FlagManager.isFlagSet("gravity")
			and activePieces.size() < MAX_PIECES
			and (countNonlockedPieces() > 1 or (previewStorage and previewStorage.getNumStored()))
		):
			# Only gravity drop if it's not your last piece
			focusPiece.gravityDrop()
	else:
		return
	
	get_viewport().set_input_as_handled()

func _on_holdSlotCycleTimer_timeout(callback:Callable):
	callback.call()

func _on_Piece_movement_requested(piece:Piece, direction:Vector2i, movementType:int):
	tryMovePiece(piece, direction, movementType)

func _on_Piece_new_cells_requested(piece:Piece, cells:Array[Vector2i]):
	var dirs:Array[Vector2i] = [Vector2i.ZERO]
	if FlagManager.isFlagSet("kick"):
		# Add more directions to push when kick is active
		dirs.append_array([
			Vector2i.DOWN,
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.DOWN+Vector2i.LEFT,
			Vector2i.DOWN+Vector2i.RIGHT,
			(Vector2i.DOWN*2)+Vector2i.RIGHT,
			(Vector2i.DOWN*2)+Vector2i.LEFT,
			Vector2i.UP,
		])
		
	for dir:Vector2i in dirs:
		var translatedCells := getTranslatedCells(cells, piece.currentPosition + dir)
		if areCellsOpen(translatedCells) and not getCollidingPiece(translatedCells, piece):
			piece.setCells(cells)
			piece.move(dir, true)
			SoundManager.play("rotate")
			if dir.x != 0:
				SoundManager.play("move")
			elif dir.y != 0:
				SoundManager.play("move_down")
			return
	SoundManager.play("rotate_fail")

func _on_Piece_ghost_cells_requested(_piece:Piece, _ghost:GhostPiece):
	updateAllGhosts()			

func _on_Piece_focus_lost(piece:Piece):
	if FlagManager.isFlagSet("hard_drop") and is_instance_valid(piece) and isPieceOnTopRow(piece):
		_waitingForPieceToGetOutOfTopRow = piece
	else:
		chooseNewFocusPiece(not effectHandler.willBlockRequestPiece(piece.attachedEffects.get("on_lock")))

func _on_Piece_tree_exiting(piece:Piece): # Fallback if piece didn't delete properly
	activePieces.erase(piece)

func _on_connected(conn:ConnectionInfo, json:Dictionary):
	conn.deathlink.connect(_on_deathlink)
	if hasOfflineDeath:
		hasOfflineDeath = false
		sendDeathLink(DracominoUtil.DeathContext.new("OFFLINE"))

func _on_deathlink(_source, _cause, _json):
	gameOver()

func _on_newPieceObtained():
	fillPreview()
	requestPiece()

func _on_DracominoState_line_mappings_updated(lineMappings:Dictionary = _linemappings) -> void:
	_linemappings = lineMappings
	_mappedpickups.clear()
	for i:int in range(lineNumberLabels.size()):
		# Re-number the labels
		var line:int = lineMappings.get(i, 0)
		lineNumberLabels[i].text = str(line + 1)
		lineNumberLabels[i].modulate = Color.WHITE if _missinglines.get(line, false) else Color8(0x55,0x55,0x55) # Make dark if collected

		# Organize the pickups
		for j:int in range(BOUNDS.size.x):
			var vec:Vector2i = Vector2i(j,line)
			if _missingpickups.has(vec):
				# Create if it doesn't exist
				if itemPickups.get(vec) == null:
					itemPickups[vec] = ItemPickupContext.new()
					itemPickups[vec].coord = vec
					itemPickups[vec].loc_id = _missingpickups[vec]
				if itemPickups[vec].node == null:
					itemPickups[vec].node = ITEMPICKUP_SCENE.instantiate()
					add_child(itemPickups[vec].node)
					setAnimBasedOnMasterCoinAndLine(itemPickups[vec].node, line)
				# Move into the proper place
				var mapCoord = Vector2i(j + BOUNDS.position.x, BOUNDS.end.y - i -1)
				itemPickups[vec].node.position = map_to_local(mapCoord)
				_mappedpickups[mapCoord] = itemPickups[vec]

func _on_DracominoState_missing_lines_updated(lineLocs: Dictionary[int, bool]) -> void:
	_missinglines = lineLocs
	_on_DracominoState_line_mappings_updated()

func _on_DracominoState_missing_pickup_coordinates_updated(map:Dictionary[Vector2i, int]) -> void:
	_missingpickups = map
	# Remove anything that's disappeared
	for k:Vector2i in itemPickups:
		if not map.has(k):
			if itemPickups[k] and itemPickups[k].node:
				itemPickups[k].node.queue_free()
				itemPickups[k].node = null
			itemPickups.erase(k)
	_on_DracominoState_line_mappings_updated()

func _on_DracominoState_slot_context_hash_updated(ctx:int) -> void:
	random.seed = ctx
	randomSaveState = random.state
	rotate_random.seed = ctx+1
	rotate_randomSaveState = rotate_random.state

func _on_activePieces_changed():
	var a:float = 1.0
	chooseNewFocusPiece(true)
	for piece in activePieces:
		## Make ghosts have a gradient
		if piece.ghost:
			piece.ghost.modulate.a = clamp(a, 0.0, 1.0)
			if not piece.isFocus and not piece.moveLock:
				a -= OPACITY_REDUCTION_PER_GHOST

func _on_mode_enabled():
	inputTimer.reset()
	pieceTimer.isAFK()
	requestPiece()

func _on_FishingBoard_piece_selected(piece:Piece) -> void:
	if previewStorage:
		var popped = previewStorage.popPieceByPiece(piece)
		if popped:
			print("Fished up a %s"%piece.prettyName)
			spawnPiece(popped)
			return
	requestPiece()

func _on_effected_activated(item:DracominoHandler.StateItem):
	if FlagManager.isFlagSet("trap_link") and item and item.data and not item.usedTrapLink:
		var trapLinkAlias:String = CONSTANTS.TRAP_ALIASES.get(item.data.internalName, "")
		if trapLinkAlias and Archipelago.conn:
			item.usedTrapLink = true
			Archipelago.conn.send_traplink(trapLinkAlias)
			print("Board: Sending trap: ", trapLinkAlias)

func _on_effect_impatience():
	var tween:Tween = create_tween().set_parallel()
	SoundManager.play("trap")
	for i in range(EFFECT_IMPATIENCE_NUM_PIECES_TO_SPAWN):
		tween.tween_callback(requestPiece.bind(true)).set_delay(i*0.5)
