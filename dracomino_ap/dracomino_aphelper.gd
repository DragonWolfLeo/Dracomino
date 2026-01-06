extends Node

var btn_deathLink:CheckButton
var btn_deathOnRestart:CheckButton
func _ready() -> void:
	if OS.is_debug_build():
		Archipelago.cmd_manager.debug_hidden = false
	AP.log(Archipelago.AP_CLIENT_VERSION)
	Archipelago.creds.updated.connect((Archipelago.config as DracominoConfigManager).update_credentials)

	Archipelago.load_console(get_parent(), false)
	SignalBus.getSignal("theme_set").connect(_on_theme_set)
	_on_theme_set()

	Archipelago.on_tag_change.connect(_on_Archipelago_tag_change)

	btn_deathLink = get_parent().find_child("Btn_DeathLink")
	if btn_deathLink:
		btn_deathLink.toggled.connect(Archipelago.set_deathlink)
	btn_deathOnRestart = get_parent().find_child("Btn_DeathOnRestart")
	if btn_deathOnRestart:
		btn_deathOnRestart.toggled.connect(_on_btn_deathOnRestart_toggled)
		SignalBus.getSignal("deathOnRestart_enabled").connect(btn_deathOnRestart.set_pressed_no_signal.bind(true))
		SignalBus.getSignal("deathOnRestart_disabled").connect(btn_deathOnRestart.set_pressed_no_signal.bind(false))

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
