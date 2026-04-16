class_name ActivatedTileHandler extends Node2D

@onready var activatedTileMap:TileMapLayer = $ActivatedTileMap
@onready var crystallizedTileMap:OutlineTileMap = $CrystallizedTileMap

signal cleared()

static var CRYSTALPARTICLE_SCENE_PATHS:Array[String] = [
	"res://object/crystalparticle.tscn",
	"res://object/crystalparticle_1.tscn",
	"res://object/crystalparticle_2.tscn",
]

static var ACTIVATE_INTERVAL:float = 0.03
static var CRYSTALLIZE_DELAY:float = 0.125
static var BIG_CRYSTALLIZE_INTERVAL:float = 0.03
static var BIG_CRYSTALLIZE_DELAY:float = 0.5 - (BIG_CRYSTALLIZE_INTERVAL*10)
static var FINISH_DELAY:float = 0.6
static var CRYSTAL_TILE:Vector2i = Vector2i(1,0)
static var BIGCRYSTAL_TILE:Vector2i = Vector2i(2,0)

# === Functions ===
func activateChunk(chunk:Board.ClearingChunk, callback:Callable):
	# Set up shatter tween
	var callbackTween:Tween = create_tween()
	callbackTween.tween_callback(shatterChunkTiles.bind(chunk)).set_delay(FINISH_DELAY)
	callbackTween.finished.connect(callback)
	cleared.connect(callbackTween.kill)
	chunk.completed.connect(callbackTween.kill)

	# Set up activations
	for i:int in range(chunk.tilesToActivate.size()):
		# Create activated tiles
		var cell:Vector2i = chunk.tilesToActivate[i]
		activateTile(cell)
		var tween:Tween = create_tween().set_parallel()
		tween.tween_callback(callWithTileIndex.bind(crystallizeTile, chunk, i)).set_delay(CRYSTALLIZE_DELAY + (i * ACTIVATE_INTERVAL))
		tween.tween_callback(callWithTileIndex.bind(bigCrystallizeTile, chunk, i)).set_delay(BIG_CRYSTALLIZE_DELAY + (i * BIG_CRYSTALLIZE_INTERVAL))
		cleared.connect(tween.kill)
		chunk.completed.connect(tween.kill)
		callbackTween.finished.connect(tween.kill)

func callWithTileIndex(fn:Callable, chunk:Board.ClearingChunk, index:int):
	if chunk.tilesToActivate.size() > index:
		fn.call(chunk.tilesToActivate[index])

func shatterTileIndex(chunk:Board.ClearingChunk, index:int):
	if chunk.tilesToActivate.size() > index:
		shatterTile(chunk.tilesToActivate[index])
		chunk.tile_shattered.emit(chunk.tilesToActivate[index])

func activateTile(cell:Vector2i) -> void:
	activatedTileMap.set_cell(cell, 0, Vector2i.ZERO, 1)

func crystallizeTile(cell:Vector2i) -> void:
	activatedTileMap.set_cell(cell, 1, CRYSTAL_TILE)

func bigCrystallizeTile(cell:Vector2i, updateCrystal:bool = true) -> void:
	activatedTileMap.set_cell(cell, 1, BIGCRYSTAL_TILE)
	crystallizedTileMap.setTile(cell, updateCrystal)

func clearBigCrystallizeTile(cell:Vector2i, updateCrystal:bool) -> void:
	activatedTileMap.set_cell(cell)
	crystallizedTileMap.clearTile(cell, updateCrystal)

func shatterTile(cell:Vector2i, updateCrystal:bool = true) -> void:
	activatedTileMap.set_cell(cell)
	clearBigCrystallizeTile(cell, updateCrystal)
	# Explode into particles when deleted
	var res:Resource = load(CRYSTALPARTICLE_SCENE_PATHS.pick_random())
	if res is PackedScene:
		var particles:CPUParticles2D = res.instantiate()
		add_child(particles)
		particles.position = activatedTileMap.map_to_local(cell)
		particles.emitting = true
		particles.one_shot = true
		particles.finished.connect(particles.queue_free)
	else:
		printerr("activatedtile.gd: Failed to load crystal particle scene")

func shatterChunkTiles(chunk:Board.ClearingChunk) -> void:
	var cells:Array[Vector2i] = chunk.tilesToActivate.duplicate()
	for cell in cells:
		shatterTile(cell, false)

	var cellsToUpdate:Array[Vector2i] = []
	cellsToUpdate.append_array(cells)
	# Get all cells above and below
	Board.mergeCells(cellsToUpdate, Board.getTranslatedCells(cells, Vector2i.UP))
	Board.mergeCells(cellsToUpdate, Board.getTranslatedCells(cells, Vector2i.DOWN))
	for cell in cellsToUpdate:
		crystallizedTileMap.updateCell(cell)

func clear() -> void:
	activatedTileMap.clear()
	crystallizedTileMap.clear()
	cleared.emit()

func pushDownRows(row:int) -> void:
	var CRYSTAL_UP:Vector2i = Vector2i.UP*2
	# Move tiles down
	for y in range(row, Board.BOUNDS.position.y -1, -1):
		for x in range(Board.BOUNDS.position.x, Board.BOUNDS.end.x):
			var cell := Vector2i(x,y)
			var aboveCell := cell + Vector2i.UP
			activatedTileMap.set_cell(
				cell,
				activatedTileMap.get_cell_source_id(aboveCell),
				activatedTileMap.get_cell_atlas_coords(aboveCell),
				activatedTileMap.get_cell_alternative_tile(aboveCell)
			)
			var crystallizedCell = cell*2
			for v in [
				crystallizedCell, 
				crystallizedCell+Vector2i.RIGHT, 
				crystallizedCell+Vector2i.DOWN, 
				crystallizedCell+Vector2i.RIGHT+Vector2i.DOWN
			]:
				crystallizedTileMap.set_cell(v, 0, crystallizedTileMap.get_cell_atlas_coords(v+CRYSTAL_UP))
	
	for x in range(Board.BOUNDS.position.x, Board.BOUNDS.end.x):
		crystallizedTileMap.updateSurrounding(Vector2i(x, row))
