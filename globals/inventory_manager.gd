extends Node
# Inventory manager

var items_recolectados: Dictionary = {}
var listado_ordenado: Array = [] # Necesario para el carrusel


func agregar_objeto(nombre: String, descripcion: String, icono: Texture2D = null, modelo_3d: PackedScene = null, cantidad: int = 1) -> void:
	if cantidad <= 0:
		return

	if items_recolectados.has(nombre):
		items_recolectados[nombre]["cantidad"] += cantidad
		# Por si el primer objeto recogido no tenía ícono/modelo y este sí
		if items_recolectados[nombre]["icono"] == null and icono != null:
			items_recolectados[nombre]["icono"] = icono
		if items_recolectados[nombre]["modelo_3d"] == null and modelo_3d != null:
			items_recolectados[nombre]["modelo_3d"] = modelo_3d
	else:
		items_recolectados[nombre] = {
			"descripcion": descripcion,
			"icono": icono,
			"modelo_3d": modelo_3d,
			"cantidad": cantidad
		}
		if not listado_ordenado.has(nombre):
			listado_ordenado.append(nombre)

	print("Objeto recogido: ", nombre, " (Total: ", items_recolectados[nombre]["cantidad"], ")")


func tiene_objeto(nombre: String) -> bool:
	return items_recolectados.has(nombre) and items_recolectados[nombre].get("cantidad", 0) > 0


func obtener_cantidad(nombre: String) -> int:
	if items_recolectados.has(nombre):
		return items_recolectados[nombre].get("cantidad", 1)
	return 0


# Útil si algún puzzle/puerta pide varias unidades a la vez (ej. 3 Esferas de Energía)
func tiene_cantidad(nombre: String, cantidad_requerida: int) -> bool:
	return obtener_cantidad(nombre) >= cantidad_requerida


func remover_objeto(nombre: String, cantidad: int = 1) -> void:
	if not items_recolectados.has(nombre) or cantidad <= 0:
		return

	items_recolectados[nombre]["cantidad"] -= cantidad
	var restante: int = items_recolectados[nombre]["cantidad"]

	if restante <= 0:
		items_recolectados.erase(nombre)
		listado_ordenado.erase(nombre)
		print("Objeto removido por completo: ", nombre)
	else:
		print("Unidad usada de: ", nombre, " (Restantes: ", restante, ")")


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
			"cantidad": datos.get("cantidad", 1),
			"icono_path": icono.resource_path if icono != null else "",
			"modelo_3d_path": modelo.resource_path if modelo != null else ""
		})
	return lista


# Reconstruye el inventario cargando de nuevo íconos, modelos 3D y cantidades
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
		var cantidad: int = entry.get("cantidad", 1)
		agregar_objeto(entry.get("nombre", ""), entry.get("descripcion", ""), icono, modelo, cantidad)
