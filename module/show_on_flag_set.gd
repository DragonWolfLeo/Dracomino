extends CanvasItem

@export var flag:String = ""

func _ready() -> void:
	if flag:
		if FlagManager.isFlagSet(flag):
			show()
		else:
			hide()
		SignalBus.getSignal("stateflag_set", flag).connect(show)
		SignalBus.getSignal("stateflag_cleared", flag).connect(hide)