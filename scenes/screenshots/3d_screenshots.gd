extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport

func _ready() -> void:
	# 1. Wait until the frame is fully rendered on the GPU
	await RenderingServer.frame_post_draw
	
	# 2. Get the texture from the viewport
	var viewport_texture = sub_viewport.get_texture()
	
	# 3. Convert the texture data into an Image object
	var image = viewport_texture.get_image()
	
	# 4. Save the image to your project directory
	var error = image.save_png("res://captured_scene.png")
	
	if error == OK:
		print("Image saved successfully to res://captured_scene.png")
	else:
		print("Failed to save image. Error code: ", error)
