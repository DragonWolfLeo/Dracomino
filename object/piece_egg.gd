extends Piece

static var EGGSHARDPARTICLES_SCENE:PackedScene = load("res://object/eggshardparticles.tscn")
static var HATCHLING_SCENE:PackedScene = load("res://object/hatchling.tscn")
@onready var crackFrames:Sprite2D = $CrackFrames
var EFFECT_DURATION:int = 32
var activeEffect:ActiveEffect

func _ready():
	super()
	piece_placed.connect(_on_piece_placed)
	landed_on_by.connect(_on_landed_on_by)

func hatch():
	if is_queued_for_deletion(): return
	# Make hatchling
	var hatchling:Sprite2D = HATCHLING_SCENE.instantiate()
	add_sibling(hatchling)
	hatchling.global_position = crackFrames.global_position
	# Make egg shards
	var eggshards:CPUParticles2D = EGGSHARDPARTICLES_SCENE.instantiate()
	add_sibling(eggshards)
	eggshards.global_position = crackFrames.global_position
	eggshards.finished.connect(eggshards.queue_free)
	eggshards.emitting = true
	queue_free()

func _on_piece_placed():
	if activeEffect:
		printerr("Piece_Egg._on_piece_placed: There's already an active effect")
	activeEffect = ActiveEffect.instantiateEffect("egg_active", EFFECT_DURATION-(6 if playHardDropSound else 0), false, "hatch")
	activeEffect.tree_exiting.connect(hatch)
	activeEffect.tree_exiting.connect(set.bind("activeEffect", null))
	activeEffect.duration_changed.connect(_on_activeEffect_duration_changed)
	add_child(activeEffect)

func _on_activeEffect_duration_changed(remaining:int) -> void:
	var numFrames:int = crackFrames.hframes
	crackFrames.frame = floori(numFrames*(EFFECT_DURATION-remaining)/EFFECT_DURATION)

func _on_landed_on_by(piece:Piece, movementType:int):
	if not activeEffect: return
	var tickAmount:int = 2
	match movementType:
		Piece.MOVEMENT.HARD_DROP, Piece.MOVEMENT.SHOVE, Piece.MOVEMENT.FORCED_SHOVE:
			tickAmount = 4
	activeEffect.tickDuration(tickAmount, false)
