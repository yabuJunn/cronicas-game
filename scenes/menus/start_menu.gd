extends Control

# Cambia esta ruta por la de la escena principal de tu juego
@export_file("*.tscn") var primera_nivel_ruta: String = "res://scenes/levels/mist_sea_level.tscn"

@onready var boton_jugar: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var boton_ajustes: Button = $MarginContainer/VBoxContainer/ConfigButton
@onready var boton_salir: Button = $MarginContainer/VBoxContainer/ExitButton

func _ready() -> void:
	# Conectamos las señales de los botones
	boton_jugar.pressed.connect(_on_jugar_pressed)
	boton_ajustes.pressed.connect(_on_ajustes_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)
	
	# Le da el foco al primer botón para poder navegar con teclado/mando
	boton_jugar.grab_focus()

func _on_jugar_pressed() -> void:
	print("Se dio click a jugar")
	if primera_nivel_ruta != "":
		TransicionGlobal.cambiar_de_nivel(primera_nivel_ruta)
		print("Cambio a primer nivel")
	else:
		print("¡Falta asignar la primera escena en el Inspector!")

func _on_ajustes_pressed() -> void:
	print("Abrir panel de ajustes...")
	# Más adelante aquí abriremos un panel/popup de configuración

func _on_salir_pressed() -> void:
	get_tree().quit()
