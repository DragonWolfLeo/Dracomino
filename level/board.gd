class_name Board extends TileMapLayer

@onready var PIECE_SCENE:PackedScene = load("res://object/piece.tscn")
@onready var LINENUMBER_SCENE:PackedScene = load("res://ui/linenumber.tscn")
@onready var ITEMPICKUP_SCENE:PackedScene = load("res://object/itempickup.tscn")

const BOUNDS := Rect2i(0, 0, 10, 20)
const SPAWN_POINT := BOUNDS.position + Vector2i(BOUNDS.size.x / 2, 0)
var DANGER_ZONE := BOUNDS.grow_individual(-2, 0, -2, -17)
var USE_ALT_ROTATE:bool = true # TODO: Make an option
var ALLOW_GRAVITY_DROP:bool = true # TODO: Make an option
var OPACITY_REDUCTION_PER_GHOST:float = 0.4
var MAX_PIECES:int = 10

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

@onready var masterCoin:Node2D = $MasterCoin
@onready var sfx_rotate:AudioStreamPlayer = $SFX_Rotate
@onready var sfx_move:AudioStreamPlayer = $SFX_Move
@onready var sfx_moveDown:AudioStreamPlayer = $SFX_MoveDown
@onready var sfx_drop:AudioStreamPlayer = $SFX_Drop
@onready var sfx_hardDrop:AudioStreamPlayer = $SFX_HardDrop
@onready var sfx_hold:AudioStreamPlayer = $SFX_Hold
@onready var sfx_itemPickup:AudioStreamPlayer = $SFX_ItemPickup
@onready var sfx_lineClear:AudioStreamPlayer = $SFX_LineClear
@onready var sfx_lineClearCheck:AudioStreamPlayer = $SFX_LineClearCheck
@onready var sfx_gameOver:AudioStreamPlayer = $SFX_GameOver

var activePieces:Array[Piece] = []

var rowsToClear = []
var blocksToClear = []
var animation_timer = 0.0
var animation_started = false
var isGameOver:bool = false
var sendDeathOnRestart:bool = false
var boardIsFresh:bool = true
var hasOfflineDeath:bool = false
var lineNumberLabels:Array[Label] = []
var itemPickups:Dictionary[Vector2i, ItemPickupContext] = {} 
var linesCleared:int = 0:
	set(value):
		linesCleared = value
		linesCleared_updated.emit(linesCleared)

var _lastHeldPieceContext:DracominoHandler.StateItem ## For deathlink message context; TODO: Obsolete

var _linemappings:Dictionary[int, int] = {}
var _missinglines:Dictionary[int, bool] = {}
var _missingpickups:Dictionary[Vector2i, int] = {}
var _mappedpickups:Dictionary[Vector2i, ItemPickupContext] = {}

static var random:RandomNumberGenerator = RandomNumberGenerator.new()
static var randomSaveState:int = random.state
static var rotate_random:RandomNumberGenerator = RandomNumberGenerator.new()
static var rotate_randomSaveState:int = rotate_random.state

signal lines_cleared(lines:Array)
signal linesCleared_updated(num:int)
signal game_over_earned()
signal game_started()
signal pieces_requested(callback:Callable, num:int)
signal piece_spawned(piece:Piece)
signal item_pickedup(loc_id:int)
signal rowClearAnimation_finished()
signal deathlink_earned(deathContext:DracominoUtil.DeathContext)
signal activePieces_changed()

class ItemPickupContext:
	var node:Node2D
	var coord:Vector2i
	var loc_id:int

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
	masterCoin.visible = false # Master coin is just a reference for the rest of the coins and should be hidden
	inputTimer = ActivityTimer.new(); add_child(inputTimer)
	inputTimer.afk_threshold = 10.0
	pieceTimer = ActivityTimer.new(); add_child(pieceTimer)
	game_started.emit()
	
	Archipelago.connected.connect(_on_connected)
	SignalBus.getSignal("restartGame").connect(resetGame)
	SignalBus.getSignal("deathOnRestart_enabled").connect(set.bind("sendDeathOnRestart", true))
	SignalBus.getSignal("deathOnRestart_disabled").connect(set.bind("sendDeathOnRestart", false))
	SignalBus.getSignal("newPieceObtained").connect(_on_newPieceObtained)
	activePieces_changed.connect(_on_activePieces_changed)

	# Make line numbers labels
	for i:int in range(BOUNDS.end.y):
		var scn:Node2D = LINENUMBER_SCENE.instantiate()
		var label:Label = scn.get_node("Label") as Label
		lineNumberLabels.append(label)
		label.text = str(i + 1)
		scn.position = map_to_local(Vector2i(BOUNDS.position.x, BOUNDS.end.y-i ))
		$LineNumberBar.add_child(scn)

