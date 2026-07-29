extends InteractableItem

# Gate (InteractableItem)

# Asegúrate de que coincida exactamente con el target_id del MechanismSwitch
@export var puerta_id: String = ""
@export var color_emision: Color = Color("4bc1c2")
@export var multiplicador_energia_max: float = 2.0 # Ajusta qué tan fuerte brilla
@onready var activeIndicatorMesh: MeshInstance3D = $GateStaticBody/ActiveIndicatorMesh
@onready var ligth1: OmniLight3D = $GateStaticBody/OmniLight3D
@onready var ligth2: OmniLight3D = $GateStaticBody/OmniLight3D2

var isActive: bool = false
var animationPlayed: bool = false


func _ready() -> void:
	super._ready()
	se_puede_recoger = false
	
	# Nos unimos dinámicamente al grupo definido por puerta_id
	if puerta_id != "":
		add_to_group(puerta_id)
	else:
		push_warning("Advertencia: puerta_id no asignado en la puerta: ", name)


# Método estándar llamado por cualquier MechanismSwitch mediante call_group()
func open(id_recibido: String = "") -> void:
	print("Open on mist gate", id_recibido)
	# 1. Validaciones para evitar llamadas erróneas o repetidas
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if animationPlayed:
		return
		
	animationPlayed = true
	isActive = true
	print("open() ejecutado con éxito en puerta: ", name, " (ID: ", id_recibido, ")")
	
	# 2. Verificamos que la malla exista
	if activeIndicatorMesh == null:
		push_warning("Advertencia: No se encontró activeIndicatorMesh en ", name)
		return

	# 3. Obtenemos el material
	var mat_activo = activeIndicatorMesh.get_active_material(0)
	if mat_activo is StandardMaterial3D or mat_activo is ORMMaterial3D:
		# Duplicamos el material para que este cambio de emisión no afecte a otros objetos del mapa
		var mat_unico = mat_activo.duplicate()
		activeIndicatorMesh.set_surface_override_material(0, mat_unico)
		
		# Configuración inicial de emisión
		mat_unico.emission_enabled = true
		mat_unico.emission = color_emision
		mat_unico.emission_energy_multiplier = 0.0
		
		#Configuracion Inicial de Luces
		ligth1.light_energy = 0
		ligth2.light_energy = 0
		
		# Animamos el multiplicador de energía de 0 al máximo en 2 segundos
		var activatedAnimationTween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		activatedAnimationTween.set_parallel(true)
		activatedAnimationTween.tween_property(mat_unico, "emission_energy_multiplier", multiplicador_energia_max, 6)
		activatedAnimationTween.tween_property(ligth1, "light_energy", 2, 6)
		activatedAnimationTween.tween_property(ligth2, "light_energy", 2, 6)
