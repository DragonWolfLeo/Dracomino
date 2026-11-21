extends Button

@export var signalKey:StringName
@export var signalFlag:StringName

func _ready() -> void:
	pressed.connect(SignalBus.getSignal(signalKey, signalFlag).emit)