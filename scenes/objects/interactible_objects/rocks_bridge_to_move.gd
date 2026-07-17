extends InteractableItem

@export var puerta_id: String = "RockBridgeForest" 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1. Buscamos la malla recursivamente ANTES de llamar al padre
	mesh = _buscar_mesh_recursivo(self)
	
	# 2. Ahora sí, llamamos de forma segura al _ready() del padre
	super._ready()
	
	se_puede_recoger = false
	add_to_group("RockBridgeForest")

func levantar_puente():
	print("Puente levantado")
	#Posicion inicial = x = -48 y = -4 z = -241
	var nodo_a_mover = $"."
	var posicion_final = Vector3(nodo_a_mover.global_position.x, 0, nodo_a_mover.global_position.z)
	var tiempo_levantar = 3
	var tween_puente = create_tween()
	tween_puente.tween_property(nodo_a_mover, "global_position", posicion_final, tiempo_levantar).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func verificar_y_levantar(id_recibido: String) -> void:
	if puerta_id == id_recibido:
		levantar_puente()

# --- FUNCIÓN AUXILIAR: BUSCADOR RECURSIVO DE MALLAS ---
# Busca hacia adentro de cualquier jerarquía de nodos hasta encontrar el primer MeshInstance3D
func _buscar_mesh_recursivo(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo
	for hijo in nodo.get_children():
		var encontrado = _buscar_mesh_recursivo(hijo)
		if encontrado != null:
			return encontrado
	return null
