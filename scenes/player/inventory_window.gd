extends ColorRect

@onready var grid = $ItemsGrid
@onready var description_text = $DescriptionText
@onready var name_text = $NameText

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if visible:
			cerrar_inventario()
		else:
			abrir_inventario()

func abrir_inventario() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	actualizar_cuadricula()

func cerrar_inventario() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	description_text.text = ""
	name_text.text = ""

func actualizar_cuadricula() -> void:
	# Borramos los botones viejos
	for child in grid.get_children():
		child.queue_free()
		
	# Creamos un botón por cada objeto
	for nombre_item in Inventory.items_recolectados.keys():
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80) # Tamaño de tu casilla
		
		# Obtenemos los datos del objeto actual
		var datos_item = Inventory.items_recolectados[nombre_item]
		var descripcion = datos_item["descripcion"]
		var icono = datos_item["icono"]
		
		# ¿Tiene una imagen PNG asignada?
		if icono != null:
			btn.icon = icono
			btn.expand_icon = true  # Esto hace que la imagen se estire para rellenar los 80x80 px
			btn.text = ""           # Borramos el texto para que solo se vea el render
		else:
			btn.text = nombre_item  # Si no tiene imagen, muestra el texto como antes
		
		# La lógica del click sigue funcionando exactamente igual
		btn.pressed.connect(func(): mostrar_info(nombre_item, descripcion))
		
		grid.add_child(btn)

func mostrar_info(nombre: String, descripcion: String) -> void:
	name_text.text = nombre
	description_text.text = descripcion
