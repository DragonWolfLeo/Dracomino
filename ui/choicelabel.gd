extends RichTextLabel
var data
signal pressed(data)

func _on_Button_pressed():
	emit_signal("pressed", data)
	

func _on_button_gui_input(event:InputEvent):
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		pressed.emit(data)
