extends Marker3D
class_name CinemaMarker

# Esta propiedad la escribes en TrenchBroom (ej: targetname "cine_puerta")
@export var targetname: String = ""

func _ready() -> void:
	# Nos metemos al grupo para que el pedestal nos encuentre
	add_to_group("marcadores_cine")
