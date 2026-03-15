class_name PieceStorage extends Node

@export var targetControl:Control
@export var storageSlots:int = 1:
	set(value):
		if storageSlots == value: return
		storageSlots = value
		storageSlots_updated.emit()

@export var slotAbilityName:String
@export var emptyFill:bool = false

@onready var PIECEPREVIEW_SCENE:PackedScene = load("res://object/piecepreview.tscn")
@onready var EMPTYPREVIEW_SCENE:PackedScene = load("res://object/emptypreview.tscn")

var storage:Array[PiecePreview]

signal storageSlots_updated()
signal numStored_changed(num:int)

func _ready() -> void:
	if targetControl:
		targetControl.hide()

	numStored_changed.connect(_updatePreviews.unbind(1))
	storageSlots_updated.connect(_updatePreviews)
	if emptyFill:
		for i:int in range(storageSlots):
			pushEmpty()
			

func pushPiece(piece:Piece, ignoreLimit:bool = false) -> Piece:
	var preview:PiecePreview = PIECEPREVIEW_SCENE.instantiate()
	var target:Node = targetControl as Node if targetControl else self
	target.add_child(preview)
	storage.append(preview)
	preview.piece = piece
	preview.tree_exiting.connect(storage.erase.bind(preview))

	# "Fill" empty spaces by deleting them
	var first:PiecePreview = storage[0]
	if not first.piece:
		storage.erase(first)
		first.queue_free()

	if not ignoreLimit and storage.size() > storageSlots:
		return popPiece()
	numStored_changed.emit(storage.size())
	return null

func popPiece() -> Piece:
	for preview in storage.duplicate():
		var piece:Piece = preview.piece
		if piece:
			storage.erase(preview)
			preview.queue_free()
			numStored_changed.emit(storage.size())
			return piece
	return null

func pushEmpty() -> void:
	var preview:PiecePreview = EMPTYPREVIEW_SCENE.instantiate()
	var target:Node = targetControl as Node if targetControl else self
	target.add_child(preview)
	if storage.size():
		# Move to front
		var first:PiecePreview = storage[0]
		target.move_child(preview, first.get_index())
	storage.push_front(preview)
	preview.tree_exiting.connect(storage.erase.bind(preview))

	numStored_changed.emit(storage.size())

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

func _updatePreviews():
	# Make empty previews
	if emptyFill:
		while storage.size() < storageSlots:
			pushEmpty()
	# Make extra buffered pieces invisible
	for i:int in range(storage.size()):
		storage[i].visible = i < storageSlots
