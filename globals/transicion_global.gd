extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var loading_text: Label = $LoadingText

var cargando: bool = false
var duracion_fade: float = 0.5

func _ready() -> void:
	loading_text.visible = false
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func cambiar_de_nivel(ruta_siguiente_nivel: String) -> void:
	if cargando:
		return
		
	cargando = true
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 1. FADE OUT
	var tween_out = create_tween()
	tween_out.tween_property(color_rect, "color:a", 1.0, duracion_fade)
	await tween_out.finished
	
	loading_text.visible = true
	
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
	var progreso := [] # Declarado fuera del bucle para no saturar memoria
	
	while true:
		var estado = ResourceLoader.load_threaded_get_status(ruta_siguiente_nivel, progreso)
		
		match estado:
			ResourceLoader.THREAD_LOAD_LOADED:
				cargado_exitoso = true
				break
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Opcional: Si agregas una ProgressBar, usas progreso[0] (da un valor float de 0.0 a 1.0)
				# $ProgressBar.value = progreso[0] * 100
				await get_tree().process_frame
			_:
				push_error("Error en hilos de carga. Código: ", estado)
				loading_text.text = "Error al cargar"
				cargado_exitoso = false
				break

	# 4. CAMBIAR DE ESCENA Y FADE IN
	if cargado_exitoso:
		var mapa_empaquetado = ResourceLoader.load_threaded_get(ruta_siguiente_nivel) as PackedScene
		get_tree().change_scene_to_packed(mapa_empaquetado)
		
		loading_text.visible = false
		await get_tree().process_frame
		
		# 5. FADE IN
		var tween_in = create_tween()
		tween_in.tween_property(color_rect, "color:a", 0.0, duracion_fade)
		await tween_in.finished

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargando = false
