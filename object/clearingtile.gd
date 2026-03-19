extends Sprite2D

@onready var CRYSTALPARTICLE_SCENE:PackedScene = load("res://object/crystalparticle.tscn")
func _exit_tree() -> void:
    var particles:CPUParticles2D = CRYSTALPARTICLE_SCENE.instantiate()
    get_parent().add_child.call_deferred(particles)
    particles.position = position
    particles.emitting = true
    particles.finished.connect(particles.queue_free)
    