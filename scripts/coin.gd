extends Area2D



@onready var gamemanster: Node = %Gamemanster





func _on_body_entered(body: Node2D) -> void:
	gamemanster.add_points()
	queue_free()
