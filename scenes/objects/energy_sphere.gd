extends InteractableItem

func _ready() -> void:
	# Llamamos al _ready de la clase padre para que configure el shader
	super._ready() 
	
	# Y aquí añades tu lógica única para este objeto
	print("La esfera esta lista para recogerse")
