extends CheckButton

@export var optionKey:String = ""

func _ready() -> void:
	if optionKey:
		set_pressed_no_signal(Config.getSetting(optionKey, false))
	else:
		printerr(name," does not have optionKey set!")
	toggled.connect(_on_toggled)

func _on_toggled(toggled_on:bool):
	if optionKey:
		Config.changeSetting(optionKey, toggled_on, true)
	else:
		printerr(name," does not have optionKey set!")