extends Node2D

var progress:int = 0
@onready var states:Node2D = $BoardStates
func _ready() -> void:
	updateCutscene()
	SignalBus.getSignal("progress_tutorial_logic").connect(_on_progress)

func updateCutscene():
	var current:CanvasItem = states.get_child(min(progress, states.get_child_count() - 1))
	for child:CanvasItem in states.get_children():
		child.visible = child == current

func _on_progress():
	progress += 1
	updateCutscene()
