extends Node3D

@onready var normalLevelSong: AudioStream = preload("res://sounds/music/3 El bosque susurrante (ingame) - Normal Forest.mp3")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MusicManager.reproducir(normalLevelSong, 4)
