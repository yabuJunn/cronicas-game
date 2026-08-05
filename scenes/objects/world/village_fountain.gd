extends StaticBody3D

#Fountain

@onready var rhomboid: StaticBody3D = $RhomboidStaticBody
@onready var soundPlayer: AudioStreamPlayer3D = $AudioStreamPlayer3D

@export_group("Animación del Rombo")
@export var altura_flote: float = 0.25      # Qué tantos metros sube
@export var tiempo_flote: float = 4.0       # Segundos que tarda en subir y volver a bajar
@export var tiempo_rotacion: float = 5.0    # Segundos que tarda en dar una vuelta de 360 grados

func _ready() -> void:
	_ajustar_escala_sonido()
	_iniciar_animaciones_rombo()

func _ajustar_escala_sonido() -> void:
	if not soundPlayer:
		return
		
	# Obtenemos el Vector3 de la escala global a través de la matriz de transformación
	var escala_global: Vector3 = global_transform.basis.get_scale()
	
	# Tomamos la mayor escala entre los ejes X, Y o Z
	var factor_escala: float = max(escala_global.x, max(escala_global.y, escala_global.z))
	
	# Escalamos tanto la distancia máxima como la distancia de referencia (unit_size)
	soundPlayer.max_distance *= factor_escala
	soundPlayer.unit_size *= factor_escala

func _iniciar_animaciones_rombo() -> void:
	if not rhomboid:
		return
		
	# --- 1. ANIMACIÓN DE FLOTE ---
	var tween_flote = create_tween().set_loops() 
	tween_flote.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var pos_inicial_y = rhomboid.position.y
	
	tween_flote.tween_property(rhomboid, "position:y", pos_inicial_y + altura_flote, tiempo_flote / 2.0)
	tween_flote.tween_property(rhomboid, "position:y", pos_inicial_y, tiempo_flote / 2.0)

	# --- 2. ANIMACIÓN DE ROTACIÓN ---
	var tween_rotacion = create_tween().set_loops()
	tween_rotacion.tween_property(rhomboid, "rotation:y", TAU, tiempo_rotacion).as_relative()
