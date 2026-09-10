extends Sprite2D
@onready var animationPlayer:AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animationPlayer.animation_finished.connect(
		_on_hatch_animation_finished.unbind(1), CONNECT_ONE_SHOT | CONNECT_DEFERRED
	)

func _enter_tree() -> void:
	get_tree().create_timer(5.0, false).timeout.connect(queue_free)

func _on_hatch_animation_finished():
	animationPlayer.play(&"fly_loop")
	var tween:Tween = create_tween()
	tween.tween_property(self, "position", Vector2(560, -560), 5.0).as_relative().from_current()
	tween.set_loops(0)