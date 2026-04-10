extends CheckButton

@export var flag:String = ""
@export var debugOnly:bool = false

func _ready() -> void:
	if flag:
		SignalBus.getSignal("stateflag_set", flag).connect(_on_stateflag_set)
		SignalBus.getSignal("stateflag_cleared", flag).connect(_on_stateflag_cleared)

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

func _on_stateflag_set():
	set_pressed_no_signal(true)
	
func _on_stateflag_cleared():
	set_pressed_no_signal(false)