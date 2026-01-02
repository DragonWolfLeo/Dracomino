class_name PiecePreview extends Control

var tileMapLayer:TileMapLayer

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

#===== Virtuals ======
func _ready() -> void:
	tileMapLayer = find_child("TileMapLayer")

#===== Functions ======
func renderPiece():
	for pos:Vector2i in piece.localCells:
		tileMapLayer.set_cell(pos, 0, Vector2i(piece.id, Board.ACTIVE_TILE_ATLAS_ROW))
