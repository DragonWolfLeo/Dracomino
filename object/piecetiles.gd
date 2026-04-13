class_name PieceTiles extends TileMapLayer

@onready var outline:OutlineTileMap = $Outline
func renderPiece(piece:Piece):
	if not piece:
		printerr("PieceTiles.renderPiece error: piece is null")
		return
	for pos:Vector2i in piece.localCells:
		set_cell(pos, 0, Vector2i(piece.id, Board.ACTIVE_TILE_ATLAS_ROW))

	if outline:
		for cell in get_used_cells():
			outline.setTile.call_deferred(cell)