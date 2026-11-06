extends Node

@onready var defaultPlayer:AudioStreamPlayer = $default
var queuedSounds:Array[QueuedSoundContext] = []

# === Classes ===
class QueuedSoundContext:
	signal activated()
	signal finished()
	var trackName:String
	var soundType:String
	var duration:float

	func _init(_trackName:String, _soundType:String, _duration:float) -> void:
		trackName = _trackName
		soundType = _soundType
		duration = _duration

# === Functions ===
func play(trackName:String, soundType:String = "sfx"):
	var targetPlayer:Node = get_node_or_null(soundType+"/"+trackName)
	var resName = "res://assets/audio/{soundType}/{trackName}.wav".format({soundType=soundType, trackName=trackName})
	if targetPlayer is AudioStreamPlayer:
		targetPlayer.play()
	elif ResourceLoader.exists(resName):
		defaultPlayer = $default
		defaultPlayer.stream = load(resName)
		defaultPlayer.play()
	else:
		printerr("Tried to play invalid %s sound: %s"%[soundType, trackName])

# Volume set helper
func setVolume(busName:String, percent:float):
	var weight:float = percent/100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), lerpf(-60, 0, weight))

func enqueue(trackName:String, soundType:String = "music", defaultDuration:float = 1) -> QueuedSoundContext:
	# Get duration from QueueableAudioPlayer
	var targetPlayer:Node = get_node_or_null(soundType+"/"+trackName)
	var duration:float = defaultDuration
	if targetPlayer is Node:
		if targetPlayer.get("duration") is float:
			duration = targetPlayer.get("duration")
	
	var context:QueuedSoundContext = QueuedSoundContext.new(trackName, soundType, duration as float)
	if not queuedSounds.is_empty():
		# Play as soon as previous sound has finished playing
		var last:QueuedSoundContext = queuedSounds.back()
		last.finished.connect(_playQueuedSound.bind(context))
	else:
		# Play immediately after deferring
		_playQueuedSound.call_deferred(context)
	
	# Add to array
	queuedSounds.append(context)
	context.finished.connect(_on_QueueSoundContext_finished.bind(context))

	return context

func _playQueuedSound(context:QueuedSoundContext) -> void:
	play(context.trackName, context.soundType)
	context.activated.emit()
	var tween:Tween = create_tween().set_pause_mode(Tween.TweenPauseMode.TWEEN_PAUSE_PROCESS)
	tween.tween_callback(context.finished.emit).set_delay(context.duration)

func _on_QueueSoundContext_finished(context:QueuedSoundContext) -> void:
	queuedSounds.erase(context)