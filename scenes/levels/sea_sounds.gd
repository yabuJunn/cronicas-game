extends Node3D

func _ready() -> void:
	# Esperamos un cuadro para asegurarnos de que todo esté listo
	await get_tree().process_frame
	
	# Recorremos todos los nodos hijos
	for hijo in get_children():
		if hijo is AudioStreamPlayer3D and hijo.stream != null:
			# 1. Obtenemos la duración total de la pista de audio (en segundos)
			var duracion_audio: float = hijo.stream.get_length()
			
			# 2. Generamos un segundo de inicio completamente aleatorio
			var punto_inicio_aleatorio: float = randf_range(0.0, duracion_audio)
			
			# 3. Lo reproducimos desde ese punto temporal
			# Modifica la velocidad del audio sutilmente entre un 90% y un 110%
			hijo.pitch_scale = randf_range(0.9, 1.1)
			hijo.play(punto_inicio_aleatorio)
