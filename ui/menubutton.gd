extends Button
@export var focusSound:StringName = "select" ## The sound that plays when focused
@export var pressSound:StringName = "confirm" ## The sound that plays when pressed

static var justPlayed:Dictionary[StringName, AudioStreamPlayer] = {}

func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	pressed.connect(_on_pressed)

func _on_focus_entered() -> void:
	if focusSound and not disabled and not justPlayed.get(focusSound):
		play(focusSound)

func _on_pressed() -> void:
	if pressSound and not justPlayed.get(pressSound):
		if justPlayed.get(focusSound):
			justPlayed[focusSound].stop()
		play(pressSound)

func play(soundName:StringName) -> void:
	var audioPlayer:AudioStreamPlayer = SoundManager.play(soundName)
	justPlayed[soundName] = audioPlayer
	get_tree().create_timer(0).timeout.connect(_clearJustPlayed.bind(soundName))

static func _clearJustPlayed(soundName:StringName) -> void:
	justPlayed.erase(soundName)