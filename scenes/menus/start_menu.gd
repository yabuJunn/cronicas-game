extends Control

signal jugar_presionado
signal ajustes_presionados
signal salir_presionado

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
	boton_jugar.disabled = true
	jugar_presionado.emit()


func ocultar_menu(duracion: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duracion)
	tween.tween_callback(hide)


func _on_ajustes_pressed() -> void:
	ajustes_presionados.emit()


func _on_salir_pressed() -> void:
	salir_presionado.emit()
	get_tree().quit()
