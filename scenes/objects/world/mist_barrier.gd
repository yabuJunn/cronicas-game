extends CollisionShape3D

# MistBarrier (CollisionShape3D)

@export_group("Configuración de Barrera")
# Debe coincidir exactamente con el target_id del MechanismSwitch
@export var puerta_id: String = ""
@export var fogVolume: FogVolume 

var ya_abierto: bool = false

func _ready() -> void:
	# 1. Unirse al grupo según puerta_id para recibir la llamada de call_group()
	if puerta_id != "":
		add_to_group(puerta_id)
	else:
		push_warning("Advertencia: puerta_id no asignado en la barrera de niebla: ", name)

	# 2. Si no asignaste el FogVolume en el Inspector, intentamos obtenerlo de los hijos
	if fogVolume == null and has_node("FogVolume"):
		fogVolume = $FogVolume as FogVolume

	# 3. Igualar el tamaño del FogVolume al del CollisionShape3D
	_sincronizar_tamano_niebla()


func _sincronizar_tamano_niebla() -> void:
	if fogVolume != null and shape is BoxShape3D:
		var box_shape := shape as BoxShape3D
		fogVolume.size = box_shape.size


# Método estándar llamado por MechanismSwitch mediante call_group()
func open(id_recibido: String = "") -> void:
	# Verificamos que sea para esta barrera y que no se haya activado previamente
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if ya_abierto:
		return
		
	ya_abierto = true
	print("open() ejecutado con éxito en barrera de niebla: ", id_recibido)
	animacionQuitarNiebla()


func animacionQuitarNiebla() -> void:
	# 1. Desactivamos la colisión de inmediato para que el jugador pueda avanzar
	set_deferred("disabled", true)

	if fogVolume == null:
		_eliminar_nodo_padre_o_self()
		return

	# 2. Preparamos el Tween para una animación fluida
	var fogTween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Reducimos la altura (eje Y) progresivamente
	fogTween.tween_property(fogVolume, "size:y", 0.01, 2.0)
	
	# Si el FogVolume usa un FogMaterial, desvanecemos la densidad a 0
	if fogVolume.material is FogMaterial:
		# Duplicamos el material en tiempo de ejecución para evitar modificar a otras nieblas
		fogVolume.material = fogVolume.material.duplicate()
		fogTween.tween_property(fogVolume.material, "density", 0.0, 2.0)

	# 3. Esperamos a que la animación de 2 segundos termine
	await fogTween.finished

	# 4. Eliminamos el StaticBody3D contenedor
	_eliminar_nodo_padre_o_self()


func _eliminar_nodo_padre_o_self() -> void:
		queue_free()
