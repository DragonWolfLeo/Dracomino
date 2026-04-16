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
		if child.visible:
			tweenLabels(child)

func tweenLabels(state:Node):
	for child:Node in state.get_children():
		if child is Label:
			var label:Label = child as Label
			var tween:Tween = label.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			var startPos:Vector2 = label.position
			tween.tween_property(label, "modulate", Color.WHITE, 0.4).from(Color(1,1,1,0))
			tween.tween_property(label, "position", startPos, 0.3).from(startPos+Vector2(-20, 0))


func _on_progress():
	progress += 1
	updateCutscene()
