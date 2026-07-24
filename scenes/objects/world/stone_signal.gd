class_name PiedraRunica
extends InteractibleObjectTextOpener

@export_group("Configuración Mística")
@export var duracion_animacion: float = 1.0     # Tiempo en segundos que tarda en encender/apagar
@export var luz_energia_maxima: float = 0.8     # Intensidad de la OmniLight3D
@export var emision_energia_maxima: float = 1.2 # Brillo del grabado
@export var color_grabado: Color = Color(0.2, 0.7, 1.0) # Color místico del brillo

@onready var textMesh: MeshInstance3D = $TextMesh
@onready var AreaActivation: Area3D = $Area3D
@onready var ligth: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $OmniLight3D/GPUParticles3D

var material_malla: StandardMaterial3D
var tween_activo: Tween

func _ready() -> void:
	super._ready()

	# 1. Aseguramos visibilidad
	if ligth: ligth.visible = true
	if particles: particles.visible = true

	# 2. Copia única del material
	if textMesh:
		var mat_original = textMesh.get_active_material(0)
		if mat_original:
			material_malla = mat_original.duplicate() as StandardMaterial3D
			textMesh.set_surface_override_material(0, material_malla)
			
			material_malla.emission_enabled = true
			material_malla.emission = color_grabado
			material_malla.emission_energy_multiplier = 0.0

	# 3. Apagado inicial
	if ligth: ligth.light_energy = 0.0
	if particles: particles.emitting = false

	# 4. Conectamos señales del Area3D SOLAMENTE para efectos de proximidad
	if AreaActivation:
		AreaActivation.body_entered.connect(_on_area_3d_body_entered)
		AreaActivation.body_exited.connect(_on_area_3d_body_exited)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		animar_efecto(true)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body is CharacterBody3D:
		animar_efecto(false)
		# Si el jugador se aleja físicamente mientras lee, cerramos el diálogo por seguridad
		if DialogueSystem.esta_activo:
			DialogueSystem.cerrar_dialogo()


func animar_efecto(encender: bool) -> void:
	if tween_activo and tween_activo.is_valid():
		tween_activo.kill()

	tween_activo = create_tween().set_parallel(true)
	
	var luz_objetivo: float = luz_energia_maxima if encender else 0.0
	var emision_objetivo: float = emision_energia_maxima if encender else 0.0

	if ligth:
		tween_activo.tween_property(ligth, "light_energy", luz_objetivo, duracion_animacion)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if material_malla:
		tween_activo.tween_property(material_malla, "emission_energy_multiplier", emision_objetivo, duracion_animacion)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if particles:
		particles.emitting = encender
