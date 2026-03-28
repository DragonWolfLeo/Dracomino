extends Node2D

@export var heightThreshold:float = (Board.BOUNDS.size.y + 6) * 16
var masterControl:Control

func _enter_tree() -> void:
	if not masterControl:
		masterControl = get_viewport().get_parent() as Control

	if masterControl is Control:
		masterControl.resized.connect(_on_resized)
		_on_resized()
	else:
		printerr("autoresize.gd error: no target control found")

func _on_resized() -> void:
	await get_tree().process_frame
	var rect = get_viewport_rect()
	var scaleMultiplier:int = max(1, floor(rect.size.y / heightThreshold))
	scale = Vector2(scaleMultiplier, scaleMultiplier)