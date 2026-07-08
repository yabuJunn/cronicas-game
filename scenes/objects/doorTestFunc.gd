extends InteractableItem

@export var musica_evento_puerta: AudioStream # Canción de suspenso / apertura
@export var musica_ambiente_siguiente: AudioStream # La música que se quedará después

@export var puerta_id: String = "puerta_principal"

# Asigna aquí tu nodo GPUParticles3D desde el Inspector
@onready var particulas_polvo: GPUParticles3D = $"../../Polvo Puerta"
@onready var fog_particulas: FogVolume = $"../../Polvo Puerta/Polvo Fog"
@onready var stoneMovingAudio3D: AudioStreamPlayer3D = $"../../Polvo Puerta/AudioStreamPlayer3D"

# --- CONFIGURACIÓN DEL POLVO ---
@export var polvo_offset_y: float = 10   
@export var alto_neblina: float = 3.0     

# --- CONFIGURACIÓN DE LA NIEBLA (FOG) ---
@export var densidad_max_niebla: float = 1.5  
@export var tiempo_entrada_niebla: float = 5   

# --- CONFIGURACIÓN DEL AUDIO ---
@export var volumen_max_audio: float = 0.0     
@export var tiempo_fade_audio: float = 0.75    

# --- CONFIGURACIÓN DEL TEMBLOR (SHADER) ---
@export var shader_temblor: Shader = preload("res://shaders/spatialShakingTrenchbroom.gdshader")
@export var tiempo_fade_temblor: float = 0.4   
var material_shader_puerta: ShaderMaterial = null

# --- CONFIGURACIÓN DE LA ANIMACIÓN ---
@export var distancia_bajada: float = 21.0   
@export var tiempo_apertura: float = 4.0    

# --- TEXTO SI EL JUGADOR MIRA LA PUERTA ---
# Reemplaza el bloque conflictivo por esta función:
func _obtener_texto_interaccion() -> String:
	return "La puerta está sellada pesadamente. Requiere energía."
	
var colisiones: Array[CollisionShape3D] = []
var esta_abriendose: bool = false

func _ready() -> void:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			colisiones.append(hijo)
		elif hijo is MeshInstance3D and mesh == null:
			mesh = hijo

	super._ready()
	se_puede_recoger = false
	preparar_material_shader()
	add_to_group("puertas_mapa")

func preparar_material_shader() -> void:
	if shader_temblor == null: return

	if mesh and mesh is MeshInstance3D:
		var mat_trenchbroom = mesh.material_override if mesh.material_override else mesh.get_active_material(0)
		if mat_trenchbroom and (mat_trenchbroom is StandardMaterial3D or mat_trenchbroom is ORMMaterial3D):
			var nuevo_material_combinado = ShaderMaterial.new()
			nuevo_material_combinado.shader = shader_temblor
			if mat_trenchbroom.albedo_texture != null:
				nuevo_material_combinado.set_shader_parameter("albedo_tex", mat_trenchbroom.albedo_texture)
			nuevo_material_combinado.set_shader_parameter("albedo_color", mat_trenchbroom.albedo_color)
			nuevo_material_combinado.set_shader_parameter("progress", 0.0)
			mesh.material_override = nuevo_material_combinado
			material_shader_puerta = nuevo_material_combinado

# Si el jugador interactúa directamente con la puerta física
func interactuar() -> void:
	print("No puedes abrir esta puerta empujándola. Busca un mecanismo.")

# --- FUNCIÓN PÚBLICA: El pedestal llamará a esto ---
func abrir_puerta() -> void:
	# Detiene la playa, toca el evento, y cuando acabe el evento, pondrá la música ambiente siguiente
	MusicManager.reproducir_temporal(musica_evento_puerta, musica_ambiente_siguiente)
	
	if esta_abriendose:
		return
		
	print("Recibida señal del pedestal. Iniciando apertura de puerta...")
	crear_polvo_en_base()
	iniciar_animacion_apertura()

