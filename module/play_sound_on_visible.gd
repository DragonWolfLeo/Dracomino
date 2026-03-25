extends Node2D

@export var soundName:String
@export_enum("sfx","voice") var soundType:String = "sfx"

func _ready() -> void:
    visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
    if is_visible_in_tree():
        SoundManager.play(soundName, soundType)