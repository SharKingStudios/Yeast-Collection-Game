extends Node

@export var hearts : Array[Node]

var total_yeast: int = 0
var lives = 3

func decrease_health():
	lives -= 1
	print(lives)
	for h in range(hearts.size()):
		if (h < lives):
			hearts[h].show()
		else:
			hearts[h].hide()
	if (lives == 0):
		lives = 3
		total_yeast = 0
		get_tree().reload_current_scene()
		

func yeast_collected(value: int):
	total_yeast += value
	EventController.emit_signal("yeast_collected", total_yeast)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
