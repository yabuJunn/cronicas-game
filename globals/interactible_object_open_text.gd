class_name InteractibleObjectTextOpener
extends InteractibleItemHighlight

@export_group("Configuración de Texto")
@export_multiline var texto_a_mostrar: String = "Primera página...||Y esta es la segunda página.||Fin."
@export var separador_paginas: String = "||"

@export_group("Configuración de Título")
@export var mostrar_titulo: bool = true
@export var titulo_personalizado: String = "" # Si se deja vacío y mostrar_titulo es true, usará 'item_name'

func _ready() -> void:
	# Los objetos de texto no se recogen al inventario
	se_puede_recoger = false
	super._ready()

# Esta función la invoca directamente el Raycast de tu jugador al presionar 'E' o Clic
func interactuar() -> bool:
	if not DialogueSystem.esta_activo:
		var titulo_a_enviar: String = ""
		
		if mostrar_titulo:
			# Si hay título personalizado usa ese, si no, usa el item_name heredado
			titulo_a_enviar = titulo_personalizado if titulo_personalizado != "" else item_name

		DialogueSystem.iniciar_dialogo(texto_a_mostrar, separador_paginas, titulo_a_enviar)
	return false
