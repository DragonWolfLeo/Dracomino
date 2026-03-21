class_name ActivatedTileHandler extends Node2D

@onready var activatedTileMap:TileMapLayer = $ActivatedTileMap
@onready var crystallizedTileMap:TileMapLayer = $CrystallizedTileMap

signal cleared()

var CRYSTALPARTICLE_SCENE_PATHS:Array[String] = [
	"res://object/crystalparticle.tscn",
	"res://object/crystalparticle_1.tscn",
	"res://object/crystalparticle_2.tscn",
]

# === Virtuals ===
func _exit_tree() -> void:
	# Explode into particles when deleted
	var res:Resource = load(CRYSTALPARTICLE_SCENE_PATHS.pick_random())
	if res is PackedScene:
		var particles:CPUParticles2D = res.instantiate()
		get_parent().add_child.call_deferred(particles)
		particles.position = position
		particles.emitting = true
		particles.finished.connect(particles.queue_free)
	else:
		printerr("activatedtile.gd: Failed to load crystal particle scene")
	
# === Functions ===
func activateTile(cell:Vector2i) -> void:
	activatedTileMap.set_cell(cell, 0, Vector2i.ZERO, 1)

func crystallizeTile(cell:Vector2i) -> void:
	var BIG_CRYSTALLIZE_DELAY:float = 0.125
	activatedTileMap.set_cell(cell, 1, Vector2i(1,0))
	var tween:Tween = create_tween()
	tween.tween_callback(bigCrystallizeTile.bind(cell)).set_delay(BIG_CRYSTALLIZE_DELAY)
	cleared.connect(tween.kill)

func bigCrystallizeTile(cell:Vector2i) -> void:
	var nativeCell:Vector2i = cell*2
	crystallizedTileMap.set_cell(nativeCell, 0, Vector2i(5,1))
	# Clear overlapping tiles
	crystallizedTileMap.set_cell(nativeCell+Vector2i.RIGHT)
	crystallizedTileMap.set_cell(nativeCell+Vector2i.DOWN)
	crystallizedTileMap.set_cell(nativeCell+Vector2i.RIGHT+Vector2i.DOWN)
	updateCrystallizedSurrounding(cell)

func clearBigCrystallizeTile(cell:Vector2i, updateCrystal:bool) -> void:
	var nativeCell:Vector2i = cell*2
	crystallizedTileMap.set_cell(nativeCell)
	if updateCrystal:
		updateCrystallizedSurrounding(cell)

func updateCrystallizedSurrounding(cell:Vector2i) -> void:
	for v:Vector2i in [
		cell,
		cell+Vector2i.UP,
		cell+Vector2i.DOWN,
		cell+Vector2i.LEFT,
		cell+Vector2i.RIGHT,
		cell+Vector2i.UP+Vector2i.LEFT,
		cell+Vector2i.UP+Vector2i.RIGHT,
		cell+Vector2i.DOWN+Vector2i.LEFT,
		cell+Vector2i.DOWN+Vector2i.RIGHT,
	]:
		if not isCellCrystallized(v):
			updateCrystallizedCell(v)

func updateCrystallizedCell(cell:Vector2i) -> void:
	if not Board.BOUNDS.has_point(cell):
		# Only change cells in bounds
		return
	var nativeCell:Vector2i = cell*2
	var up_occupied = isCellCrystallized(cell+Vector2i.UP)
	var down_occupied = isCellCrystallized(cell+Vector2i.DOWN)
	var left_occupied = isCellCrystallized(cell+Vector2i.LEFT)
	var right_occupied = isCellCrystallized(cell+Vector2i.RIGHT)
	
	# Top left
	crystallizedTileMap.set_cell(nativeCell, 0,
		Vector2i(2,2) if up_occupied and left_occupied
		else Vector2i(5,3) if up_occupied
		else Vector2i(7,1) if left_occupied
		else Vector2i(7,3) if isCellCrystallized(cell+Vector2i.UP+Vector2i.LEFT)
		else Vector2i(-1,-1)
	)
	# Top right
	crystallizedTileMap.set_cell(nativeCell + Vector2i.RIGHT, 0,
		Vector2i(3,2) if up_occupied and right_occupied
		else Vector2i(6,3) if up_occupied
		else Vector2i(4,1) if right_occupied
		else Vector2i(4,3) if isCellCrystallized(cell+Vector2i.UP+Vector2i.RIGHT)
		else Vector2i(-1,-1)
	)
	# Bottom left
	crystallizedTileMap.set_cell(nativeCell + Vector2i.DOWN, 0,
		Vector2i(2,3) if down_occupied and left_occupied
		else Vector2i(5,0) if down_occupied
		else Vector2i(7,2) if left_occupied
		else Vector2i(7,0) if isCellCrystallized(cell+Vector2i.DOWN+Vector2i.LEFT)
		else Vector2i(-1,-1)
	)
	# Bottom right
	crystallizedTileMap.set_cell(nativeCell + Vector2i.DOWN + Vector2i.RIGHT, 0,
		Vector2i(3,3) if down_occupied and right_occupied
		else Vector2i(6,0) if down_occupied
		else Vector2i(4,2) if right_occupied
		else Vector2i(4,0) if isCellCrystallized(cell+Vector2i.DOWN+Vector2i.RIGHT)
		else Vector2i(-1,-1)
	)

func isCellCrystallized(cell:Vector2i) -> bool:
	return crystallizedTileMap.get_cell_atlas_coords(cell*2) == Vector2i(5, 1)

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

func shatterTiles(cells:Array[Vector2i]) -> void:
	for cell in cells:
		shatterTile(cell, false)

	var cellsToUpdate:Array[Vector2i] = []
	cellsToUpdate.append_array(cells)
	# Get all cells above and below
	Board.mergeCells(cellsToUpdate, Board.getTranslatedCells(cells, Vector2i.UP))
	Board.mergeCells(cellsToUpdate, Board.getTranslatedCells(cells, Vector2i.DOWN))
	for cell in cellsToUpdate:
		updateCrystallizedCell(cell)

func clear() -> void:
	activatedTileMap.clear()
	crystallizedTileMap.clear()
	cleared.emit()

func pushDownRows(row:int) -> void:
	var CRYSTAL_UP:Vector2i = Vector2i.UP*2
	# Move tiles down
	for y in range(row, Board.BOUNDS.position.y -1, -1):
		for x in range(Board.BOUNDS.position.x, Board.BOUNDS.end.x):
			activatedTileMap.set_cell(Vector2i(x,y), 0, activatedTileMap.get_cell_atlas_coords(Vector2i(x, y - 1)))
			var crystallizedCell = Vector2i(x,y) * 2
			for v in [
				crystallizedCell, 
				crystallizedCell+Vector2i.RIGHT, 
				crystallizedCell+Vector2i.DOWN, 
				crystallizedCell+Vector2i.RIGHT+Vector2i.DOWN
			]:
				crystallizedTileMap.set_cell(v, 0, crystallizedTileMap.get_cell_atlas_coords(v+CRYSTAL_UP))
	
	for x in range(Board.BOUNDS.position.x, Board.BOUNDS.end.x):
		updateCrystallizedSurrounding(Vector2i(x, row))
