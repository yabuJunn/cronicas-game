#Inventory Manager Autoload

extends Node

# Ahora guarda: { "Nombre": { "descripcion": String, "icono": Texture2D } }
var items_recolectados: Dictionary = {}

func agregar_objeto(nombre: String, descripcion: String, icono: Texture2D = null) -> void:
	items_recolectados[nombre] = {
		"descripcion": descripcion,
		"icono": icono
	}
	print("Objeto recogido: ", nombre)

func tiene_objeto(nombre: String) -> bool:
	return items_recolectados.has(nombre)
	
func remover_objeto(nombre: String) -> void:
	if items_recolectados.has(nombre):
		items_recolectados.erase(nombre)
		print("Objeto removido del inventario: ", nombre)
	else:
		print("Advertencia: Se intentó remover '", nombre, "' pero no estaba en el inventario.")
