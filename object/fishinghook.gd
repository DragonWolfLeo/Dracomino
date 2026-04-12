class_name FishingHook extends CharacterBody2D

var gravity:float = 300
var hooked:FishPiece:
    set(value):
        if hooked == value:
            return
        hooked = value
        if hooked:
            hooked.tree_exiting.connect(set.bind("hooked", null))
var submerged:bool

var SUBMERGED_DAMPEN:Vector2 = Vector2(0.75,0.7)
var SUBMERGED_HOOKED_DAMPEN:Vector2 = Vector2(0.7,0.7)
var AIR_HOOKED_DAMPEN:Vector2 = Vector2(0.9,0.5)

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
    
    if submerged and hooked:
        velocity *= SUBMERGED_HOOKED_DAMPEN
    elif submerged:
        velocity *= SUBMERGED_DAMPEN
    elif hooked:
        velocity *= AIR_HOOKED_DAMPEN

func stickToHookedPiece():
    if hooked:
        hooked.global_position = global_position

func set_submerged(value) -> void: ## To be used externally
    submerged = value