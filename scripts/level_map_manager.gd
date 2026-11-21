extends Node3D
class_name level_map_manager

@export var musica_nivel: AudioStream

@onready var player: CharacterBody3D = $Jugador


func _ready() -> void:
	_posicionar_jugador()

	# 1. Ejecutamos el Fade In desde negro al terminar de cargar este nivel (1.5 segundos)
	if TransicionGlobal:
		TransicionGlobal.realizar_fade_in(1.5)

	# 2. Reproducimos directamente la música del nivel
	if musica_nivel and MusicManager:
		MusicManager.reproducir(musica_nivel, 2.0)


func _posicionar_jugador() -> void:
	if player == null:
		push_warning("level_map_manager: No se encontró el nodo $Jugador.")
		return

	var ruta_mapa := scene_file_path

	if SaveManager and ruta_mapa != "" and SaveManager.tiene_spawn_mapa(ruta_mapa):
		var spawn_data := SaveManager.obtener_spawn_mapa(ruta_mapa)
		player.global_position = spawn_data["posicion"]
		player.rotation.y = spawn_data["rotacion_y"]
		player.velocity = Vector3.ZERO

		if RespawnManager:
			RespawnManager.set_checkpoint(spawn_data["posicion"])
	else:
		# Respaldo: si el nivel no tiene ningún CheckpointArea con es_spawn_inicial = true,
		# se queda donde lo dejaste en el editor y registra esa posición como base.
		if SaveManager and ruta_mapa != "":
			SaveManager.registrar_spawn_mapa(ruta_mapa, player.global_position, player.rotation.y)
		if RespawnManager:
			RespawnManager.set_checkpoint(player.global_position)
