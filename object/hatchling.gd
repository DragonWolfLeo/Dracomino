extends Sprite2D

func _ready() -> void:
    frame = randi_range(0, hframes-1)

func _enter_tree() -> void:
    get_tree().create_timer(5.0, false).timeout.connect(queue_free)