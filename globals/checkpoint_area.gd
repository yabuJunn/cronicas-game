extends Area3D

## Opcional: Asigna un Marker3D interno para decir exactamente dónde aparecerá el jugador.
## Si lo dejas vacío, usará el centro de esta Area3D.
@export var punto_de_aparicion: Node3D 

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var posicion_guardada = global_position
		
		if punto_de_aparicion != null:
			posicion_guardada = punto_de_aparicion.global_position
			
		# Llamamos al Autoload
		RespawnManager.set_checkpoint(posicion_guardada)
