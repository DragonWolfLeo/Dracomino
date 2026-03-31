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

@onready var tileMapLayer:TileMapLayer = $TileMapLayer

# === Virtuals ===
func _ready() -> void:
	# Set initial speed and direction
	direction = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
	speed = randf_range(SPEED_MIN, SPEED_MAX)
	collisionWait = randf_range(COLLISION_WAIT_MIN, COLLISION_WAIT_MAX)

	await get_tree().process_frame
	# Copy tile collision into the collision body
	var cells = tileMapLayer.get_used_cells()
	for cell in cells:
		var data:TileData = tileMapLayer.get_cell_tile_data(cell) 
		var points:PackedVector2Array = data.get_collision_polygon_points(0, 0) 
		var collisionShape = CollisionPolygon2D.new()  
		collisionShape.polygon = points
		
		collisionShape.position = tileMapLayer.map_to_local(cell)
		add_child(collisionShape)

func _physics_process(delta: float) -> void:
	time += delta
	tileMapLayer.position.y = waveAmplitude*sin(time*waveFrequency)
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
	if tileMapLayer:
		for pos:Vector2i in piece.localCells:
			tileMapLayer.set_cell(pos, 0, Vector2i(piece.id, Board.ACTIVE_TILE_ATLAS_ROW))
	else:
		printerr("FishPiece.renderPiece: tileMapLayer is null for some reason")

func beHooked():
	# Disable further collisions
	for child in get_children():
		if child is CollisionPolygon2D:
			(child as CollisionPolygon2D).disabled = true
	set_physics_process(false)
