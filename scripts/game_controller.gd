extends Node

var hearts: Array[Control] = []

var total_yeast: int = 0
var lives = 3

signal yeastcollected

func decrease_health():
	update_health(1)
	SoundController.play_player_hurt()
	print(lives)
	if lives < 1:
		lives = 3
		total_yeast = 0
		get_tree().reload_current_scene()
	if lives > 3:
		lives = 3
		
func increase_health():
	lives += 0.25
	EventController.emit_signal("health_update", lives)
	print("Emit health update signal")
	print(lives)
	if lives > 3:
		lives = 3

func yeast_collected(value: int):
	total_yeast += value
	emit_signal("yeastcollected")
	EventController.emit_signal("yeast_collected", total_yeast)
	
func update_health(value: int) -> void:
	lives -= value
	EventController.emit_signal("health_update", lives)
	print("Emit health update signal")
