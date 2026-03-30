class_name FishPiece extends TileMapLayer
var piece:Piece:
	set(value):
		if piece and piece.tree_exiting.is_connected(queue_free):
				piece.tree_exiting.disconnect(queue_free)
		piece = value
		if piece == null:
				queue_free()
		renderPiece()
		piece.makeLimbo()
		piece.tree_exiting.connect(queue_free)

# === Functions ===
func renderPiece():
	if not piece:
		printerr("FishPiece.renderPiece error: piece is null")
		return
	for pos:Vector2i in piece.localCells:
		set_cell(pos, 0, Vector2i(piece.id, Board.ACTIVE_TILE_ATLAS_ROW))