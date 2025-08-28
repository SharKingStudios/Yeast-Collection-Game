extends Node

var total_yeast: int = 0

func yeast_collected(value: int):
	total_yeast += value
	EventController.emit_signal("yeast_collected", total_yeast)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
