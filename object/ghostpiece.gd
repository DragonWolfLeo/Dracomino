class_name GhostPiece extends TileMapLayer

var localCells:Array[Vector2i] = []
var relativePosition:Vector2i: set = _set_relativePosition
var GHOSTPIECE_ATLAS_COORD:Vector2i = Vector2i(0,0)

func _ready() -> void:
	visible = FlagManager.isFlagSet("ghost_piece")
	SignalBus.getSignal("stateflag_set", "ghost_piece").connect(show)
	SignalBus.getSignal("stateflag_cleared", "ghost_piece").connect(hide)

func updateTiles():
	clear()	
	for cell in localCells:
		var pos:Vector2i = cell
		set_cell(pos, 0, GHOSTPIECE_ATLAS_COORD)

func setCells(cells:Array[Vector2i]) -> void:
	localCells = cells
	updateTiles()

# Events
func _set_relativePosition(value:Vector2i):
	relativePosition = value
	position = relativePosition * tile_set.tile_size
	updateTiles()
