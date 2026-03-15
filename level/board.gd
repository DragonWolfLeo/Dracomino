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

@export var holdStorage:PieceStorage

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
var holdOnCooldown:bool = false: set = _on_holdOnCooldown_set
var _lastHeldPieceContext:DracominoHandler.StateItem ## For deathlink message context

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
		updateGhostFromIndex(0)
		requestPiece()

func requestPiece(allowMultiplePieces:bool = false):
	if isGameOver: return
	if activePieces.size() and not allowMultiplePieces:
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
		holdOnCooldown = false # Holding sets this to true immediately
		activePieces.append(piece)
		piece.movement_requested.connect(_on_Piece_movement_requested)
		piece.new_cells_requested.connect(_on_Piece_new_cells_requested)
		piece.ghost_cells_requested.connect(_on_Piece_ghost_cells_requested)
		piece.makeActive()
		piece.currentPosition = SPAWN_POINT + piece.origin
		pieceTimer.reset()
		placeOnHighestRow(piece)
		activePieces_changed.emit()
		if not checkForFailure(piece):
			piece_spawned.emit(piece)

func hold():
	var piece:Piece = getFocusPiece()
	if piece and piece.moveLock:
		# Don't hold if hard dropping
		return
	if holdStorage and not holdOnCooldown:
		sfx_hold.play()
		var popped:Piece
		if piece:
			# Cleanup
			if piece.movement_requested.is_connected(_on_Piece_movement_requested):
				piece.movement_requested.disconnect(_on_Piece_movement_requested)
			if piece.new_cells_requested.is_connected(_on_Piece_new_cells_requested):
				piece.new_cells_requested.disconnect(_on_Piece_new_cells_requested)
			if piece.ghost_cells_requested.is_connected(_on_Piece_ghost_cells_requested):
				piece.ghost_cells_requested.disconnect(_on_Piece_ghost_cells_requested)
			popped = holdStorage.pushPiece(piece)
			activePieces.erase(piece)
			activePieces_changed.emit()
		else:
			popped = holdStorage.popPiece()
		if popped:
			spawnPiece(popped)
		else:
			requestPiece(true)	
		holdOnCooldown = true

func isTileOccupied(coords:Vector2i) -> bool:
	return get_cell_atlas_coords(coords).y == SET_TILE_ATLAS_ROW

func placeOnHighestRow(piece:Piece):
	var greatestY:int = 0
	for cell in piece.localCells:
		var pos:Vector2i = piece.currentPosition + cell
		if greatestY < pos.y:
			greatestY = pos.y
	if greatestY > 0:
		# If reach below top-most row, nudge up
		piece.move(Vector2i.UP)
		placeOnHighestRow(piece)

func checkForFailure(piece:Piece) -> bool:
	for cell in piece.localCells:
		var pos:Vector2i = piece.currentPosition + cell
		if isTileOccupied(pos):
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
			else "RESTART_HELD_PIECE" if holdOnCooldown and _lastHeldPieceContext
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
	holdOnCooldown = false

	# Clear board
	for y in range(BOUNDS.position.y, BOUNDS.end.y):
		for x in range(BOUNDS.position.x, BOUNDS.end.x):
			set_cell(Vector2i(x, y))
	game_started.emit()

	# Create new piece
	requestPiece.call_deferred()

func lockPiece(piece:Piece):
	var pickedUpItem:bool = false
	for pos in piece.localCells:
		if BOUNDS.has_point(piece.currentPosition + pos):
			var mapCoord:Vector2i = piece.currentPosition + pos
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

func areCellsValid(cells:Array[Vector2i], offset:Vector2i, invalidCells:Array[Vector2i] = []) -> bool:
	for cell in cells:
		var pos:Vector2i = offset + cell
		if (
			isTileOccupied(pos)
			or pos.x < BOUNDS.position.x or pos.x >= BOUNDS.end.x # Check horizontal bounds
			or pos.y >= BOUNDS.end.y # Check if reached bottom
			or invalidCells.has(pos)
		):
			return false
	return true

