extends InteractableItem

# RockBridgeSwitch

# --- CONFIGURACIÓN CINEMÁTICA (ADAPTADA A FUNC_GODOT) ---
@export var tiempo_escena: float = 6
# Escribe aquí el 'targetname' del marcador de cámara que pusiste en el mapa
@export var camera_marker_id: String = "RockBridgeMarker" 

# --- CONFIGURACIÓN DE ACTIVACIÓN ---
@export_group("Configuración de Activación")
@export var llave_requerida: String = "Esfera de Energía"
@export var target_id: String = "RockBridgeForest" 

@export var texto_sin_llave: String = "Falta llave"
@export var texto_con_llave: String = "Activar artefacto misterioso"

@onready var placedEnergySphere: StaticBody3D = $EnergySphere
var energySphereAudio: AudioStreamPlayer3D

var ya_activado: bool = false

func _obtener_texto_interaccion() -> String:
	if ya_activado:
		return "El interruptor ya ha sido activado"
	if Inventory.tiene_objeto(llave_requerida):
		outline_habilitado = true
		return "[ E ] activar"
	else:
		outline_habilitado = false
		return "No tienes nada que parezca activar esto"

func _ready() -> void:
	print(self, ": Rocks Bridge Switch")
	super._ready() 
	getEnergySphereAudio()
	se_puede_recoger = false
	
	if placedEnergySphere:
		# 1. La sacamos del grupo para que el script del jugador no la tome en cuenta
		if placedEnergySphere.is_in_group("interactibleObjects"):
			placedEnergySphere.remove_from_group("interactibleObjects")
		
		# 2. Apagamos sus capas de colisión (así el Raycast pasa de largo como si fuera aire)
		placedEnergySphere.collision_layer = 0
		placedEnergySphere.collision_mask = 0
		
		# 3. Le borramos el material overlay para que el shader de outline no actúe jamás
		if placedEnergySphere.mesh:
			placedEnergySphere.mesh.material_overlay = null
	
	placedEnergySphere.visible = false
	if energySphereAudio:
		energySphereAudio.playing = false
	else:
		print("Error on sphereAudio: ", energySphereAudio)
	

func interactuar() -> void:
	if ya_activado:
		return

	ya_activado = true
	Inventory.remover_objeto(llave_requerida)
	placedEnergySphere.visible = true
	energySphereAudio.playing = true
		
	set_highlight(false)
	if is_in_group("interactibleObjects"):
		remove_from_group("interactibleObjects")
		
	# --- DISPARAR CINEMÁTICA AUTOMÁTICA EN EL JUGADOR ---
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador and camera_marker_id != "":
		var marcador = _buscar_por_id(camera_marker_id)
		if marcador:
			jugador.ejecutar_cinematica(marcador.global_transform, tiempo_escena)
		else:
			push_warning("Advertencia: No se encontró ningún CinemaMarker con el ID: ", camera_marker_id)
		
		# --- CONEXIÓN AUTOMÁTICA CON LA PUERTA ---
		get_tree().call_group("RockBridgeForest", "verificar_y_levantar", target_id)

# --- FUNCIÓN AUXILIAR PARA BUSCAR EL MARCADOR EN EL MAPA ---
func _buscar_por_id(id_buscado: String) -> Marker3D:
	var marcadores = get_tree().get_nodes_in_group("cinemaMarkers")
	for marcador in marcadores:
		if "targetname" in marcador and marcador.targetname == id_buscado:
			return marcador
		elif "id" in marcador and marcador.id == id_buscado:
			return marcador
	return null

func getEnergySphereAudio():
	for child in $EnergySphere.get_children():
		if child is AudioStreamPlayer3D:
			energySphereAudio = child
