extends Node
# Inventory manager

var items_recolectados: Dictionary = {}
var listado_ordenado: Array = [] # Necesario para el carrusel


func agregar_objeto(nombre: String, descripcion: String, icono: Texture2D = null, modelo_3d: PackedScene = null) -> void:
	items_recolectados[nombre] = {
		"descripcion": descripcion,
		"icono": icono,
		"modelo_3d": modelo_3d
	}
	if not listado_ordenado.has(nombre):
		listado_ordenado.append(nombre)
	print("Objeto recogido: ", nombre)


func tiene_objeto(nombre: String) -> bool:
	return items_recolectados.has(nombre)


func remover_objeto(nombre: String) -> void:
	if items_recolectados.has(nombre):
		items_recolectados.erase(nombre)
		listado_ordenado.erase(nombre)
		print("Objeto removido: ", nombre)


func limpiar() -> void:
	items_recolectados.clear()
	listado_ordenado.clear()


# Convierte el inventario a un formato seguro para guardar en disco
func serializar() -> Array:
	var lista := []
	for nombre in listado_ordenado:
		if not items_recolectados.has(nombre):
			continue
		var datos: Dictionary = items_recolectados[nombre]
		var icono: Texture2D = datos.get("icono")
		var modelo: PackedScene = datos.get("modelo_3d")
		lista.append({
			"nombre": nombre,
			"descripcion": datos.get("descripcion", ""),
			"icono_path": icono.resource_path if icono != null else "",
			"modelo_3d_path": modelo.resource_path if modelo != null else ""
		})
	return lista


# Reconstruye el inventario cargando de nuevo íconos y modelos 3D
func deserializar(lista: Array) -> void:
	limpiar()
	for entry in lista:
		var icono: Texture2D = null
		var modelo: PackedScene = null
		var icono_path: String = entry.get("icono_path", "")
		var modelo_path: String = entry.get("modelo_3d_path", "")
		if icono_path != "" and ResourceLoader.exists(icono_path):
			icono = load(icono_path)
		if modelo_path != "" and ResourceLoader.exists(modelo_path):
			modelo = load(modelo_path)
		agregar_objeto(entry.get("nombre", ""), entry.get("descripcion", ""), icono, modelo)
