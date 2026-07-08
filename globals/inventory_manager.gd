extends Node

var items_recolectados: Dictionary = {}
var listado_ordenado: Array = [] # Necesario para el carrusel

# Ahora pedimos el modelo_3d (la escena empaquetada)
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
