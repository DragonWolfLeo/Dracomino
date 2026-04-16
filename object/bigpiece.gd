@tool
class_name BigPiece extends Node2D

var BIG_PIECE_SCENE:PackedScene = load("res://object/bigblock.tscn")
@export var vertical_offset = Vector2(7.0 , 57.0):
	set(value):
		if vertical_offset == value: return
		vertical_offset = value
		render()
@export var horizontal_offset = Vector2(58.0 , -15.0):
	set(value):
		if horizontal_offset == value: return
		horizontal_offset = value
		render()
@export var cells:Array[Vector2i] = []:
	set(value):
		cells = value
		render()
@export var colorId:int = 0:
	set(value):
		if colorId == value: return
		colorId = value
		render()
var center:Vector2
var bigBlocks:Array[Node] = []

func _ready() -> void:
	if cells.size():
		render()

func clear() -> void:
	for node in bigBlocks:
		node.queue_free()
	bigBlocks.clear()

func renderPiece(piece:Piece) -> void:
	if not piece: return
	colorId = piece.colorId
	cells = piece.localCells

func render():
	clear()
	if not cells.size(): return
	var rect:Rect2 = Rect2()
	rect.position = Vector2(cells.front())
	for cell in cells:
		rect = rect.expand(Vector2(cell))
	rect.grow_side(SIDE_RIGHT, 1)
	rect.grow_side(SIDE_BOTTOM, 1)
	center = Vector2.ZERO
	center += rect.get_center().x * horizontal_offset
	center += rect.get_center().y * vertical_offset
	
	# Make cells starting from the bottom, then go right to left
	for y:int in range(rect.end.y, rect.position.y-1, -1):
		for x:int in range(rect.end.x, rect.position.x-1, -1):
			if cells.has(Vector2i(x,y)):
				var block:Node2D = BIG_PIECE_SCENE.instantiate()
				block.position += x * horizontal_offset
				block.position += y * vertical_offset
				block.position -= center
				block.frame = colorId
				add_child(block, false, INTERNAL_MODE_BACK)
				bigBlocks.append(block)
