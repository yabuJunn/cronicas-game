extends Node3D

@export var musica_playa: AudioStream
@export var startMenuMusic: AudioStream

@onready var player: CharacterBody3D = $Jugador
@onready var menu_camera_marker: Marker3D = $CinemaMarkers/MenuCameraMarker
@onready var start_menu: Control = $StartMenu


func _ready() -> void:
	# 1. Reproducimos la música del menú inicial
	if startMenuMusic:
		MusicManager.reproducir(startMenuMusic)
		
	if start_menu and menu_camera_marker and player:
		# 2. Posicionamos la cámara en la vista panorámica del menú
		player.preparar_camara_menu(menu_camera_marker.global_transform)
		
		# 3. Conectamos la señal de "Jugar"
		start_menu.jugar_presionado.connect(_on_jugar_presionado)


func _on_jugar_presionado() -> void:
	# Ocultamos la interfaz del menú
	start_menu.ocultar_menu(1.0)
	
	# Transición suave de cámara hacia el jugador (dura 3.5s)
	player.transicionar_a_jugador(3.5)
	
	# Hacemos crossfade a la música del nivel durante 2.5 segundos
	if musica_playa:
		MusicManager.reproducir(musica_playa, 2.5)
