extends CollisionShape3D

# MistBarrier (CollisionShape3D)

@export_group("Configuración de Barrera")
# Debe coincidir exactamente con el target_id del MechanismSwitch
@export var puerta_id: String = ""
@export var meshInstance: MeshInstance3D

var ya_abierto: bool = false

func _ready() -> void:
	# 1. Unirse al grupo correspondiente
	if puerta_id != "":
		add_to_group(puerta_id)
	else:
		push_warning("Advertencia: puerta_id no asignado en la barrera de niebla: ", name)

	# 2. Si no se asignó la malla en el inspector, buscarla en los hijos
	if meshInstance == null and has_node("MeshInstance3D"):
		meshInstance = $MeshInstance3D as MeshInstance3D

	# 3. Igualar el tamaño del BoxMesh al del BoxShape3D
	_sincronizar_tamano_niebla()


func _sincronizar_tamano_niebla() -> void:
	if meshInstance != null and shape is BoxShape3D:
		var box_shape := shape as BoxShape3D
		
		# Verificamos que tenga asignada una BoxMesh
		if meshInstance.mesh is BoxMesh:
			# Duplicamos la malla para que el cambio de tamaño no altere a otras barreras
			meshInstance.mesh = meshInstance.mesh.duplicate()
			var box_mesh := meshInstance.mesh as BoxMesh
			box_mesh.size = box_shape.size
			
			# IMPORTANTE: Subdividir la malla para que el shader pueda deformar los vértices
			box_mesh.subdivide_width = 10
			box_mesh.subdivide_height = 10
			box_mesh.subdivide_depth = 10
		else:
			# Si es un modelo importado genérico, ajustamos su escala
			meshInstance.scale = box_shape.size


# Método estándar llamado por MechanismSwitch mediante call_group()
func open(id_recibido: String = "") -> void:
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if ya_abierto:
		return
		
	ya_abierto = true
	print("open() ejecutado con éxito en barrera de niebla con malla: ", id_recibido)
	animacionQuitarNiebla()


func animacionQuitarNiebla() -> void:
	# 1. Desactivar la colisión de inmediato
	set_deferred("disabled", true)

	if meshInstance == null:
		queue_free()
		return

	# 2. Duplicar el material del shader para animar solo esta instancia
	var mat_shader = meshInstance.get_active_material(0)
	if mat_shader is ShaderMaterial:
		mat_shader = mat_shader.duplicate()
		meshInstance.set_surface_override_material(0, mat_shader)

	# 3. Tween paralelo: Encoger en la altura (Y) y desvanecer alfa
	var fogTween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	#if meshInstance.mesh is BoxMesh:
	#	fogTween.tween_property(meshInstance.mesh, "size:y", 0.01, 2.0)
	#else:
	#	fogTween.tween_property(meshInstance, "scale:y", 0.01, 2.0)
		
	if mat_shader is ShaderMaterial:
		fogTween.tween_property(mat_shader, "shader_parameter/fade_dissolve", 0.0, 6)

	# 4. Esperar a que termine la animación y eliminar este nodo
	await fogTween.finished
	queue_free()
