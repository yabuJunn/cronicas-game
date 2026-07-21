extends Control

# Cambia esta ruta por la de la escena principal de tu juego
@export_file("*.tscn") var primera_nivel_ruta: String = "res://scenes/levels/mist_sea_level.tscn"

# UI components
@onready var boton_jugar: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var boton_ajustes: Button = $MarginContainer/VBoxContainer/ConfigButton
@onready var boton_salir: Button = $MarginContainer/VBoxContainer/ExitButton

# Background components (Corregida la ruta según tu .tscn)
@onready var backgroundParticles: GPUParticles2D = $GPUParticles2D

func _ready() -> void:
	# Conectamos las señales de los botones
	boton_jugar.pressed.connect(_on_jugar_pressed)
	boton_ajustes.pressed.connect(_on_ajustes_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)
	
	# Le da el foco al primer botón
	boton_jugar.grab_focus()
	
	# Escuchamos cambios de resolución de pantalla
	get_viewport().size_changed.connect(_ajustar_componentes_fondo)
	
	# Ajustamos las partículas al iniciar
	_ajustar_componentes_fondo()

func _ajustar_componentes_fondo() -> void:
	var tamano_pantalla: Vector2 = get_viewport_rect().size
	
	# --- POSICIONAR Y ESCALAR PARTÍCULAS ---
	# 1. Colocamos el nodo centrado horizontalmente y en el 95% de la altura (franja inferior)
	backgroundParticles.position = Vector2(tamano_pantalla.x / 2.0, tamano_pantalla.y - (tamano_pantalla.y * 0.05))
	
	var particle_mat = backgroundParticles.process_material as ParticleProcessMaterial
	if particle_mat:
		# Reseteamos la escala base para que no multiplique raro con los extents
		particle_mat.emission_shape_scale = Vector3(1, 1, 1)
		
		# Ancho total = 100% de la pantalla (semi_ancho es la mitad)
		var semi_ancho: float = tamano_pantalla.x / 2.0
		
		# Alto total = 10% de la pantalla (semi_alto es la mitad del 10%)
		var semi_alto: float = (tamano_pantalla.y * 0.10) / 2.0
		
		particle_mat.emission_box_extents = Vector3(semi_ancho, semi_alto, 1.0)
	
	# 2. Solución al desvanecimiento: Expandimos la zona donde Godot dibuja las partículas
	# Para que aunque floten hacia arriba en toda la pantalla, no dejen de renderizarse.
	backgroundParticles.visibility_rect = Rect2(
		-tamano_pantalla.x / 2.0, 
		-tamano_pantalla.y, 
		tamano_pantalla.x, 
		tamano_pantalla.y
	)

func _on_jugar_pressed() -> void:
	print("Se dio click a jugar")
	if primera_nivel_ruta != "":
		TransicionGlobal.cambiar_de_nivel(primera_nivel_ruta)
		print("Cambio a primer nivel")
	else:
		print("¡Falta asignar la primera escena en el Inspector!")

func _on_ajustes_pressed() -> void:
	print("Abrir panel de ajustes...")

func _on_salir_pressed() -> void:
	get_tree().quit()
