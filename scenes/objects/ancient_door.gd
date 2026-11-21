extends InteractableItem
class_name OpenableAncientDoor

# Asegúrate de que coincida con el target_id del switch o pedestal
@export var puerta_id: String = ""

@export_group("Configuración de Movimiento")
@export var nodo_puerta: Node3D          # Opcional: si lo dejas vacío, detecta automáticamente el nodo contenedor de la puerta
@export var distancia_bajar: float = 20.0 # Metros que bajará respecto a su posición original
@export var tiempo_bajar: float = 3.0     # Segundos que tarda en bajar

@export_group("Efectos (Audio, Polvo y Shake)")
@export var intensidad_shake: float = 0.03 # Fuerza de la vibración lateral de la piedra
@export var audio_puerta: AudioStreamPlayer3D # Opcional: si lo dejas vacío, lo busca en los nodos hermanos
@export var volumen_max_audio: float = 0.0    # Volumen objetivo en dB durante la apertura
@export var particulas_polvo: Array[Node3D] = [] # Opcional: si lo dejas vacío, busca GPUParticles3D/CPUParticles3D en los hermanos

@export_group("Música de Evento")
@export var musica_evento_puerta: AudioStream      # Canción de suspenso / apertura
@export var musica_ambiente_siguiente: AudioStream # La música que se quedará después (opcional)

var puerta_posicion_inicial: Vector3
var mesh_posicion_inicial: Vector3
var ya_abierta: bool = false
var esta_bajando: bool = false


func _ready() -> void:
	# 1. Buscamos la malla recursivamente ANTES de llamar al padre
	mesh = _buscar_mesh_recursivo(self)
	if mesh != null:
		mesh_posicion_inicial = mesh.position

	# 2. Identificamos qué nodo hijo contiene la puerta para mover SOLO ese nodo
	# y dejar quietos a sus hermanos (Polvo Puerta y AudioStreamPlayer3D)
	if nodo_puerta == null:
		nodo_puerta = _obtener_contenedor_puerta()
	if nodo_puerta == null:
		nodo_puerta = self

	puerta_posicion_inicial = nodo_puerta.global_position

	# 3. Llamamos al ready del padre
	super._ready()
	se_puede_recoger = false

	# 4. Buscamos automáticamente audio y partículas en los nodos hermanos
	_inicializar_efectos()

	# 5. Compatibilidad con MechanismSwitch (puerta_id) y pedestales ("puertas_mapa")
	add_to_group("puertas_mapa")
	if puerta_id != "":
		add_to_group(puerta_id)

	# 6. Si ya se abrió antes en esta partida, aparece abajo al instante sin repetir animación ni sonido
	if SaveManager and SaveManager.get_flag(SaveManager.generar_clave_nodo("puerta_antigua", self), false):
		ya_abierta = true
		nodo_puerta.global_position = puerta_posicion_inicial - Vector3(0.0, distancia_bajar, 0.0)
		_desactivar_interaccion()


func _process(_delta: float) -> void:
	# Aplicamos el shake solo sobre la malla visual para no alterar las colisiones ni el Tween
	if esta_bajando and mesh != null:
		var offset_x := randf_range(-intensidad_shake, intensidad_shake)
		var offset_z := randf_range(-intensidad_shake, intensidad_shake)
		mesh.position = mesh_posicion_inicial + Vector3(offset_x, 0.0, offset_z)


func abrir_puerta() -> void:
	if ya_abierta:
		return
	ya_abierta = true
	esta_bajando = true

	# Disparar música de evento solo si esta puerta tiene una pista asignada
	if musica_evento_puerta != null and MusicManager:
		MusicManager.reproducir_temporal(musica_evento_puerta, musica_ambiente_siguiente)

	if SaveManager:
		SaveManager.set_flag(SaveManager.generar_clave_nodo("puerta_antigua", self), true)

	_desactivar_interaccion()

	# Activar sonido de piedra en su posición fija original (con fade in/out suave)
	if audio_puerta != null:
		audio_puerta.volume_db = -40.0
		audio_puerta.play()
		var tiempo_fade_in := minf(0.5, tiempo_bajar * 0.25)
		var tiempo_fade_out := minf(0.8, tiempo_bajar * 0.3)
		var tiempo_sostenido := maxf(0.0, tiempo_bajar - tiempo_fade_in - tiempo_fade_out)

		var tween_audio := create_tween()
		tween_audio.tween_property(audio_puerta, "volume_db", volumen_max_audio, tiempo_fade_in)
		tween_audio.tween_interval(tiempo_sostenido)
		tween_audio.tween_property(audio_puerta, "volume_db", -40.0, tiempo_fade_out)
		tween_audio.tween_callback(audio_puerta.stop)

	# Activar partículas de polvo en su posición fija original
	for particula in particulas_polvo:
		if is_instance_valid(particula):
			particula.emitting = true

	# Movemos ÚNICAMENTE el nodo de la puerta; Polvo Puerta y el audio no se mueven
	var posicion_final := puerta_posicion_inicial - Vector3(0.0, distancia_bajar, 0.0)
	var tween_puerta := create_tween()
	tween_puerta.tween_property(nodo_puerta, "global_position", posicion_final, tiempo_bajar)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)

	tween_puerta.tween_callback(func():
		esta_bajando = false
		if mesh != null:
			mesh.position = mesh_posicion_inicial
		for particula in particulas_polvo:
			if is_instance_valid(particula):
				particula.emitting = false
	)


# Método estándar llamado por MechanismSwitch
func open(_id_recibido: String = "") -> void:
	abrir_puerta()


# Método compatible con pedestales que llaman al grupo "puertas_mapa"
func verificar_y_abrir(id_recibido: String) -> void:
	if id_recibido == puerta_id:
		abrir_puerta()


func _desactivar_interaccion() -> void:
	set_highlight(false)
	outline_habilitado = false
	if is_in_group("interactibleObjects"):
		remove_from_group("interactibleObjects")


# --- RESOLUCIÓN DE NODOS INTERNOS ---
func _obtener_contenedor_puerta() -> Node3D:
	if mesh == null:
		return null
	# Sube desde la malla hasta encontrar el hijo directo de SeaDoor (ej. "Door")
	var actual: Node = mesh
	while actual != null and actual.get_parent() != self:
		actual = actual.get_parent()
	return actual as Node3D


func _inicializar_efectos() -> void:
	if audio_puerta == null:
		var audios := find_children("*", "AudioStreamPlayer3D", true, false)
		if not audios.is_empty():
			audio_puerta = audios[0] as AudioStreamPlayer3D

	if particulas_polvo.is_empty():
		for nodo in find_children("*", "", true, false):
			if nodo is GPUParticles3D or nodo is CPUParticles3D:
				particulas_polvo.append(nodo)

	for particula in particulas_polvo:
		if is_instance_valid(particula):
			particula.emitting = false


func _buscar_mesh_recursivo(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo
	for hijo in nodo.get_children():
		var encontrado := _buscar_mesh_recursivo(hijo)
		if encontrado != null:
			return encontrado
	return null
