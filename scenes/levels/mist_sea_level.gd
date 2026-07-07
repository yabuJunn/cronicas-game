extends Node3D

@export var musica_playa: AudioStream # Arrastra aquí tu .wav o .mp3 en el Inspector

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Así de fácil se inicia la música ambiental
	MusicManager.reproducir(musica_playa)
