extends InteractableItem

# Asegúrate de que coincida con el target_id del switch
@export var puerta_id: String = ""


func _ready() -> void:
	# 1. Buscamos la malla recursivamente ANTES de llamar al padre
	mesh = _buscar_mesh_recursivo(self)
	
	# 2. Llamamos al ready del padre
	super._ready()
	
	se_puede_recoger = false
	
	# Nos unimos dinámicamente al grupo definido por puerta_id
	if puerta_id != "":
		add_to_group(puerta_id)


func levantar_puente() -> void:
	print("Levantando puente...")
	var nodo_a_mover = self
	var posicion_final = Vector3(nodo_a_mover.global_position.x, 0, nodo_a_mover.global_position.z)
	var tiempo_levantar = 3.0
	
	var tween_puente = create_tween()
	tween_puente.tween_property(nodo_a_mover, "global_position", posicion_final, tiempo_levantar)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)


# Método estándar llamado por cualquier MechanismSwitch
func open(id_recibido: String = "") -> void:
	print("open() ejecutado con éxito en: ", name, id_recibido)
	levantar_puente()


# --- FUNCIÓN AUXILIAR: BUSCADOR RECURSIVO DE MALLAS ---
func _buscar_mesh_recursivo(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo
	for hijo in nodo.get_children():
		var encontrado = _buscar_mesh_recursivo(hijo)
		if encontrado != null:
			return encontrado
	return null
