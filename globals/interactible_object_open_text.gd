class_name InteractibleObjectTextOpener
extends InteractableItem

@export_group("Configuración de Texto")
@export_multiline var texto_a_mostrar: String = "Primera página...||Y esta es la segunda página.||Fin."
@export var separador_paginas: String = "||"

var jugador_en_rango: bool = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		jugador_en_rango = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		jugador_en_rango = false
		# Si el jugador se aleja mientras lee, cerramos el diálogo automáticamente
		if DialogueSystem.esta_activo:
			DialogueSystem.cerrar_dialogo()

func _unhandled_input(event: InputEvent) -> void:
	if jugador_en_rango and not DialogueSystem.esta_activo:
		if event.is_action_pressed("interact"):
			# Consumimos el evento para no activar otras cosas a la vez
			get_viewport().set_input_as_handled() 
			DialogueSystem.iniciar_dialogo(texto_a_mostrar, separador_paginas)
