class_name PiecePreview extends Control

signal triggered()

@onready var label:Label = $Label

var pieceTiles:PieceTiles
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
	pieceTiles = find_child("PieceTiles")

func _unhandled_key_input(event: InputEvent) -> void:
	if shortcut.is_empty(): return
	if event.is_action_pressed(shortcut):
		triggered.emit()
		get_viewport().set_input_as_handled()

#===== Functions ======
func renderPiece():
	pieceTiles.renderPiece(piece)

func setLabel(text:String = ""):
	if label:
		label.visible = text.length() > 0
		label.text = text
		
