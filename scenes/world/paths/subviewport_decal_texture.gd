extends Decal

@onready var sub_viewport: SubViewport = $"../SubViewport"

func _ready() -> void:
	# 1. Esperamos a que la tarjeta gráfica termine de renderizar el primer cuadro.
	# Sin esto, el viewport te devolverá una imagen vacía o transparente.
	await RenderingServer.frame_post_draw

	# 2. Llamamos a nuestra función para aplicar la textura
	update_decal_texture()

func update_decal_texture() -> void:
	# 3. Obtenemos la ViewportTexture dinámica
	var vp_texture = sub_viewport.get_texture()
	
	# 4. Sacamos los datos de píxeles puros (el Image) desde la TEXTURA, no desde el Viewport
	var img = vp_texture.get_image()
	
	# 5. Convertimos esa imagen en un ImageTexture estático que el Decal SÍ acepta de forma nativa
	var final_texture = ImageTexture.create_from_image(img)
	
	# 6. Lo asignamos finalmente al Albedo del Decal
	texture_albedo = final_texture
