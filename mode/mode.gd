class_name Mode extends Control

signal mode_enabled()

@export var modeName:StringName

func _ready() -> void:
	SignalBus.getSignal("mode_set_requested", modeName).connect(mode_enabled.emit)