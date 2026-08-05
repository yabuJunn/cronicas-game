extends InteractibleItemHighlight

# --- ANIMACIÓN DE FLOTE Y ROTACIÓN ---
@export_group("Animación Idle Flotación")
@export var animacion_habilitada: bool = true
@export var floating: bool = true            # Controla si el flote vertical está activo
@export var rotating: bool = true            # Controla si la rotación está activa
@export var altura_flote: float = 0.15       # Altura que sube en metros
@export var tiempo_flote: float = 3.0        # Tiempo total del ciclo (subir y bajar)
@export var tiempo_rotacion: float = 4.0     # Tiempo que tarda en dar 360°

var tween_flote: Tween
var tween_rotacion: Tween
var pos_inicial_y: float = 0.0

func _ready() -> void:
	super._ready()
	pos_inicial_y = position.y
	iniciar_animaciones()


# --- CONTROL DE ANIMACIONES EN TIEMPO DE EJECUCIÓN ---

func iniciar_animaciones() -> void:
	if not animacion_habilitada:
		return
	iniciar_flote()
	iniciar_rotacion()


func detener_animaciones(restablecer_posicion: bool = true) -> void:
	detener_flote(restablecer_posicion)
	detener_rotacion()


func iniciar_flote() -> void:
	if not floating:
		return
	detener_flote(false) # Limpiamos cualquier tween previo de flote sin reiniciar la Y base
	
	tween_flote = create_tween().set_loops()
	tween_flote.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween_flote.tween_property(self, "position:y", pos_inicial_y + altura_flote, tiempo_flote / 2.0)
	tween_flote.tween_property(self, "position:y", pos_inicial_y, tiempo_flote / 2.0)


func detener_flote(restablecer_posicion: bool = true) -> void:
	if tween_flote and tween_flote.is_valid():
		tween_flote.kill()
	if restablecer_posicion:
		position.y = pos_inicial_y


func iniciar_rotacion() -> void:
	if not rotating:
		return
	detener_rotacion()
	
	tween_rotacion = create_tween().set_loops()
	tween_rotacion.tween_property(self, "rotation:y", TAU, tiempo_rotacion).as_relative()


func detener_rotacion() -> void:
	if tween_rotacion and tween_rotacion.is_valid():
		tween_rotacion.kill()


# Método helper para activar/desactivar el flote desde otros scripts fácilmente
func set_floating(activar: bool, restablecer_posicion: bool = true) -> void:
	floating = activar
	if floating:
		iniciar_flote()
	else:
		detener_flote(restablecer_posicion)

func set_rotating(activar: bool) -> void:
	rotating = activar
	if rotating:
		iniciar_rotacion()
	else:
		detener_rotacion()
