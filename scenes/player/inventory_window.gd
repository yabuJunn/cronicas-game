extends ColorRect

@onready var grid = $ItemsGrid
@onready var description_text = $DescriptionText
@onready var name_text = $NameText # 1. Agregamos la referencia al nuevo nodo

# Asegúrate de crear una acción llamada "inventory" (ej. tecla Tab o I) en el Input Map
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if visible:
			cerrar_inventario()
		else:
			abrir_inventario()

func abrir_inventario() -> void:
	visible = true
	get_tree().paused = true # ¡Pausa el juego!
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Liberamos el mouse
	actualizar_cuadricula()

func cerrar_inventario() -> void:
	visible = false
	get_tree().paused = false # Despausa el juego
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Volvemos a atrapar el mouse
	description_text.text = "" # Limpiamos la descripción
	name_text.text = "" # 2. Limpiamos también el título para que no quede pegado

func actualizar_cuadricula() -> void:
	# 1. Borramos los botones viejos para no duplicar
	for child in grid.get_children():
		child.queue_free()
		
	# 2. Creamos un botón por cada objeto que haya en nuestro Autoload
	for nombre_item in Inventory.items_recolectados.keys():
		var btn = Button.new()
		btn.text = nombre_item
		btn.custom_minimum_size = Vector2(80, 80) # Tamaño de la casilla en la cuadrícula
		
		# Conectamos el click del botón a la nueva función, pasándole ambos datos
		var descripcion = Inventory.items_recolectados[nombre_item]
		btn.pressed.connect(func(): mostrar_info(nombre_item, descripcion))
		
		grid.add_child(btn)

# 3. Modificamos la función para que reciba y asigne ambos textos
func mostrar_info(nombre: String, descripcion: String) -> void:
	name_text.text = nombre
	description_text.text = descripcion
