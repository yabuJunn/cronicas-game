extends InteractableItem

# --- CONFIGURACIÓN DE FUNC_GODOT ---
@export_group("Configuración de Activación")
@export var llave_requerida: String = "Esfera de Energía"
# Escribe aquí el ID de la puerta que quieres que abra este pedestal
@export var target_id: String = "puerta_principal" 

@export var texto_sin_llave: String = "Falta la Esfera de Energía."
@export var texto_con_llave: String = "Colocar Esfera de Energía"

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
		
		# --- CONEXIÓN AUTOMÁTICA ---
		# Le enviamos un mensaje a todas las puertas del grupo, pasando el ID objetivo
		get_tree().call_group("puertas_mapa", "verificar_y_abrir", target_id)
		
	else:
		print("El pedestal emite un zumbido vacío. Necesitas la ", llave_requerida)
