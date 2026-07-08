extends ColorRect

# --- CONFIGURACIÓN DE PROPORCIONES (Modificables desde el Inspector) ---
@export_group("Proporciones UI")
@export_range(0.1, 0.9) var ratio_ancho_info: float = 0.3     # 0.3 significa 30% para el texto, 70% para el visor

# --- REFERENCIAS A NODOS ---
@onready var main_container = $MainContainer
@onready var carrusel_panel = $MainContainer/CarruselPanel
@onready var info_panel = $MainContainer/InferiorHBox/InfoPanel
@onready var visor_3d_panel = $MainContainer/InferiorHBox/Visor3DPanel

@onready var slot_izq_2 = $MainContainer/CarruselPanel/CarruselHBox/SlotIzquierda2
@onready var slot_izq_1 = $MainContainer/CarruselPanel/CarruselHBox/SlotIzquierda1
@onready var slot_centro = $MainContainer/CarruselPanel/CarruselHBox/SlotCentro
@onready var slot_der_1 = $MainContainer/CarruselPanel/CarruselHBox/SlotDerecha1
@onready var slot_der_2 = $MainContainer/CarruselPanel/CarruselHBox/SlotDerecha2

@onready var name_text = $MainContainer/InferiorHBox/InfoPanel/MargenInterno/VBoxInfo/NameText
@onready var description_text = $MainContainer/InferiorHBox/InfoPanel/MargenInterno/VBoxInfo/DescriptionText

@onready var model_pivot = $MainContainer/InferiorHBox/Visor3DPanel/SubViewportContainer/SubViewport/ModelPivot
@onready var visor_container = $MainContainer/InferiorHBox/Visor3DPanel/SubViewportContainer

@onready var btn_prev = $MainContainer/CarruselPanel/CarruselHBox/BtnPrev
@onready var btn_next = $MainContainer/CarruselPanel/CarruselHBox/BtnNext

# --- VARIABLES ---
var slots: Array = []
var indice_actual: int = 0
var arrastrando_modelo: bool = false
const ROTATION_SPEED: float = 0.01

# Recursos para los bordes generados por código
var style_seleccionado: StyleBoxFlat
var style_deseleccionado: StyleBoxFlat

func _ready() -> void:
	slots = [slot_izq_2, slot_izq_1, slot_centro, slot_der_1, slot_der_2]
	
	# Conectamos las flechas y el mouse del visor
	btn_prev.pressed.connect(mover_carrusel.bind(-1))
	btn_next.pressed.connect(mover_carrusel.bind(1))
	visor_container.gui_input.connect(_on_visor_gui_input)
	
	# ESCUCHA DE REDIMENSIÓN
	resized.connect(recalcular_proporciones_ui)
	
	# =================================================================
	# CONFIGURACIÓN DE BORDES RETRO (StyleBoxes)
	# =================================================================
	style_seleccionado = StyleBoxFlat.new()
	style_seleccionado.draw_center = false
	style_seleccionado.border_color = Color.WHITE
	style_seleccionado.set_border_width_all(3) # Grosor del borde blanco
	
	style_deseleccionado = StyleBoxFlat.new()
	style_deseleccionado.draw_center = false
	style_deseleccionado.border_color = Color(0.3, 0.3, 0.3, 0.8) # Gris oscuro retro
	style_deseleccionado.set_border_width_all(2) # Grosor del borde gris

	# Inyectamos un nodo Panel invisible en cada slot para que sirva de marco
	for slot in slots:
		if slot:
			var marco = Panel.new()
			marco.name = "MarcoVisual"
			marco.mouse_filter = Control.MOUSE_FILTER_IGNORE # Evita que bloquee clicks
			slot.add_child(marco)
			marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# =================================================================
	# ARREGLO DE CONTENEDORES Y RICHTEXTLABELS
	# =================================================================
	var margen_interno = $MainContainer/InferiorHBox/InfoPanel/MargenInterno
	margen_interno.layout_mode = 1 
	margen_interno.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	margen_interno.add_theme_constant_override("margin_left", 15)
	margen_interno.add_theme_constant_override("margin_top", 15)
	margen_interno.add_theme_constant_override("margin_right", 15)
	margen_interno.add_theme_constant_override("margin_bottom", 15)
	
	var vbox_info = $MainContainer/InferiorHBox/InfoPanel/MargenInterno/VBoxInfo
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.size_flags_vertical = Control.SIZE_EXPAND_FILL

	name_text.fit_content = true 
	name_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	description_text.fit_content = true 
	description_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# =================================================================

	# Ejecutamos la primera pasada de calibración
	recalcular_proporciones_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if visible:
			cerrar_inventario()
		else:
			abrir_inventario()
			
	if visible:
		if event.is_action_pressed("ui_left"):
			mover_carrusel(-1)
		elif event.is_action_pressed("ui_right"):
			mover_carrusel(1)

