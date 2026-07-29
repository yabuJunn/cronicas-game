extends CollisionShape3D

# MistBarrier (CollisionShape3D)

@export_group("Configuración de Barrera")
# Debe coincidir exactamente con el target_id del MechanismSwitch
@export var puerta_id: String = ""
@export var meshInstance: MeshInstance3D
@export var fogVolume: FogVolume

@export_group("Textura de Disolución (BOTW)")
## Textura de ruido utilizada para el patrón de disolución.
## Si se deja vacía, se generará un ruido FastNoiseLite automáticamente al cargar la escena.
@export var textura_ruido: Texture2D

## Escala del patrón de disolución. 
## Valores más altos (ej: 8.0 a 25.0) crean agujeros más pequeños y detallados en mallas grandes.
@export_range(0.1, 50.0, 0.5) var escala_ruido: float = 12.0

@export_group("Ajuste de Margen de Malla")
## Factor de escala relativo a la colisión (ej: X: 0.98, Y: 0.98, Z: 0.80).
@export var factor_escala_malla: Vector3 = Vector3(0.98, 0.98, 0.95)

@export_group("Configuración de Fog Base")
## Altura en metros del FogVolume en la base (ej: 0.5m)
@export var altura_fog_base: float = 0.5

@export_group("Animación de Salida")
## Duración total del proceso (Encendido + Disolución)
@export var duracion_desvanecimiento: float = 6.0
## Proporción del tiempo dedicada a "encender" la malla (ej: 0.35 = 35% encendido, 65% disolución)
@export_range(0.1, 0.9) var proporcion_tiempo_encendido: float = 0.35

@onready var simple_dissolve_shader: Shader = preload("res://shaders/simple_dissolve.gdshader")

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

	# 3. Sincronizar tamaños aplicando el margen a la malla
	_sincronizar_tamano_niebla()
	
	# 4. Pre-generar textura de respaldo si no fue asignada en el inspector
	_preparar_textura_ruido()


func _preparar_textura_ruido() -> void:
	if textura_ruido == null:
		var noise_gen := FastNoiseLite.new()
		noise_gen.frequency = 0.03
		var noise_tex_fallback := NoiseTexture2D.new()
		noise_tex_fallback.noise = noise_gen
		textura_ruido = noise_tex_fallback
		await noise_tex_fallback.changed


func _sincronizar_tamano_niebla() -> void:
	if not (shape is BoxShape3D):
		return
		
	var box_shape := shape as BoxShape3D
	var tamano_malla_reducido: Vector3 = box_shape.size * factor_escala_malla
	
	if meshInstance != null:
		if meshInstance.mesh is BoxMesh:
			meshInstance.mesh = meshInstance.mesh.duplicate()
			var box_mesh := meshInstance.mesh as BoxMesh
			box_mesh.size = tamano_malla_reducido
			box_mesh.subdivide_width = 70
			box_mesh.subdivide_height = 25
			box_mesh.subdivide_depth = 2
		else:
			meshInstance.scale = tamano_malla_reducido

	if fogVolume != null:
		fogVolume.size = Vector3(box_shape.size.x, altura_fog_base, box_shape.size.z)
		var offset_y_base: float = (-box_shape.size.y + altura_fog_base) * 0.5
		fogVolume.position = Vector3(0.0, offset_y_base, 0.0)


func open(id_recibido: String = "") -> void:
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if ya_abierto:
		return
		
	ya_abierto = true
	print("open() ejecutado en barrera de niebla: ", name)
	animacionQuitarNiebla()


func animacionQuitarNiebla() -> void:	
	var tiempo_encendido: float = duracion_desvanecimiento * proporcion_tiempo_encendido
	var tiempo_disolucion: float = duracion_desvanecimiento - tiempo_encendido

	# 1. Animar desvanecimiento del FogVolume en paralelo
	if fogVolume != null and fogVolume.material is ShaderMaterial:
		var mat_fog = fogVolume.material.duplicate() as ShaderMaterial
		fogVolume.material = mat_fog
		var fogTween: Tween = create_tween()
		fogTween.tween_property(mat_fog, "shader_parameter/density", 0.0, duracion_desvanecimiento)

	# 2. Configurar la Malla y su ShaderMaterial
	if meshInstance != null:
		var mat_dissolve := ShaderMaterial.new()
		mat_dissolve.shader = simple_dissolve_shader
		mat_dissolve.set_shader_parameter("noise_tex", textura_ruido)
		mat_dissolve.set_shader_parameter("noise_scale", escala_ruido)
		mat_dissolve.set_shader_parameter("t", 0.0)
		mat_dissolve.set_shader_parameter("albedo_and_emissive_color", Vector3(0.05, 0.05, 0.05))

		meshInstance.set_surface_override_material(0, mat_dissolve)
		
		# Creamos el Tween SOLAMENTE cuando el material ya está listo y sin pausas
		var meshTween: Tween = create_tween()

		# FASE 1: Encendido progresivo
		meshTween.tween_property(
			mat_dissolve, 
			"shader_parameter/albedo_and_emissive_color", 
			Vector3(2.5, 2.5, 2.5),
			tiempo_encendido
		).set_trans(Tween.TRANS_LINEAR)

		# FASE 2: Disolución
		meshTween.tween_property(
			mat_dissolve, 
			"shader_parameter/t", 
			1.05, 
			tiempo_disolucion
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Esperamos a que la secuencia de la malla termine
		await meshTween.finished
	else:
		await get_tree().create_timer(duracion_desvanecimiento).timeout

	queue_free()