func _process(delta):
	# TODO: Replace with tween
	if rowsToClear.size() > 0:
		blockRemoveAnimationStep(delta)

#===== Functions ======
func getFocusPiece() -> Piece:
	for piece in activePieces:
		if not piece.moveLock:
			return piece
	return null

func blockRemoveAnimationStep(delta):
	if !animation_started and blocksToClear.size() == 0:
		for x in range(BOUNDS.position.x, BOUNDS.end.x):
			blocksToClear.append(x)
		animation_started = true
	
	animation_timer += delta
	
	if animation_timer >= 0.08: 	#this number controls at which speed blocks get removed
		animation_timer = 0
		for y in rowsToClear:
			set_cell(Vector2i(blocksToClear.front(),y))
			set_cell(Vector2i(blocksToClear.back(),y))
		blocksToClear.pop_front()
		blocksToClear.pop_back()
	
	if animation_started and blocksToClear.size() == 0: 	#Animation has finished
		for i in rowsToClear:
			pushDownRows(i)
		rowsToClear = []
		animation_started = false
		rowClearAnimation_finished.emit()
		updateAllGhosts()
		requestPiece()

func requestPiece(allowMultiplePieces:bool = false):
	if isGameOver: return
	if activePieces.size() > MAX_PIECES or (activePieces.size() and not allowMultiplePieces):
		return
	fillPreview(1) # Generate one extra because we're gonna use it
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

func fillPreview(buffer:int = 0): ## This functions usually leads into createPiece being called, if there's pieces available
	if isGameOver: return

	var availableSpace:int = 0
	if previewStorage: availableSpace += previewStorage.getAvailableSpace(buffer)

	pieces_requested.emit(createPiece, availableSpace)

func createPiece(pieceName:StringName = "", pieceContext:DracominoHandler.StateItem = null) -> void:
	if pieceName.is_empty():
		return

	var piece:Piece = PIECE_SCENE.instantiate()
	piece.setPiece(pieceName, pieceContext)
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
		piece.makeActive()
		piece.currentPosition = SPAWN_POINT + piece.origin
		pieceTimer.reset()
		placeOnHighestRow(piece)
		if not checkForFailure(piece):
			if piece != getFocusPiece():
				placeAboveOtherPieces(piece)
				sortActivePieces()
			activePieces_changed.emit()
			piece_spawned.emit(piece)

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
			popped = holdStorage.pushPiece(piece, false, index)
			activePieces.erase(piece)
			activePieces_changed.emit()
		else:
			popped = holdStorage.popPiece(index)
		if popped:
			succeeded = true
			spawnPiece(popped)
		else:
			requestPiece(true)
		if succeeded:
			sfx_hold.play()

func isTileOccupied(coords:Vector2i) -> bool:
	return get_cell_atlas_coords(coords).y == SET_TILE_ATLAS_ROW

func placeOnHighestRow(piece:Piece):
	var greatestY:int = 0
	for cell in piece.globalCells:
		if greatestY < cell.y:
			greatestY = cell.y
	if greatestY > 0:
		# If reach below top-most row, nudge up
		piece.move(Vector2i.UP)
		placeOnHighestRow(piece)

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

