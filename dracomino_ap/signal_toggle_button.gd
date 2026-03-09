extends CheckButton

@export var signalKey:String = ""

func _ready() -> void:
	toggled.connect(_on_toggled)

func _on_toggled(toggled_on:bool):
	SignalBus.getSignal(signalKey+("_enabled" if toggled_on else "_disabled")).emit()