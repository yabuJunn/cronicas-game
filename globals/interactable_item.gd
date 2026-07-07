# InteractableItem Class
class_name InteractableItem
extends Node3D

# --- PROPIEDADES DEL OBJETO ---
@export var item_name: String = "Objeto Desconocido"
@export_multiline var item_description: String = "Descripción por defecto."
@export var se_puede_recoger: bool = true

@export var mesh: MeshInstance3D 
var outline_material: ShaderMaterial

# Propiedad base para que el texto cambie según el objeto (la lee el jugador)
# Cambia esta parte en tu clase padre:
var texto_interaccion: String:
	get:
		return _obtener_texto_interaccion()

# Esta función actúa como "virtual", los hijos la cambiarán
func _obtener_texto_interaccion() -> String:
	return "[ E ] " + item_name

# Ruta de respaldo por si algún objeto de FuncGodot nace vacío
const RUTA_MATERIAL_BASE = "res://materials/interactible_item_default_material_3d.tres" 

func _ready() -> void:
	if mesh == null:
		push_warning("Falta asignar la malla en el objeto interactuable: ", name)
		return
		
	if mesh.material_overlay == null:
		var recurso_base = load(RUTA_MATERIAL_BASE)
		if recurso_base:
			mesh.material_overlay = recurso_base.duplicate()
	else:
		mesh.material_overlay = mesh.material_overlay.duplicate()
			
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


func interactuar() -> void:
	if se_puede_recoger:
		Inventory.agregar_objeto(item_name, item_description)
		queue_free()
	else:
		print("Has interactuado con: ", item_name, " (Objeto estático)")
