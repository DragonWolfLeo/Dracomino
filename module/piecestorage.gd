class_name PieceStorage extends Node

@export var targetControl:Control
@export var storageSlots:int = 1:
	set(value):
		if storageSlots == value: return
		storageSlots = value
		storageSlots_updated.emit()

@export var slotAbilityName:String:
	set(value):
		slotAbilityName = value.to_snake_case()
@export var emptyFill:bool = false
@export var useNumberedSlots:bool = false
@export var addToPieceTotal:bool = false:
	set(value):
		if addToPieceTotal == value: return
		addToPieceTotal = value
		if flagHolder: flagHolder.monitoring = addToPieceTotal

@onready var PIECEPREVIEW_SCENE:PackedScene = load("res://object/piecepreview.tscn")
@onready var EMPTYPREVIEW_SCENE:PackedScene = load("res://object/emptypreview.tscn")
var flagHolder:FlagHolder

static var INPUT_MAPPINGS:Dictionary = {
	"slot1":  "1",
	"slot2":  "2",
	"slot3":  "3",
	"slot4":  "4",
	"slot5":  "5",
	"slot6":  "6",
	"slot7":  "7",
	"slot8":  "8",
	"slot9":  "9",
	"slot10": "0",
}

var storage:Array[PiecePreview]

signal storageSlots_updated()
signal numStored_changed(num:int)
signal slot_triggered(index:int)

func _ready() -> void:
	if targetControl:
		targetControl.hide()

	flagHolder = FlagHolder.new(FlagHolder.PRIORITY.LEVEL)
	flagHolder.monitoring = addToPieceTotal
	add_child(flagHolder)

	numStored_changed.connect(_updatePreviews.unbind(1))
	numStored_changed.connect(func(num:int): flagHolder.count("shapes_left", "stored", num))
	storageSlots_updated.connect(_updatePreviews)
	if emptyFill:
		for i:int in range(storageSlots):
			pushEmpty()

	# Connect to flag signal
	SignalBus.getSignal("stateflag_changed", slotAbilityName).connect(_on_stateflag_changed)

func _on_numStored_changed(num:int):
	# Update shapes stored
	for preview:PiecePreview in storage:
		if not preview.piece:
			num -= 1
	flagHolder.count("shapes_left", "stored", num)

func pushPiece(piece:Piece, ignoreLimit:bool = false, index:int = -1) -> Piece:
	var popped:Piece = null
	var oldPreview:PiecePreview = null
	var preview:PiecePreview = PIECEPREVIEW_SCENE.instantiate()
	var target:Node = targetControl as Node if targetControl else self
	target.add_child(preview)
	if index >= 0 and index < storage.size():
		# Switch this preview with previous
		oldPreview = storage[index]
		var moveToNodeIndex:int = oldPreview.get_index()
		popped = popPiece(index, true)
		storage.insert(index, preview)
		target.move_child(preview, moveToNodeIndex)
	else:
		# Add to end
		storage.append(preview)
	preview.piece = piece
	preview.tree_exiting.connect(storage.erase.bind(preview))
	preview.triggered.connect(_on_PiecePreview_triggered.bind(preview))

	# Used index to swap
	if popped:
		storageSlots_updated.emit()
		return popped
	elif oldPreview:
		# "Fill" empty slot by deleting it
		if not oldPreview.piece:
			storage.erase(oldPreview)
			oldPreview.queue_free()
		storageSlots_updated.emit()
		return null

	# "Fill" empty spaces by deleting them
	var first:PiecePreview = storage[0]
	if not first.piece:
		storage.erase(first)
		first.queue_free()

	if not ignoreLimit and storage.size() > storageSlots:
		return popPiece()
	numStored_changed.emit(storage.size())
	return null

func popPiece(index:int = -1, swap:bool = false) -> Piece:
	# Return at index if that is set
	if index >= 0 and index < storage.size():
		var preview:PiecePreview = storage[index]
		if preview.piece == null:
			# Don't delete empty slots
			return null
		
		if not swap and emptyFill:
			pushEmpty(index, false)
		storage.erase(preview)
		preview.queue_free()
		if not swap: numStored_changed.emit(storage.size())
		return preview.piece
	
	# Return first valid
	for preview in storage.duplicate():
		var piece:Piece = preview.piece
		if piece:
			storage.erase(preview)
			preview.queue_free()
			if not swap: numStored_changed.emit(storage.size())
			return piece
	return null


func getPreviewAtIndex(index:int = 0) -> PiecePreview:
	if index >= 0 and index < storage.size():
		return storage[index]
	return null

func pushEmpty(index:int = -1, emit_numStored_changed:bool = true) -> void:
	var preview:PiecePreview = EMPTYPREVIEW_SCENE.instantiate()
	var target:Node = targetControl as Node if targetControl else self
	target.add_child(preview)
	if storage.size():
		if index >= 0 and index < storage.size():
			target.move_child(preview, storage[index].get_index())
			storage.insert(index, preview)
		else:
			# Move to front
			target.move_child(preview, storage[0].get_index())
			storage.push_front(preview)
	else:
		storage.push_front(preview)
	preview.tree_exiting.connect(storage.erase.bind(preview))
	preview.triggered.connect(_on_PiecePreview_triggered.bind(preview))

	if emit_numStored_changed: numStored_changed.emit(storage.size())

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

func cycleUp():
	# Move top to the bottom
	if storage.size() > 1:
		var popped:PiecePreview = storage.pop_front() as PiecePreview
		var parent:Node = popped.get_parent()
		parent.move_child(popped, -1)
		storage.append(popped)
		storageSlots_updated.emit()

func cycleDown():
	# Move bottom to the top
	if storage.size() > 1:
		var popped:PiecePreview = storage.pop_back() as PiecePreview
		var parent:Node = popped.get_parent()
		parent.move_child(popped, (storage.front() as PiecePreview).get_index())
		storage.push_front(popped)
		storageSlots_updated.emit()

# === Events ===
func _on_stateflag_changed() -> void:
	storageSlots = FlagManager.getIntFlagValue(slotAbilityName)
	if targetControl:
		targetControl.visible = storageSlots > 0

func _updatePreviews():
	# Make empty previews
	if emptyFill:
		while storage.size() < storageSlots:
			pushEmpty()
	# Make extra buffered pieces invisible and update numbers
	var actions:Array = INPUT_MAPPINGS.keys()
	for i:int in range(storage.size()):
		var preview:PiecePreview = storage[i]
		var visibilityState = i < storageSlots
		preview.visible = Config.debugMode or visibilityState
		preview.modulate.a = 1.0 if visibilityState or not Config.debugMode else 0.33333

		# Clear shortcuts
		if useNumberedSlots:
			if i < storageSlots and i < actions.size():
				preview.shortcut = actions[i]
				preview.setLabel(INPUT_MAPPINGS[actions[i]])
			else:
				preview.shortcut = ""
				preview.setLabel()

func _on_PiecePreview_triggered(triggeredPreview:PiecePreview):
	# Emit a signal after receiving signal from preview
	var index:int = 0
	for preview:PiecePreview in storage:
		if triggeredPreview == preview:
			slot_triggered.emit(index)
			break
		index += 1
