extends Area3D
class_name NextLevelArea3D

# Permite arrastrar y soltar la escena del siguiente nivel directamente desde el inspector
@export_file("*.tscn") var siguiente_nivel_ruta: String


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player") or body.name == "Jugador":
		if MusicManager:
			MusicManager.quitar_musica(2.0)

		if siguiente_nivel_ruta != "":
			if "controles_bloqueados" in body:
				body.controles_bloqueados = true

			TransicionGlobal.cambiar_de_nivel(siguiente_nivel_ruta)