# --- SISTEMA DE POLVO Y FOG DINÁMICO ---
func crear_polvo_en_base() -> void:
	if particulas_polvo == null or mesh == null or mesh.mesh == null: return

	var aabb: AABB = mesh.mesh.get_aabb()
	var escala_global = mesh.global_transform.basis.get_scale()
	var ancho_real = aabb.size.x * escala_global.x
	var profundidad_real = aabb.size.z * escala_global.z
	var alto_real = aabb.size.y * escala_global.y

	var posicion_base = mesh.global_position + Vector3(0, -(alto_real / 2.0) + polvo_offset_y, 0)
	particulas_polvo.global_position = posicion_base
	particulas_polvo.force_update_transform() 

	if particulas_polvo.process_material is ParticleProcessMaterial:
		particulas_polvo.process_material.emission_box_extents = Vector3(ancho_real / 2.0, 0.1, profundidad_real / 2.0)

	if fog_particulas:
		fog_particulas.visible = true
		fog_particulas.size = Vector3(ancho_real, alto_neblina, profundidad_real)
		if fog_particulas.material:
			fog_particulas.material = fog_particulas.material.duplicate()
			var tween_entrada = create_tween()
			if fog_particulas.material is ShaderMaterial:
				fog_particulas.material.set_shader_parameter("density", 0.0) 
				tween_entrada.tween_property(fog_particulas.material, "shader_parameter/density", densidad_max_niebla, tiempo_entrada_niebla).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			elif fog_particulas.material is FogMaterial:
				fog_particulas.material.density = 0.0
				tween_entrada.tween_property(fog_particulas.material, "density", densidad_max_niebla, tiempo_entrada_niebla).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	particulas_polvo.emitting = true
	particulas_polvo.restart() 

func iniciar_animacion_apertura() -> void:
	esta_abriendose = true
	if is_in_group("interactibleObjects"):
		remove_from_group("interactibleObjects")
	set_highlight(false)
	
	for colision in colisiones:
		if is_instance_valid(colision): colision.disabled = true
			
	var nodo_a_mover = get_parent() if get_parent() != null else self
	var posicion_final = nodo_a_mover.global_position + Vector3(0, -distancia_bajada, 0)
	var tween_puerta = create_tween()
	
	tween_puerta.tween_property(nodo_a_mover, "global_position", posicion_final, tiempo_apertura).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	if material_shader_puerta != null:
		tween_puerta.parallel().tween_property(material_shader_puerta, "shader_parameter/progress", 1.0, tiempo_fade_temblor).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var retraso_Detener_temblor = tiempo_apertura - tiempo_fade_temblor
		if retraso_Detener_temblor > 0:
			tween_puerta.parallel().tween_property(material_shader_puerta, "shader_parameter/progress", 0.0, tiempo_fade_temblor).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(retraso_Detener_temblor)

	if is_instance_valid(stoneMovingAudio3D):
		stoneMovingAudio3D.volume_db = 15
		stoneMovingAudio3D.play()
		tween_puerta.parallel().tween_property(stoneMovingAudio3D, "volume_db", volumen_max_audio, tiempo_fade_audio).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var retraso_fade_out = tiempo_apertura - tiempo_fade_audio
		if retraso_fade_out > 0:
			tween_puerta.parallel().tween_property(stoneMovingAudio3D, "volume_db", -80.0, tiempo_fade_audio).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(retraso_fade_out)
	
	tween_puerta.tween_callback(func():
		if is_instance_valid(stoneMovingAudio3D): stoneMovingAudio3D.stop()
		if material_shader_puerta != null: material_shader_puerta.set_shader_parameter("progress", 0.0)
			
		if is_instance_valid(particulas_polvo):
			particulas_polvo.emitting = false 
			var cleanup_tween = create_tween()
			var tiempo_desaparicion = particulas_polvo.lifetime
			
			if is_instance_valid(fog_particulas) and fog_particulas.material:
				if fog_particulas.material is ShaderMaterial:
					cleanup_tween.tween_property(fog_particulas.material, "shader_parameter/density", 0.0, tiempo_desaparicion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				elif fog_particulas.material is FogMaterial:
					cleanup_tween.tween_property(fog_particulas.material, "density", 0.0, tiempo_desaparicion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
			var p_polvo = particulas_polvo
			var n_mover = nodo_a_mover
			cleanup_tween.tween_callback(func():
				if is_instance_valid(p_polvo): p_polvo.queue_free()
				if is_instance_valid(n_mover): n_mover.queue_free()
			)
		else:
			nodo_a_mover.queue_free()
	)

# El pedestal llamará a esto automáticamente por código
func verificar_y_abrir(id_recibido: String) -> void:
	if puerta_id == id_recibido:
		abrir_puerta()
