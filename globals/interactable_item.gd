class_name InteractableItem
extends Node3D

# --- PROPIEDADES DEL OBJETO ---
@export var item_name: String = "Objeto Desconocido"
@export_multiline var item_description: String = "Descripción por defecto."

# NUEVO: Interruptor para decidir si el objeto va al inventario o se queda en el mundo
@export var se_puede_recoger: bool = true

@export var mesh: MeshInstance3D 
var outline_material: ShaderMaterial

func _ready() -> void:
	if mesh == null:
		push_warning("Falta asignar la malla en el objeto interactuable: ", name)
		return
		
	var mat: Material = mesh.material_overlay
	
	if mat != null and mat.next_pass != null:
		outline_material = mat.next_pass.duplicate() as ShaderMaterial
		mat.next_pass = outline_material
		outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 0))

func set_highlight(active: bool) -> void:
	if outline_material != null:
		if active:
			outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 1))
		else:
			outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 0))

# NUEVO: Esta es la función que el jugador llamará al presionar la 'E'
func interactuar() -> void:
	if se_puede_recoger:
		# Mandamos el objeto al Autoload del inventario
		Inventory.agregar_objeto(item_name, item_description)
		# Destruimos el objeto del mundo 3D
		queue_free()
	else:
		# Si es un objeto estático (se_puede_recoger = false), no se destruye.
		# Las clases hijas (como la caja fuerte) pueden sobreescribir esta función para hacer cosas distintas.
		print("Has interactuado con: ", item_name, " (Objeto estático)")
