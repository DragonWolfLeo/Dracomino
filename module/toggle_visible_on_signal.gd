extends CanvasItem

@export var signalName:StringName

func _ready() -> void:
	SignalBus.getSignal(signalName).connect(_on_signal)

func _on_signal() -> void:
	visible = not visible
