extends InteractableItem

# El nombre exacto de la llave que abre esta puerta
@export var llave_requerida: String = "Llave"

# Necesitamos la colisión para apagarla cuando se abra
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	print(self)
	# Ejecuta el _ready de la clase padre (para configurar el shader blanco)
	super._ready()
	
	# ¡IMPORTANTE! Una puerta NO se puede meter al bolsillo
	se_puede_recoger = false


# Sobreescribimos la función interactuar de la clase padre
func interactuar() -> void:
	# OJO: Aquí depende de cóm	o se llame la función en tu Autoload 'Inventory'.
	# Asumiré que tienes una función para comprobar si el objeto existe.
	# Si tu inventario usa algo como 'Inventory.items.has(llave_requerida)', cámbialo aquí.
	if Inventory.tiene_objeto(llave_requerida):
		print("¡Puerta abierta con éxito usando: ", llave_requerida, "!")
		
		# Si quieres que la llave se gaste y desaparezca del inventario, descomenta esto:
		Inventory.remover_objeto(llave_requerida)
		
		# --- ELIGE UNA DE LAS DOS OPCIONES DE ABAJO ---
		
		# OPCIÓN A: Eliminar la puerta por completo del juego
		queue_free()
		
		# OPCIÓN B: Cambiar de estado (Recomendado para que no desaparezca mágicamente)
		abrir_puerta()
		
	else:
		# Lógica si el jugador NO tiene la llave
		print("La puerta está cerrada. Necesitas: ", llave_requerida)
		# Aquí podrías reproducir un sonido de "puerta trabada"


# Función para cambiar el estado de la puerta sin destruirla
func abrir_puerta() -> void:
	# 1. Desactivamos la colisión para que el jugador pueda pasar a través de ella
	if collision_shape:
		collision_shape.disabled = true
		
	# 2. Ocultamos la malla para que visualmente no se vea
	# (Si en el futuro haces una animación de rotar, la llamarías aquí en vez de ocultarla)
	if mesh:
		mesh.hide()
		
	# 3. La sacamos del grupo para que el RayCast del jugador la ignore por completo
	remove_from_group("interactibleObjects")
	
	# 4. Apagamos el borde blanco por si acaso
	set_highlight(false)
