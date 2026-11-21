extends Area3D
class_name CheckpointArea

@export var punto_de_aparicion: Node3D

@export_group("Comportamiento en el Nivel")
## Actívalo en UN checkpoint del nivel para usarlo la primera vez que se entra al mapa
## (si aún no hay otra referencia de aparición guardada para este nivel).
@export var es_spawn_inicial: bool = false

## Actualiza el punto de aparición de este mapa en memoria al tocarlo (para volver por puertas).
@export var actualizar_spawn_al_tocar: bool = true

## Guarda la partida completa en disco la primera vez que el jugador entra aquí.
@export var guardar_partida_al_tocar: bool = false

var activado: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Si es el spawn por defecto del nivel y este mapa aún no tiene uno registrado, lo establecemos
	if es_spawn_inicial and SaveManager:
		var ruta_mapa := _obtener_ruta_mapa_actual()
		if ruta_mapa != "" and not SaveManager.tiene_spawn_mapa(ruta_mapa):
			var datos_spawn := _obtener_transform_spawn()
			SaveManager.registrar_spawn_mapa(ruta_mapa, datos_spawn.posicion, datos_spawn.rotacion_y)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var datos_spawn := _obtener_transform_spawn()
	var pos: Vector3 = datos_spawn.posicion
	var rot_y: float = datos_spawn.rotacion_y

	if RespawnManager:
		RespawnManager.set_checkpoint(pos)

	if actualizar_spawn_al_tocar and SaveManager:
		var ruta_mapa := _obtener_ruta_mapa_actual()
		SaveManager.registrar_spawn_mapa(ruta_mapa, pos, rot_y)

	if guardar_partida_al_tocar and not activado:
		activado = true
		if SaveManager:
			SaveManager.guardar_partida(pos, rot_y)


func _obtener_transform_spawn() -> Dictionary:
	if punto_de_aparicion != null:
		return {
			"posicion": punto_de_aparicion.global_position,
			"rotacion_y": punto_de_aparicion.global_rotation.y
		}
	return {
		"posicion": global_position,
		"rotacion_y": global_rotation.y
	}


func _obtener_ruta_mapa_actual() -> String:
	var escena := get_tree().current_scene
	return escena.scene_file_path if escena != null else ""
