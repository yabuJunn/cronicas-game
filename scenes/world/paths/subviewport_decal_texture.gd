extends Decal

@export_group("Tipo de Sección")
@export var use_circle_mode: bool = false   # Si se activa, genera una plaza circular llena

@export_group("Dimensiones del Camino")
@export var path_width: float = 4.0       # Ancho de la calle en metros (Eje X)
@export var path_length: float = 20.0     # Largo del camino lineal en metros (Eje Z)
@export var decal_projection_height: float = 10.0

@export_group("Configuración del Círculo")
@export var circle_radius: float = 6.0    # Radio base de la plaza

@export_group("Configuración de Textura")
# OPTIMIZACIÓN 1: Bajamos el valor por defecto a 64 o 128. 256 es una exageración para el suelo.
@export var unit_size: int = 64           # Densidad de píxeles razonable y nítida
@export var texture_real_size: float = 4.0 # Tamaño de tu textura original (Tiling)

@export_group("Control de Ajuste Modular")
@export var curve_bends: int = 2          # S-bends para tramos rectos

@export_group("Optimización de Solapamiento")
@export var lock_to_world_grid: bool = true 
@export var layer_priority: int = 0 :       
	set(value):
		layer_priority = value
		sorting_offset = layer_priority

@onready var sub_viewport: SubViewport = $SubViewport
@onready var color_rect: ColorRect = $SubViewport/ColorRect
@onready var path_preview_mesh: MeshInstance3D = $PathPreview

func _ready() -> void:
	path_preview_mesh.visible = false
	sorting_offset = layer_priority
	setup_dynamic_path()

func setup_dynamic_path() -> void:
	# Si por alguna razón se llama dos veces y ya no hay Viewport, salimos de forma segura
	if not is_instance_valid(sub_viewport):
		return

	# 1. Definir dimensiones de la caja contenedora
	var box_width: float = path_width
	var box_length: float = path_length
	
	if use_circle_mode:
		var total_diameter: float = (circle_radius * 2.0) + path_width
		box_width = total_diameter
		box_length = total_diameter
		
	size = Vector3(box_width, decal_projection_height, box_length)
	
	# 2. Adaptar la resolución del SubViewport
	# OPTIMIZACIÓN 2: Clameamos el tamaño máximo a 2048 para blindar la tarjeta gráfica
	var max_texture_size: int = 2048
	var viewport_width: int = clampi(int(box_width * unit_size), 64, max_texture_size)
	var viewport_height: int = clampi(int(box_length * unit_size), 64, max_texture_size)
	sub_viewport.size = Vector2i(viewport_width, viewport_height)
	
	# 3. Enviar datos al ShaderMaterial
	var shader_material = color_rect.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("use_circle_mode", use_circle_mode)
		shader_material.set_shader_parameter("circle_radius", circle_radius)
		shader_material.set_shader_parameter("track_width", path_width)
		shader_material.set_shader_parameter("virtual_scale", Vector2(box_width, box_length))
		
		shader_material.set_shader_parameter("lock_to_world_grid", lock_to_world_grid)
		shader_material.set_shader_parameter("global_pos", Vector2(global_position.x, global_position.z))
		shader_material.set_shader_parameter("global_rot", global_rotation.y)
		
		var tiling_factor: float = 1.0 / texture_real_size
		shader_material.set_shader_parameter("uv1_scale", Vector2(tiling_factor, tiling_factor))
		
		if not use_circle_mode:
			var n: float = float(curve_bends)
			var perfect_frequency: float = (n * PI) / path_length
			var perfect_phase: float = (n * PI) / 2.0
			shader_material.set_shader_parameter("curve_frequency", perfect_frequency)
			shader_material.set_shader_parameter("curve_phase", perfect_phase)

	# 4. Renderizar y capturar la textura final
	await RenderingServer.frame_post_draw
	
	if is_instance_valid(sub_viewport):
		var vp_texture = sub_viewport.get_texture()
		var img = vp_texture.get_image()
		var final_texture = ImageTexture.create_from_image(img)
		
		texture_albedo = final_texture
		
		# OPTIMIZACIÓN 3: ¡EL PASO CLAVE! Destruimos el SubViewport para liberar la VRAM de inmediato
		sub_viewport.queue_free()
