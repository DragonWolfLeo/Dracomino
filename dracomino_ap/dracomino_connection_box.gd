extends MarginContainer

@export var total_slide_dur: float = 0.5
@onready var row: HBoxContainer = $Row
@export var connect_btn: Button
@export var disconnect_btn: Button
var is_open := false

func _ready():
	slide_to(Archipelago.conn == null)
	row.add_theme_constant_override("separation", 0)
	row.reset_size()
	custom_minimum_size = Vector2.ZERO
	reset_size()
	Archipelago.connected.connect(func(_conn, _json):
		connect_btn.disabled = true
		disconnect_btn.disabled = false
		if Archipelago.AP_CONSOLE_CONNECTION_AUTO:
			slide_to(false))
	Archipelago.disconnected.connect(func():
		connect_btn.disabled = false
		disconnect_btn.disabled = true
		if Archipelago.AP_CONSOLE_CONNECTION_AUTO:
			slide_to(true))
	if Archipelago.AP_CONSOLE_CONNECTION_AUTO or Archipelago.AP_CONSOLE_CONNECTION_OPEN:
		is_open = true
		
func slide_to(open:bool) -> void:
	if open == is_open: return
	is_open = open
	visible = open
	connect_btn.visible = open
	disconnect_btn.visible = not open

func get_closed_width() -> float:
	return 0.0
