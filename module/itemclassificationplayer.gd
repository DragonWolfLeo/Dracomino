extends AnimationPlayer

@export var defaultAnimationName:StringName = &"default"
@export var progusefulAnimationName:StringName = &"proguseful"
@export var progressionAnimationName:StringName = &"progression"
@export var usefulAnimationName:StringName = &"useful"
@export var nothingAnimationName:StringName = &"nothing"
@export var trapAnimationName:StringName = &"trap"

func _on_locationContext_updated(item:NetworkItem) -> void:
	if not item:
		return
	play(
		progusefulAnimationName if item.is_prog() and (item.flags & AP.ItemClassification.USEFUL)
		else progressionAnimationName if item.is_prog()
		else usefulAnimationName if item.flags & AP.ItemClassification.USEFUL
		else trapAnimationName if item.flags & AP.ItemClassification.TRAP
		else nothingAnimationName if item.get_name() == "Nothing"
		else defaultAnimationName
	)
