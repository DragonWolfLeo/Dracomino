extends Node

var btn_deathLink:CheckButton
var btn_deathOnRestart:CheckButton
var btn_allowUnfocusedInputs:CheckButton
var btn_gravityAmt_reset:Button
var label_gravityAmt:Label
var slider_gravityAmt:Slider
var slider_masterVol:Slider
var slider_musicVol:Slider
var slider_sfxVol:Slider

var _sfxSliderBeingDragged:bool = true # Set to true prevent triggering when loading
	
func _ready() -> void:
	if OS.is_debug_build():
		Archipelago.cmd_manager.debug_hidden = false
	AP.log(Archipelago.AP_CLIENT_VERSION)
	Archipelago.creds.updated.connect((Archipelago.config as DracominoConfigManager).update_credentials)

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
	# Unfocused inputs toggle
	btn_allowUnfocusedInputs = get_parent().find_child("Btn_AllowUnfocusedInputs")
	if btn_allowUnfocusedInputs:
		btn_allowUnfocusedInputs.set_pressed_no_signal(Config.getSetting("allowUnfocusedInputs", false))
		btn_allowUnfocusedInputs.toggled.connect(_on_btn_allowUnfocusedInputs_toggled)
	# Gravity slider
	slider_gravityAmt = get_parent().find_child("HSlider_GravityAmt")
	if slider_gravityAmt:
		label_gravityAmt = get_parent().find_child("Label_GravityAmt")
		slider_gravityAmt.value_changed.connect(_on_slider_gravityAmt_value_changed)
		slider_gravityAmt.value = Config.getSetting("gravity", 1.0)
		btn_gravityAmt_reset = get_parent().find_child("Btn_GravityAmt_reset")
		if btn_gravityAmt_reset:
			btn_gravityAmt_reset.pressed.connect(slider_gravityAmt.set.bind("value", Config.getDefaultSetting("gravity", 1.0)))

	slider_masterVol = get_parent().find_child("HSlider_MasterVol")
	if slider_masterVol:
		slider_masterVol.value = Config.getSetting("volume", 80.0) as float
		slider_masterVol.value_changed.connect(_on_slider_masterVol_value_changed)
		slider_masterVol.drag_started.connect(_on_slider_sfxVol_drag_started) # TODO: This is temporary while sfx slider is hidden
		slider_masterVol.drag_ended.connect(_on_slider_sfxVol_drag_ended) # TODO: This is temporary while sfx slider is hidden
	slider_musicVol = get_parent().find_child("HSlider_MusicVol")
	if slider_musicVol:
		slider_musicVol.value = Config.getSetting("volume_music", 100.0) as float
		slider_musicVol.value_changed.connect(_on_slider_musicVol_value_changed)
	slider_sfxVol = get_parent().find_child("HSlider_SfxVol")
	if slider_sfxVol:
		slider_sfxVol.value = Config.getSetting("volume_sfx", 100.0) as float
		slider_sfxVol.value_changed.connect(_on_slider_sfxVol_value_changed)
		slider_sfxVol.drag_started.connect(_on_slider_sfxVol_drag_started)
		slider_sfxVol.drag_ended.connect(_on_slider_sfxVol_drag_ended)

	_sfxSliderBeingDragged = false

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

func _on_btn_allowUnfocusedInputs_toggled(toggled_on:bool):
	Config.changeSetting("allowUnfocusedInputs", toggled_on)

func _on_slider_gravityAmt_value_changed(value:float) -> void:
	Config.changeSetting("gravity", value)
	if label_gravityAmt:
		label_gravityAmt.text = str(value)

# Volume stuff
func _on_slider_masterVol_value_changed(value):
	Config.changeSetting("volume", value)
	DracominoUtil.setVolume("Master",value)
	if !slider_sfxVol.visible and !_sfxSliderBeingDragged: $SFX_AudioTest.play() # TODO: This is temporary while sfx slider is hidden

func _on_slider_musicVol_value_changed(value):
	Config.changeSetting("volume_music", value)
	DracominoUtil.setVolume("Music",value)

func _on_slider_sfxVol_value_changed(value):
	Config.changeSetting("volume_sfx", value)
	DracominoUtil.setVolume("Sfx",value)
	if !_sfxSliderBeingDragged: $SFX_AudioTest.play()
	
func _on_slider_sfxVol_drag_started():
	_sfxSliderBeingDragged = true

func _on_slider_sfxVol_drag_ended(_value_changed):
	$SFX_AudioTest.play()
	_sfxSliderBeingDragged = false