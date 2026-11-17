extends Node3D
class_name level_map

@export var musica_nivel: AudioStream

@onready var player: CharacterBody3D = $Jugador

func _ready() -> void:
	# 1. Ejecutamos el Fade In desde negro al terminar de cargar este nivel (1.5 segundos)
	if TransicionGlobal:
		TransicionGlobal.realizar_fade_in(1.5)

	# 2. Reproducimos directamente la música del nivel de la playa
	if musica_nivel and MusicManager:
		MusicManager.reproducir(musica_nivel, 2.0)
