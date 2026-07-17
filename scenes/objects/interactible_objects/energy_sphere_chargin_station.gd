extends InteractableItem

var objeto_requerido: String = "Esfera de Energía Desactivada"
var texto_sin_objeto: String = "No tienes nada para cargar"
var texto_con_objeto: String = "Cargar esfera de energía"

@onready var esferaCargando = $EnergySphere
@onready var omniLigth = $EnergySphere/OmniLight3D
@onready var particulas = $EnergySphere/OmniLight3D/GPUParticles3D

var chargedEnergySphereUI: PackedScene = preload("res://scenes/objects/Inventory/energy_sphere_ui.tscn")
var chargedEnergySphereIcon = preload("res://icons/inventory/energySphere.png")
var ya_activado: bool = false
var ya_cargado: bool = false
var materialEsferaCargando: StandardMaterial3D
var tiempoAnimacionCarga: float = 2.0

func _ready() -> void:
	materialEsferaCargando = esferaCargando.get_active_material(0)
	super._ready() 

func _obtener_texto_interaccion() -> String:
	if ya_activado and not ya_cargado:
		return "Cargando"
	if Inventory.tiene_objeto(objeto_requerido):
		return "[ E ] " + texto_con_objeto
	if ya_cargado and ya_activado:
		return "Recoger"
	else:
		return texto_sin_objeto

func interactuar() -> void:
	if ya_activado and ya_cargado:
		recogerEsferaCargada()
		
	if Inventory.tiene_objeto(objeto_requerido):
		ya_activado = true
		estadoInicialCarga()
		
		print("¡Esfera colocada con éxito en la estación de carga!")
		Inventory.remover_objeto(objeto_requerido)
		await animacionDeCarga()
		
		ya_cargado = true
	

func estadoInicialCarga():
	esferaCargando.visible = false
	materialEsferaCargando.emission_enabled = false
	materialEsferaCargando.emission_energy_multiplier = 0
	omniLigth.visible = false
	omniLigth.light_energy = 0
	particulas.emitting = false

func animacionDeCarga():
	var animacionDeCargaTween = create_tween()
	animacionDeCargaTween.set_parallel(true)
	
	omniLigth.visible = true
	particulas.emitting = true
	esferaCargando.visible = true
	
	materialEsferaCargando.emission_enabled = true
	animacionDeCargaTween.tween_property(materialEsferaCargando, "emission_energy_multiplier", 2.81, tiempoAnimacionCarga)
	animacionDeCargaTween.tween_property(omniLigth, "light_energy", 1, tiempoAnimacionCarga)
	
	await animacionDeCargaTween.finished
	
func recogerEsferaCargada():
	estadoInicialCarga()
	ya_activado = false
	
	Inventory.agregar_objeto("Esfera de Energía", "Brilla con una energía poderosa", chargedEnergySphereIcon, chargedEnergySphereUI)
