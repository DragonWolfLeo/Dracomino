extends Area2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body:Node2D) -> void:
    if body is FishingHook:
        (body as FishingHook).set_submerged(true)

func _on_body_exited(body:Node2D) -> void:
    if body is FishingHook:
        (body as FishingHook).set_submerged(false)