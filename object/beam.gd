extends Area2D

@onready var sprite:Sprite2D = $BeamSprite

var TARGET_SPRITE_HEIGHT:float = 256
var VELOCITY:Vector2 = Vector2.UP * 1000
static var BEAM_ORB_EFFECT_SCENE:PackedScene = load("res://object/beam_orb_effect.tscn")

var startPosition:Vector2
var velocity:Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if not sprite: return
	sprite.region_rect.end.y = min(abs(position.y - startPosition.y), TARGET_SPRITE_HEIGHT)

func _enter_tree() -> void:
	initialize.call_deferred()

func initialize() -> void: ## Start deferred
	startPosition = position
	
	var fx:CanvasItem = BEAM_ORB_EFFECT_SCENE.instantiate()
	if fx is CanvasItem:
		add_sibling(fx)
		fx.global_position = global_position
	else:
		printerr("Beam.initialize error: beam orb effect node is not a CanvasItem")
	
	velocity = VELOCITY

func _physics_process(delta: float) -> void:
	position += velocity*delta

func _expire() -> void:
	queue_free()