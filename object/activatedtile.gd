extends Sprite2D

var ANIMATION_TIME:float = 0.2
func _ready() -> void:
    # Make fade in
    modulate = Color.BLACK
    var tween:Tween = create_tween()
    tween.tween_callback(set.bind("modulate", Color8(0x55, 0x55, 0x55))).set_delay(ANIMATION_TIME/3)
    tween.tween_callback(set.bind("modulate", Color8(0xAA, 0xAA, 0xAA))).set_delay(ANIMATION_TIME/3)
    tween.tween_callback(set.bind("modulate", Color.WHITE)).set_delay(ANIMATION_TIME/3)