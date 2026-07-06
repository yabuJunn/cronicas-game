extends Node

# Usamos un diccionario para guardar el nombre del objeto y su descripción
var items_recolectados: Dictionary = {}

func agregar_objeto(nombre: String, descripcion: String) -> void:
	items_recolectados[nombre] = descripcion
	print("Objeto recogido: ", nombre)

func tiene_objeto(nombre: String) -> bool:
	return items_recolectados.has(nombre)
