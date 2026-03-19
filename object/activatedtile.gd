extends Sprite2D

@onready var CRYSTALPARTICLE_SCENE:PackedScene = load("res://object/crystalparticle.tscn")
var ANIMATION_TIME:float = 0.2

func _ready() -> void:
    # Make glow layer fade in
    $ActivatedTileGlow.modulate.a = 0
    var tween := create_tween()
    tween.tween_property($ActivatedTileGlow, "modulate", Color.WHITE, ANIMATION_TIME).from_current()

func _exit_tree() -> void:
    # Explode into particles when deleted
    var particles:CPUParticles2D = CRYSTALPARTICLE_SCENE.instantiate()
    get_parent().add_child.call_deferred(particles)
    particles.position = position
    particles.emitting = true
    particles.finished.connect(particles.queue_free)
    