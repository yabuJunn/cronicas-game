extends Control

# Ruta de la escena del menú principal (puedes cambiarla en el Inspector si tu ruta es diferente)
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/menus/start_menu.gd"

@onready var play_button: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ExitButton


func _ready() -> void:
	# Asegura que el ratón sea visible si venía capturado de la partida
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Conectar señales por código
	play_button.pressed.connect(_on_play_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	
	# Enfocar el primer botón para soporte de mando/teclado
	play_button.grab_focus()


func _on_play_button_pressed() -> void:
	if main_menu_scene != "" and ResourceLoader.exists(main_menu_scene):
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		push_error("Error: La ruta del menú principal no es válida en final_demo.gd")


func _on_exit_button_pressed() -> void:
	get_tree().quit()
