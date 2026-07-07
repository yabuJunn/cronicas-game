extends Node

var audio_player: AudioStreamPlayer
var musica_retorno: AudioStream = null
# --- NUEVA VARIABLE DE ESTADO ---
var es_bucle: bool = false 

func _ready() -> void:
	# Creamos el reproductor por código para que sea totalmente global
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.bus = "Music"
	
	# Nos conectamos a la señal que avisa cuando una canción termina
	audio_player.finished.connect(_on_musica_terminada)

# Reproduce una canción normal (bucle infinito del nivel)
func reproducir(cancion: AudioStream) -> void:
	musica_retorno = null # Cancelamos cualquier retorno previo
	es_bucle = true # <-- Marcamos que esta canción DEBE loopear
	
	if audio_player.stream == cancion and audio_player.playing:
		return # Si ya está sonando esa misma canción, no la reinicies
	
	# Forzamos que el archivo NO tenga loop interno para que use nuestro sistema
	desactivar_loop_interno(cancion)
		
	audio_player.stream = cancion
	audio_player.play()

# Reproduce una canción de evento (no loopeada). Al terminar, vuelve a otra.
func reproducir_temporal(cancion: AudioStream, cancion_al_volver: AudioStream = null) -> void:
	es_bucle = false # <-- Marcamos que esta canción NO debe loopear
	
	# Si no especificas una canción al volver, recordará la que está sonando justo ahora
	if cancion_al_volver != null:
		musica_retorno = cancion_al_volver
	else:
		musica_retorno = audio_player.stream
		
	desactivar_loop_interno(cancion)
	
	audio_player.stream = cancion
	audio_player.play()

func detener() -> void:
	audio_player.stop()

# --- FUNCIÓN AUXILIAR ---
# Apaga el loop nativo del recurso para que la señal 'finished' siempre responda
func desactivar_loop_interno(cancion: AudioStream) -> void:
	if cancion == null: return
	
	if "loop" in cancion:
		cancion.loop = false # Para MP3 y OGG
	elif "loop_mode" in cancion:
		cancion.loop_mode = 0 # Para WAV (0 significa sin loop)

func _on_musica_terminada() -> void:
	# 1. Si la canción actual estaba configurada como bucle, la reiniciamos inmediatamente
	if es_bucle:
		audio_player.play()
	
	# 2. Si no era un bucle y teníamos una música guardada para regresar, volvemos a ella
	elif musica_retorno != null:
		var cancion_a_poner = musica_retorno
		musica_retorno = null # Limpiamos la variable
		reproducir(cancion_a_poner)
