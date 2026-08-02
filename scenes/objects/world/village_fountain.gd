extends StaticBody3D

#Fountain

@onready var rhomboid: StaticBody3D = $RhomboidStaticBody

@export_group("Animación del Rombo")
@export var altura_flote: float = 0.25      # Qué tantos metros sube
@export var tiempo_flote: float = 4.0       # Segundos que tarda en subir y volver a bajar
@export var tiempo_rotacion: float = 5.0    # Segundos que tarda en dar una vuelta de 360 grados

func _ready() -> void:
	_iniciar_animaciones_rombo()

func _iniciar_animaciones_rombo() -> void:
	# Verificamos que el nodo exista para evitar errores
	if not rhomboid:
		return
		
	# --- 1. ANIMACIÓN DE FLOTE ---
	# set_loops() sin argumentos hace que el Tween se repita de forma infinita
	var tween_flote = create_tween().set_loops() 
	tween_flote.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var pos_inicial_y = rhomboid.position.y
	
	# Mitad del tiempo subiendo
	tween_flote.tween_property(rhomboid, "position:y", pos_inicial_y + altura_flote, tiempo_flote / 2.0)
	# Mitad del tiempo bajando a su posición original
	tween_flote.tween_property(rhomboid, "position:y", pos_inicial_y, tiempo_flote / 2.0)


	# --- 2. ANIMACIÓN DE ROTACIÓN ---
	var tween_rotacion = create_tween().set_loops()
	
	# Usamos TAU (que equivale a 360 grados o 2*PI radianes) 
	# .as_relative() es la magia aquí: en lugar de ir a un ángulo fijo, suma 360 grados a su rotación actual constantemente
	tween_rotacion.tween_property(rhomboid, "rotation:y", TAU, tiempo_rotacion).as_relative()
