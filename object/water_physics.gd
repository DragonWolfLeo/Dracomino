extends Area2D

var SPEED_MODIFIER:float = 0.7
func _physics_process(delta: float) -> void:
    for body in get_overlapping_bodies():
        if body is CharacterBody2D:
            (body as CharacterBody2D).velocity *= SPEED_MODIFIER