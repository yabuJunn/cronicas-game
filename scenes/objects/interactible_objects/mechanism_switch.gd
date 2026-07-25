extends InteractableItem

# MechanismSwitchPedestal

# --- CONFIGURACIÓN DE CINEMÁTICA Y TARGET ---
@export_group("Configuración Específica del Mecanismo")
@export var tiempo_escena: float = 6.0
# 'targetname' del marcador de cámara en el mapa
@export var camera_marker_id: String = "RockBridgeMarker" 
# Grupo/ID de la puerta o puente que se levantará
@export var target_id: String 

# --- REFERENCIAS INTERNAS ---
@onready var placedEnergySphere: StaticBody3D = $EnergySphere
var energySphereAudio: AudioStreamPlayer3D

var ya_activado: bool = false


func _ready() -> void:
	
	# Configuración de variables heredadas de InteractableItem (Valores por defecto)
	se_puede_recoger = false
	es_puerta = true
	
	if item_clave_requerido == "":
		item_clave_requerido = "Esfera de Energía"
	if texto_con_objeto == "":
		texto_con_objeto = "[ E ] Activar artefacto misterioso"
	if texto_sin_objeto == "":
		texto_sin_objeto = "Falta llave"

	super._ready()
	_preparar_esfera_y_audio()


func _preparar_esfera_y_audio() -> void:
	_obtener_audio_esfera()
	
	if placedEnergySphere:
		# 1. Sacamos la esfera del grupo para evitar interacciones directas con ella
		if placedEnergySphere.is_in_group("interactibleObjects"):
			placedEnergySphere.remove_from_group("interactibleObjects")
		
		# 2. Desactivamos colisiones para que el Raycast la ignore
		placedEnergySphere.collision_layer = 0
		placedEnergySphere.collision_mask = 0
		
		# 3. Quitamos el material overlay para evitar problemas con el outline
		if placedEnergySphere.mesh:
			placedEnergySphere.mesh.material_overlay = null
			
		placedEnergySphere.visible = false

	if energySphereAudio:
		energySphereAudio.playing = false
	else:
		print("Error en energySphereAudio: ", energySphereAudio)


# --- SOBREESCRITURA DE TEXTOS DE INTERACCIÓN ---
func _obtener_texto_interaccion() -> String:
	if ya_activado:
		return "El interruptor ya ha sido activado"
		
	if Inventory.tiene_objeto(item_clave_requerido):
		outline_habilitado = true
		return texto_con_objeto
	else:
		outline_habilitado = false
		return texto_sin_objeto

# --- LÓGICA DE INTERACCIÓN ---
func interactuar() -> void:
	if ya_activado:
		return

	if item_clave_requerido != "" and not Inventory.tiene_objeto(item_clave_requerido):
		return

	ya_activado = true
	Inventory.remover_objeto(item_clave_requerido)
	
	if placedEnergySphere:
		placedEnergySphere.visible = true
	if energySphereAudio:
		energySphereAudio.playing = true
		
	set_highlight(false)
	outline_habilitado = false
	
	if is_in_group("interactibleObjects"):
		remove_from_group("interactibleObjects")
		
	# --- DISPARAR CINEMÁTICA EN EL JUGADOR ---
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador and camera_marker_id != "":
		var marcador = _buscar_por_id(camera_marker_id)
		if marcador:
			jugador.ejecutar_cinematica(marcador.global_transform, tiempo_escena)
		else:
			push_warning("Advertencia: No se encontró ningún CinemaMarker con el ID: ", camera_marker_id)
		
	# --- CONEXIÓN AUTOMÁTICA CON EL TARGET ---
	if target_id != "":
		get_tree().call_group(target_id, "open", target_id)
	else:
		push_warning("Advertencia: target_id no está configurado en el switch.")

# --- FUNCIÓN AUXILIAR PARA BUSCAR EL MARCADOR EN EL MAPA ---
func _buscar_por_id(id_buscado: String) -> Marker3D:
	var marcadores = get_tree().get_nodes_in_group("cinemaMarkers")
	for marcador in marcadores:
		if "targetname" in marcador and marcador.targetname == id_buscado:
			return marcador
		elif "id" in marcador and marcador.id == id_buscado:
			return marcador
	return null


func _obtener_audio_esfera() -> void:
	if placedEnergySphere:
		for child in placedEnergySphere.get_children():
			if child is AudioStreamPlayer3D:
				energySphereAudio = child
				break
