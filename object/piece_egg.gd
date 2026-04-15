extends Piece

func _ready():
    super()
    piece_placed.connect(_on_piece_placed)

func _on_piece_placed():
    var ae:ActiveEffect = ActiveEffect.instantiateEffect("egg_active", 10, false, "hatch")
    ae.tree_exiting.connect(queue_free)
    add_child(ae)