extends ColorRect

# --- CONFIGURACIÓN DE PROPORCIONES (Modificables desde el Inspector) ---
@export_group("Proporciones UI")
@export_range(0.1, 0.9) var ratio_ancho_info: float = 0.3     # 0.3 significa 30% para el texto, 70% para el visor
@export_range(0.1, 1.0) var ratio_altura_slots: float = 0.8   # 0.8 significa que los slots ocupan el 80% de la altura del carrusel

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

func _ready() -> void:
	slots = [slot_izq_2, slot_izq_1, slot_centro, slot_der_1, slot_der_2]
	
	# Conectamos las flechas y el mouse del visor
	btn_prev.pressed.connect(mover_carrusel.bind(-1))
	btn_next.pressed.connect(mover_carrusel.bind(1))
	visor_container.gui_input.connect(_on_visor_gui_input)
	
	# ESCUCHA DE REDIMENSIÓN: Cada vez que el inventario cambie de tamaño, recalculamos la UI
	resized.connect(recalcular_proporciones_ui)
	
	# Ejecutamos una primera pasada de calibración al iniciar
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
	# 1. Ajuste del Contenedor Inferior (30% / 70%)
	# Forzamos a que expandan y fillen horizontalmente
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visor_3d_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Aplicamos los ratios calculados matemáticamente
	info_panel.size_flags_stretch_ratio = ratio_ancho_info
	visor_3d_panel.size_flags_stretch_ratio = 1.0 - ratio_ancho_info
	
	# 2. Ajuste de la banda del Carrusel y sus slots
	# Obtenemos la altura real que tiene el panel gris superior en este instante
	var altura_actual_carrusel = carrusel_panel.size.y
	
	# Calculamos el tamaño del slot (queremos que sean cuadrados perfectos de XxX píxeles)
	var dimension_proporcional = altura_actual_carrusel * ratio_altura_slots
	
	# Aplicamos el tamaño mínimo a cada slot para obligar al HBox a escalarlos
	for slot in slots:
		if slot:
			slot.custom_minimum_size = Vector2(dimension_proporcional, dimension_proporcional)

func abrir_inventario() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Forzamos un recalculado al abrir por si se cambió la resolución en el menú de pausa
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
		
		slots[i].texture = Inventory.items_recolectados[nombre_item]["icono"]
		slots[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slots[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	mostrar_info_central()

func limpiar_interfaz() -> void:
	for slot in slots:
		slot.texture = null
	name_text.text = "VACÍO"
	description_text.text = ""
	_limpiar_visor_3d()

func mostrar_info_central() -> void:
	var nombre_seleccionado = Inventory.listado_ordenado[indice_actual]
	var datos = Inventory.items_recolectados[nombre_seleccionado]
	
	name_text.text = nombre_seleccionado.to_upper()
	description_text.text = datos["descripcion"]
	
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
