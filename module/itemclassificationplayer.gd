extends AnimationPlayer

@export var defaultAnimationName:StringName = &"default"
@export var progusefulAnimationName:StringName = &"proguseful"
@export var progressionAnimationName:StringName = &"progression"
@export var usefulAnimationName:StringName = &"useful"
@export var nothingAnimationName:StringName = &"nothing"
@export var trapAnimationName:StringName = &"trap"

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
func _on_locationContext_updated(item:NetworkItem) -> void:
	if not item:
		return
	var loc_ctx:DracominoHandler.LocationContext = DracominoHandler.LocationContext.getOrCreateFromNetItem(item)
	var isProgression:bool = item.is_prog()
	var isTrap:bool = item.flags & AP.ItemClassification.TRAP
	var isUseful:bool = item.flags & AP.ItemClassification.USEFUL
	var isHinted = loc_ctx.hinted if loc_ctx else false
	# Make traps look like progression
	if isTrap and not isHinted:
		isProgression = true
	play(
		progusefulAnimationName if isProgression and isUseful
		else progressionAnimationName if isProgression
		else usefulAnimationName if isUseful
		else trapAnimationName if isTrap
		else nothingAnimationName if item.get_name() == "Nothing"
		else defaultAnimationName
	)
