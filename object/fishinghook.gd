class_name FishingHook extends CharacterBody2D

var gravity:float = 300
var hooked:FishPiece:
    set(value):
        if hooked == value:
            return
        hooked = value
        if hooked:
            hooked.tree_exiting.connect(set.bind("hooked", null))

func _physics_process(delta: float) -> void:
    velocity += Vector2.DOWN*gravity*delta
    var collided := move_and_slide()
    if not hooked:
        for i in range(get_slide_collision_count()):
            var collider := get_slide_collision(i).get_collider()
            if collider is FishPiece:
                hooked = collider as FishPiece
                hooked.beHooked()
                break
    if hooked:
        stickToHookedPiece()

func stickToHookedPiece():
    if hooked:
        hooked.global_position = global_position