extends InteractableItem

# Asigna aquí tu nodo GPUParticles3D desde el Inspector
@onready var particulas_polvo: GPUParticles3D = $"../../Polvo Puerta"
@onready var fog_particulas: FogVolume = $"../../Polvo Puerta/Polvo Fog"

# --- CONFIGURACIÓN DEL POLVO ---
@export var polvo_offset_y: float = 10   # Margen de seguridad para que el polvo no aparezca abajo del suelo
@export var alto_neblina: float = 3.0     # Qué tan alto (en metros) subirá la nube de FogVolume

# --- CONFIGURACIÓN DE LA NIEBLA (FOG) ---
@export var densidad_max_niebla: float = 1.5  # Qué tan densa/oscura será la nube de polvo (Tu shader usa 0.99 por defecto)
@export var tiempo_entrada_niebla: float = 5 # Cuánto tardará en aparecer la niebla por completo

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

	# 1. Calculamos las dimensiones de la puerta usando su caja de colisión/malla (AABB)
	var aabb: AABB = mesh.mesh.get_aabb()
	var escala_global = mesh.global_transform.basis.get_scale()
	var ancho_real = aabb.size.x * escala_global.x
	var profundidad_real = aabb.size.z * escala_global.z
	var alto_real = aabb.size.y * escala_global.y

	# 2. Teletransportamos el nodo usando el offset de seguridad
	var posicion_base = mesh.global_position + Vector3(0, -(alto_real / 2.0) + polvo_offset_y, 0)
	particulas_polvo.global_position = posicion_base
	
	# Sincroniza la posición con los servidores de la GPU al instante
	particulas_polvo.force_update_transform() 

	# 3. Ajustamos el tamaño de la caja de emisión de partículas
	if particulas_polvo.process_material is ParticleProcessMaterial:
		particulas_polvo.process_material.emission_box_extents = Vector3(ancho_real / 2.0, 0.1, profundidad_real / 2.0)

	# 4. CONFIGURACIÓN DINÁMICA DEL FOG VOLUME (FADE IN SUAVE DESDE SHADER)
	if fog_particulas:
		fog_particulas.visible = true
		fog_particulas.size = Vector3(ancho_real, alto_neblina, profundidad_real)
		
		if fog_particulas.material:
			# Duplicamos el ShaderMaterial único de esta puerta
			fog_particulas.material = fog_particulas.material.duplicate()
			
			var tween_entrada = create_tween()
			
			# Comprobamos si es tu Shader personalizado o un FogMaterial clásico
			if fog_particulas.material is ShaderMaterial:
				fog_particulas.material.set_shader_parameter("density", 0.0) # Iniciamos invisible
				tween_entrada.tween_property(fog_particulas.material, "shader_parameter/density", densidad_max_niebla, tiempo_entrada_niebla)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_OUT)
			elif fog_particulas.material is FogMaterial:
				fog_particulas.material.density = 0.0
				tween_entrada.tween_property(fog_particulas.material, "density", densidad_max_niebla, tiempo_entrada_niebla)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_OUT)

	# 5. Forzamos el encendido de las partículas
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
	
	# Tween principal del movimiento de la puerta
	var tween_puerta = create_tween()
	tween_puerta.tween_property(nodo_a_mover, "global_position", posicion_final, tiempo_apertura)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# Cuando la puerta termina de bajar por completo:
	tween_puerta.tween_callback(func():
		if is_instance_valid(particulas_polvo):
			particulas_polvo.emitting = false # Deja de generar nuevas partículas
			
			# Creamos el Tween de limpieza final (FADE OUT SUAVE)
			var cleanup_tween = create_tween()
			var tiempo_desaparicion = particulas_polvo.lifetime
			
			# Desvanecer la densidad del shader gradualmente a 0.0
			if is_instance_valid(fog_particulas) and fog_particulas.material:
				if fog_particulas.material is ShaderMaterial:
					cleanup_tween.tween_property(fog_particulas.material, "shader_parameter/density", 0.0, tiempo_desaparicion)\
						.set_trans(Tween.TRANS_SINE)\
						.set_ease(Tween.EASE_IN)
				elif fog_particulas.material is FogMaterial:
					cleanup_tween.tween_property(fog_particulas.material, "density", 0.0, tiempo_desaparicion)\
						.set_trans(Tween.TRANS_SINE)\
						.set_ease(Tween.EASE_IN)
			
			# Guardamos referencias en variables locales seguras
			var p_polvo = particulas_polvo
			var n_mover = nodo_a_mover
			
			# Cuando la niebla llegue exactamente a cero, limpiamos todo del mapa
			cleanup_tween.tween_callback(func():
				if is_instance_valid(p_polvo):
					p_polvo.queue_free()
				if is_instance_valid(n_mover):
					n_mover.queue_free()
				print("Efectos y puerta eliminados del mapa de manera definitiva y limpia.")
			)
		else:
			nodo_a_mover.queue_free()
	)
