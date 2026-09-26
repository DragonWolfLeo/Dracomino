extends AnimationPlayer

## Signal from SignalBus to activate. Not needed if connecting _on_signal manually.
@export var signalName:StringName
## Play animation when target signal is emitted
@export var animationToPlay:StringName

func _ready() -> void:
	if signalName:
		SignalBus.getSignal(signalName).connect(_on_signal)

func _on_signal() -> void:
	play(animationToPlay)