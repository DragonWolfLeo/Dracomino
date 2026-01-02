extends PanelContainer

signal x_pressed()

func _on_ButtonX_pressed():
	x_pressed.emit()
	
func _ready():
	move_child($Button_X, get_child_count()-1)
