extends CanvasItem

@export var flag:String = ""

func _ready() -> void:
	if flag.length():
		visible = FlagManager.isFlagSet(flag);
		SignalBus.getSignal("stateflag_set", flag).connect(_on_enabledSignal)
		SignalBus.getSignal("stateflag_cleared", flag).connect(_on_disabledSignal)

func _on_enabledSignal():
	show()
	var parent:Node = get_parent()
	if parent:
		parent.move_child(self, parent.get_child_count(true)-1)

func _on_disabledSignal():
	hide()
