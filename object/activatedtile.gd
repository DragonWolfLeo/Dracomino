extends Sprite2D

var ANIMATION_TIME:float = 0.15
func _ready() -> void:
    # Make fade in
    modulate.a = 0
    create_tween().tween_property(self, "modulate", Color.WHITE, ANIMATION_TIME).from_current()