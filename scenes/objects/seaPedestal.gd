extends InteractableItem

# Pedestal

var energy_sphere: PackedScene = preload("res://scenes/objects/energy_sphere.tscn")

# --- CONFIGURACIÓN DE FUNC_GODOT ---
@export_group("Configuración de Activación")
@export var llave_requerida: String = "Esfera de Energía"
# Escribe aquí el ID de la puerta que quieres que abra este pedestal
@export var target_id: String = "puerta_principal" 

@export var texto_sin_llave: String = "Falta la Esfera de Energía."
@export var texto_con_llave: String = "Colocar Esfera de Energía"

# Ajusta esto desde el Inspector para mover la esfera hacia arriba si aparece muy abajo
@export var esfera_offset_posicion: Vector3 = Vector3(0.0, 1.5, 0.0)

var ya_activado: bool = false

func _obtener_texto_interaccion() -> String:
	if ya_activado:
		return "El mecanismo ya está activo."
	if Inventory.tiene_objeto(llave_requerida):
		return "[ E ] " + texto_con_llave
	else:
		return texto_sin_llave

func _ready() -> void:
	super._ready() 
	se_puede_recoger = false 

func interactuar() -> void:
	if ya_activado:
		return

	if Inventory.tiene_objeto(llave_requerida):
		print("¡Esfera colocada con éxito en el pedestal!")
		ya_activado = true
		Inventory.remover_objeto(llave_requerida)
		
		set_highlight(false)
		if is_in_group("interactibleObjects"):
			remove_from_group("interactibleObjects")
		
		# --- INSTANCIAR LA ESFERA VISUAL ---
		if energy_sphere:
			var nueva_esfera = energy_sphere.instantiate()
			add_child(nueva_esfera)
			
			# La posicionamos usando el offset configurado
			nueva_esfera.position = esfera_offset_posicion
			
			# Desactivamos su interactividad inmediatamente si hereda de InteractableItem
			if "se_puede_recoger" in nueva_esfera:
				nueva_esfera.se_puede_recoger = false
			if nueva_esfera.has_method("set_highlight"):
				nueva_esfera.set_highlight(false)
			if nueva_esfera.is_in_group("interactibleObjects"):
				nueva_esfera.remove_from_group("interactibleObjects")
			
			# Desactivamos todas sus colisiones para que el Raycast del jugador la ignore por completo
			# y no intente interactuar con ella nunca más.
			desactivar_colisiones_recursivo(nueva_esfera)
		
		# --- CONEXIÓN AUTOMÁTICA ---
		# Le enviamos un mensaje a todas las puertas del grupo, pasando el ID objetivo
		get_tree().call_group("puertas_mapa", "verificar_y_abrir", target_id)
		
	else:
		print("El pedestal emite un zumbido vacío. Necesitas la ", llave_requerida)

# Función auxiliar para apagar cualquier CollisionShape3D dentro de la esfera colocada
func desactivar_colisiones_recursivo(nodo: Node) -> void:
	if nodo is CollisionShape3D:
		nodo.disabled = true
	for hijo in nodo.get_children():
		desactivar_colisiones_recursivo(hijo)
