extends CollisionShape2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _explosion: Node = $CheeseExplosion

signal died

var _is_dying: bool = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	if _is_dying:
		return

	if body is Player:
		var rel: Vector2 = to_local(body.global_position)
		if rel.y < -200.0:
			print("Destroy enemy")
			_start_death(body as Player)
		else:
			print("Decrease player health")
			GameController.decrease_health()


func _start_death(player: Player) -> void:
	_is_dying = true
	emit_signal("died")

	# stop all further hits
	set_deferred("disabled", true)  # disables this CollisionShape2D
	var area := get_parent()
	if area is Area2D:
		(area as Area2D).set_deferred("monitoring", false)
		(area as Area2D).set_deferred("monitorable", false)

	_sprite.visible = false
	
	_explosion.emitting = true

	player._do_double_jump_with_dash()
	player._jumps_used = 1

	# remove the enemy after a short delay
	await get_tree().create_timer(1.1).timeout
	get_parent().get_parent().queue_free()
