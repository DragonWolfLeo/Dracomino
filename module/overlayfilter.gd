extends ColorRect

@export var debugSignalKey:String = ""

func _ready() -> void:
	if debugSignalKey.length():
		hide();
		SignalBus.getSignal(debugSignalKey+"_enabled").connect(_on_enabledSignal)
		SignalBus.getSignal(debugSignalKey+"_disabled").connect(_on_disabledSignal)

func _on_enabledSignal():
	show()
	var parent:Node = get_parent()
	if parent:
		parent.move_child(self, parent.get_child_count(true)-1)

func _on_disabledSignal():
	hide()
