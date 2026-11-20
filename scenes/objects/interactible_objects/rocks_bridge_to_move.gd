extends InteractableItem
class_name MovableBridge

# Asegúrate de que coincida con el target_id del switch
@export var puerta_id: String = ""

@export_group("Configuración de Movimiento")
@export var altura_levantar: float = 3.0 # Metros que subirá respecto a su posición original
@export var tiempo_levantar: float = 3.0 # Segundos que tarda en subir

var posicion_inicial: Vector3
var ya_levantado: bool = false


func _ready() -> void:
	# 1. Buscamos la malla recursivamente ANTES de llamar al padre
	mesh = _buscar_mesh_recursivo(self)
	
	# 2. Llamamos al ready del padre
	super._ready()
	
	se_puede_recoger = false
	posicion_inicial = global_position
	
	# Nos unimos dinámicamente al grupo definido por puerta_id
	if puerta_id != "":
		add_to_group(puerta_id)


func levantar_puente() -> void:
	if ya_levantado:
		return
	ya_levantado = true
	
	var posicion_final = posicion_inicial + Vector3(0.0, altura_levantar, 0.0)
	print("Levantando puente [", name, "] | Posición inicial: ", posicion_inicial, " -> Posición destino: ", posicion_final)
	
	var tween_puente = create_tween()
	tween_puente.tween_property(self, "global_position", posicion_final, tiempo_levantar)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
		
	tween_puente.tween_callback(func():
		print("Puente [", name, "] levantado por completo. Posición final: ", global_position)
	)


# Método estándar llamado por cualquier MechanismSwitch
func open(id_recibido: String = "") -> void:
	print("open() ejecutado con éxito en: ", name, " | ID: ", id_recibido)
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
