extends Node

# --- CONFIGURACIÓN DE TIEMPOS DE FADE ---
@export var tiempo_fade_normal: float = 1.2   # Transición suave entre niveles/eventos
@export var tiempo_fade_rapido: float = 0.1   # Ajuste rápido para evitar silencios al volver

# --- SISTEMA DE DOBLE REPRODUCTOR ---
var p1: AudioStreamPlayer
var p2: AudioStreamPlayer

var active_player: AudioStreamPlayer
var inactive_player: AudioStreamPlayer

var tween_fade_in: Tween
var tween_fade_out: Tween

# --- VARIABLES DE ESTADO ---
var musica_retorno: AudioStream = null
var es_bucle: bool = false 

func _ready() -> void:
	# Instanciamos ambos reproductores para poder cruzarlos
	p1 = AudioStreamPlayer.new()
	p2 = AudioStreamPlayer.new()
	add_child(p1)
	add_child(p2)
	
	p1.bus = "Music"
	p2.bus = "Music"
	
	# Al principio, el p1 es el activo y el p2 el de reserva
	active_player = p1
	inactive_player = p2
	
	# Conectamos ambos a la detección de finalización de pista
	p1.finished.connect(_on_player_finished.bind(p1))
	p2.finished.connect(_on_player_finished.bind(p2))

# --- FUNCIÓN NÚCLEO: GESTIONA EL CROSSFADE ---
func transicion_a(cancion: AudioStream, tiempo_fade: float) -> void:
	# Si la canción ya está sonando en el reproductor activo, la ignoramos
	if active_player.stream == cancion and active_player.playing:
		return 
	
	desactivar_loop_interno(cancion)
	
	# Matamos tweens activos para evitar que se peleen por el volumen
	if tween_fade_in: tween_fade_in.kill()
	if tween_fade_out: tween_fade_out.kill()
	
	# 1. FADE OUT: Desvanecer el reproductor actual (si está sonando)
	if active_player.playing:
		tween_fade_out = create_tween()
		tween_fade_out.tween_property(active_player, "volume_db", -80.0, tiempo_fade).set_trans(Tween.TRANS_SINE)
		tween_fade_out.tween_callback(active_player.stop) # Se apaga al terminar el fade
		
	# 2. FADE IN: Preparar y encender el reproductor de reserva
	inactive_player.stream = cancion
	inactive_player.volume_db = -80.0 # Empezamos desde el silencio absoluto
	inactive_player.play()
	
	tween_fade_in = create_tween()
	tween_fade_in.tween_property(inactive_player, "volume_db", 0.0, tiempo_fade).set_trans(Tween.TRANS_SINE)
	
	# 3. INTERCAMBIO: El que era de reserva ahora es el activo, y viceversa
	var temp = active_player
	active_player = inactive_player
	inactive_player = temp

# Reproduce una canción normal (bucle infinito del nivel)
func reproducir(cancion: AudioStream, tiempo_fade: float = tiempo_fade_normal) -> void:
	musica_retorno = null 
	es_bucle = true 
	transicion_a(cancion, tiempo_fade)

# Reproduce una canción de evento (no loopeada). Al terminar, vuelve a otra.
func reproducir_temporal(cancion: AudioStream, cancion_al_volver: AudioStream = null) -> void:
	es_bucle = false 
	
	if cancion_al_volver != null:
		musica_retorno = cancion_al_volver
	else:
		musica_retorno = active_player.stream # Guarda la que suena ahora mismo
		
	transicion_a(cancion, tiempo_fade_normal)

func detener(tiempo_fade: float = tiempo_fade_normal) -> void:
	es_bucle = false
	musica_retorno = null
	if tween_fade_out: tween_fade_out.kill()
	tween_fade_out = create_tween()
	tween_fade_out.tween_property(active_player, "volume_db", -80.0, tiempo_fade)
	tween_fade_out.tween_callback(active_player.stop)

# --- NUEVA FUNCIÓN: ELIMINA Y SILENCIA TODA LA MÚSICA CON GARANTÍAS ---
func quitar_musica(tiempo_fade: float = tiempo_fade_normal) -> void:
	es_bucle = false
	musica_retorno = null
	
	# Forzamos la muerte de cualquier animación de volumen en proceso
	if tween_fade_in: tween_fade_in.kill()
	if tween_fade_out: tween_fade_out.kill()
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	
	# Apagamos en paralelo lo que sea que esté haciendo ruido
	if p1.playing:
		tween.parallel().tween_property(p1, "volume_db", -80.0, tiempo_fade)
	if p2.playing:
		tween.parallel().tween_property(p2, "volume_db", -80.0, tiempo_fade)
		
	# Al terminar el fade de silencio, liberamos canales y restablecemos volúmenes base
	tween.tween_callback(func():
		p1.stop()
		p2.stop()
		p1.stream = null
		p2.stream = null
		p1.volume_db = 0.0
		p2.volume_db = 0.0
	)

func desactivar_loop_interno(cancion: AudioStream) -> void:
	if cancion == null: return
	if "loop" in cancion:
		cancion.loop = false 
	elif "loop_mode" in cancion:
		cancion.loop_mode = 0 

# Nueva función conectada que sabe qué reproductor específico terminó
func _on_player_finished(player_que_termino: AudioStreamPlayer) -> void:
	if player_que_termino != active_player:
		return
		
	if es_bucle:
		active_player.play()
	elif musica_retorno != null:
		var cancion_a_poner = musica_retorno
		musica_retorno = null 
		reproducir(cancion_a_poner, tiempo_fade_rapido)
