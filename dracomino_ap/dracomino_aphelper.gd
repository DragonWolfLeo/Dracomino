extends Node

var btn_deathLink:CheckButton
var btn_deathOnRestart:CheckButton
var optionBtn_deathLinkGroup:OptionButton
var lineEdit_deathLinkGroup:LineEdit
var btn_energyLink:CheckButton
var btn_allowUnfocusedInputs:CheckButton
var btn_gravityAmt_reset:Button
var label_gravityAmt:Label
var slider_gravityAmt:Slider
var slider_masterVol:Slider
var slider_musicVol:Slider
var slider_sfxVol:Slider
var slider_voiceVol:Slider

var _sfxSliderBeingDragged:bool = true # Set to true prevent triggering when loading

enum DEATH_LINK_GROUP {
	DEFAULT,
	DRACOMINO,
	CUSTOM,
}
	
func _ready() -> void:
	if OS.is_debug_build():
		Archipelago.cmd_manager.debug_hidden = false
	AP.log(Archipelago.AP_CLIENT_VERSION)
	Archipelago.creds.updated.connect((Archipelago.config as DracominoConfigManager).update_credentials)

	Archipelago.load_console(get_parent(), false)

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
	# Death link group
	SignalBus.getSignal("setting_changed", "deathLinkGroup").connect(_on_deathLinkGroup_setting_changed)
	SignalBus.getSignal("setting_changed", "deathLinkGroup_custom").connect(_on_deathLinkGroup_custom_setting_changed)
	optionBtn_deathLinkGroup = get_parent().find_child("OptionButton_DeathLinkGroup")
	if optionBtn_deathLinkGroup:
		optionBtn_deathLinkGroup.select(Config.getSetting("deathLinkGroup", DEATH_LINK_GROUP.DEFAULT))
		optionBtn_deathLinkGroup.item_selected.connect(_on_optionBtn_deathLinkGroup_item_selected)
	lineEdit_deathLinkGroup = get_parent().find_child("LineEdit_DeathLinkGroup")
	if lineEdit_deathLinkGroup:
		lineEdit_deathLinkGroup.text = Config.getSetting("deathLinkGroup_custom", "")
		lineEdit_deathLinkGroup.focus_exited.connect(func(): _on_lineEdit_deathLinkGroup_text_submitted(lineEdit_deathLinkGroup.text))
		lineEdit_deathLinkGroup.text_submitted.connect(_on_lineEdit_deathLinkGroup_text_submitted)
	_on_deathLinkGroup_setting_changed()

	# Energy Link toggle
	btn_energyLink = get_parent().find_child("Btn_EnergyLink")
	if btn_energyLink:
		btn_energyLink.toggled.connect(_on_btn_energyLink_toggled)
		SignalBus.getSignal("energyLink_enabled").connect(btn_energyLink.set_pressed_no_signal.bind(true))
		SignalBus.getSignal("energyLink_disabled").connect(btn_energyLink.set_pressed_no_signal.bind(false))

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
		slider_masterVol.value_changed.connect(_on_slider_value_changed.bind(
			"volume",
			"Master",
			"sfx", # TODO# Remove when music gets implemented
		))
		slider_masterVol.drag_started.connect(_on_slider_sfxVol_drag_started)
		slider_masterVol.drag_ended.connect(_on_slider_sfxVol_drag_ended.bind("sfx"))
	slider_musicVol = get_parent().find_child("HSlider_MusicVol")
	if slider_musicVol:
		slider_musicVol.value = Config.getSetting("volume_music", 100.0) as float
		slider_musicVol.value_changed.connect(_on_slider_value_changed.bind(
			"volume_music",
			"Music",
		))
	slider_sfxVol = get_parent().find_child("HSlider_SfxVol")
	if slider_sfxVol:
		slider_sfxVol.value = Config.getSetting("volume_sfx", 100.0) as float
		slider_sfxVol.value_changed.connect(_on_slider_value_changed.bind(
			"volume_sfx",
			"Sfx",
			"sfx",
		))
		slider_sfxVol.drag_started.connect(_on_slider_sfxVol_drag_started)
		slider_sfxVol.drag_ended.connect(_on_slider_sfxVol_drag_ended.bind("sfx"))
	slider_voiceVol = get_parent().find_child("HSlider_VoiceVol")
	if slider_voiceVol:
		slider_voiceVol.value = Config.getSetting("volume_voice", 100.0) as float
		slider_voiceVol.value_changed.connect(_on_slider_value_changed.bind(
			"volume_voice",
			"Voice",
			"voice",
		))
		slider_voiceVol.drag_started.connect(_on_slider_sfxVol_drag_started)
		slider_voiceVol.drag_ended.connect(_on_slider_sfxVol_drag_ended.bind("voice"))

	_sfxSliderBeingDragged = false

	# Select IP box on loading
	var ipbox:LineEdit = get_parent().find_child("IP_Box")
	if ipbox is LineEdit and ipbox.is_visible_in_tree():
		ipbox.grab_focus()

