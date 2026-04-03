extends CheckButton

@export var flag:String = ""
@export var debugOnly:bool = false

func _ready() -> void:
	toggled.connect(_on_toggled)
	SignalBus.getSignal("setting_changed", "debug").connect(updateVisible)
	updateVisible()

func updateVisible() -> void:
	visible = (debugOnly == false) or Config.debugMode

func _on_toggled(toggled_on:bool):
	if toggled_on:
		FlagManager.setFlag(flag)
	else:
		FlagManager.clearFlag(flag)