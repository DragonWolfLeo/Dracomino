class_name AttackableArea extends Area2D

@export var hitSound:StringName

signal attacked(attack:Attack)

func _ready() -> void:
	area_entered.connect(_on_collided)
	body_entered.connect(_on_collided)

func _on_collided(node: Node2D) -> void:
	var attack:Node = node.get_node_or_null("Attack")
	if attack is Attack:
		attacked.emit(attack)
		if hitSound:
			SoundManager.play(hitSound)