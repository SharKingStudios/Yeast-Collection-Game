extends Node

var hearts: Array[Control] = []

var total_yeast: int = 0
var lives = 3

#func update_hearts():
	#print("Updating Bread Hearts")
	#for h in range(hearts.size()):
		#if h < lives:
			#print("shown")
			#hearts[h].show()
		#else:
			#print("hide")
			#hearts[h].hide()

func decrease_health():
	update_health(1)
	print(lives)
	#%Bread.hide()
	#update_hearts()
	if lives == 0:
		lives = 3
		total_yeast = 0
		get_tree().reload_current_scene()


func yeast_collected(value: int):
	total_yeast += value
	EventController.emit_signal("yeast_collected", total_yeast)
	
func update_health(value: int) -> void:
	lives -= value
	EventController.emit_signal("health_update", lives)
	print("Emit health update signal")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#call_deferred("_init_hearts")
	pass

#func _init_hearts():
	#var health_node = $UI/HealthUI/Health
	#if health_node == null:
		#print("Health node not found yet!")
		#return
	#
	#hearts.clear()
	#for child in health_node.get_children():
		#if child is TextureRect:
			#hearts.append(child)
			#print("Found heart:", child.name)
	
	#update_hearts()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
