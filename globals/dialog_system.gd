extends CanvasLayer

@export_group("Dimensiones de la Caja (%)")
@export_range(0.1, 1.0, 0.01) var ancho_caja_pct: float = 0.75     # 75% del ancho de la pantalla
@export_range(0.05, 0.5, 0.01) var alto_caja_pct: float = 0.20     # 20% del alto de la pantalla
@export_range(0.0, 0.2, 0.01) var distancia_inferior_pct: float = 0.04 # 4% desde la parte inferior

@export_group("Márgenes Internos del Texto (%)")
@export_range(0.0, 0.2, 0.005) var margen_horizontal_pct: float = 0.03 # Margen lateral dentro de la caja
@export_range(0.0, 0.2, 0.005) var margen_vertical_pct: float = 0.03   # Margen vertical dentro de la caja

@export_group("Título Exterior (%)")
@export_range(0.0, 0.1, 0.005) var titulo_offset_y_pct: float = 0.015 # Distancia arriba de la caja de texto
@export_range(0.1, 0.8, 0.01) var titulo_ancho_pct: float = 0.35      # Ancho del área del título
@export_range(0.02, 0.1, 0.005) var titulo_alto_pct: float = 0.05     # Alto del área del título

@onready var control_ui: Control = $Control
@onready var backgroundTextBox: ColorRect = $Control/BackgroundTextBox
@onready var margin: MarginContainer = $Control/BackgroundTextBox/MarginContainer
@onready var title_label: RichTextLabel = $Control/BackgroundTextBox/TitleText
@onready var texto_label: RichTextLabel = $Control/BackgroundTextBox/MarginContainer/DialogueText

var paginas: Array = []
var pagina_actual: int = 0
var esta_activo: bool = false
var esta_escribiendo: bool = false
var tween_texto: Tween

func _ready() -> void:
	control_ui.visible = false
	# Escuchamos el cambio de tamaño de la ventana para recalcular proporciones
	get_viewport().size_changed.connect(_ajustar_layout_dinamico)
	_ajustar_layout_dinamico()

# Función que calcula y posiciona todos los elementos por porcentajes
func _ajustar_layout_dinamico() -> void:
	var pantalla_size: Vector2 = get_viewport().get_visible_rect().size
	if pantalla_size.x <= 0 or pantalla_size.y <= 0:
		return

	# 1. Expandir el contenedor raíz a toda la pantalla
	control_ui.size = pantalla_size
	control_ui.position = Vector2.ZERO

	# 2. Calcular tamaño y posición inferior de la caja de diálogo
	var box_w: float = pantalla_size.x * ancho_caja_pct
	var box_h: float = pantalla_size.y * alto_caja_pct
	var box_x: float = (pantalla_size.x - box_w) / 2.0
	var box_y: float = pantalla_size.y - box_h - (pantalla_size.y * distancia_inferior_pct)

	backgroundTextBox.size = Vector2(box_w, box_h)
	backgroundTextBox.position = Vector2(box_x, box_y)

	# 3. Aplicar márgenes internos dinámicos al MarginContainer
	var m_horiz: int = int(box_w * margen_horizontal_pct)
	var m_vert: int = int(box_h * margen_vertical_pct)

	margin.add_theme_constant_override("margin_left", m_horiz)
	margin.add_theme_constant_override("margin_right", m_horiz)
	margin.add_theme_constant_override("margin_top", m_vert)
	margin.add_theme_constant_override("margin_bottom", m_vert)

	margin.size = backgroundTextBox.size
	margin.position = Vector2.ZERO

	# 4. Posicionar el Título en la parte superior exterior (centrado)
	var title_w: float = pantalla_size.x * titulo_ancho_pct
	var title_h: float = pantalla_size.y * titulo_alto_pct
	var gap_y: float = pantalla_size.y * titulo_offset_y_pct

	title_label.size = Vector2(title_w, title_h)
	title_label.bbcode_enabled = true
	
	# Centrado horizontal relativo a la caja y posicionado justo arriba del borde superior
	title_label.position.x = (box_w - title_w) / 2.0
	title_label.position.y = -title_h - gap_y

func iniciar_dialogo(texto_completo: String, separador: String, titulo: String = "") -> void:
	if esta_activo: return

	# Recalculamos posiciones por si cambió la resolución
	_ajustar_layout_dinamico()

	esta_activo = true
	paginas = texto_completo.split(separador, false)
	pagina_actual = 0

	# Configuración del título opcional
	if titulo != "":
		title_label.text = "[center]" + titulo + "[/center]"
		title_label.visible = true
	else:
		title_label.text = ""
		title_label.visible = false

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
	texto_label.visible_ratio = 0.0

	if tween_texto and tween_texto.is_valid():
		tween_texto.kill()

	tween_texto = create_tween()
	var tiempo_escritura = texto_label.text.length() * 0.03

	tween_texto.tween_property(texto_label, "visible_ratio", 1.0, tiempo_escritura)
	tween_texto.finished.connect(_al_terminar_de_escribir)

func _al_terminar_de_escribir() -> void:
	esta_escribiendo = false

func _input(event: InputEvent) -> void:
	if not esta_activo: return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()

		if esta_escribiendo:
			if tween_texto and tween_texto.is_valid():
				tween_texto.kill()
			texto_label.visible_ratio = 1.0
			esta_escribiendo = false
		else:
			pagina_actual += 1
			mostrar_pagina()

func cerrar_dialogo() -> void:
	esta_activo = false
	var tween_desaparicion = create_tween()
	tween_desaparicion.tween_property(control_ui, "modulate:a", 0.0, 0.2)
	tween_desaparicion.finished.connect(_ocultar_control)

func _ocultar_control() -> void:
	control_ui.visible = false
