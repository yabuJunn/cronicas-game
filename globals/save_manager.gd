extends Node
# SaveManager (Autoload)

const RUTA_GUARDADO := "user://cronicas_save.sav"

# Estado en memoria de la partida en curso
var mapa_actual: String = ""
var ultima_posicion_guardada: Vector3 = Vector3.ZERO
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
	world_flags.clear()
	if Inventory:
		Inventory.limpiar()
	if RespawnManager:
		RespawnManager.reiniciar_checkpoint()


# --- GUARDAR Y CARGAR ---

# Guarda en el último checkpoint registrado (o en una posición específica si se pasa por parámetro)
func guardar_partida(posicion_custom: Variant = null) -> bool:
	var escena_actual := get_tree().current_scene
	if escena_actual == null or escena_actual.scene_file_path == "":
		push_error("SaveManager: No se pudo obtener la ruta del nivel actual.")
		return false

	mapa_actual = escena_actual.scene_file_path

	if posicion_custom is Vector3:
		ultima_posicion_guardada = posicion_custom
	elif RespawnManager and RespawnManager.tiene_checkpoint:
		ultima_posicion_guardada = RespawnManager.current_checkpoint
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			ultima_posicion_guardada = player.global_position

	var datos := {
		"mapa": mapa_actual,
		"posicion": ultima_posicion_guardada,
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
	world_flags = datos.get("world_flags", {}).duplicate(true)

	if Inventory:
		Inventory.deserializar(datos.get("inventario", []))

	if TransicionGlobal:
		TransicionGlobal.cambiar_de_nivel(mapa_actual, ultima_posicion_guardada)
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


# Genera una clave única y estable usando el nombre del archivo del mapa + ruta del nodo
# Ejemplo: "item:nivel_playa/Interactuables/LlaveAntigua"
func generar_clave_nodo(prefijo: String, nodo: Node) -> String:
	var escena := get_tree().current_scene
	if escena != null and (escena == nodo or escena.is_ancestor_of(nodo)):
		var nombre_mapa := escena.scene_file_path.get_file().get_basename()
		if nombre_mapa == "":
			nombre_mapa = escena.name
		return "%s:%s/%s" % [prefijo, nombre_mapa, str(escena.get_path_to(nodo))]
	return "%s:%s" % [prefijo, str(nodo.get_path())]
