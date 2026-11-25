extends Button
@export var focusSound:StringName = "select" ## The sound that plays when focused
@export var pressSound:StringName = "confirm" ## The sound that plays when pressed

func _ready() -> void:
    focus_entered.connect(_on_focus_entered)
    pressed.connect(SoundManager.play.bind(pressSound))

func _on_focus_entered() -> void:
    if not disabled:
        SoundManager.play(focusSound)