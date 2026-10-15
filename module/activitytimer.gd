class_name ActivityTimer extends Node
## An auto-ticking node for detecting AFK amounts

var time:float = 0
@export var afk_threshold:float = 30
@export var pausable:bool = false: # By default, keep going even if paused
    set(value):
        pausable = value
        _on_pausable_changed()

func _ready() -> void:
    _on_pausable_changed()

func _process(delta: float) -> void:
    time += delta

func _on_pausable_changed() -> void:
    process_mode = PROCESS_MODE_INHERIT if pausable else PROCESS_MODE_ALWAYS

func reset() -> void:
    time = 0

func isAFK() -> bool:
    return time > afk_threshold

func toPrettyTime() -> String:
    if time < 120:
        # Measure in seconds
        return "{time} seconds".format({time=roundi(time)})
    else:
        # Measure in minutes
        return "{time} minutes".format({time=roundi(time/60)})
