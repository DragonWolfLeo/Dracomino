class_name BoardObject extends Node2D

@export var animSync:AnimationSyncConfig

func attachTimerAndOffset(timer:ActivityTimer, offset:float) -> void:
	if animSync:
		animSync.attachTimerAndOffset(timer, offset)