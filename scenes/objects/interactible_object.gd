extends RigidBody3D

# El nombre que aparecerá en la UI
@export var item_name: String = "Llave"
@export_multiline var item_description: String = "Una llave oxidada que parece abrir una puerta pesada."

# Referencia a la malla para cambiar el shader
@onready var mesh = $MeshInstance3D 
var outline_material: ShaderMaterial

func _ready() -> void:
	# Vamos directamente a la propiedad Geometry > Material Overlay
	var mat: Material = mesh.material_overlay
	
	print("Material Overlay encontrado: ", mat) # Para verificar en consola
	
	# Si encontramos el material base, y tiene un shader en su next_pass...
	if mat != null and mat.next_pass != null:
		# ¡IMPORTANTE! Duplicamos el shader para que sea único para esta llave
		outline_material = mat.next_pass.duplicate() as ShaderMaterial
		mat.next_pass = outline_material
		
		# Apagamos el borde desde el inicio por precaución (Alpha = 0)
		outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 0))

# Función que nuestro RayCast llamará
func set_highlight(active: bool) -> void:
	if outline_material != null:
		if active:
			outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 1)) # Borde blanco visible
		else:
			outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 0)) # Borde invisible
