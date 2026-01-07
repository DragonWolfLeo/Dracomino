extends VBoxContainer

var _sfxSliderBeingDragged: bool = true # Set to true prevent triggering when loading
func _ready():
	find_child("HSlider_MasterVol").value = Config.getSetting("volume", 80.0) as float
	find_child("HSlider_MusicVol").value = Config.getSetting("volume_music", 100.0) as float
	find_child("HSlider_SfxVol").value = Config.getSetting("volume_sfx", 100.0) as float
	
	_sfxSliderBeingDragged = false
	
func _setVolume(busName:String, percent:float):
	var weight:float = percent/100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), lerpf(-60, 0, weight))

func _on_HSliderMasterVol_value_changed(value):
	Config.changeSetting("volume", value, false)
	_setVolume("Master",value)


func _on_HSliderMusicVol_value_changed(value):
	Config.changeSetting("volume_music", value, false)
	_setVolume("Music",value)


func _on_HSliderSfxVol_value_changed(value):
	Config.changeSetting("volume_sfx", value, false)
	_setVolume("Sfx",value)
	if !_sfxSliderBeingDragged: pass # TODO: Sound
	
func _on_HSliderSfxVol_drag_started():
	_sfxSliderBeingDragged = true

func _on_HSliderSfxVol_drag_ended(_value_changed):
	# TODO: Sound
	_sfxSliderBeingDragged = false




