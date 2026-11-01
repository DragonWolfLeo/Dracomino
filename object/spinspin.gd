extends RigidBody2D
@export var speed:float = 256.0
@export var collisionSound:StringName = &"dink"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visibility_changed.connect(_on_visibility_changed)

func _enter_tree() -> void:
	_on_visibility_changed()

func normalizeSpeed() -> void:
	linear_velocity = linear_velocity.normalized() * speed

func _on_visibility_changed() -> void:
	if is_inside_tree() and is_visible_in_tree():
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED

func _on_body_entered(_body:Node) -> void:
	SoundManager.play(collisionSound)
	normalizeSpeed()