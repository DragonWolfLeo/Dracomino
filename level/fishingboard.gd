extends Node2D

@onready var FISHPIECE_SCENE:PackedScene = load("res://object/fishpiece.tscn")
@onready var BOUNDS:Rect2 = $SpawnRect.get_rect()

@export var board:Board
@export var fishLimit:int = 4

var fishes:Array[FishPiece] = []

# === Virtuals ===
func _enter_tree() -> void:
	var mode:Mode = DracominoUtil.getParentMode(self)
	if mode:
		mode.mode_enabled.connect(_on_mode_enabled)
	else:
		printerr("FishingBoard._enter_tree warning: does not have mode parent!")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and fishes.size() == 0:
		spawnFishes()

# === Functions ===
func spawnFish(piece:Piece):
	if not piece:
		return
	for fish in fishes:
		if fish.piece == piece:
			return

	var fishPiece:FishPiece = FISHPIECE_SCENE.instantiate() as FishPiece
	fishPiece.position = BOUNDS.position + (BOUNDS.size/Vector2(1, fishLimit+1) * Vector2(randf(), fishes.size()+randf()))
	fishPiece.piece = piece
	fishPiece.tree_exiting.connect(fishes.erase.bind(fishPiece))
	fishes.append(fishPiece)
	add_child(fishPiece)

func spawnFishes():
	print("spawning fishes")
	for fish in fishes:
		fish.queue_free()
	fishes.clear()
	board.fillPreview(4)

	if board.previewStorage:
		for preview:PiecePreview in board.previewStorage.storage:
			spawnFish(preview.piece)
			if fishes.size() >= fishLimit:
				break
		print("filled pond with %s fishes"%fishes.size())
		if fishes.size() == 0:
			quitFishing()
	else:
		printerr("FishingBoard.spawnFishes error: board needs previewStorage for this to work!")

func quitFishing():
	pass

# === Events ===
func _on_mode_enabled():
	spawnFishes()
