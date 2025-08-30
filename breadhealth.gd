extends Control

@onready var hearts: Array[Control] = [$Bread, $Bread2, $Bread3]
var lives := 3

func _ready() -> void:
	EventController.health_update.connect(on_event_health_updated)

	on_event_health_updated(lives)

func on_event_health_updated(value: int) -> void:
	lives = value
	print("Updating Bread Hearts")
	for h in range(hearts.size()):
		if h < lives:
			hearts[h].show()
		else:
			hearts[h].hide()
