extends ColorRect

# --- CONFIGURACIÓN DE PROPORCIONES (Modificables desde el Inspector) ---
@export_group("Proporciones UI")
@export_range(0.1, 0.9) var ratio_ancho_info: float = 0.3     # 0.3 significa 30% para el texto, 70% para el visor
@export_range(0.05, 0.4) var porcentaje_ancho_botones: float = 0.05 # NUEVO: 0.1 significa que cada botón ocupará el 10% del ancho del carrusel

# --- CONFIGURACIÓN DE PROPORCIONES (Modificables desde el Inspector) ---
@export_group("Tiempos de Animación")
@export_range(0.05, 2.0) var tiempo_abrir: float = 0.2        # Tiempo que tarda en desplegarse el inventario
@export_range(0.05, 2.0) var tiempo_cambio: float = 0.4       # Tiempo para la transición lateral (ajustado para suavidad)



# --- REFERENCIAS A NODOS ---
@onready var main_container = $MainContainer
@onready var carrusel_panel = $MainContainer/CarruselPanel
@onready var info_panel = $MainContainer/InferiorHBox/InfoPanel
@onready var visor_3d_panel = $MainContainer/InferiorHBox/Visor3DPanel

@onready var name_text = $MainContainer/InferiorHBox/InfoPanel/MargenInterno/VBoxInfo/NameText
@onready var description_text = $MainContainer/InferiorHBox/InfoPanel/MargenInterno/VBoxInfo/DescriptionText

@onready var model_pivot = $MainContainer/InferiorHBox/Visor3DPanel/SubViewportContainer/SubViewport/ModelPivot
@onready var visor_container = $MainContainer/InferiorHBox/Visor3DPanel/SubViewportContainer

@onready var btn_prev = $MainContainer/CarruselPanel/CarruselHBox/BtnPrev
@onready var btn_next = $MainContainer/CarruselPanel/CarruselHBox/BtnNext

# --- VARIABLES ---
var slots: Array = [] # Ahora almacenará nuestros slots generados dinámicamente
var items_container: Control # Contenedor dinámico superpuesto

var indice_actual: int = 0
var arrastrando_modelo: bool = false
const ROTATION_SPEED: float = 0.01

# Recursos para los bordes generados por código
var style_seleccionado: StyleBoxFlat
var style_deseleccionado: StyleBoxFlat

# Tweens globales para controlar el ciclo de vida de las animaciones
var carrusel_tween: Tween
var name_tween: Tween
var desc_tween: Tween
var desc_flicker_tween: Tween

#Sounds
@onready var miscellaneousSoundsPlayer : AudioStreamPlayer3D = $"../../Sounds/MiscellaneousSounds"
var openInventorySound = preload("res://sounds/player/Inventory Open Sound.mp3")


