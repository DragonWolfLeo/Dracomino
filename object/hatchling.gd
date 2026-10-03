extends Sprite2D

@onready var animationPlayer:AnimationPlayer = $AnimationPlayer

var velocity:Vector2
var flying:bool = false

func _ready() -> void:
	animationPlayer.animation_finished.connect(
		_on_hatch_animation_finished.unbind(1), CONNECT_ONE_SHOT | CONNECT_DEFERRED
	)

func _enter_tree() -> void:
	get_tree().create_timer(5.0, false).timeout.connect(queue_free)

func _process(delta: float) -> void:
	if flying:
		position += velocity * delta

func _on_hatch_animation_finished():
	animationPlayer.play(&"fly_loop")
	flying = true
	var tween:Tween = create_tween()
	tween.tween_property(self, "velocity", Vector2(75, 200), 0.4).from(Vector2(50, -100))
	tween.tween_property(self, "velocity", Vector2(100, -800), 2).from(Vector2(75, 100))
