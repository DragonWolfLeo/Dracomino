## Add this node as AnimationSyncConfig to item pickups for Board to detect
class_name AnimationSyncConfig extends Node

@export var offsetCycle:float = 40.0
@export var cycleUpwards:bool = true
@export var targetAnimationPlayer:AnimationPlayer

func _enter_tree() -> void:
	if not is_instance_valid(targetAnimationPlayer):
		targetAnimationPlayer = null
	# Infer target animation player if not set
	if targetAnimationPlayer == null:
		var parent:Node = get_parent()
		if parent:
			targetAnimationPlayer = parent.get_node_or_null("AnimationPlayer")

func syncAnim(globalTime:float = 0, offset:float = 0) -> void: ## Sync animation with a global timer with an offset
	# Return if invalid
	if not targetAnimationPlayer: return
	if offsetCycle == 0: print("syncAnim warning: offsetCycle can't be zero!"); return
	
	# Get target animation position
	var targetSeek:float = fmod(globalTime, targetAnimationPlayer.current_animation_length)
	targetSeek += (offset/offsetCycle)*targetAnimationPlayer.current_animation_length*(
		-1 if cycleUpwards else 1
	)

	# Clamp into animation length
	while targetSeek < 0: targetSeek += targetAnimationPlayer.current_animation_length
	while targetSeek > targetAnimationPlayer.current_animation_length: targetSeek -= targetAnimationPlayer.current_animation_length

	targetAnimationPlayer.seek(targetSeek)