class_name PieceTiles extends TileMapLayer

var outline:OutlineTileMap

static var RARITY_OUTLINE_TILESET_PATHS:Dictionary[StringName, String] = {
	curse = "res://resource/tileset/outline_curse.tres",
	uncommon = "res://resource/tileset/outline_uncommon.tres",
	rare = "res://resource/tileset/outline_rare.tres",
	epic = "res://resource/tileset/outline_epic.tres",
	legendary = "res://resource/tileset/outline_legendary.tres",
}
static var OUTLINE_TILE_MAP_SCENE:PackedScene = load("res://object/outlinetilemap.tscn")

func setRarity(rarity:StringName):
	if outline: outline.queue_free()
	if rarity in RARITY_OUTLINE_TILESET_PATHS:
		outline = OUTLINE_TILE_MAP_SCENE.instantiate()
		add_child(outline)
		outline.tile_set = load(RARITY_OUTLINE_TILESET_PATHS.get(rarity))

func clearOutline():
	if outline:
		outline.clear()

func renderPiece(piece:Piece):
	if not piece:
		printerr("PieceTiles.renderPiece error: piece is null")
		return
	if piece.uniquePiece:
		# Copy the piece
		for cell:Vector2i in piece.get_used_cells():
			set_cell(
				cell,
				piece.get_cell_source_id(cell),
				piece.get_cell_atlas_coords(cell),
				piece.get_cell_alternative_tile(cell)
			)
	else:
		for cell:Vector2i in piece.localCells:
			set_cell(cell, 0, Vector2i(piece.colorId, Board.ACTIVE_TILE_ATLAS_ROW))

		if not outline and piece.rarity:
			setRarity(piece.rarity)

	if outline:
		for cell in get_used_cells():
			outline.setTile.call_deferred(cell)