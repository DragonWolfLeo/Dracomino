extends "res://module/overlayfilter.gd"

@onready var leftCanvasLayer:CanvasLayer = %LeftCanvasLayer
@onready var rightCanvasLayer:CanvasLayer = %RightCanvasLayer
var tween:Tween

func _ready() -> void:
	super()
	hideCanvasLayers()
	SignalBus.getSignal("stateflag_set", flag).connect(_on_welldone_set)
	SignalBus.getSignal("stateflag_cleared", flag).connect(_on_welldone_cleared)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)

func _on_welldone_set():
	if DialogueManager.dialogue:
		return
	if tween:
		tween.kill()
	leftCanvasLayer.show()
	rightCanvasLayer.show()
	tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(leftCanvasLayer, "offset", Vector2.ZERO, 0.2).from(Vector2(-300, 0))
	tween.tween_property(rightCanvasLayer, "offset", Vector2.ZERO, 0.2).from(Vector2(300, 0))

func _on_welldone_cleared():
	if tween:
		tween.kill()
	if not leftCanvasLayer.visible or not rightCanvasLayer.visible:
		return
	tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	if leftCanvasLayer.visible:
		tween.tween_property(leftCanvasLayer, "offset", Vector2(-300, 0), 0.2).from_current()
	if rightCanvasLayer.visible:
		tween.tween_property(rightCanvasLayer, "offset", Vector2(300, 0), 0.2).from_current()
	tween.finished.connect(hideCanvasLayers)

func _on_dialogue_started():
	if tween:
		tween.kill()
	hideCanvasLayers()
func hideCanvasLayers():
	leftCanvasLayer.hide()
	rightCanvasLayer.hide()