func _ready() -> void:
	# 1. Ocultamos la imagen de los slots estáticos originales
	# Los mantenemos en el árbol para que el HBoxContainer siga manteniendo
	# la separación física de los botones Prev y Next a los lados.
	var old_slots = [
		$MainContainer/CarruselPanel/CarruselHBox/SlotIzquierda2,
		$MainContainer/CarruselPanel/CarruselHBox/SlotIzquierda1,
		$MainContainer/CarruselPanel/CarruselHBox/SlotCentro,
		$MainContainer/CarruselPanel/CarruselHBox/SlotDerecha1,
		$MainContainer/CarruselPanel/CarruselHBox/SlotDerecha2
	]
	for s in old_slots:
		if s:
			s.modulate.a = 0.0 # Se vuelven invisibles
			var marco = s.get_node_or_null("MarcoVisual")
			if marco: marco.queue_free()

	# 2. Creamos nuestro propio contenedor para mover los slots libremente
	items_container = Control.new()
	items_container.name = "ItemsContainer"
	items_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carrusel_panel.add_child(items_container)
	# Lo movemos atrás para que los botones de Prev/Next se puedan seguir clickeando
	carrusel_panel.move_child(items_container, 0)
	
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
	style_seleccionado.set_border_width_all(3)
	
	style_deseleccionado = StyleBoxFlat.new()
	style_deseleccionado.draw_center = false
	style_deseleccionado.border_color = Color(0.3, 0.3, 0.3, 0.8)
	style_deseleccionado.set_border_width_all(2)

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

	# =================================================================
	# ESTILOS DE LOS BOTONES DE NAVEGACIÓN (PREV / NEXT)
	# =================================================================
	var estilo_boton = StyleBoxFlat.new()
	estilo_boton.bg_color = Color("0E223A") # Tu color personalizado

	# Crear un estilo ligeramente más claro para cuando pasas el ratón (Hover)
	var estilo_hover = estilo_boton.duplicate()
	estilo_hover.bg_color = Color("0E223A").lightened(0.2)
	
	

	# Aplicar el estilo a los botones
	btn_prev.add_theme_stylebox_override("normal", estilo_boton)
	btn_next.add_theme_stylebox_override("normal", estilo_boton)
	
	btn_prev.add_theme_stylebox_override("hover", estilo_hover)
	btn_next.add_theme_stylebox_override("hover", estilo_hover)
	
	btn_prev.add_theme_stylebox_override("pressed", estilo_boton)
	btn_next.add_theme_stylebox_override("pressed", estilo_boton)
	
	btn_next.add_theme_stylebox_override("pressed", estilo_boton)

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
# --- SISTEMA DINÁMICO RESPONSIVO ---
# --- SISTEMA DINÁMICO RESPONSIVO ---
func recalcular_proporciones_ui() -> void:
	if not is_node_ready(): return
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visor_3d_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_stretch_ratio = ratio_ancho_info
	visor_3d_panel.size_flags_stretch_ratio = 1.0 - ratio_ancho_info
	
	# Obtenemos ancho y alto. Si Godot nos da 0 (porque está oculto), 
	# usamos el tamaño base de la pantalla (self.size) como red de seguridad.
	var altura = carrusel_panel.size.y
	if altura == 0: altura = self.size.y * 0.5 # Asume que el panel es la mitad de la pantalla
	
	var ancho_total = carrusel_panel.size.x
	if ancho_total == 0: ancho_total = self.size.x
	
	# --- NUEVO: Ajuste responsive del Width de los botones ---
	var ancho_boton = ancho_total * porcentaje_ancho_botones
	
	btn_prev.custom_minimum_size = Vector2(ancho_boton, btn_prev.custom_minimum_size.y)
	btn_next.custom_minimum_size = Vector2(ancho_boton, btn_next.custom_minimum_size.y)
	# ---------------------------------------------------------
	
	# Mantiene el marco estático para que los botones Prev/Next no se peguen
	var old_slots = [
		$MainContainer/CarruselPanel/CarruselHBox/SlotIzquierda2,
		$MainContainer/CarruselPanel/CarruselHBox/SlotIzquierda1,
		$MainContainer/CarruselPanel/CarruselHBox/SlotCentro,
		$MainContainer/CarruselPanel/CarruselHBox/SlotDerecha1,
		$MainContainer/CarruselPanel/CarruselHBox/SlotDerecha2
	]
	for s in old_slots:
		if s: s.custom_minimum_size = Vector2(altura * 0.8, altura * 0.8)
	
	if visible:
		actualizar_interfaz("ninguna")

# Genera la cantidad exacta de slots según lo que haya en el inventario
func sincronizar_slots_dinamicos() -> void:
	var total_items = Inventory.listado_ordenado.size()
	
	# Si cambió la cantidad, reconstruimos los nodos
	if slots.size() != total_items:
		for child in items_container.get_children():
			child.queue_free()
		slots.clear()
		
		for i in range(total_items):
			var slot = TextureRect.new()
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			var marco = Panel.new()
			marco.name = "MarcoVisual"
			marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(marco)
			marco.set_anchors_preset(Control.PRESET_FULL_RECT)
			
			items_container.add_child(slot)
			slots.append(slot)
			
	# Actualizamos texturas para reflejar el estado real
	for i in range(total_items):
		var nombre_item = Inventory.listado_ordenado[i]
		slots[i].texture = Inventory.items_recolectados[nombre_item]["icono"]