func setAnimBasedOnMasterCoinAndLine(node:Node2D, line:int = 0) -> void:
	var animPlayer:AnimationPlayer = node.get_node_or_null("AnimationPlayer")
	var animPlayer_master:AnimationPlayer = masterCoin.get_node_or_null("AnimationPlayer")
	if not animPlayer or not animPlayer_master: printerr("setAnimBasedOnMasterCoinAndLine error: No AnimationPlayer!"); return
	var WAVE_CYCLE:float = 40
	var targetSeek:float = -(line/WAVE_CYCLE)*animPlayer_master.current_animation_length
	targetSeek += animPlayer_master.current_animation_position
	while targetSeek < 0: targetSeek += animPlayer_master.current_animation_length
	animPlayer.seek(targetSeek)

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
	if focusPiece == null: return
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

func _on_Piece_movement_requested(piece:Piece, direction:Vector2i, movementType:int):
	if areCellsValid(piece.localCells, piece.currentPosition + direction):
		match movementType:
			Piece.MOVEMENT.HORIZONTAL: sfx_move.play()
			Piece.MOVEMENT.SOFT_DROP: sfx_moveDown.play()
		piece.move(direction)
	elif direction == Vector2i.DOWN:
		match movementType:
			Piece.MOVEMENT.HARD_DROP: sfx_hardDrop.play()
			_: sfx_drop.play()
		lockPiece(piece)

func _on_Piece_new_cells_requested(piece:Piece, cells:Array[Vector2i]):
	if areCellsValid(cells, piece.currentPosition):
		piece.setCells(cells)

func _on_Piece_ghost_cells_requested(piece:Piece, ghost:GhostPiece):
	var relativePosition:Vector2i = Vector2i.ZERO
	var invalidCells:Array[Vector2i] = []
	var updateIndex:int = 0
	# Let ghosts stack on each other
	for activePiece:Piece in activePieces:
		updateIndex += 1
		if piece == activePiece: break
		if activePiece.ghost:
			for cell:Vector2i in activePiece.ghost.localCells:
				cell += activePiece.ghost.relativePosition + activePiece.currentPosition
				if not invalidCells.has(cell):
					invalidCells.append(cell)
	# Move down until collide with something
	while areCellsValid(piece.localCells, piece.currentPosition+ relativePosition + Vector2i.DOWN, invalidCells):
		relativePosition += Vector2i.DOWN
	ghost.relativePosition = relativePosition
	
	# Add to invalid cells for other ghosts
	for cell:Vector2i in ghost.localCells:
		cell += ghost.relativePosition + piece.currentPosition
		if not invalidCells.has(cell):
			invalidCells.append(cell)
	
	# Fix other ghosts
	updateGhostFromIndex(updateIndex, invalidCells)

func updateGhostFromIndex(index:int = 0, invalidCells:Array[Vector2i] = []):
	if index >= activePieces.size():
		return

	var piece:Piece = activePieces[index]
	var relativePosition:Vector2i = Vector2i.ZERO
	# Move down until collide with something
	while areCellsValid(piece.localCells, piece.currentPosition + relativePosition + Vector2i.DOWN, invalidCells):
		relativePosition += Vector2i.DOWN
	piece.ghost.relativePosition = relativePosition
	
	# Add to invalid cells for other ghosts
	for cell:Vector2i in piece.ghost.localCells:
		cell += piece.ghost.relativePosition + piece.currentPosition
		if not invalidCells.has(cell):
			invalidCells.append(cell)

	updateGhostFromIndex(index + 1, invalidCells)


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

func _on_holdOnCooldown_set(value):
	## For deathlink message context
	var focusPiece:Piece = getFocusPiece()
	_lastHeldPieceContext = focusPiece.context if (value and focusPiece) else null
	holdOnCooldown = value

func _on_activePieces_changed():
	## Make ghosts have a gradient
	var a:float = 1.0
	for piece in activePieces:
		if piece.ghost:
			piece.ghost.modulate.a = clamp(a, 0.0, 1.0)
			if not piece.moveLock:
				a -= OPACITY_REDUCTION_PER_GHOST
