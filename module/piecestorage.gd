class_name PieceStorage extends Node

@export var targetControl:Control
@export var storageSlots:int = 1:
	set(value):
		if storageSlots == value: return
		storageSlots = value
		storageSlots_updated.emit()

@export var slotAbilityName:String

@onready var PIECEPREVIEW_SCENE:PackedScene = load("res://object/piecepreview.tscn")

var storage:Array[PiecePreview]

signal storageSlots_updated()
signal numStored_changed(num:int)

func _ready() -> void:
	if targetControl:
		targetControl.hide()

	numStored_changed.connect(_on_numStoredChanged.unbind(1))

func pushPiece(piece:Piece, ignoreLimit:bool = false) -> Piece:
	var preview:PiecePreview = PIECEPREVIEW_SCENE.instantiate()
	var target:Node = targetControl as Node if targetControl else self
	target.add_child(preview)
	storage.append(preview)
	preview.piece = piece
	preview.tree_exiting.connect(storage.erase.bind(preview))

	if not ignoreLimit and storage.size() > storageSlots:
		return popPiece()
	numStored_changed.emit(storage.size())
	return null

func popPiece() -> Piece:
	if storage.size():
		var preview:PiecePreview = storage.pop_front()
		var piece:Piece = preview.piece
		preview.queue_free()
		numStored_changed.emit(storage.size())
		return piece
	return null

func isFull() -> bool:
	return storage.size() >= storageSlots

func isEmpty() -> bool:
	return storage.size() == 0

func getNumStored() -> int:
	return storage.size()

func getAvailableSpace(bufferSize:int = 0) -> int:
	return max(0, storageSlots + bufferSize - storage.size())

func clear():
	if storage.size():
		while storage.size():
			var preview:PiecePreview = storage.pop_back()
			if preview.piece:
				preview.piece.queue_free()
			preview.queue_free()
		numStored_changed.emit(0)

# === Events ===
func _on_DracominoHandler_active_abilities_updated(abilities: Dictionary[String, int]) -> void:
	storageSlots = abilities.get(slotAbilityName, 0)
	if targetControl:
		targetControl.visible = storageSlots > 0

func _on_numStoredChanged():
	# Make extra buffered pieces invisible
	for i:int in range(storage.size()):
		storage[i].visible = i < storageSlots
