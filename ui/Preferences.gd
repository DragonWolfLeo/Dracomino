extends VBoxContainer

var _sfxSliderBeingDragged: bool = true # Set to true prevent triggering when loading
func _ready():
	find_child("HSlider_MasterVol").value = Config.volume
	find_child("HSlider_MusicVol").value = Config.volume_music
	find_child("HSlider_SfxVol").value = Config.volume_sfx
	
	_sfxSliderBeingDragged = false
	
func _setVolume(busName:String, percent:float):
	var weight:float = percent/100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), lerpf(-60, 0, weight))

func _on_HSliderMasterVol_value_changed(value):
	Config.volume = value
	_setVolume("Master",value)


func _on_HSliderMusicVol_value_changed(value):
	Config.volume_music = value
	_setVolume("Music",value)


func _on_HSliderSfxVol_value_changed(value):
	Config.volume_sfx = value
	_setVolume("Sfx",value)
	if !_sfxSliderBeingDragged: pass # TODO: Sound
	
func _on_HSliderSfxVol_drag_started():
	_sfxSliderBeingDragged = true

func _on_HSliderSfxVol_drag_ended(_value_changed):
	# TODO: Sound
	_sfxSliderBeingDragged = false




