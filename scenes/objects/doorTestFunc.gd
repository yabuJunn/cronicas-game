extends InteractableItem

# El nombre exacto de la llave que abre esta puerta
@export var llave_requerida: String = "Llave"

# --- CONFIGURACIÓN DE LA ANIMACIÓN ---
@export var distancia_bajada: float = 21.0   # Cuántos metros bajará la puerta
@export var tiempo_apertura: float = 4.0    # Cuánto tardará en bajarse (en segundos)

# --- MENSAJES PERSONALIZADOS PARA LA INTERFAZ ---
@export var texto_cerrada: String = "La puerta está cerrada."
@export var texto_con_llave: String = "[ E ] Abrir puerta"

# PROPIEDAD DINÁMICA: Cada vez que el jugador pregunte por "texto_interaccion",
# se ejecutará este bloque de código 'get' y devolverá el texto correcto.
var texto_interaccion: String:
	get:
		if Inventory.tiene_objeto(llave_requerida):
			return texto_con_llave
		else:
			return texto_cerrada

# Array dinámico para guardar TODAS las colisiones que genere FuncGodot para esta puerta
var colisiones: Array[CollisionShape3D] = []
var esta_abriendose: bool = false

func _ready() -> void:
	# 1. Buscamos automáticamente la malla y las colisiones dentro de este StaticBody3D
	for hijo in get_children():
		if hijo is CollisionShape3D:
			colisiones.append(hijo)
		elif hijo is MeshInstance3D and mesh == null:
			mesh = hijo

	# Ejecuta el _ready de la clase padre (para configurar el shader blanco)
	super._ready()
	
	# ¡IMPORTANTE! Una puerta NO se puede meter al bolsillo
	se_puede_recoger = false


# Sobreescribimos la función interactuar de la clase padre
func interactuar() -> void:
	# Si ya se está abriendo, ignoramos más interacciones
	if esta_abriendose:
		return

	if Inventory.tiene_objeto(llave_requerida):
		print("¡Puerta abierta con éxito usando: ", llave_requerida, "!")
		
		# Gastamos la llave
		Inventory.remover_objeto(llave_requerida)
		
		# Iniciamos la transición y desaparición
		iniciar_animacion_apertura()
		
	else:
		print("La puerta está cerrada. Necesitas: ", llave_requerida)
		# Aquí puedes poner tu sonido de puerta trabada


# Función encargada de deslizar la puerta hacia abajo y luego borrarla
func iniciar_animacion_apertura() -> void:
	esta_abriendose = true
	
	# 1. La sacamos del grupo INMEDIATAMENTE para que el jugador ya no pueda mirarla ni iluminarla
	remove_from_group("interactibleObjects")
	set_highlight(false)
	
	# 2. Desactivamos las colisiones ya mismo. Así el jugador puede pasar de inmediato
	for colision in colisiones:
		if is_instance_valid(colision):
			colision.disabled = true
			
	# 3. Detectamos el nodo a mover. Si tiene padre de FuncGodot movemos al padre entero; si no, a sí misma.
	var nodo_a_mover = get_parent() if get_parent() != null else self
	
	# 4. Calculamos la posición final (su posición actual menos la distancia en el eje Y)
	var posicion_final = nodo_a_mover.global_position + Vector3(0, -distancia_bajada, 0)
	
	# 5. Creamos el Tween de Godot 4
	var tween = create_tween()
	
	# Transición suave de tipo Quad (frena un poco al llegar al final)
	tween.tween_property(nodo_a_mover, "global_position", posicion_final, tiempo_apertura)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	
	# 6. CUANDO TERMINE EL TWEEN: Eliminamos el nodo de forma definitiva
	tween.tween_callback(func():
		nodo_a_mover.queue_free()
		print("Puerta eliminada del mapa tras abrirse por completo.")
	)
