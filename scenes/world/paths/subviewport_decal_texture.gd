extends Decal

@export_group("Dimensiones del Camino")
@export var path_width: float = 4.0       # Ancho real del camino en metros (Eje X)
@export var path_length: float = 20.0     # Largo real del camino en metros (Eje Z)
@export var decal_projection_height: float = 4.0 # Qué tan alta es la caja para proyectar en relieves

@export_group("Configuración de Textura")
@export var unit_size: int = 256          # Cuántos píxeles representa 1 metro de mundo (Densidad)
@export var texture_real_size: float = 4.0 # Cuántos metros mide tu archivo de textura original (ej: 4x4 metros)

@onready var sub_viewport: SubViewport = $"../SubViewport"
@onready var color_rect: ColorRect = $"../SubViewport/ColorRect"

func _ready() -> void:
	# Iniciamos la configuración dinámica
	setup_dynamic_path()

func setup_dynamic_path() -> void:
	# 1. Ajustar las dimensiones de la caja del Decal nativo en el espacio 3D
	size = Vector3(path_width, decal_projection_height, path_length)
	
	# 2. Calcular el tamaño del SubViewport en píxeles (Metros × Densidad de Píxeles)
	var viewport_width: int = clampi(int(path_width * unit_size), 64, 4096)
	var viewport_height: int = clampi(int(path_length * unit_size), 64, 4096)
	
	sub_viewport.size = Vector2i(viewport_width, viewport_height)
	
	# Forzamos al ColorRect 2D a estirarse por completo en el nuevo tamaño del Viewport
	# Esto evita fallos si los anclajes (anchors) no se actualizan a tiempo
	color_rect.size = Vector2(viewport_width, viewport_height)
	
	# 3. Configurar los parámetros internos del Shader del camino
	var shader_material = color_rect.material as ShaderMaterial
	if shader_material:
		# Sincronizamos la escala virtual del shader con los metros reales
		shader_material.set_shader_parameter("virtual_scale", Vector2(path_width, path_length))
		
		# Calculamos el factor de repetición (tiling) automático: (1.0 / metros_que_mide_la_textura)
		var tiling_factor: float = 1.0 / texture_real_size
		shader_material.set_shader_parameter("uv1_scale", Vector2(tiling_factor, tiling_factor))
	
	# 4. ¡Mucha atención aquí! Al cambiar el tamaño del SubViewport por código, 
	# la GPU necesita procesar el cambio de tamaño y redibujar las UVs.
	# Esperamos un cuadro completo de renderizado para asegurarnos de que no salga estirado.
	await RenderingServer.frame_post_draw
	
	# 5. Capturamos la textura limpia y finalizada desde el Viewport
	var vp_texture = sub_viewport.get_texture()
	var img = vp_texture.get_image()
	var final_texture = ImageTexture.create_from_image(img)
	
	# 6. Asignamos la nueva textura al Albedo del Decal
	texture_albedo = final_texture
