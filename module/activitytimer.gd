class_name ActivityTimer extends Node
## An auto-ticking node for detecting AFK amounts

var time:float = 0
var afk_threshold = 30

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS # Keep going even if paused

func _process(delta: float) -> void:
    time += delta

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
