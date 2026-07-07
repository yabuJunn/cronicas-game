extends InteractableItem

# Asigna aquí tu nodo GPUParticles3D desde el Inspector
@onready var particulas_polvo: GPUParticles3D = $"../../Polvo Puerta"
@onready var fog_particulas: FogVolume = $"../../Polvo Puerta/Polvo Fog"
@onready var stoneMovingAudio3D: AudioStreamPlayer3D = $"../../Polvo Puerta/AudioStreamPlayer3D"

# --- CONFIGURACIÓN DEL POLVO ---
@export var polvo_offset_y: float = 10   # Margen de seguridad para que el polvo no aparezca abajo del suelo
@export var alto_neblina: float = 3.0     # Qué tan alto (en metros) subirá la nube de FogVolume

# --- CONFIGURACIÓN DE LA NIEBLA (FOG) ---
@export var densidad_max_niebla: float = 1.5  # Qué tan densa/oscura será la nube de polvo
@export var tiempo_entrada_niebla: float = 5   # Cuánto tardará en aparecer la niebla por completo

# --- CONFIGURACIÓN DEL AUDIO ---
@export var volumen_max_audio: float = 0.0     # Volumen ideal cuando la puerta se mueve (en decibelios)
@export var tiempo_fade_audio: float = 0.75    # Duración de las transiciones de entrada y salida del sonido

# --- CONFIGURACIÓN DEL TEMBLOR (SHADER) ---
@export var shader_temblor: Shader = preload("res://shaders/spatialShakingTrenchbroom.gdshader")
@export var tiempo_fade_temblor: float = 0.4   # Cuánto tarda en empezar y dejar de vibrar suavemente el bloque
var material_shader_puerta: ShaderMaterial = null

# El nombre exacto de la llave que abre esta puerta
@export var llave_requerida: String = "Llave"

# --- CONFIGURACIÓN DE LA ANIMACIÓN ---
@export var distancia_bajada: float = 21.0   # Cuántos metros bajará la puerta
@export var tiempo_apertura: float = 4.0    # Cuánto tardará en bajarse (en segundos)

# --- MENSAJES PERSONALIZADOS PARA LA INTERFAZ ---
@export var texto_cerrada: String = "La puerta está cerrada."
@export var texto_con_llave: String = "Abrir puerta"

# PROPIEDAD DINÁMICA: El texto cambia según el inventario
var texto_interaccion: String:
	get:
		if Inventory.tiene_objeto(llave_requerida):
			return "[ E ] " + texto_con_llave
		else:
			return texto_cerrada

# Array dinámico para guardar las colisiones
var colisiones: Array[CollisionShape3D] = []
var esta_abriendose: bool = false

func _ready() -> void:
	# Buscamos automáticamente la malla y las colisiones
	for hijo in get_children():
		if hijo is CollisionShape3D:
			colisiones.append(hijo)
		elif hijo is MeshInstance3D and mesh == null:
			mesh = hijo

	super._ready()
	se_puede_recoger = false

	# Fusionamos el material de TrenchBroom con nuestro Shader de temblor
	preparar_material_shader()


func preparar_material_shader() -> void:
	if shader_temblor == null:
		print("ADVERTENCIA: No has asignado el archivo .gdshader en el slot 'shader_temblor' de la puerta.")
		return

	if mesh and mesh is MeshInstance3D:
		# 1. Obtenemos el material original con texturas generado por TrenchBroom
		var mat_trenchbroom = mesh.material_override if mesh.material_override else mesh.get_active_material(0)
		
		if mat_trenchbroom and (mat_trenchbroom is StandardMaterial3D or mat_trenchbroom is ORMMaterial3D):
			# 2. Creamos un contenedor ShaderMaterial vacío en tiempo de ejecución
			var nuevo_material_combinado = ShaderMaterial.new()
			nuevo_material_combinado.shader = shader_temblor
			
			# 3. EXTRAER TEXTURAS: Si el material de TrenchBroom tiene textura albedo, se la pasamos al Shader
			if mat_trenchbroom.albedo_texture != null:
				nuevo_material_combinado.set_shader_parameter("albedo_tex", mat_trenchbroom.albedo_texture)
			
			# También copiamos el color base por si acaso
			nuevo_material_combinado.set_shader_parameter("albedo_color", mat_trenchbroom.albedo_color)
			
			# 4. Nos aseguramos de que empiece completamente quieta
			nuevo_material_combinado.set_shader_parameter("progress", 0.0)
			
			# 5. Aplicamos el nuevo material híbrido a la malla
			mesh.material_override = nuevo_material_combinado
			material_shader_puerta = nuevo_material_combinado


