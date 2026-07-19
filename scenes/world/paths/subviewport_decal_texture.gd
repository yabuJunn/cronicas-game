extends Decal

@export_group("Tipo de Sección")
@export var use_circle_mode: bool = false   # Si se activa, genera una plaza circular llena

@export_group("Dimensiones del Camino")
@export var path_width: float = 4.0       # Ancho de la calle / grosor extra en metros
@export var path_length: float = 20.0     # Largo del camino lineal en metros
@export var decal_projection_height: float = 10.0

@export_group("Configuración del Círculo")
@export var circle_radius: float = 6.0    # Radio base de la plaza

@export_group("Configuración de Textura")
@export var unit_size: int = 256          # Densidad de píxeles
@export var texture_real_size: float = 4.0 # Tamaño de tu textura original (Tiling)

@export_group("Control de Ajuste Modular")
@export var curve_bends: int = 2          # S-bends para tramos rectos

@onready var sub_viewport: SubViewport = $SubViewport
@onready var color_rect: ColorRect = $SubViewport/ColorRect
@onready var path_preview_mesh: MeshInstance3D = $PathPreview

func _ready() -> void:
	path_preview_mesh.visible = false
	setup_dynamic_path()

func setup_dynamic_path() -> void:
	# 1. Definir dimensiones de la caja contenedora (Cuadrado perfecto si es círculo)
	var box_width: float = path_width
	var box_length: float = path_length
	
	if use_circle_mode:
		var total_diameter: float = (circle_radius * 2.0) + path_width
		box_width = total_diameter
		box_length = total_diameter
		
	size = Vector3(box_width, decal_projection_height, box_length)
	
	# 2. Adaptar la resolución del SubViewport
	var viewport_width: int = clampi(int(box_width * unit_size), 64, 4096)
	var viewport_height: int = clampi(int(box_length * unit_size), 64, 4096)
	sub_viewport.size = Vector2i(viewport_width, viewport_height)
	
	# 3. Enviar datos al ShaderMaterial
	var shader_material = color_rect.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("use_circle_mode", use_circle_mode)
		shader_material.set_shader_parameter("circle_radius", circle_radius)
		shader_material.set_shader_parameter("track_width", path_width)
		shader_material.set_shader_parameter("virtual_scale", Vector2(box_width, box_length))
		
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
	
	var vp_texture = sub_viewport.get_texture()
	var img = vp_texture.get_image()
	var final_texture = ImageTexture.create_from_image(img)
	
	texture_albedo = final_texture