func abrir_inventario() -> void:
	# Ajustamos el tono hacia arriba (agudo) para abrir
	miscellaneousSoundsPlayer.pitch_scale = 1.0
	miscellaneousSoundsPlayer.stream = openInventorySound
	miscellaneousSoundsPlayer.play()
	
	visible = true
	
	# Esperamos al siguiente frame para que el contenedor calcule su tamaño
	await get_tree().process_frame
	
	recalcular_proporciones_ui()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	sincronizar_slots_dinamicos()
	actualizar_interfaz("ninguna") 
	actualizar_interfaz("abrir")

func cerrar_inventario() -> void:
	# Ajustamos el tono hacia abajo (grave) para cerrar
	miscellaneousSoundsPlayer.pitch_scale = 0.8 
	miscellaneousSoundsPlayer.stream = openInventorySound
	miscellaneousSoundsPlayer.play()
	
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
	actualizar_interfaz("cambio")

# --- ACTUALIZACIÓN DE INTERFAZ INTEGRADA ---
func actualizar_interfaz(tipo_animacion: String = "ninguna") -> void:
	var total_items = slots.size()
	
	if total_items == 0:
		limpiar_interfaz()
		return

	indice_actual = clamp(indice_actual, 0, total_items - 1)

	if tipo_animacion != "ninguna":
		if carrusel_tween and carrusel_tween.is_valid():
			carrusel_tween.kill()
		carrusel_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Medidas del carrusel para posicionar
	var altura = carrusel_panel.size.y
	var ancho = carrusel_panel.size.x
	var centro_x = ancho / 2.0
	var espaciado_x = altura * 0.85 # Separación física entre cada slot

	for i in range(total_items):
		var slot = slots[i]
		var marco = slot.get_node("MarcoVisual") as Panel
		
		# --- MATEMÁTICA DE POSICIÓN CIRCULAR ---
		var diff = i - indice_actual
		var half = float(total_items) / 2.0
		
		# Forzamos el salto circular (wrap) para la ilusión de bucle infinito
		if total_items > 2:
			if diff > half: diff -= total_items
			elif diff < -half: diff += total_items
			
		var es_centro = (diff == 0)
		
		# Medidas Objetivo
		var tam_objetivo = altura * 0.9 if es_centro else altura * 0.7
		var pos_x_objetivo = centro_x + (diff * espaciado_x) - (tam_objetivo / 2.0)
		var pos_y_objetivo = (altura - tam_objetivo) / 2.0
		
		# Colores y Estilos
		var color_objetivo = Color(1.0, 1.0, 1.0, 1.0) if es_centro else Color(0.5, 0.5, 0.5, 0.4)
		if abs(diff) > 2.5: # Si se aleja mucho del centro lo hacemos invisible
			color_objetivo.a = 0.0
			
		slot.visible = true
		if es_centro:
			marco.add_theme_stylebox_override("panel", style_seleccionado)
			slot.move_to_front() # Trae al frente para tapar a los laterales
		else:
			marco.add_theme_stylebox_override("panel", style_deseleccionado)
		
		# --- EJECUCIÓN DE ANIMACIÓN ---
		if tipo_animacion == "ninguna":
			slot.size = Vector2(tam_objetivo, tam_objetivo)
			slot.position = Vector2(pos_x_objetivo, pos_y_objetivo)
			slot.modulate = color_objetivo
			
		elif tipo_animacion == "abrir":
			slot.position = Vector2(pos_x_objetivo, pos_y_objetivo)
			slot.size = Vector2(tam_objetivo, tam_objetivo)
			slot.modulate = Color(color_objetivo.r, color_objetivo.g, color_objetivo.b, 0.0)
			
			carrusel_tween.tween_property(slot, "modulate", color_objetivo, tiempo_abrir)
			
		elif tipo_animacion == "cambio":
			# EL TRUCO DEL INFINITO: Si el salto posicional de un slot es gigante (recorrió 
			# todo el layout de golpe porque pasó del final al principio), 
			# lo teletransportamos fuera de pantalla antes de hacer el tween para que "entre" suavamente.
			if abs(pos_x_objetivo - slot.position.x) > espaciado_x * 1.5:
				var dir_salto = sign(pos_x_objetivo - centro_x)
				var pos_x_inicio = pos_x_objetivo + (dir_salto * espaciado_x)
				
				slot.position = Vector2(pos_x_inicio, pos_y_objetivo)
				slot.size = Vector2(tam_objetivo, tam_objetivo)
				slot.modulate.a = 0.0 # Nace transparente
			
			carrusel_tween.tween_property(slot, "position", Vector2(pos_x_objetivo, pos_y_objetivo), tiempo_cambio)
			carrusel_tween.tween_property(slot, "size", Vector2(tam_objetivo, tam_objetivo), tiempo_cambio)
			carrusel_tween.tween_property(slot, "modulate", color_objetivo, tiempo_cambio)

	mostrar_info_central()

