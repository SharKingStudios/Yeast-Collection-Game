extends CollisionShape2D



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		var rel: Vector2 = to_local(body.global_position)
		if (rel.y < -200):
			print("Destroy enemy")
			get_parent().get_parent().queue_free()
			body.jump()
		else:
			print("Decrease player healthd")
