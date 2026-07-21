extends StaticBody3D

# Tiempo en segundos que tarda en dar una vuelta completa (360°)
@export var velocidad_vuelta: float = 6

func _ready() -> void:
	# Creamos el Tween y le indicamos que se repita infinitamente (set_loops)
	var tween = create_tween().set_loops()
	
	# Usamos transición LINEAR para que mantenga una velocidad constante
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Anima la rotación añadiendo 360° (TAU en radianes)
	# Cambia "rotation:z" por "rotation:x" o "rotation:y" según cómo esté orientado tu modelo
	tween.tween_property(self, "rotation:z", TAU, velocidad_vuelta).as_relative()
