extends CanvasLayer
#Transicion Global Manager

@onready var color_rect: ColorRect = $ColorRect
@onready var loading_text: Label = $LoadingText

var cargando: bool = false
var duracion_fade: float = 0.5

func _ready() -> void:
	loading_text.visible = false
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- FADE IN CON FRAMES DE CORTESÍA ---
func realizar_fade_in(duracion: float = 1.0, cuadros_espera: int = 3) -> void:
	# Si cambiar_de_nivel() ya está gestionando el fade, no interferimos
	if cargando:
		return

	color_rect.color.a = 1.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_text.visible = false

	for i in range(cuadros_espera):
		await get_tree().process_frame

	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duracion)
	await tween.finished

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func cambiar_de_nivel(ruta_siguiente_nivel: String, posicion_spawn: Variant = null) -> void:
	if cargando:
		return

	cargando = true
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. FADE OUT
	var tween_out = create_tween()
	tween_out.tween_property(color_rect, "color:a", 1.0, duracion_fade)
	await tween_out.finished

	loading_text.text = "Cargando"
	loading_text.visible = true

	var tiempo_inicio = Time.get_ticks_msec()

	# 2. INICIAR CARGA EN HILO SECUNDARIO
	var error = ResourceLoader.load_threaded_request(ruta_siguiente_nivel)
	if error != OK:
		push_error("No se pudo iniciar la carga para: ", ruta_siguiente_nivel)
		loading_text.text = "Error de lectura"
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargando = false
		return

	# 3. BUCLE DE ESPERA ASÍNCRONO
	var cargado_exitoso := false
	var progreso := []
	var tiempo_puntos := 0.0
	var cantidad_puntos := 0

	while true:
		var estado = ResourceLoader.load_threaded_get_status(ruta_siguiente_nivel, progreso)

		match estado:
			ResourceLoader.THREAD_LOAD_LOADED:
				cargado_exitoso = true
				break
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				tiempo_puntos += get_process_delta_time()
				if tiempo_puntos >= 0.3:
					tiempo_puntos = 0.0
					cantidad_puntos = (cantidad_puntos + 1) % 4
					loading_text.text = "Cargando" + ".".repeat(cantidad_puntos)
				await get_tree().process_frame
			_:
				push_error("Error en hilos de carga. Código: ", estado)
				loading_text.text = "Error al cargar"
				cargado_exitoso = false
				break

	# 4. CAMBIAR DE ESCENA, POSICIONAR AL JUGADOR Y FADE IN
	if cargado_exitoso:
		var tiempo_fin = Time.get_ticks_msec()
		print("⏱️ Mapa cargado en: ", tiempo_fin - tiempo_inicio, " ms")

		var mapa_empaquetado = ResourceLoader.load_threaded_get(ruta_siguiente_nivel) as PackedScene
		get_tree().change_scene_to_packed(mapa_empaquetado)
		loading_text.visible = false

		# Esperamos 1 frame para que la nueva escena entre al árbol
		await get_tree().process_frame

		var player := get_tree().get_first_node_in_group("player")
		if player:
			if posicion_spawn is Vector3:
				player.global_position = posicion_spawn
				player.velocity = Vector3.ZERO
				if RespawnManager:
					RespawnManager.set_checkpoint(posicion_spawn)
			elif RespawnManager:
				# Si entramos normal a un nivel nuevo, su inicio es el checkpoint base
				RespawnManager.set_checkpoint(player.global_position)

		# 2 frames extra de cortesía antes de revelar la escena
		for i in range(2):
			await get_tree().process_frame

		# 5. FADE IN
		var tween_in = create_tween()
		tween_in.tween_property(color_rect, "color:a", 0.0, duracion_fade)
		await tween_in.finished

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargando = false
