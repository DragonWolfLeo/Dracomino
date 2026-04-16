class_name Mode extends Control

signal mode_enabled()

@export var modeName:StringName

var flagHolder:FlagHolder

func _ready() -> void:
	SignalBus.getSignal("mode_set_requested", modeName).connect(mode_enabled.emit)

	flagHolder = FlagHolder.new(FlagHolder.PRIORITY.LEVEL)
	add_child(flagHolder)
	flagHolder.setFlag("mode", modeName)
	flagHolder.monitoring = is_visible_in_tree()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	flagHolder.monitoring = is_visible_in_tree()
	
