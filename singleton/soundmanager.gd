extends Node

func play(trackName:String, soundType:String = "sfx"):
	var targetPlayer = get_node_or_null(soundType+"/"+trackName) as AudioStreamPlayer
	var resName = "res://assets/audio/{soundType}/{trackName}.wav".format({soundType=soundType, trackName=trackName})
	if targetPlayer:
		targetPlayer.play()
	elif ResourceLoader.exists(resName):
		targetPlayer = $default
		targetPlayer.stream = load(resName)
		targetPlayer.play()
	else:
		printerr("Tried to play invalid %s sound: %s"%[soundType, trackName])

# Volume set helper
func setVolume(busName:String, percent:float):
	var weight:float = percent/100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), lerpf(-60, 0, weight))
