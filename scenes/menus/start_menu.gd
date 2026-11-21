extends Control
# Title menu

signal jugar_presionado
signal ajustes_presionados
signal salir_presionado

@export_file("*.tscn") var escena_siguiente: String

# UI components
@onready var boton_continuar: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var boton_jugar: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var boton_ajustes: Button = $MarginContainer/VBoxContainer/ConfigButton
@onready var boton_salir: Button = $MarginContainer/VBoxContainer/ExitButton

# Background components
@onready var backgroundParticles: GPUParticles2D = $GPUParticles2D

var dialogo_confirmacion: ConfirmationDialog


func _ready() -> void:
	boton_continuar.pressed.connect(_on_continuar_pressed)
	boton_jugar.pressed.connect(_on_jugar_pressed)
	boton_ajustes.pressed.connect(_on_ajustes_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)

	_crear_dialogo_confirmacion()
	_actualizar_botones_partida()

	get_viewport().size_changed.connect(_ajustar_componentes_fondo)
	_ajustar_componentes_fondo()


func _crear_dialogo_confirmacion() -> void:
	dialogo_confirmacion = ConfirmationDialog.new()
	dialogo_confirmacion.title = "Advertencia"
	dialogo_confirmacion.dialog_text = "Ya existe una partida guardada.\n¿Seguro que quieres crear una nueva partida? Se borrará todo el progreso actual."
	dialogo_confirmacion.ok_button_text = "Sí, borrar y empezar"
	dialogo_confirmacion.cancel_button_text = "Cancelar"
	dialogo_confirmacion.confirmed.connect(_iniciar_nueva_partida)
	add_child(dialogo_confirmacion)


func _actualizar_botones_partida() -> void:
	var hay_guardado: bool = SaveManager != null and SaveManager.tiene_partida_guardada()

	if hay_guardado:
		boton_continuar.visible = true
		boton_continuar.text = "Continuar"
		boton_jugar.text = "Crear nueva partida"
		boton_continuar.grab_focus()
	else:
		boton_continuar.visible = false
		boton_jugar.text = "Nueva partida"
		boton_jugar.grab_focus()


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


func _bloquear_botones(bloquear: bool) -> void:
	boton_continuar.disabled = bloquear
	boton_jugar.disabled = bloquear
	boton_ajustes.disabled = bloquear
	boton_salir.disabled = bloquear


func _on_continuar_pressed() -> void:
	_bloquear_botones(true)
	jugar_presionado.emit()

	if MusicManager:
		MusicManager.quitar_musica(1.2)

	if not SaveManager.cargar_partida():
		_bloquear_botones(false)


func _on_jugar_pressed() -> void:
	# Si ya hay una partida, pedimos confirmación antes de borrar el progreso
	if SaveManager and SaveManager.tiene_partida_guardada():
		dialogo_confirmacion.popup_centered()
	else:
		_iniciar_nueva_partida()


func _iniciar_nueva_partida() -> void:
	if escena_siguiente == "":
		push_warning("Falta asignar 'Escena Siguiente' en el inspector del menú.")
		return

	_bloquear_botones(true)
	jugar_presionado.emit()

	if SaveManager:
		SaveManager.borrar_partida()

	if MusicManager:
		MusicManager.quitar_musica(1.2)

	if TransicionGlobal:
		TransicionGlobal.cambiar_de_nivel(escena_siguiente)
	else:
		push_error("TransicionGlobal no está disponible. Revisa tus AutoLoads.")
		_bloquear_botones(false)


func _on_ajustes_pressed() -> void:
	ajustes_presionados.emit()


func _on_salir_pressed() -> void:
	salir_presionado.emit()
	get_tree().quit()
