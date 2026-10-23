class_name BoardObject extends Node2D

@export var animSync:AnimationSyncConfig

@export var collectOnCover:bool = true
@export var collectOnTouch:bool = false
@export var collectOnCollision:bool = false
@export var lockPieceOnTouch:bool = false
@export var collectSound:StringName = &"itempickup"
@export var deathParticlesScene:PackedScene

signal collected()

func attachTimerAndOffset(timer:ActivityTimer, offset:float) -> void: ## Pass anim sync setup to AnimationSyncConfig
	if animSync:
		animSync.attachTimerAndOffset(timer, offset)

func collect() -> void: ## Play sound as if this is collected
	if collectSound:
		SoundManager.play(collectSound)
	makeDeathParticles()
	collected.emit()

func reactToCover(_piece:Piece) -> void: ## Reaction to a piece locking on it
	if collectOnCover:
		collect()

func reactToTouch(_piece:Piece) -> void: ## Reaction to a piece touching it
	if collectOnTouch:
		collect()

func makeDeathParticles() -> void:
	if deathParticlesScene:
		var particles:Node = deathParticlesScene.instantiate()
		add_sibling(particles)

		if particles is Node2D:
			(particles as Node2D).global_position = global_position
			
		if particles is CPUParticles2D:
			particles.finished.connect(particles.queue_free)
			particles.one_shot = true
			particles.emitting = true

func _on_BoardObjectCollisionArea_area_entered(area:Area2D) -> void:
	if collectOnCollision:
		collect()
