extends Node3D

@export var musica_playa: AudioStream

@onready var player: CharacterBody3D = $Jugador
@onready var menu_camera_marker: Marker3D = $CinemaMarkers/MenuCameraMarker
@onready var start_menu: Control = $StartMenu


func _ready() -> void:
	if musica_playa:
		MusicManager.reproducir(musica_playa)
		
	if start_menu and menu_camera_marker and player:
		# 1. Posiciona la cámara en el Marker3D
		player.preparar_camara_menu(menu_camera_marker.global_transform)
		
		# 2. Escucha el clic en "Jugar"
		start_menu.jugar_presionado.connect(_on_jugar_presionado)


func _on_jugar_presionado() -> void:
	start_menu.ocultar_menu(1.0)
	player.transicionar_a_jugador(3.5)
