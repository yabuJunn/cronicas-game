extends Control

signal jugar_presionado
signal ajustes_presionados
signal salir_presionado

# --- CONFIGURACIÓN DE ESCENA ---
# Permite arrastrar y soltar la escena del siguiente nivel o cinemática directamente desde el inspector
@export_file("*.tscn") var escena_siguiente: String

# UI components
@onready var boton_jugar: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var boton_ajustes: Button = $MarginContainer/VBoxContainer/ConfigButton
@onready var boton_salir: Button = $MarginContainer/VBoxContainer/ExitButton

# Background components
@onready var backgroundParticles: GPUParticles2D = $GPUParticles2D

func _ready() -> void:
	boton_jugar.pressed.connect(_on_jugar_pressed)
	boton_ajustes.pressed.connect(_on_ajustes_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)
	
	boton_jugar.grab_focus()
	
	get_viewport().size_changed.connect(_ajustar_componentes_fondo)
	_ajustar_componentes_fondo()


func _ajustar_componentes_fondo() -> void:
	var tamano_pantalla: Vector2 = get_viewport_rect().size
	backgroundParticles.position = Vector2(tamano_pantalla.x / 2.0, tamano_pantalla.y - (tamano_pantalla.y * 0.05))
	
	var particle_mat = backgroundParticles.process_material as ParticleProcessMaterial
	if particle_mat:
		particle_mat.emission_shape_scale = Vector3(1, 1, 1)
		var semi_ancho: float = tamano_pantalla.x / 2.0
		var semi_alto: float = (tamano_pantalla.y * 0.10) / 2.0
		particle_mat.emission_box_extents = Vector3(semi_ancho, semi_alto, 1.0)
	
	backgroundParticles.visibility_rect = Rect2(
		-tamano_pantalla.x / 2.0, 
		-tamano_pantalla.y, 
		tamano_pantalla.x, 
		tamano_pantalla.y
	)


func _on_jugar_pressed() -> void:
	# Desactivar botones para evitar múltiples clics
	boton_jugar.disabled = true
	boton_ajustes.disabled = true
	boton_salir.disabled = true
	
	jugar_presionado.emit()
	
	if escena_siguiente != "":
		# Silenciamos la música del menú base usando el manager global
		if MusicManager:
			MusicManager.quitar_musica(1.2)
			
		# Iniciamos la carga en segundo plano usando la transición global
		if TransicionGlobal:
			TransicionGlobal.cambiar_de_nivel(escena_siguiente)
		else:
			push_error("TransicionGlobal no está disponible. Revisa tus AutoLoads.")
	else:
		push_warning("Falta asignar 'Escena Siguiente' en el inspector del menú.")
		# Rehabilitar botones por si faltó la escena, para no dejar el menú bloqueado
		boton_jugar.disabled = false
		boton_ajustes.disabled = false
		boton_salir.disabled = false


func _on_ajustes_pressed() -> void:
	ajustes_presionados.emit()


func _on_salir_pressed() -> void:
	salir_presionado.emit()
	get_tree().quit()
