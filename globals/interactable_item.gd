class_name InteractableItem
extends Node3D

# --- PROPIEDADES DEL OBJETO ---
@export var item_name: String = "Objeto Desconocido"
@export_multiline var item_description: String = "Descripción por defecto."
@export var se_puede_recoger: bool = true

@export var mesh: MeshInstance3D 
var outline_material: ShaderMaterial

# Ruta de respaldo por si algún objeto de FuncGodot nace vacío
const RUTA_MATERIAL_BASE = "res://materials/interactible_item_default_material_3d.tres" 

func _ready() -> void:
	if mesh == null:
		push_warning("Falta asignar la malla en el objeto interactuable: ", name)
		return
		
	# 1. COMPROBACIÓN Y DUPLICADO CRÍTICO
	if mesh.material_overlay == null:
		# Si viene de FuncGodot sin material, le cargamos uno nuevo y único
		var recurso_base = load(RUTA_MATERIAL_BASE)
		if recurso_base:
			mesh.material_overlay = recurso_base.duplicate()
	else:
		# ¡AQUÍ ESTABA EL TRUCO! Si ya lo traía desde el editor (ExtResource 10_1qcro),
		# LO DUPLICAMOS por completo para romper el enlace compartido en memoria.
		mesh.material_overlay = mesh.material_overlay.duplicate()
			
	# 2. Ahora que el material es 100% único de este objeto, manejamos su next_pass
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
