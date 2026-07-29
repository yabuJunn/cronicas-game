extends CollisionShape3D

# MistBarrier (CollisionShape3D)

@export_group("Configuración de Barrera")
# Debe coincidir exactamente con el target_id del MechanismSwitch
@export var puerta_id: String = ""
@export var meshInstance: MeshInstance3D
@export var fogVolume: FogVolume

@export_group("Ajuste de Margen de Malla")
## Factor de escala relativo a la colisión (ej: X: 0.98, Y: 0.98, Z: 0.80).
## Reducir principalmente Z (profundidad) evita que la cabeza del jugador
## entre a las crestas deformadas por el shader antes de colisionar.
@export var factor_escala_malla: Vector3 = Vector3(0.98, 0.98, 0.95)

@export_group("Configuración de Fog Base")
## Altura en metros del FogVolume en la base (ej: 0.5m)
@export var altura_fog_base: float = 0.5

@export_group("Animación de Salida")
@export var duracion_desvanecimiento: float = 6.0

var ya_abierto: bool = false


func _ready() -> void:
	# 1. Unirse al grupo correspondiente
	if puerta_id != "":
		add_to_group(puerta_id)
	else:
		push_warning("Advertencia: puerta_id no asignado en la barrera de niebla: ", name)

	# 2. Búsqueda automática de nodos si no fueron asignados en el inspector
	if meshInstance == null and has_node("MeshInstance3D"):
		meshInstance = $MeshInstance3D as MeshInstance3D

	if fogVolume == null and has_node("FogVolume"):
		fogVolume = $FogVolume as FogVolume

	# 3. Sincronizar tamaños aplicando el margen a la malla y posicionando el FogVolume en la base
	_sincronizar_tamano_niebla()


func _sincronizar_tamano_niebla() -> void:
	if not (shape is BoxShape3D):
		return
		
	var box_shape := shape as BoxShape3D
	
	# Calculamos el tamaño con la reducción porcentual aplicada a la Malla
	var tamano_malla_reducido: Vector3 = box_shape.size * factor_escala_malla
	
	# Sincronizar Malla 3D (Mantiene la altura completa de 200m o la asignada al CollisionShape3D)
	if meshInstance != null:
		if meshInstance.mesh is BoxMesh:
			meshInstance.mesh = meshInstance.mesh.duplicate()
			var box_mesh := meshInstance.mesh as BoxMesh
			box_mesh.size = tamano_malla_reducido
			
			# Subdivisiones necesarias para deformar vértices a gran escala
			box_mesh.subdivide_width = 70
			box_mesh.subdivide_height = 25
			box_mesh.subdivide_depth = 2
		else:
			meshInstance.scale = tamano_malla_reducido

	# Sincronizar FogVolume (Restringido solo a la base)
	if fogVolume != null:
		# 1. Conserva el 100% de X y Z, pero su altura Y se fija a altura_fog_base (ej: 0.5m)
		fogVolume.size = Vector3(box_shape.size.x, altura_fog_base, box_shape.size.z)
		
		# 2. Posicionar en la base del CollisionShape3D:
		# El centro de la colisión está en Y=0. Su suelo físico está en -box_shape.size.y / 2.0.
		# Desplazamos el centro del FogVolume para que descanse justo en ese suelo.
		var offset_y_base: float = (-box_shape.size.y + altura_fog_base) * 0.5
		fogVolume.position = Vector3(0.0, offset_y_base, 0.0)


# Método invocado por MechanismSwitch vía call_group()
func open(id_recibido: String = "") -> void:
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if ya_abierto:
		return
		
	ya_abierto = true
	print("open() ejecutado en barrera de niebla: ", name)
	animacionQuitarNiebla()


func animacionQuitarNiebla() -> void:
	# 1. Desactivar la colisión de inmediato
	set_deferred("disabled", true)

	var fogTween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 2. Animar desvanecimiento del Shader de la Malla
	if meshInstance != null:
		var mat_shader = meshInstance.get_active_material(0)
		if mat_shader is ShaderMaterial:
			mat_shader = mat_shader.duplicate()
			meshInstance.set_surface_override_material(0, mat_shader)
			fogTween.tween_property(mat_shader, "shader_parameter/fade_dissolve", 0.0, duracion_desvanecimiento)

	# 3. Animar desvanecimiento del Shader del FogVolume (reducir densidad a 0)
	if fogVolume != null and fogVolume.material is ShaderMaterial:
		var mat_fog = fogVolume.material.duplicate() as ShaderMaterial
		fogVolume.material = mat_fog
		fogTween.tween_property(mat_fog, "shader_parameter/density", 0.0, duracion_desvanecimiento)

	# 4. Destruir el nodo una vez terminadas ambas animaciones
	await fogTween.finished
	queue_free()