#===== Events =====
func _on_Theme_update_theme(theme_res:Theme) -> void:
	var parent:Node = get_parent()
	if parent is Control and theme_res:
		parent.theme = theme_res
	else:
		printerr("dracomino_aphelper.gd: Failed to update theme")

func _on_Archipelago_tag_change():
	var isDeathLink:bool = Archipelago.is_deathlink()
	if btn_deathLink:
		btn_deathLink.set_pressed_no_signal(isDeathLink)
	if btn_deathOnRestart:
		btn_deathOnRestart.disabled = not isDeathLink

func _on_btn_deathOnRestart_toggled(toggled_on:bool):
	SignalBus.getSignal(
		"deathOnRestart_enabled" if toggled_on else "deathOnRestart_disabled"
	).emit()

func _on_btn_energyLink_toggled(toggled_on:bool):
	SignalBus.getSignal(
		"energyLink_enabled" if toggled_on else "energyLink_disabled"
	).emit()

func _on_deathLinkGroup_setting_changed():
	var _deathLinkGroupId:int = int(Config.getSetting("deathLinkGroup", DEATH_LINK_GROUP.DEFAULT))
	if lineEdit_deathLinkGroup:
		lineEdit_deathLinkGroup.visible = _deathLinkGroupId == DEATH_LINK_GROUP.CUSTOM
	match _deathLinkGroupId:
		DEATH_LINK_GROUP.DEFAULT:
			Archipelago.set_deathlink_group("")
		DEATH_LINK_GROUP.DRACOMINO:
			Archipelago.set_deathlink_group("Dracomino")
		DEATH_LINK_GROUP.CUSTOM:
			Archipelago.set_deathlink_group(Config.getSetting("deathLinkGroup_custom", ""))

func _on_deathLinkGroup_custom_setting_changed():
	Archipelago.set_deathlink_group(Config.getSetting("deathLinkGroup_custom", ""))

func _on_optionBtn_deathLinkGroup_item_selected(index:int):
	Config.changeSetting("deathLinkGroup", index)

func _on_lineEdit_deathLinkGroup_text_submitted(new_text:String):
	Config.changeSetting("deathLinkGroup_custom", new_text)

func _on_btn_allowUnfocusedInputs_toggled(toggled_on:bool):
	Config.changeSetting("allowUnfocusedInputs", toggled_on)

func _on_slider_gravityAmt_value_changed(value:float) -> void:
	Config.changeSetting("gravity", value)
	if label_gravityAmt:
		label_gravityAmt.text = str(value)

# Volume stuff
func _on_slider_value_changed(value:float, settingName:String, busName:String, testSoundType:String=""):
	Config.changeSetting(settingName, value)
	SoundManager.setVolume(busName,value)
	if testSoundType and !_sfxSliderBeingDragged: SoundManager.play("test", testSoundType)
	
func _on_slider_sfxVol_drag_started():
	_sfxSliderBeingDragged = true

func _on_slider_sfxVol_drag_ended(_value_changed:bool, soundType:String):
	SoundManager.play("test", soundType)
	_sfxSliderBeingDragged = false