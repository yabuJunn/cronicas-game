extends CanvasLayer

@onready var control_ui = $Control
@onready var texto_label = $Control/BackgroundTextBox/DialogueText

var paginas: Array = []
var pagina_actual: int = 0
var esta_activo: bool = false
var esta_escribiendo: bool = false
var tween_texto: Tween

func _ready() -> void:
	control_ui.visible = false # Ocultamos la UI al iniciar el juego

func iniciar_dialogo(texto_completo: String, separador: String) -> void:
	if esta_activo: return
	
	esta_activo = true
	# Separamos el texto usando el delimitador (ej: "||")
	paginas = texto_completo.split(separador, false)
	pagina_actual = 0
	
	control_ui.visible = true
	
	# Animación de aparición suave de la caja
	control_ui.modulate.a = 0.0
	var tween_aparicion = create_tween()
	tween_aparicion.tween_property(control_ui, "modulate:a", 1.0, 0.2)
	
	mostrar_pagina()

func mostrar_pagina() -> void:
	if pagina_actual >= paginas.size():
		cerrar_dialogo()
		return
		
	esta_escribiendo = true
	texto_label.text = paginas[pagina_actual]
	texto_label.visible_ratio = 0.0 # Ocultamos el texto
	
	if tween_texto and tween_texto.is_valid():
		tween_texto.kill()
	
	tween_texto = create_tween()
	# Calculamos el tiempo según la cantidad de letras (0.03 segundos por letra)
	var tiempo_escritura = texto_label.text.length() * 0.03 
	
	# Animamos el texto para que parezca máquina de escribir
	tween_texto.tween_property(texto_label, "visible_ratio", 1.0, tiempo_escritura)
	tween_texto.finished.connect(_al_terminar_de_escribir)

func _al_terminar_de_escribir() -> void:
	esta_escribiendo = false

func _input(event: InputEvent) -> void:
	if not esta_activo: return
	
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled() # Consumimos el input para que no haga otra cosa
		
		if esta_escribiendo:
			# Si está escribiendo y apretamos 'E', completamos el texto al instante
			if tween_texto and tween_texto.is_valid():
				tween_texto.kill()
			texto_label.visible_ratio = 1.0
			esta_escribiendo = false
		else:
			# Si ya terminó de escribir, pasamos a la siguiente página
			pagina_actual += 1
			mostrar_pagina()

func cerrar_dialogo() -> void:
	esta_activo = false
	var tween_desaparicion = create_tween()
	tween_desaparicion.tween_property(control_ui, "modulate:a", 0.0, 0.2)
	tween_desaparicion.finished.connect(_ocultar_control)

func _ocultar_control() -> void:
	control_ui.visible = false
