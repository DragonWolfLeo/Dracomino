extends Node

var btn_deathLink:CheckButton
var btn_deathOnRestart:CheckButton
var btn_gravityAmt_reset:Button
var label_gravityAmt:Label
var slider_gravityAmt:Slider

func _ready() -> void:
	if OS.is_debug_build():
		Archipelago.cmd_manager.debug_hidden = false
	Archipelago.AP_GAME_NAME = "Dracomino"
	Archipelago.AP_CLIENT_VERSION = Version.val(0,1,0) # GodotAP CommonClient version
	Archipelago.AP_HIDE_NONLOCAL_ITEMSENDS = true
	AP.log(Archipelago.AP_CLIENT_VERSION)
	Archipelago.set_tags([])
	Archipelago.AP_ITEM_HANDLING = Archipelago.ItemHandling.ALL
	Archipelago.creds.updated.connect(save_connection)
	load_connection()

	if Archipelago.output_console:
		Archipelago.close_console()

	Archipelago.load_console(get_parent(), false)
	SignalBus.getSignal("theme_set").connect(_on_theme_set)
	_on_theme_set()

	Archipelago.on_tag_change.connect(_on_Archipelago_tag_change)

	# Set up option controls
	btn_deathLink = get_parent().find_child("Btn_DeathLink")
	# Death link toggle
	if btn_deathLink:
		btn_deathLink.toggled.connect(Archipelago.set_deathlink)
	# Death on restart toggle
	btn_deathOnRestart = get_parent().find_child("Btn_DeathOnRestart")
	if btn_deathOnRestart:
		btn_deathOnRestart.toggled.connect(_on_btn_deathOnRestart_toggled)
		SignalBus.getSignal("deathOnRestart_enabled").connect(btn_deathOnRestart.set_pressed_no_signal.bind(true))
		SignalBus.getSignal("deathOnRestart_disabled").connect(btn_deathOnRestart.set_pressed_no_signal.bind(false))
	# Gravity slider
	slider_gravityAmt = get_parent().find_child("HSlider_GravityAmt")
	if slider_gravityAmt:
		label_gravityAmt = get_parent().find_child("Label_GravityAmt")
		slider_gravityAmt.value_changed.connect(_on_slider_gravityAmt_value_changed)
		slider_gravityAmt.value = Config.getSetting("gravity", 1.0)
		btn_gravityAmt_reset = get_parent().find_child("Btn_GravityAmt_reset")
		if btn_gravityAmt_reset:
			btn_gravityAmt_reset.pressed.connect(slider_gravityAmt.set.bind("value", 1.0))

static func load_connection():
	var conn_info_file: FileAccess = FileAccess.open("user://ap/connection.dat", FileAccess.READ)
	if not conn_info_file: return
	var ip = conn_info_file.get_line()
	var port = conn_info_file.get_line()
	var slot = conn_info_file.get_line()
	Archipelago.creds.update(ip, port, slot, "")
	conn_info_file.close()
static func save_connection(creds: APCredentials):
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var conn_info_file: FileAccess = FileAccess.open("user://ap/connection.dat", FileAccess.WRITE)
	if not conn_info_file: return
	conn_info_file.store_line(creds.ip)
	conn_info_file.store_line(creds.port)
	conn_info_file.store_line(creds.slot)
	conn_info_file.close()

#===== Events =====
func _on_theme_set():
	var parent := get_parent() as Control
	var theme_path := Archipelago.config.window_theme_path
	var theme_res = load(theme_path)
	if parent and theme_res:
		parent.theme = theme_res

func _on_Archipelago_tag_change():
	var isDeathLink := Archipelago.is_deathlink()
	if btn_deathLink:
		btn_deathLink.set_pressed_no_signal(isDeathLink)
	if btn_deathOnRestart:
		btn_deathOnRestart.disabled = not isDeathLink

func _on_btn_deathOnRestart_toggled(toggled_on:bool):
	SignalBus.getSignal(
		"deathOnRestart_enabled" if toggled_on else "deathOnRestart_disabled"
	).emit()

func _on_slider_gravityAmt_value_changed(value:float) -> void:
	Config.changeSetting("gravity", value)
	if label_gravityAmt:
		label_gravityAmt.text = str(value)