func limpiar_interfaz() -> void:
	if name_tween and name_tween.is_valid(): name_tween.kill()
	if desc_tween and desc_tween.is_valid(): desc_tween.kill()
	if desc_flicker_tween and desc_flicker_tween.is_valid(): desc_flicker_tween.kill()

	for slot in slots:
		slot.visible = false
			
	name_text.text = "VACÍO"
	description_text.text = ""
	_limpiar_visor_3d()

func mostrar_info_central() -> void:
	# --- SEGURIDAD: Si no hay objetos, no hacemos nada ---
	if Inventory.listado_ordenado.is_empty() or indice_actual >= Inventory.listado_ordenado.size():
		_limpiar_visor_3d()
		return
	# ----------------------------------------------------
	
	var nombre_seleccionado = Inventory.listado_ordenado[indice_actual]
	var datos = Inventory.items_recolectados[nombre_seleccionado]
	
	if name_tween and name_tween.is_valid(): name_tween.kill()
	if desc_tween and desc_tween.is_valid(): desc_tween.kill()
	if desc_flicker_tween and desc_flicker_tween.is_valid(): desc_flicker_tween.kill()
	
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

# --- EFECTOS VISUALES RETRO REUTILIZABLES ---

func _animar_nombre_flicker(label: RichTextLabel) -> void:
	label.modulate.a = 0.0
	name_tween = create_tween()
	name_tween.tween_property(label, "modulate:a", 1.0, 0.02)
	name_tween.tween_property(label, "modulate:a", 0.2, 0.03)
	name_tween.tween_property(label, "modulate:a", 0.9, 0.02)
	name_tween.tween_property(label, "modulate:a", 0.0, 0.04)
	name_tween.tween_property(label, "modulate:a", 1.0, 0.03)

func _animar_descripcion_typewriter(label: RichTextLabel) -> void:
	label.visible_ratio = 0.0
	label.modulate.a = 1.0
	
	var duracion_escritura = clamp(label.text.length() * 0.015, 0.2, 0.7)
	
	desc_tween = create_tween().set_parallel(true)
	desc_tween.tween_property(label, "visible_ratio", 1.0, duracion_escritura)
	
	desc_flicker_tween = create_tween()
	var repeticiones = int(duracion_escritura / 0.06)
	
	for i in range(repeticiones):
		desc_flicker_tween.tween_property(label, "modulate:a", 0.4, 0.03)
		desc_flicker_tween.tween_property(label, "modulate:a", 1.0, 0.03)
