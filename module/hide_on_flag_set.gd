extends CanvasItem

@export var flag:String = ""

func _ready() -> void:
	if flag:
		if FlagManager.isFlagSet(flag):
			hide()
		else:
			show()
		SignalBus.getSignal("stateflag_set", flag).connect(hide)
		SignalBus.getSignal("stateflag_cleared", flag).connect(show)