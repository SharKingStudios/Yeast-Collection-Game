extends Node2D

@export var value: int = 1


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		GameController.yeast_collected(value)
		GameController.increase_health()
		self.queue_free()
