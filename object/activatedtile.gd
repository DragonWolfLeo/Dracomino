extends Sprite2D

var CRYSTALPARTICLE_SCENE_PATHS:Array[String] = [
    "res://object/crystalparticle.tscn",
    "res://object/crystalparticle_1.tscn",
    "res://object/crystalparticle_2.tscn",
]
var ANIMATION_TIME:float = 0.2

func _ready() -> void:
    # Make glow layer fade in
    $ActivatedTileGlow.modulate.a = 0
    var tween := create_tween()
    tween.tween_property($ActivatedTileGlow, "modulate", Color.WHITE, ANIMATION_TIME).from_current()

func _exit_tree() -> void:
    # Explode into particles when deleted
    var res:Resource = load(CRYSTALPARTICLE_SCENE_PATHS.pick_random())
    if res is PackedScene:
        var particles:CPUParticles2D = res.instantiate()
        get_parent().add_child.call_deferred(particles)
        particles.position = position
        particles.emitting = true
        particles.finished.connect(particles.queue_free)
    else:
        printerr("activatedtile.gd: Failed to load crystal particle scene")
    