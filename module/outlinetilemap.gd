class_name OutlineTileMap extends TileMapLayer

@export var specificAtlasCoordTest:Vector2i = Vector2i(-1, -1)
@export var specificSourceTest:int = -1
@export var target:TileMapLayer

func setTile(cell:Vector2i, _updateSurrounding:bool = true) -> void:
	var nativeCell:Vector2i = cell*2
	# Clear overlapping tiles
	set_cell(nativeCell)
	set_cell(nativeCell+Vector2i.RIGHT)
	set_cell(nativeCell+Vector2i.DOWN)
	set_cell(nativeCell+Vector2i.RIGHT+Vector2i.DOWN)
	if _updateSurrounding:
		updateSurrounding(cell)

func clearTile(cell:Vector2i, _updateSurrounding:bool) -> void:
	var nativeCell:Vector2i = cell*2
	set_cell(nativeCell)
	if _updateSurrounding:
		updateSurrounding(cell)

func updateSurrounding(cell:Vector2i) -> void:
	for v:Vector2i in [
		cell,
		cell+Vector2i.UP,
		cell+Vector2i.DOWN,
		cell+Vector2i.LEFT,
		cell+Vector2i.RIGHT,
		cell+Vector2i.UP+Vector2i.LEFT,
		cell+Vector2i.UP+Vector2i.RIGHT,
		cell+Vector2i.DOWN+Vector2i.LEFT,
		cell+Vector2i.DOWN+Vector2i.RIGHT,
	]:
		updateCell(v)

func updateCell(cell:Vector2i) -> void:
	if not Board.BOUNDS.has_point(cell) or isCellOccupied(cell):
		# Only change crystal edges in bounds
		return
	var nativeCell:Vector2i = cell*2
	var up_occupied = isCellOccupied(cell+Vector2i.UP)
	var down_occupied = isCellOccupied(cell+Vector2i.DOWN)
	var left_occupied = isCellOccupied(cell+Vector2i.LEFT)
	var right_occupied = isCellOccupied(cell+Vector2i.RIGHT)
	
	# Top left
	set_cell(nativeCell, 0,
		Vector2i(1,1) if up_occupied and left_occupied
		else Vector2i(1,3) if up_occupied
		else Vector2i(3,1) if left_occupied
		else Vector2i(3,3) if isCellOccupied(cell+Vector2i.UP+Vector2i.LEFT)
		else Vector2i(-1,-1)
	)
	# Top right
	set_cell(nativeCell + Vector2i.RIGHT, 0,
		Vector2i(2,1) if up_occupied and right_occupied
		else Vector2i(2,3) if up_occupied
		else Vector2i(0,1) if right_occupied
		else Vector2i(0,3) if isCellOccupied(cell+Vector2i.UP+Vector2i.RIGHT)
		else Vector2i(-1,-1)
	)
	# Bottom left
	set_cell(nativeCell + Vector2i.DOWN, 0,
		Vector2i(1,2) if down_occupied and left_occupied
		else Vector2i(1,0) if down_occupied
		else Vector2i(3,2) if left_occupied
		else Vector2i(3,0) if isCellOccupied(cell+Vector2i.DOWN+Vector2i.LEFT)
		else Vector2i(-1,-1)
	)
	# Bottom right
	set_cell(nativeCell + Vector2i.DOWN + Vector2i.RIGHT, 0,
		Vector2i(2,2) if down_occupied and right_occupied
		else Vector2i(2,0) if down_occupied
		else Vector2i(0,2) if right_occupied
		else Vector2i(0,0) if isCellOccupied(cell+Vector2i.DOWN+Vector2i.RIGHT)
		else Vector2i(-1,-1)
	)

func isCellOccupied(cell:Vector2i) -> bool:
	if not target:
		return false
	var atlasCoord:Vector2i = target.get_cell_atlas_coords(cell)
	if atlasCoord == Vector2i(-1, -1) or atlasCoord != specificAtlasCoordTest:
		return false
	var source:int = target.get_cell_source_id(cell)
	if source == -1 or source != specificSourceTest:
		return false
	return true