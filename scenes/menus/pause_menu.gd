extends CanvasLayer
# PauseMenu (Autoload)

signal opciones_presionadas

enum AccionSalida { NINGUNA, MENU_PRINCIPAL, ESCRITORIO }

@export_group("Navegación")
## Arrastra aquí la escena de tu menú principal (.tscn) desde el Inspector
@export_file("*.tscn") var ruta_menu_principal: String = ""

# --- NODOS MENÚ PRINCIPAL DE PAUSA ---
@onready var root_control: Control = $RootControl
@onready var feedback_label: Label = $RootControl/CenterContainer/VBoxContainer/FeedbackLabel
@onready var boton_continuar: Button = $RootControl/CenterContainer/VBoxContainer/ContinuarButton
@onready var boton_guardar: Button = $RootControl/CenterContainer/VBoxContainer/GuardarButton
@onready var boton_opciones: Button = $RootControl/CenterContainer/VBoxContainer/OpcionesButton
@onready var boton_salir_menu: Button = $RootControl/CenterContainer/VBoxContainer/SalirMenuButton
@onready var boton_salir: Button = $RootControl/CenterContainer/VBoxContainer/SalirEscritorio

# --- NODOS MODAL DE CONFIRMACIÓN ---
@onready var modal_confirmacion: Control = $RootControl/ConfirmacionModal
@onready var titulo_modal: Label = $RootControl/ConfirmacionModal/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TituloModalLabel
@onready var mensaje_modal: Label = $RootControl/ConfirmacionModal/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MensajeModalLabel
@onready var boton_cancelar_modal: Button = $RootControl/ConfirmacionModal/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CancelarModalButton
@onready var boton_confirmar_modal: Button = $RootControl/ConfirmacionModal/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ConfirmarModalButton

var esta_pausado: bool = false
var tween_feedback: Tween
var accion_pendiente: AccionSalida = AccionSalida.NINGUNA
var ultimo_boton_salida: Button = null

# Registro de pantallas/sistemas que impiden abrir la pausa (ej. {"inventario": true})
var bloqueadores_pausa: Dictionary = {}


func _ready() -> void:
	# Indispensable: permite que este nodo siga recibiendo inputs aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	visible = false
	modal_confirmacion.visible = false
	feedback_label.text = ""
	feedback_label.modulate.a = 0.0
	
	boton_continuar.pressed.connect(reanudar_juego)
	boton_guardar.pressed.connect(_on_guardar_pressed)
	boton_opciones.pressed.connect(_on_opciones_pressed)
	boton_salir_menu.pressed.connect(_on_salir_menu_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)
	
	boton_cancelar_modal.pressed.connect(_cerrar_modal_salida)
	boton_confirmar_modal.pressed.connect(_on_confirmar_salida_pressed)


# --- API PÚBLICA PARA BLOQUEAR/DESBLOQUEAR PAUSA DESDE OTROS MENÚS ---

func bloquear_pausa(origen: String) -> void:
	if origen != "":
		bloqueadores_pausa[origen] = true


func desbloquear_pausa(origen: String) -> void:
	bloqueadores_pausa.erase(origen)


func limpiar_bloqueos() -> void:
	bloqueadores_pausa.clear()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	if esta_pausado:
		# Si el modal de confirmación está abierto, Esc lo cierra y vuelve al menú de pausa
		if modal_confirmacion.visible:
			_cerrar_modal_salida()
		else:
			reanudar_juego()
		get_viewport().set_input_as_handled()
	elif _puede_pausar():
		pausar_juego()
		get_viewport().set_input_as_handled()


func _puede_pausar() -> bool:
	# 1. Si hay algún bloqueo activo registrado (inventario, notas, etc.)
	if not bloqueadores_pausa.is_empty():
		return false

	# 2. Si el árbol ya fue pausado por otra interfaz (como el inventario)
	if get_tree().paused:
		return false

	# 3. Si existe algún nodo visible marcado con el grupo "bloquea_pausa"
	for nodo in get_tree().get_nodes_in_group("bloquea_pausa"):
		if nodo is CanvasItem and nodo.is_visible_in_tree():
			return false

	# 4. No permitir pausar en el menú principal (donde no existe el jugador)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false

	# 5. Evitar pausar durante pantallas de carga, respawns o cinemáticas
	if TransicionGlobal and TransicionGlobal.cargando:
		return false
	if RespawnManager and RespawnManager.is_respawning:
		return false
	if "en_cinematica" in player and player.en_cinematica:
		return false

	return true


func pausar_juego() -> void:
	esta_pausado = true
	get_tree().paused = true
	
	visible = true
	modal_confirmacion.visible = false
	accion_pendiente = AccionSalida.NINGUNA
	feedback_label.text = ""
	feedback_label.modulate.a = 0.0
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	boton_continuar.grab_focus()


