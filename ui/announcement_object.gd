class_name AnnouncementObject extends Control

@onready var label:RichTextLabel = find_child("Label")
@onready var offsetNode:Control = find_child("Offset")

func _enter_tree() -> void:
	if not is_node_ready():
		await ready
	offsetNode.modulate = Color(1,1,1,0)
	var tween:Tween = offsetNode.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(offsetNode, "modulate", Color.WHITE, 0.4).from_current()
	tween.tween_property(offsetNode, "position", Vector2.ZERO, 0.3).from(Vector2.DOWN*20)
	tween.tween_property(offsetNode, "modulate", Color(1,1,1,0), 0.4).from(Color.WHITE).set_delay(1.7)
	tween.tween_property(offsetNode, "position", Vector2.UP*20, 0.3).from(Vector2.ZERO).set_delay(1.7)
	tween.finished.connect(queue_free)

func setText(message:String):
	label.text = message
