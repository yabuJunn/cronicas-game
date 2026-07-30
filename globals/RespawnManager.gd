extends Node

var current_checkpoint: Vector3 = Vector3.ZERO
var is_respawning: bool = false

var fade_canvas: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	# 1. Crear el sistema visual de fade dinámicamente
	fade_canvas = CanvasLayer.new()
	fade_canvas.layer = 128 # Número alto para asegurar que tape tu HUD y el inventario
	add_child(fade_canvas)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) # Negro completamente transparente
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_canvas.add_child(fade_rect)
	
	# 2. Registrar la posición inicial del jugador por si muere antes de tocar un checkpoint
	call_deferred("_registrar_posicion_inicial")

func _registrar_posicion_inicial() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		current_checkpoint = players[0].global_position

# Función que llamarán tus áreas o cinemáticas
func set_checkpoint(global_pos: Vector3) -> void:
	current_checkpoint = global_pos
	#print("Checkpoint guardado en: ", current_checkpoint)

# Función principal para ejecutar la muerte
func kill_player() -> void:
	if is_respawning:
		return
		
	is_respawning = true
	
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		push_error("RespawnManager: No se encontró al jugador.")
		is_respawning = false
		return
		
	var player = player_nodes[0]
	
	# 1. Bloquear controles del jugador (tu script seguirá aplicando gravedad pero no inputs)
	player.controles_bloqueados = true
	
	# 2. Animación de Fade Out (Pantalla a negro)
	var tween_out = create_tween()
	tween_out.tween_property(fade_rect, "color:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	await tween_out.finished
	
	# 3. Teletransportar y resetear físicas para evitar velocidad residual de una caída larga
	player.global_position = current_checkpoint
	player.velocity = Vector3.ZERO 
	
	# Opcional: Pequeña pausa en negro para que no sea tan brusco
	await get_tree().create_timer(0.4).timeout
	
	# 4. Animación de Fade In (Pantalla a transparente)
	var tween_in = create_tween()
	tween_in.tween_property(fade_rect, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	await tween_in.finished
	
	# 5. Devolver el control
	player.controles_bloqueados = false
	is_respawning = false
