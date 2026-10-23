class_name BoardObject extends Node2D

@export var animSync:AnimationSyncConfig

@export var collectOnCover:bool = true
@export var collectSound:StringName = &"itempickup"

signal collected()

func attachTimerAndOffset(timer:ActivityTimer, offset:float) -> void: ## Pass anim sync setup to AnimationSyncConfig
	if animSync:
		animSync.attachTimerAndOffset(timer, offset)

func collect() -> void: ## Play sound as if this is collected
	if collectSound:
		SoundManager.play(collectSound)
	collected.emit()

func reactToCover(_piece:Piece) -> void: ## Reaction to a piece locking on it
	if collectOnCover:
		collect()