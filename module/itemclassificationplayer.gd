extends AnimationPlayer

@export var defaultAnimationName:StringName = &"default"
@export var progusefulAnimationName:StringName = &"proguseful"
@export var progressionAnimationName:StringName = &"progression"
@export var usefulAnimationName:StringName = &"useful"
@export var nothingAnimationName:StringName = &"nothing"
@export var trapAnimationName:StringName = &"trap"

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
func _on_locationContext_updated(loc_ctx:DracominoHandler.LocationContext) -> void:
	var item:DracominoHandler.StateItem = loc_ctx.item
	if not item:
		return
	match item.getClassification():
		&"proguseful": play(progusefulAnimationName)
		&"progression": play(progressionAnimationName)
		&"useful": play(usefulAnimationName)
		&"trap": play(trapAnimationName if loc_ctx.hinted else progressionAnimationName)
		_: play(nothingAnimationName if item.id == -1 else defaultAnimationName)
