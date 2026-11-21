extends Area3D
class_name CheckpointArea

@export var punto_de_aparicion: Node3D
@export var guardar_partida_al_tocar: bool = true

var activado: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var posicion_guardada := punto_de_aparicion.global_position if punto_de_aparicion != null else global_position
	RespawnManager.set_checkpoint(posicion_guardada)

	if guardar_partida_al_tocar and not activado:
		activado = true
		if SaveManager:
			SaveManager.guardar_partida(posicion_guardada)
