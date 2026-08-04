extends InteractableItem

# OpenableHouseDoor (InteractableItem)

@export_group("Configuración de Puerta")
@export var puerta_id: String = ""
@export var angulo_apertura_grados: float = 90.0 # Usa valor positivo o negativo según hacia dónde deba abrir
@export var animationTime: float = 1.5

@onready var lock_static_body: StaticBody3D = $Lock

var isOpen: bool = false
var animationPlayed: bool = false


func _ready() -> void:
	# Configuramos los parámetros de la clase base antes de su _ready()
	se_puede_recoger = false
	es_puerta = true
	
	super._ready()
	
	# Nos unimos dinámicamente al grupo definido por puerta_id
	if puerta_id != "":
		add_to_group(puerta_id)
	else:
		push_warning("Advertencia: puerta_id no asignado en la puerta: ", name)


# Sobrescribimos la interacción del objeto
func interactuar() -> bool:
	if isOpen or animationPlayed:
		return false

	# 1. Verificamos si requiere llave y si el jugador la tiene en su inventario
	if item_clave_requerido != "":
		if Inventory.has_method("tiene_objeto") and Inventory.tiene_objeto(item_clave_requerido):
			Inventory.remover_objeto(item_clave_requerido)
		else:
			return false # No tiene la llave, se cancela la interacción

	# 2. Si tiene la llave (o no requería), notificamos a todos los nodos con este puerta_id
	if puerta_id != "":
		get_tree().call_group(puerta_id, "open", puerta_id)
	else:
		open("")
		
	return false


# Método estándar llamado mediante call_group()
func open(id_recibido: String = "") -> void:
	# 1. Validaciones para evitar llamadas erróneas o repetidas
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if animationPlayed or isOpen:
		return

	animationPlayed = true
	isOpen = true
	
	# Desactivamos interacción y contornos en la puerta
	set_highlight(false)
	outline_habilitado = false
	es_puerta = false 

	# 2. Eliminamos el nodo del candado ($Lock)
	if lock_static_body and is_instance_valid(lock_static_body):
		lock_static_body.queue_free()

	# 3. Animación de apertura de 90 grados
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:y", rotation_degrees.y + angulo_apertura_grados, animationTime)
