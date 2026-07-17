extends InteractableItem

# RockBridgeSwitch

# --- CONFIGURACIÓN CINEMÁTICA (ADAPTADA A FUNC_GODOT) ---
@export var tiempo_escena: float = 6
# Escribe aquí el 'targetname' del marcador de cámara que pusiste en el mapa
@export var camera_marker_id: String = "RockBridgeMarker" 

# --- CONFIGURACIÓN DE ACTIVACIÓN ---
@export_group("Configuración de Activación")
@export var llave_requerida: String = "EnergyBattery"
@export var target_id: String = "RockBridgeForest" 

@export var texto_sin_llave: String = "Falta llave"
@export var texto_con_llave: String = "Activar artefacto misterioso"

@onready var ligthBulb: MeshInstance3D = $LigthBulb
@onready var omniLight: OmniLight3D = $LigthBulb/OmniLight3D
@onready var particles: GPUParticles3D = $LigthBulb/OmniLight3D/GPUParticles3D
var ya_activado: bool = false
var material_bombilla: StandardMaterial3D

func _obtener_texto_interaccion() -> String:
	if ya_activado:
		return "El interruptor ya ha sido activado"
	else:
		return "[ E ] activar" 

func _ready() -> void:
	print(self, ": Rocks Bridge Switch")
	super._ready() 
	se_puede_recoger = false
	material_bombilla = ligthBulb.get_active_material(0)
	material_bombilla.emission_enabled = false
	material_bombilla.albedo_color = "#FFFFFF"
	omniLight.visible = false
	particles.emitting = false

func interactuar() -> void:
	if ya_activado:
		return
	
	

	ya_activado = true
	#Inventory.remover_objeto(llave_requerida)
		
	material_bombilla.emission_enabled = true
	material_bombilla.albedo_color = "#4bc1c2"
	omniLight.visible = true
	particles.emitting = true
		
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
