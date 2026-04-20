class_name FishPiece extends CharacterBody2D
var piece:Piece:
	set(value):
		if piece and piece.tree_exiting.is_connected(queue_free):
			piece.tree_exiting.disconnect(queue_free)
		piece = value
		if piece == null:
			queue_free()
		renderPiece.call_deferred()
		piece.tree_exiting.connect(queue_free)

var direction:Vector2 = Vector2.RIGHT
var SPEED_MIN:float = 5
var SPEED_MAX:float = 20
var speed:float
var COLLISION_WAIT_MIN:float = 0.5
var COLLISION_WAIT_MAX:float = 2
var collisionWait:float
var time:float
var waveFrequency:float = 5
var waveAmplitude:float = 3
var tileMapOffset:Vector2
var collisionShapes:Array[CollisionPolygon2D] = []

@onready var pieceTiles:PieceTiles = $PieceTiles
@onready var bigPiece:BigPiece = $BigPiece

# === Virtuals ===
func _ready() -> void:
	# Set initial speed and direction
	direction = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
	speed = randf_range(SPEED_MIN, SPEED_MAX)
	collisionWait = randf_range(COLLISION_WAIT_MIN, COLLISION_WAIT_MAX)	

func _physics_process(delta: float) -> void:
	time += delta
	pieceTiles.position.y = waveAmplitude*sin(time*waveFrequency) + tileMapOffset.y
	var col := move_and_collide(direction*speed*delta)
	if col:
		set_physics_process(false)
		var tween:Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_interval(collisionWait)
		await tween.finished
		direction *= -1
		set_physics_process(true)

# === Functions ===
func renderPiece():
	if not piece:
		printerr("FishPiece.renderPiece error: piece is null")
		return
	if pieceTiles:
		pieceTiles.renderPiece(piece)
		# Center piece
		var rect:Rect2 = Rect2(pieceTiles.get_used_rect())
		tileMapOffset = -rect.get_center() * Vector2(pieceTiles.tile_set.tile_size)
		pieceTiles.position += tileMapOffset
		buildCollision()
	else:
		printerr("FishPiece.renderPiece: pieceTiles is null for some reason")

func buildCollision():
	for shape in collisionShapes:
		shape.queue_free()
	collisionShapes.clear()
	# Copy tile collision into the collision body
	var cells:Array[Vector2i] = pieceTiles.get_used_cells()
	for cell:Vector2i in cells:
		var data:TileData = pieceTiles.get_cell_tile_data(cell) 
		if data.get_collision_polygons_count(0):
			var points:PackedVector2Array = data.get_collision_polygon_points(0, 0) 
			var collisionShape = CollisionPolygon2D.new()  
			collisionShape.polygon = points
			
			collisionShape.position = pieceTiles.map_to_local(cell) + pieceTiles.position
			add_child(collisionShape)
			collisionShapes.append(collisionShape)

func beHooked():
	# Disable further collisions
	for child in get_children():
		if child is CollisionPolygon2D:
			(child as CollisionPolygon2D).disabled = true
	set_physics_process(false)

func showBigPiece() -> void:
	if piece.uniquePiece:
		return
	pieceTiles.hide()
	bigPiece.show()
	bigPiece.renderPiece(piece)
	# Adjust position to be close to the tile map position
	bigPiece.position = pieceTiles.position - tileMapOffset
