extends Node
# SaveManager (Autoload)

const RUTA_GUARDADO := "user://cronicas_save.sav"

# Estado en memoria de la partida en curso
var mapa_actual: String = ""
var ultima_posicion_guardada: Vector3 = Vector3.ZERO
var ultima_rotacion_y: float = 0.0
var spawns_por_mapa: Dictionary = {} # { "res://ruta/nivel.tscn": { "posicion": Vector3, "rotacion_y": float } }
var world_flags: Dictionary = {}


# --- UTILIDADES DE ARCHIVO ---

func tiene_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


func borrar_partida() -> void:
	if tiene_partida_guardada():
		DirAccess.remove_absolute(RUTA_GUARDADO)
	reiniciar_estado()


func reiniciar_estado() -> void:
	mapa_actual = ""
	ultima_posicion_guardada = Vector3.ZERO
	ultima_rotacion_y = 0.0
	spawns_por_mapa.clear()
	world_flags.clear()
	if Inventory:
		Inventory.limpiar()
	if RespawnManager:
		RespawnManager.reiniciar_checkpoint()


# --- GESTIÓN DE SPAWNS POR MAPA (MEMORIA DE SESIÓN Y GUARDADO) ---

func registrar_spawn_mapa(ruta_mapa: String, posicion: Vector3, rotacion_y: float = 0.0) -> void:
	if ruta_mapa == "":
		return
	spawns_por_mapa[ruta_mapa] = {
		"posicion": posicion,
		"rotacion_y": rotacion_y
	}


func tiene_spawn_mapa(ruta_mapa: String) -> bool:
	return spawns_por_mapa.has(ruta_mapa)


func obtener_spawn_mapa(ruta_mapa: String) -> Dictionary:
	return spawns_por_mapa.get(ruta_mapa, {})


# --- GUARDAR Y CARGAR EN DISCO ---

func guardar_partida(posicion_custom: Variant = null, rotacion_custom: Variant = null) -> bool:
	var escena_actual := get_tree().current_scene
	if escena_actual == null or escena_actual.scene_file_path == "":
		push_error("SaveManager: No se pudo obtener la ruta del nivel actual.")
		return false

	mapa_actual = escena_actual.scene_file_path
	var player := get_tree().get_first_node_in_group("player")

	if posicion_custom is Vector3:
		ultima_posicion_guardada = posicion_custom
	elif spawns_por_mapa.has(mapa_actual):
		ultima_posicion_guardada = spawns_por_mapa[mapa_actual]["posicion"]
	elif RespawnManager and RespawnManager.tiene_checkpoint:
		ultima_posicion_guardada = RespawnManager.current_checkpoint
	elif player:
		ultima_posicion_guardada = player.global_position

	if rotacion_custom is float or rotacion_custom is int:
		ultima_rotacion_y = float(rotacion_custom)
	elif spawns_por_mapa.has(mapa_actual):
		ultima_rotacion_y = spawns_por_mapa[mapa_actual]["rotacion_y"]
	elif player:
		ultima_rotacion_y = player.rotation.y

	# Nos aseguramos de que el mapa actual tenga este punto registrado
	registrar_spawn_mapa(mapa_actual, ultima_posicion_guardada, ultima_rotacion_y)

	var datos := {
		"mapa": mapa_actual,
		"posicion": ultima_posicion_guardada,
		"rotacion_y": ultima_rotacion_y,
		"spawns_por_mapa": spawns_por_mapa.duplicate(true),
		"inventario": Inventory.serializar() if Inventory else [],
		"world_flags": world_flags.duplicate(true)
	}

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("SaveManager: Error al escribir archivo -> " + error_string(FileAccess.get_open_error()))
		return false

	archivo.store_var(datos)
	archivo.close()
	print("💾 Partida guardada en: ", mapa_actual, " | Pos: ", ultima_posicion_guardada)
	return true


func cargar_partida() -> bool:
	if not tiene_partida_guardada():
		push_warning("SaveManager: No existe archivo de guardado.")
		return false

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		push_error("SaveManager: Error al leer archivo -> " + error_string(FileAccess.get_open_error()))
		return false

	var datos = archivo.get_var()
	archivo.close()

	if not datos is Dictionary or not datos.has("mapa"):
		push_error("SaveManager: Archivo de guardado corrupto.")
		return false

	mapa_actual = datos["mapa"]
	ultima_posicion_guardada = datos.get("posicion", Vector3.ZERO)
	ultima_rotacion_y = datos.get("rotacion_y", 0.0)
	spawns_por_mapa = datos.get("spawns_por_mapa", {}).duplicate(true)
	world_flags = datos.get("world_flags", {}).duplicate(true)

	# Garantizamos que el punto exacto donde se guardó sea el spawn al cargar ese nivel
	registrar_spawn_mapa(mapa_actual, ultima_posicion_guardada, ultima_rotacion_y)

	if Inventory:
		Inventory.deserializar(datos.get("inventario", []))

	if TransicionGlobal:
		TransicionGlobal.cambiar_de_nivel(mapa_actual)
	else:
		push_error("SaveManager: TransicionGlobal no está disponible.")
		return false

	return true


# --- FLAGS DE ESTADO DEL MUNDO ---

func get_flag(clave: String, valor_por_defecto = false):
	if clave == "":
		return valor_por_defecto
	return world_flags.get(clave, valor_por_defecto)


func set_flag(clave: String, valor) -> void:
	if clave == "":
		return
	world_flags[clave] = valor


func generar_clave_nodo(prefijo: String, nodo: Node) -> String:
	var escena := get_tree().current_scene
	if escena != null and (escena == nodo or escena.is_ancestor_of(nodo)):
		var nombre_mapa := escena.scene_file_path.get_file().get_basename()
		if nombre_mapa == "":
			nombre_mapa = escena.name
		return "%s:%s/%s" % [prefijo, nombre_mapa, str(escena.get_path_to(nodo))]
	return "%s:%s" % [prefijo, str(nodo.get_path())]
