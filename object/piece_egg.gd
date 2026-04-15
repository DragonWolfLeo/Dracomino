extends Piece

@onready var crackFrames:Sprite2D = $CrackFrames
var EFFECT_DURATION:int = 16

func _ready():
    super()
    piece_placed.connect(_on_piece_placed)

func _on_piece_placed():
    var ae:ActiveEffect = ActiveEffect.instantiateEffect("egg_active", EFFECT_DURATION, false, "hatch")
    ae.tree_exiting.connect(queue_free)
    ae.duration_changed.connect(_on_activeEffect_duration_changed)
    add_child(ae)

func _on_activeEffect_duration_changed(remaining:int) -> void:
    var numFrames:int = crackFrames.hframes
    crackFrames.frame = floori(numFrames*(EFFECT_DURATION-remaining)/EFFECT_DURATION)