func reanudar_juego() -> void:
	esta_pausado = false
	visible = false
	modal_confirmacion.visible = false
	accion_pendiente = AccionSalida.NINGUNA
	get_tree().paused = false
	
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var bloqueado: bool = "controles_bloqueados" in player and player.controles_bloqueados
		if not bloqueado:
			if "camera_enabled" in player:
				player.camera_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_guardar_pressed() -> void:
	if SaveManager == null:
		push_error("PauseMenu: SaveManager no está disponible.")
		return

	var exito := SaveManager.guardar_partida()
	if exito:
		_mostrar_feedback("¡Partida guardada!", Color(0.55, 0.95, 0.65))
	else:
		_mostrar_feedback("No se pudo guardar aquí", Color(0.95, 0.45, 0.45))


func _mostrar_feedback(texto: String, color: Color) -> void:
	feedback_label.text = texto
	feedback_label.modulate = color
	feedback_label.modulate.a = 1.0

	if tween_feedback:
		tween_feedback.kill()

	tween_feedback = create_tween()
	tween_feedback.tween_interval(1.5)
	tween_feedback.tween_property(feedback_label, "modulate:a", 0.0, 0.5)


func _on_opciones_pressed() -> void:
	opciones_presionadas.emit()
	_mostrar_feedback("Opciones disponibles próximamente", Color(0.85, 0.85, 0.85))


# --- GESTIÓN DINÁMICA DEL MODAL DE SALIDA ---

func _on_salir_menu_pressed() -> void:
	ultimo_boton_salida = boton_salir_menu
	_abrir_modal_salida(AccionSalida.MENU_PRINCIPAL)


func _on_salir_pressed() -> void:
	ultimo_boton_salida = boton_salir
	_abrir_modal_salida(AccionSalida.ESCRITORIO)


func _abrir_modal_salida(accion: AccionSalida) -> void:
	accion_pendiente = accion

	match accion:
		AccionSalida.MENU_PRINCIPAL:
			titulo_modal.text = "¿Salir al menú principal?"
			mensaje_modal.text = "Si vuelves al menú sin guardar, perderás todo el progreso no guardado.\n¿Deseas continuar?"
			boton_confirmar_modal.text = "Salir al menú"
		AccionSalida.ESCRITORIO:
			titulo_modal.text = "¿Salir al escritorio?"
			mensaje_modal.text = "Si cierras el juego sin guardar, perderás todo el progreso no guardado.\n¿Deseas salir?"
			boton_confirmar_modal.text = "Salir del juego"

	modal_confirmacion.visible = true
	# Enfocar "Cancelar" por seguridad para evitar cierres accidentales con Enter/Espacio
	boton_cancelar_modal.grab_focus()


func _cerrar_modal_salida() -> void:
	modal_confirmacion.visible = false
	accion_pendiente = AccionSalida.NINGUNA
	if is_instance_valid(ultimo_boton_salida):
		ultimo_boton_salida.grab_focus()
	else:
		boton_continuar.grab_focus()


func _on_confirmar_salida_pressed() -> void:
	var accion_a_ejecutar := accion_pendiente
	modal_confirmacion.visible = false
	accion_pendiente = AccionSalida.NINGUNA

	match accion_a_ejecutar:
		AccionSalida.MENU_PRINCIPAL:
			_ejecutar_salida_menu()
		AccionSalida.ESCRITORIO:
			_ejecutar_salida_escritorio()


func _ejecutar_salida_menu() -> void:
	if ruta_menu_principal == "":
		push_warning("PauseMenu: Falta asignar 'Ruta Menu Principal' en el inspector de pause_menu.tscn.")
		return

	esta_pausado = false
	visible = false
	limpiar_bloqueos()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if MusicManager:
		MusicManager.quitar_musica(1.0)

	if TransicionGlobal:
		TransicionGlobal.cambiar_de_nivel(ruta_menu_principal)
	else:
		get_tree().change_scene_to_file(ruta_menu_principal)


func _ejecutar_salida_escritorio() -> void:
	boton_confirmar_modal.disabled = true
	boton_cancelar_modal.disabled = true

	if MusicManager:
		MusicManager.quitar_musica(0.4)

	# Fundido rápido a negro antes de cerrar la ventana
	if TransicionGlobal and TransicionGlobal.color_rect:
		TransicionGlobal.color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween_cierre := create_tween()
		tween_cierre.tween_property(TransicionGlobal.color_rect, "color:a", 1.0, 0.4)
		await tween_cierre.finished

	limpiar_bloqueos()
	get_tree().paused = false
	get_tree().quit()
