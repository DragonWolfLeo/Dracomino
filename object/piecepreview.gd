class_name PiecePreview extends Control

signal triggered()

@onready var label:Label = $Label

var tileMapLayer:TileMapLayer
var shortcut:StringName = ""
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
	setLabel()
	tileMapLayer = find_child("TileMapLayer")

func _unhandled_key_input(event: InputEvent) -> void:
	if shortcut.is_empty(): return
	if event.is_action_pressed(shortcut):
		triggered.emit()
		get_viewport().set_input_as_handled()

#===== Functions ======
func renderPiece():
	for pos:Vector2i in piece.localCells:
		tileMapLayer.set_cell(pos, 0, Vector2i(piece.id, Board.ACTIVE_TILE_ATLAS_ROW))

func setLabel(text:String = ""):
	if label:
		label.visible = text.length() > 0
		label.text = text
		
