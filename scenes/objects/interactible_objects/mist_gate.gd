extends InteractableItem

# Gate (InteractableItem)

@export var puerta_id: String = ""
@export var color_emision: Color = Color("4bc1c2")
@export var multiplicador_energia_max: float = 2.0

@onready var activeIndicatorMesh: MeshInstance3D = $GateStaticBody/ActiveIndicatorMesh
@onready var ligth1: OmniLight3D = $GateStaticBody/OmniLight3D
@onready var ligth2: OmniLight3D = $GateStaticBody/OmniLight3D2
@onready var fogGageSwitch: MechanismSwitch = $FogGateSwitch

var animationTime: float = 10
var isActive: bool = false
var animationPlayed: bool = false


func _ready() -> void:
	super._ready()
	se_puede_recoger = false
	
	ligth1.light_energy = 0
	ligth2.light_energy = 0
	
	# Desactivar flote y rotación si ya viene colocada desde el editor
	_desactivar_animaciones_esfera()
	
	if puerta_id != "":
		add_to_group(puerta_id)
		
		if fogGageSwitch:
			fogGageSwitch.camera_marker_id = puerta_id
			fogGageSwitch.target_id = puerta_id
	else:
		push_warning("Advertencia: puerta_id no asignado en la puerta: ", name)


func open(id_recibido: String = "") -> void:
	if id_recibido != puerta_id and puerta_id != "":
		return
		
	if animationPlayed:
		return
		
	animationPlayed = true
	isActive = true
	print("open() ejecutado con éxito en puerta: ", name, " (ID: ", id_recibido, ")")
	
	# Desactivar flote y rotación al activar el mecanismo
	_desactivar_animaciones_esfera()

	if activeIndicatorMesh == null:
		push_warning("Advertencia: No se encontró activeIndicatorMesh en ", name)
		return

	var mat_activo = activeIndicatorMesh.get_active_material(0)
	if mat_activo is StandardMaterial3D or mat_activo is ORMMaterial3D:
		var mat_unico = mat_activo.duplicate()
		activeIndicatorMesh.set_surface_override_material(0, mat_unico)
		
		mat_unico.emission_enabled = true
		mat_unico.emission = color_emision
		mat_unico.emission_energy_multiplier = 0.0
		
		ligth1.light_energy = 0
		ligth2.light_energy = 0
		
		var activatedAnimationTween = create_tween().set_parallel(true)
		activatedAnimationTween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		
		activatedAnimationTween.tween_property(mat_unico, "emission_energy_multiplier", multiplicador_energia_max, animationTime)
		activatedAnimationTween.tween_property(ligth1, "light_energy", 2.0, animationTime)
		activatedAnimationTween.tween_property(ligth2, "light_energy", 2.0, animationTime)


# Función auxiliar para apagar tanto el flote como la rotación de la esfera colocada
func _desactivar_animaciones_esfera() -> void:
	print("Desactivar animacion de mist core")
	if fogGageSwitch and "placedEnergySphere" in fogGageSwitch and fogGageSwitch.placedEnergySphere:
		var esfera = fogGageSwitch.placedEnergySphere
		if esfera.has_method("set_floating"):
			esfera.set_floating(false)
		if esfera.has_method("set_rotating"):
			esfera.set_rotating(false)