func interactuar() -> void:
	if esta_abriendose:
		return

	if Inventory.tiene_objeto(llave_requerida):
		print("¡Puerta abierta con éxito usando: ", llave_requerida, "!")
		Inventory.remover_objeto(llave_requerida)
		
		# ¡Preparamos y encendemos el polvo y el fog!
		crear_polvo_en_base()
		
		iniciar_animacion_apertura()
	else:
		print("La puerta está cerrada. Necesitas: ", llave_requerida)


# --- SISTEMA DE POLVO Y FOG DINÁMICO ---
func crear_polvo_en_base() -> void:
	print("Inicio de crear_polvo_en_base()")
	if particulas_polvo == null:
		print("ADVERTENCIA: No has asignado el nodo particulas_polvo en el Inspector.")
		return
		
	if mesh == null or mesh.mesh == null:
		return

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
				tween_entrada.tween_property(fog_particulas.material, "shader_parameter/density", densidad_max_niebla, tiempo_entrada_niebla)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_OUT)
			elif fog_particulas.material is FogMaterial:
				fog_particulas.material.density = 0.0
				tween_entrada.tween_property(fog_particulas.material, "density", densidad_max_niebla, tiempo_entrada_niebla)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_OUT)

	particulas_polvo.emitting = true
	particulas_polvo.restart() 
	print("Polvo y Fog activados correctamente.")


func iniciar_animacion_apertura() -> void:
	esta_abriendose = true
	
	remove_from_group("interactibleObjects")
	set_highlight(false)
	
	for colision in colisiones:
		if is_instance_valid(colision):
			colision.disabled = true
			
	var nodo_a_mover = get_parent() if get_parent() != null else self
	var posicion_final = nodo_a_mover.global_position + Vector3(0, -distancia_bajada, 0)
	
	var tween_puerta = create_tween()
	
	tween_puerta.tween_property(nodo_a_mover, "global_position", posicion_final, tiempo_apertura)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# CONTROL DEL SHADER DE TEMBLOR (En paralelo con el movimiento)
	if material_shader_puerta != null:
		tween_puerta.parallel().tween_property(material_shader_puerta, "shader_parameter/progress", 1.0, tiempo_fade_temblor)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		
		var retraso_Detener_temblor = tiempo_apertura - tiempo_fade_temblor
		if retraso_Detener_temblor > 0:
			tween_puerta.parallel().tween_property(material_shader_puerta, "shader_parameter/progress", 0.0, tiempo_fade_temblor)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN)\
				.set_delay(retraso_Detener_temblor)

	# CONTROL DEL AUDIO
	if is_instance_valid(stoneMovingAudio3D):
		stoneMovingAudio3D.volume_db = -80.0
		stoneMovingAudio3D.play()
		
		tween_puerta.parallel().tween_property(stoneMovingAudio3D, "volume_db", volumen_max_audio, tiempo_fade_audio)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		
		var retraso_fade_out = tiempo_apertura - tiempo_fade_audio
		if retraso_fade_out > 0:
			tween_puerta.parallel().tween_property(stoneMovingAudio3D, "volume_db", -80.0, tiempo_fade_audio)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN)\
				.set_delay(retraso_fade_out)
	
	tween_puerta.tween_callback(func():
		if is_instance_valid(stoneMovingAudio3D):
			stoneMovingAudio3D.stop()
			
		if material_shader_puerta != null:
			material_shader_puerta.set_shader_parameter("progress", 0.0)
			
		if is_instance_valid(particulas_polvo):
			particulas_polvo.emitting = false 
			
			var cleanup_tween = create_tween()
			var tiempo_desaparicion = particulas_polvo.lifetime
			
			if is_instance_valid(fog_particulas) and fog_particulas.material:
				if fog_particulas.material is ShaderMaterial:
					cleanup_tween.tween_property(fog_particulas.material, "shader_parameter/density", 0.0, tiempo_desaparicion)\
						.set_trans(Tween.TRANS_SINE)\
						.set_ease(Tween.EASE_IN)
				elif fog_particulas.material is FogMaterial:
					cleanup_tween.tween_property(fog_particulas.material, "density", 0.0, tiempo_desaparicion)\
						.set_trans(Tween.TRANS_SINE)\
						.set_ease(Tween.EASE_IN)
			
			var p_polvo = particulas_polvo
			var n_mover = nodo_a_mover
			
			cleanup_tween.tween_callback(func():
				if is_instance_valid(p_polvo):
					p_polvo.queue_free()
				if is_instance_valid(n_mover):
					n_mover.queue_free()
				print("Efectos finalizados y nodos liberados.")
			)
		else:
			nodo_a_mover.queue_free()
	)
