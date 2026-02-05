class_name Piece extends TileMapLayer

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
}

@onready var horizontalTimer:Timer = $HorizontalTimer
@onready var softDropTimer:Timer = $SoftDropTimer
@onready var gravityTimer:Timer = $GravityTimer

@onready var GRAVITY_WAIT_TIME:float = gravityTimer.wait_time
var HARD_DROP_WAIT_TIME:float = 0.01
@onready var SOFT_DROP_WAIT_TIME:float = softDropTimer.wait_time
var SOFT_DROP_REPEAT_WAIT_TIME:float = .04
@onready var HORIZONTAL_WAIT_TIME:float = horizontalTimer.wait_time
var HORIZONTAL_REPEAT_WAIT_TIME:float = .075

enum MOVEMENT {
	NONE = -1,
	HORIZONTAL,
	SOFT_DROP,
	GRAVITY,
	HARD_DROP,
}

static var TOTAL_NUMBER_OF_COLORS = 12
var pieceDefinition:PieceDefinition
var localCells:Array[Vector2i] =[]
var currentPosition:Vector2i: set = _setCurrentPosition
var origin:Vector2i
var id:int
var prettyName:String = "Piece"
var context:DracominoHandler.StateItem = null
var moveLock:bool = false: ## Prevent moving this anymore
	set(value):
		if horizontalTimer: horizontalTimer.paused = value
		if softDropTimer: softDropTimer.paused = value
		moveLock = value
var playHardDropSound:bool = false
var ghost:GhostPiece

static var GHOSTPIECE_SCENE:PackedScene = load("res://object/ghostpiece.tscn")

signal movement_requested(piece:Piece, direction:Vector2i)
signal new_cells_requested(piece:Piece, cells:Array[Vector2i])
signal ghost_cells_requested(piece:Piece, ghostPiece:GhostPiece)

#==== Virtuals ======
func _ready() -> void:
	SignalBus.getSignal("setting_changed", "gravity").connect(_on_gravity_setting_changed)
	_on_gravity_setting_changed()

func _physics_process(delta: float) -> void:
	var moved := Vector2i.ZERO
	var movementType:int = MOVEMENT.NONE
	if not moveLock:
		if Input.is_action_just_pressed("moveLeft"):
			movementType = MOVEMENT.HORIZONTAL
			moved += Vector2i.LEFT
			horizontalTimer.start()
		if Input.is_action_just_pressed("moveRight"):
			movementType = MOVEMENT.HORIZONTAL
			moved += Vector2i.RIGHT
			horizontalTimer.start()
		if Input.is_action_just_pressed("moveDown") and DracominoHandler.activeAbilities.get("Soft Drop", 0):
			movementType = MOVEMENT.SOFT_DROP
			moved = Vector2i.DOWN
			softDropTimer.start()
			# Avoid falling too soon
			gravityTimer.start()
	
	if moved != Vector2i.ZERO:
		movement_requested.emit(self, moved, movementType)

#==== Functions ======
func makeActive():
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process_input(true)
	show()
	if DracominoHandler.activeAbilities.get("Ghost Piece", 0) and ghost:
		ghost.show()
	# Avoid falling too soon
	gravityTimer.start()

func makeLimbo():
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process_input(false)
	hide()

func setPiece(pieceName, pieceContext:DracominoHandler.StateItem = null) -> void:
	prettyName = pieceName
	pieceDefinition = PIECES.get(pieceName)
	id = Board.random.randi_range(0, TOTAL_NUMBER_OF_COLORS - 1)
	var orientation:int = Board.rotate_random.randi_range(0,3)
	if pieceDefinition:
		if not ghost:
			ghost = GHOSTPIECE_SCENE.instantiate()
			add_child(ghost)
		localCells = pieceDefinition.tiles.duplicate()
		if DracominoHandler.randomizeOrientations:
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
	else:
		printerr("Piece.setPiece:", pieceName, " does not exist!")
		queue_free()

func updateTiles():
	clear()	
	for cell in localCells:
		var pos:Vector2i = cell
		# if Board.BOUNDS.has_point(pos+currentPosition): # Render in bounds
		set_cell(pos, 0, Vector2i(id, Board.ACTIVE_TILE_ATLAS_ROW))
	
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
		gravityTimer.wait_time = HARD_DROP_WAIT_TIME
		gravityTimer.start()

func move(direction:Vector2i):
	currentPosition += direction
	if moveLock:
		playHardDropSound = true

# Events
func _on_HorizontalTimer_timeout():
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
	if Input.is_action_pressed("moveDown") and DracominoHandler.activeAbilities.get("Soft Drop", 0):
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.SOFT_DROP)
		softDropTimer.wait_time = SOFT_DROP_REPEAT_WAIT_TIME
		softDropTimer.start()
		# Avoid falling too soon
		gravityTimer.start()
	else:
		softDropTimer.wait_time = SOFT_DROP_WAIT_TIME

func _on_GravityTimer_timeout():
	if moveLock or DracominoHandler.activeAbilities.get("Gravity", 0):
		movement_requested.emit(self, Vector2i.DOWN, MOVEMENT.HARD_DROP if playHardDropSound else MOVEMENT.GRAVITY)

func _setCurrentPosition(value:Vector2i):
	currentPosition = value
	position = currentPosition * tile_set.tile_size
	updateTiles()

func _on_gravity_setting_changed():
	if not moveLock:
		var gravSpeed = Config.getSetting("gravity", 1.0)
		gravityTimer.wait_time = GRAVITY_WAIT_TIME/gravSpeed
		gravityTimer.start()