# --- SISTEMA DINÁMICO RESPONSIVO ---
func recalcular_proporciones_ui() -> void:
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visor_3d_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_stretch_ratio = ratio_ancho_info
	visor_3d_panel.size_flags_stretch_ratio = 1.0 - ratio_ancho_info
	
	# Obtenemos la altura real de la banda del carrusel
	var altura_actual_carrusel = carrusel_panel.size.y
	
	# Ajustamos los tamaños diferenciando el centro de los laterales
	for i in range(slots.size()):
		var slot = slots[i]
		if slot:
			# ¡CRUCIAL!: Evita que el contenedor estire el slot verticalmente.
			# Al centrarlo, respetará de forma estricta el tamaño cuadrado de custom_minimum_size.
			slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			if i == 2:
				# El seleccionado (centro) es un cuadrado del 90% de la altura total
				var tam_centro = altura_actual_carrusel * 0.9
				slot.custom_minimum_size = Vector2(tam_centro, tam_centro)
			else:
				# Los deseleccionados (laterales) son cuadrados del 80% de la altura total
				var tam_lateral = altura_actual_carrusel * 0.8
				slot.custom_minimum_size = Vector2(tam_lateral, tam_lateral)

func abrir_inventario() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	recalcular_proporciones_ui()
	
	if Inventory.listado_ordenado.size() > 0:
		indice_actual = clamp(indice_actual, 0, Inventory.listado_ordenado.size() - 1)
	
	actualizar_interfaz()

func cerrar_inventario() -> void:
	visible = false
	arrastrando_modelo = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- LÓGICA DEL CARRUSEL INFINITO ---
func mover_carrusel(direccion: int) -> void:
	var total_items = Inventory.listado_ordenado.size()
	if total_items <= 1:
		return
		
	indice_actual = posmod(indice_actual + direccion, total_items)
	actualizar_interfaz()

func actualizar_interfaz() -> void:
	var total_items = Inventory.listado_ordenado.size()
	
	if total_items == 0:
		limpiar_interfaz()
		return

	for i in range(5):
		var offset = i - 2
		var index_real = posmod(indice_actual + offset, total_items)
		var nombre_item = Inventory.listado_ordenado[index_real]
		
		var slot = slots[i]
		slot.texture = Inventory.items_recolectados[nombre_item]["icono"]
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Recuperamos el marco que creamos en el _ready()
		var marco = slot.get_node("MarcoVisual") as Panel
		
		# Aplicamos el filtro de selección/deselección visual
		if i == 2:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if marco:
				marco.add_theme_stylebox_override("panel", style_seleccionado)
		else:
			slot.modulate = Color(0.5, 0.5, 0.5, 0.4)
			if marco:
				marco.add_theme_stylebox_override("panel", style_deseleccionado)

	mostrar_info_central()

func limpiar_interfaz() -> void:
	for slot in slots:
		slot.texture = null
		slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var marco = slot.get_node("MarcoVisual") as Panel
		if marco:
			# SOLUCIÓN AL ERROR: En Godot 4 los overrides se eliminan con remove
			marco.remove_theme_stylebox_override("panel")
			
	name_text.text = "VACÍO"
	description_text.text = ""
	_limpiar_visor_3d()

func mostrar_info_central() -> void:
	var nombre_seleccionado = Inventory.listado_ordenado[indice_actual]
	var datos = Inventory.items_recolectados[nombre_seleccionado]
	
	var viejo_tween_name = create_tween()
	viejo_tween_name.kill() 
	
	name_text.text = nombre_seleccionado.to_upper()
	description_text.text = datos["descripcion"]
	
	_animar_nombre_flicker(name_text)
	_animar_descripcion_typewriter(description_text)
	
	_cargar_modelo_3d(datos["modelo_3d"])

# --- VISOR 3D ---
func _cargar_modelo_3d(modelo_scene: PackedScene) -> void:
	_limpiar_visor_3d()
	if modelo_scene == null: return
		
	var instancia = modelo_scene.instantiate()
	model_pivot.add_child(instancia)
	instancia.position = Vector3.ZERO 
	model_pivot.rotation = Vector3.ZERO

func _limpiar_visor_3d() -> void:
	for child in model_pivot.get_children():
		child.queue_free()

# --- ROTACIÓN CON RATÓN ---
func _on_visor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			arrastrando_modelo = event.pressed
			
	if event is InputEventMouseMotion and arrastrando_modelo:
		model_pivot.rotate_y(-event.relative.x * ROTATION_SPEED)
		model_pivot.rotate_x(-event.relative.y * ROTATION_SPEED)

# --- EFECTOS VISUALES RETRO ---

func _animar_nombre_flicker(label: RichTextLabel) -> void:
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.02)
	tween.tween_property(label, "modulate:a", 0.2, 0.03)
	tween.tween_property(label, "modulate:a", 0.9, 0.02)
	tween.tween_property(label, "modulate:a", 0.0, 0.04)
	tween.tween_property(label, "modulate:a", 1.0, 0.03)


func _animar_descripcion_typewriter(label: RichTextLabel) -> void:
	label.visible_ratio = 0.0
	label.modulate.a = 1.0
	
	var duracion_escritura = clamp(label.text.length() * 0.015, 0.2, 0.7)
	
	var tween_principal = create_tween().set_parallel(true)
	tween_principal.tween_property(label, "visible_ratio", 1.0, duracion_escritura)
	
	var tween_flicker = create_tween()
	var repeticiones = int(duracion_escritura / 0.06)
	
	for i in range(repeticiones):
		tween_flicker.tween_property(label, "modulate:a", 0.4, 0.03)
		tween_flicker.tween_property(label, "modulate:a", 1.0, 0.03)
