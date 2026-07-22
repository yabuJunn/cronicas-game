class_name EstacionDeCarga
extends InteractableItem

@export_group("Configuración de Estación")
@export var tiempo_animacion_carga: float = 2.0
@export var esfera_cargada_nombre: String = "Esfera de Energía"
@export_multiline var esfera_cargada_desc: String = "Brilla con una energía poderosa."

@onready var esferaCargando: MeshInstance3D = $EnergySphere
@onready var omniLigth: OmniLight3D = $EnergySphere/OmniLight3D
@onready var particulas: GPUParticles3D = $EnergySphere/OmniLight3D/GPUParticles3D

var chargedEnergySphereUI: PackedScene = preload("res://scenes/objects/Inventory/energy_sphere_ui.tscn")
var chargedEnergySphereIcon = preload("res://icons/inventory/energySphere.png")

var ya_activado: bool = false
var ya_cargado: bool = false
var materialEsferaCargando: StandardMaterial3D

func _ready() -> void:
	# La estación en sí no se recoge, solo se interactúa con ella
	se_puede_recoger = false
	
	if esferaCargando:
		materialEsferaCargando = esferaCargando.get_active_material(0)
		
	estadoInicialCarga()
	super._ready()


# Sobrescribimos el texto dinámico según los 4 estados de la estación
func _obtener_texto_interaccion() -> String:
	# ESTADO 1: En proceso de carga
	if ya_activado and not ya_cargado:
		outline_habilitado = false
		return "Cargando..."

	# ESTADO 2: Carga terminada (Lista para recoger la esfera llena)
	if ya_activado and ya_cargado:
		outline_habilitado = true
		if texto_recoger != "":
			return texto_recoger
		return "[ E ] Recoger " + esfera_cargada_nombre

	# ESTADO 3 y 4: Estación vacía -> Comprobamos si tiene la esfera descargada en el inventario
	var tiene_objeto_req: bool = _comprobar_item_requerido()

	if tiene_objeto_req:
		outline_habilitado = true
		if texto_con_objeto != "":
			return texto_con_objeto
		var nombre_req = item_clave_requerido if item_clave_requerido != "" else "Objeto"
		return "[ E ] Colocar " + nombre_req
	else:
		outline_habilitado = false
		if texto_sin_objeto != "":
			return texto_sin_objeto
		var nombre_req = item_clave_requerido if item_clave_requerido != "" else "Objeto"
		return "[ Requieres: " + nombre_req + " ]"


func interactuar() -> void:
	# 1. Recoger esfera cargada
	if ya_activado and ya_cargado:
		recogerEsferaCargada()
		return

	# 2. Si está cargando, ignoramos clics adicionales
	if ya_activado and not ya_cargado:
		return

	# 3. Colocar esfera e iniciar carga
	if _comprobar_item_requerido():
		ya_activado = true
		
		# Consumimos la esfera del inventario
		if Inventory.has_method("remover_objeto"):
			Inventory.remover_objeto(item_clave_requerido)
		elif Inventory.has_method("remove_item"):
			Inventory.remove_item(item_clave_requerido)

		estadoInicialCarga()
		await animacionDeCarga()
		ya_cargado = true


func _comprobar_item_requerido() -> bool:
	if item_clave_requerido == "":
		return false
	if Inventory.has_method("tiene_objeto"):
		return Inventory.tiene_objeto(item_clave_requerido)
	elif Inventory.has_method("has_item"):
		return Inventory.has_item(item_clave_requerido)
	return false


func estadoInicialCarga() -> void:
	if esferaCargando:
		esferaCargando.visible = false
	if materialEsferaCargando:
		materialEsferaCargando.emission_enabled = false
		materialEsferaCargando.emission_energy_multiplier = 0.0
	if omniLigth:
		omniLigth.visible = false
		omniLigth.light_energy = 0.0
	if particulas:
		particulas.emitting = false


func animacionDeCarga() -> void:
	if omniLigth: omniLigth.visible = true
	if particulas: particulas.emitting = true
	if esferaCargando: esferaCargando.visible = true

	var animacionDeCargaTween = create_tween().set_parallel(true)
	
	if materialEsferaCargando:
		materialEsferaCargando.emission_enabled = true
		animacionDeCargaTween.tween_property(materialEsferaCargando, "emission_energy_multiplier", 2.81, tiempo_animacion_carga)
	
	if omniLigth:
		animacionDeCargaTween.tween_property(omniLigth, "light_energy", 1.0, tiempo_animacion_carga)

	await animacionDeCargaTween.finished


func recogerEsferaCargada() -> void:
	estadoInicialCarga()
	ya_activado = false
	ya_cargado = false
	
	Inventory.agregar_objeto(esfera_cargada_nombre, esfera_cargada_desc, chargedEnergySphereIcon, chargedEnergySphereUI)
