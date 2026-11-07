extends Node

@export var target:Node

func _on_signal() -> void:
    if is_instance_valid(target):
        target.queue_free()
    else:
        var parent:Node = get_parent()
        if parent:
            parent.queue_free()
        else:
            printerr("queue_free_target_on_signal.gd _on_signal error: Could not free target")