func sortActivePieces():
	activePieces.sort_custom(
		func(a:Piece, b:Piece):
			var focusPiece = getFocusPiece()
			if a == focusPiece: return true
			if b == focusPiece: return false
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

func gameOver(deathContext:DracominoUtil.DeathContext = null):
	if isGameOver:
		print("You already died!")
		return
	sfx_gameOver.play()
	isGameOver = true
	for piece in activePieces:
		lockPiece(piece)
	activePieces.clear()
	activePieces_changed.emit()
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
		sfx_gameOver.play()
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

	# Delete current pieces
	for piece in activePieces:
		piece.queue_free()
	activePieces.clear()
	activePieces_changed.emit()

	# Clear previews and hold
	if previewStorage: previewStorage.clear()
	if holdStorage: holdStorage.clear()

	# Reset variables
	isGameOver = false
	boardIsFresh = true
	linesCleared = 0
	random.state = randomSaveState
	rotate_random.state = rotate_randomSaveState

	# Clear board
	for y in range(BOUNDS.position.y, BOUNDS.end.y):
		for x in range(BOUNDS.position.x, BOUNDS.end.x):
			set_cell(Vector2i(x, y))
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
		sfx_itemPickup.play()
	activePieces.erase(piece)
	activePieces_changed.emit()
	piece.queue_free()
	boardIsFresh = false
	
	var focusPiece:Piece = getFocusPiece() # Check collisions with new piece
	if focusPiece and checkForFailure(focusPiece):
		pass # Game over
	elif not isGameOver:
		var fullRows = checkForFullRows()
		if fullRows.size() > 0:
			linesCleared += fullRows.size()
			rowsToClear = fullRows # TODO: Replace this with a tween
			var clearedlines = fullRows.map(func(lineNum): return BOUNDS.end.y - lineNum -1)
			await rowClearAnimation_finished
			lines_cleared.emit(clearedlines)
		else:
			requestPiece.call_deferred()

func checkForFullRows() -> Array:
	var fullRows = []
	for y in range(BOUNDS.position.y, BOUNDS.end.y):
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
		(sfx_lineClearCheck if isMissingLineCheck else sfx_lineClear).play()
	return fullRows

func isInDanger() -> bool:
	for y in range(DANGER_ZONE.position.y, DANGER_ZONE.end.y):
		for x in range(DANGER_ZONE.position.x, DANGER_ZONE.end.x):
			if isTileOccupied(Vector2i(x,y)):
				return true
	return false

func pushDownRows(full_row):
	for y in range(full_row, BOUNDS.position.y -1, -1):
		for x in range(BOUNDS.position.x, BOUNDS.end.x):
			var aboveCell := Vector2i(x, y - 1)
			var target_id = get_cell_source_id(aboveCell)
			var target_atlas = get_cell_atlas_coords(aboveCell)
			set_cell(Vector2i(x,y), 0, target_atlas)

func areCellsOpen(cells:Array[Vector2i], invalidCells:Array[Vector2i] = []) -> bool:
	for cell in cells:
		if (
			isTileOccupied(cell)
			or cell.x < BOUNDS.position.x or cell.x >= BOUNDS.end.x # Check horizontal bounds
			or cell.y >= BOUNDS.end.y # Check if reached bottom
			or invalidCells.has(cell)
		):
			return false
	return true

func areCellsCollidingWithActivePieces(cells:Array[Vector2i], sourcePiece:Piece) -> bool:
	for cell:Vector2i in cells:
		for piece:Piece in activePieces:
			if piece != sourcePiece and piece.collidible:
				if piece.globalCells.has(cell):
					return true
	return false

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
			if not areCellsOpen(getTranslatedCells(piece.globalCells, relativePosition + Vector2i.DOWN), invalidCells):
				piece.ghost.relativePosition = relativePosition
				floatingPieces.erase(piece)
				mergeCells(invalidCells, getTranslatedCells(piece.globalCells, piece.ghost.relativePosition))
				somethingLanded = true
		if not somethingLanded:
			relativePosition += Vector2i.DOWN

#==== Events =====
func _unhandled_input(event: InputEvent) -> void:
	var focusPiece:Piece = getFocusPiece()
	if not isGameOver:
		if Config.getSetting("debug", false) and event.is_action_pressed("spawn"):
			requestPiece(true)
			inputTimer.reset()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("hold"):
			if DracominoHandler.activeAbilities.get("Hold Slot", 0):
				hold()
				get_viewport().set_input_as_handled()
				return
		elif not focusPiece:
			if event.is_action_pressed("ui_accept"):
				requestPiece.call_deferred()
				inputTimer.reset()
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
	if (event.is_action_pressed("moveRight") 
	or event.is_action_pressed("moveLeft")
	or event.is_action_pressed("moveDown")
	):
		pass
		# # TODO: This doesn't do anything due to piece handling it
		# # I know there's Input.get_vector, but a controller that can't reset perfectly to zero needs per-axis deadzones
		# var inputVector:Vector2 = Vector2(
		# 	Input.get_action_strength("moveRight") - Input.get_action_strength("moveLeft"),
		# 	Input.get_action_strength("moveDown") if DracominoHandler.activeAbilities.get("Soft Drop", 0) else 0.0
		# )
		
		# if inputVector.length_squared() < MIN_VELOCITY_LENGTH_SQUARED:
		# 	inputVector = Vector2.ZERO

	elif event.is_action_pressed("rotateClockwise"):
		if DracominoHandler.activeAbilities.get("Rotate Clockwise", 0):
			sfx_rotate.play()
			focusPiece.rotateClockwise()
		elif USE_ALT_ROTATE and DracominoHandler.activeAbilities.get("Rotate Counterclockwise", 0):
			sfx_rotate.play()
			focusPiece.rotateCounterclockwise()
	elif event.is_action_pressed("rotateCounterclockwise"):
		if DracominoHandler.activeAbilities.get("Rotate Counterclockwise", 0):
			sfx_rotate.play()
			focusPiece.rotateCounterclockwise()
		elif USE_ALT_ROTATE and DracominoHandler.activeAbilities.get("Rotate Clockwise", 0):
			sfx_rotate.play()
			focusPiece.rotateClockwise()
	elif event.is_action_pressed("hardDrop") and Input.is_action_just_pressed("hardDrop"): # Double check to ignore events from slight axis movement
		if DracominoHandler.activeAbilities.get("Hard Drop", 0):
			focusPiece.hardDrop()
			if not getFocusPiece(): requestPiece(true)
		elif ALLOW_GRAVITY_DROP and DracominoHandler.activeAbilities.get("Gravity", 0):
			focusPiece.gravityDrop()
			if not getFocusPiece(): requestPiece(true)
	else:
		return
	
	inputTimer.reset()
	get_viewport().set_input_as_handled()

func _on_holdSlotCycleTimer_timeout(callback:Callable):
	callback.call()

func _on_Piece_movement_requested(piece:Piece, direction:Vector2i, movementType:int):
	var translatedCells := getTranslatedCells(piece.globalCells, direction)
	if areCellsOpen(translatedCells):
		if not areCellsCollidingWithActivePieces(translatedCells, piece):
			match movementType:
				Piece.MOVEMENT.HORIZONTAL: sfx_move.play()
				Piece.MOVEMENT.SOFT_DROP: sfx_moveDown.play()
			piece.move(direction)
			piece.collidible = true # Allow collision now that we know it's in a free space
	elif direction == Vector2i.DOWN:
		match movementType:
			Piece.MOVEMENT.HARD_DROP: sfx_hardDrop.play()
			_: sfx_drop.play()
		lockPiece(piece)

func _on_Piece_new_cells_requested(piece:Piece, cells:Array[Vector2i]):
	var dirs:Array[Vector2i] = [Vector2i.ZERO]
	if DracominoHandler.activeAbilities.get("Kick", 0):
		# Add more directions to push when kick is active
		for cell in cells:
			var dir = -cell
			if not dirs.has(dir):
				dirs.append(dir)
		
	for dir:Vector2i in dirs:
		var translatedCells := getTranslatedCells(cells, piece.currentPosition + dir)
		if areCellsOpen(translatedCells) and not areCellsCollidingWithActivePieces(translatedCells, piece):
			piece.setCells(cells)
			piece.move(dir)
			return


func _on_Piece_ghost_cells_requested(_piece:Piece, _ghost:GhostPiece):
	updateAllGhosts()			

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

func _on_Btn_Restart_pressed() -> void:
	resetGame()

func _on_DracominoState_line_mappings_updated(lineMappings:Dictionary = _linemappings) -> void:
	_linemappings = lineMappings
	_mappedpickups.clear()
	for i:int in range(lineNumberLabels.size()):
		# Re-number the labels
		var line:int = lineMappings.get(i, 0)
		lineNumberLabels[i].text = str(line + 1)
		lineNumberLabels[i].modulate.a = 1.0 if _missinglines.get(line, false) else 0.2 # Make transparent if collected

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
	## Make ghosts have a gradient
	var a:float = 1.0
	for piece in activePieces:
		if piece.ghost:
			piece.ghost.modulate.a = clamp(a, 0.0, 1.0)
			if not piece.moveLock:
				a -= OPACITY_REDUCTION_PER_GHOST
