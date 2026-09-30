extends Control

signal finished()

@export var duration:float = 1.0
@export var bounceDistance:float = 64.0
var startingPosition:Vector2

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

func _enter_tree() -> void:
	startingPosition = position
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		fadeIn()

func fadeIn() -> void:
	var colorTween:Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	visibility_changed.connect(colorTween.kill)
	colorTween.tween_property(self, "modulate", Color.WHITE, duration/2).from(Color8(0xFF,0xFF,0xFF, 0))

	var positionTween:Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	visibility_changed.connect(positionTween.kill)
	positionTween.tween_property(self, "position", startingPosition, duration).from(startingPosition + (Vector2.UP * bounceDistance))
	positionTween.tween_callback(finished.emit)