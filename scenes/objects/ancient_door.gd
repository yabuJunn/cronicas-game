extends InteractableItem
class_name OpenableAncientDoor

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
		
	# Si ya se levantó antes, aparece arriba al instante sin repetir la animación
	if SaveManager and SaveManager.get_flag(SaveManager.generar_clave_nodo("puente", self), false):
		ya_levantado = true
		global_position = posicion_inicial + Vector3(0.0, altura_levantar, 0.0)


func levantar_puente() -> void:
	if ya_levantado:
		return
	ya_levantado = true

	if SaveManager:
		SaveManager.set_flag(SaveManager.generar_clave_nodo("puente", self), true)

	var posicion_final = posicion_inicial + Vector3(0.0, altura_levantar, 0.0)
	var tween_puente = create_tween()
	tween_puente.tween_property(self, "global_position", posicion_final, tiempo_levantar)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)


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
