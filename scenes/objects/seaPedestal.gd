extends InteractableItem

# Pedestal

var energy_sphere: PackedScene = preload("res://scenes/objects/energy_sphere.tscn")

# --- CONFIGURACIÓN CINEMÁTICA (ADAPTADA A FUNC_GODOT) ---
@export var tiempo_escena: float = 6
# Escribe aquí el 'targetname' del marcador de cámara que pusiste en el mapa
@export var camera_marker_id: String = "Door" 

# --- CONFIGURACIÓN DE ACTIVACIÓN ---
@export_group("Configuración de Activación")
@export var llave_requerida: String = "Esfera de Energía"
@export var target_id: String = "puerta_principal" 

@export var texto_sin_llave: String = "Falta la Esfera de Energía."
@export var texto_con_llave: String = "Colocar Esfera de Energía"

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
			
		# --- NUEVO: ACTIVAR EFECTO DE ENERGÍA ---
		aplicar_shader_energia()
		
		# --- DISPARAR CINEMÁTICA AUTOMÁTICA EN EL JUGADOR ---
		var jugador = get_tree().get_first_node_in_group("player")
		if jugador and camera_marker_id != "":
			var marcador = _buscar_por_id(camera_marker_id)
			if marcador:
				jugador.ejecutar_cinematica(marcador.global_transform, tiempo_escena)
			else:
				push_warning("Advertencia: No se encontró ningún CinemaMarker con el ID: ", camera_marker_id)

		# --- INSTANCIAR LA ESFERA VISUAL ---
		if energy_sphere:
			var nueva_esfera = energy_sphere.instantiate()
			add_child(nueva_esfera)
			
			nueva_esfera.position = esfera_offset_posicion
			
			if "se_puede_recoger" in nueva_esfera:
				nueva_esfera.se_puede_recoger = false
			if nueva_esfera.has_method("set_highlight"):
				nueva_esfera.set_highlight(false)
			if nueva_esfera.is_in_group("interactibleObjects"):
				nueva_esfera.remove_from_group("interactibleObjects")
			
			desactivar_colisiones_recursivo(nueva_esfera)
		
		# --- CONEXIÓN AUTOMÁTICA CON LA PUERTA ---
		get_tree().call_group("puertas_mapa", "verificar_y_abrir", target_id)
		
	else:
		print("El pedestal emite un zumbido vacío. Necesitas la ", llave_requerida)

# --- FUNCIÓN AUXILIAR PARA BUSCAR EL MARCADOR EN EL MAPA ---
func _buscar_por_id(id_buscado: String) -> Marker3D:
	var marcadores = get_tree().get_nodes_in_group("cinemaMarkers")
	for marcador in marcadores:
		if "targetname" in marcador and marcador.targetname == id_buscado:
			return marcador
		elif "id" in marcador and marcador.id == id_buscado:
			return marcador
	return null

# Función auxiliar para apagar cualquier CollisionShape3D dentro de la esfera colocada
func desactivar_colisiones_recursivo(nodo: Node) -> void:
	if nodo is CollisionShape3D:
		nodo.disabled = true
	for hijo in nodo.get_children():
		desactivar_colisiones_recursivo(hijo)

# --- NUEVO: CREACIÓN DINÁMICA DEL SHADER DE ENERGÍA ---
func aplicar_shader_energia() -> void:
	if not mesh:
		return
		
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode blend_add, unshaded, depth_draw_never;

	// El color exacto #4bc1c2 convertido a valores RGB de Godot
	uniform vec4 color_energia : source_color = vec4(0.294, 0.757, 0.761, 1.0);
	uniform float velocidad_pulso = 2.5;
	uniform float potencia_fresnel = 3.0;

	void fragment() {
		// Efecto Fresnel: Brillo dominante en los bordes de la geometría
		float fresnel = pow(1.0 - dot(NORMAL, VIEW), potencia_fresnel);
		
		// Pulsación matemática usando el tiempo interno del motor
		float pulso = mix(0.15, 0.55, sin(TIME * velocidad_pulso) * 0.5 + 0.5);
		
		// Combinamos una base de tinte leve (0.2) con el brillo del borde (fresnel)
		vec3 brillo_final = color_energia.rgb * (fresnel * 0.8 + 0.2) * pulso;
		
		ALBEDO = brillo_final;
	}
	"""
	
	var material_shader = ShaderMaterial.new()
	material_shader.shader = shader
	
	# Se aplica como overlay para conservar intactas las texturas y materiales inferiores
	mesh.material_overlay = material_shader
