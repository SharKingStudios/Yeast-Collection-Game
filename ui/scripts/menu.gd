extends Node

@onready var main_panel: Panel    = %MainPanel
#@onready var options_panel: Panel = %OptionsPanel

# Set these to your scenes
@export var game_scene_path: String = "res://main.tscn"
@export var main_menu_scene_path: String = "res://mainMenu.tscn"

func _ready() -> void:
	# Ensure game is not paused when on the main menu
	get_tree().paused = false
	_show_main()

func _process(_delta: float) -> void:
	# Optional: ESC backs out of Options to Main
	#if Input.is_action_just_pressed("ui_cancel") and options_panel.visible:
		#_show_main()
	pass

# ---- Button handlers (connect in the editor) -------------------------------
func _on_resume_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

#func _on_options_pressed() -> void:
	#_show_options()


func _on_quit_pressed() -> void:
	get_tree().quit()

#func _on_back_button_pressed() -> void:
	#_show_main()

# ---- Helpers ---------------------------------------------------------------
func _show_main() -> void:
	main_panel.show()
	#if is_instance_valid(options_panel):
		#options_panel.hide()

#func _show_options() -> void:
	#options_panel.show()
	#if is_instance_valid(main_panel):
		#main_panel.hide()
