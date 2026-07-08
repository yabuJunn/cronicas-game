extends Area3D

# Permite arrastrar y soltar la escena del siguiente nivel directamente desde el inspector
@export_file("*.tscn") var siguiente_nivel_ruta: String

func _ready():
	# Conectamos la señal de que algo entró a nuestra área
	body_entered.connect(_on_body_entered	)

func _on_body_entered(body):
	print("Body entered: ", body)
	# Validamos si lo que entró es el jugador y si configuramos una ruta válida
	if body.name == "Jugador" or body.is_in_group("Player"):
		if MusicManager:
			MusicManager.quitar_musica(2)
			
		if siguiente_nivel_ruta != "":
			# Bloqueamos los controles del jugador para que no se mueva durante el fade out
			if "controles_bloqueados" in body:
				body.controles_bloqueados = true
			
			# Llamamos a nuestro Singleton global
			TransicionGlobal.cambiar_de_nivel(siguiente_nivel_ruta)
