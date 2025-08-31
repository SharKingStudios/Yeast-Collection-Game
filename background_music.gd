extends AudioStreamPlayer


func _ready():
	finished.connect(_on_music_finished)
	play()

func _on_music_finished():
	seek(0.0)
	play()
