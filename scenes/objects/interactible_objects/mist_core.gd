extends InteractibleItemHighlight

# --- ANIMACIÓN DE FLOTE Y ROTACIÓN ---
@export_group("Animación Idle Flotación")
@export var animacion_habilitada: bool = true
@export var altura_flote: float = 0.15       # Altura que sube en metros
@export var tiempo_flote: float = 3.0        # Tiempo total del ciclo (subir y bajar)
@export var tiempo_rotacion: float = 4.0     # Tiempo que tarda en dar 360°

func _ready() -> void:
	super._ready()
	
	_iniciar_animaciones()

func _iniciar_animaciones() -> void:
	if not animacion_habilitada:
		return

	# --- 1. ANIMACIÓN DE FLOTE (SUBIR Y BAJAR) ---
	var tween_flote = create_tween().set_loops()
	tween_flote.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var pos_inicial_y = position.y
	
	tween_flote.tween_property(self, "position:y", pos_inicial_y + altura_flote, tiempo_flote / 2.0)
	tween_flote.tween_property(self, "position:y", pos_inicial_y, tiempo_flote / 2.0)

	# --- 2. ANIMACIÓN DE ROTACIÓN CONTINUA ---
	var tween_rotacion = create_tween().set_loops()
	tween_rotacion.tween_property(self, "rotation:y", TAU, tiempo_rotacion).as_relative()
