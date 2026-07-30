# InteractableItem Class
class_name InteractableItem
extends Node3D

# --- PROPIEDADES BÁSICAS DEL OBJETO ---
@export_group("Información Base")
@export var item_name: String = "Objeto Desconocido"
@export_multiline var item_description: String = "Descripción por defecto."
@export var se_puede_recoger: bool = true
@export var item_icon: Texture2D
@export_file("*.tscn") var ruta_modelo3d: String

# --- CONFIGURACIÓN DE PUERTAS / BLOQUEOS ---
@export_group("Configuración de Puerta / Cerradura")
@export var es_puerta: bool = false
@export var item_clave_requerido: String = "" # Nombre exacto del objeto en el inventario (Ej: "Llave Antigua")

# --- TEXTOS PERSONALIZADOS DE INTERACCIÓN ---
@export_group("Textos Personalizados (Opcional)")
@export var texto_recoger: String = ""          # Si está vacío: "[ E ] Recoger " + item_name
@export var texto_estatico: String = ""         # Si no se recoge ni es puerta: "[ E ] Leer / Inspeccionar " + item_name
@export var texto_con_objeto: String = ""       # Si es puerta y TIENES la llave
@export var texto_sin_objeto: String = ""       # Si es puerta y NO TIENES la llave

# --- VISUALES Y OUTLINE ---
@export_group("Malla")
@export var mesh: MeshInstance3D 
var outline_material: ShaderMaterial

# --- CONTROL DE OVERLAY DINÁMICO ---
var es_mirado: bool = false
var outline_habilitado: bool = true:
	set(valor):
		outline_habilitado = valor
		_actualizar_estado_outline()

# Propiedad base para que el texto cambie según el objeto (la lee el RayCast del jugador)
var texto_interaccion: String:
	get:
		return _obtener_texto_interaccion()

# Ruta de respaldo por si algún objeto de FuncGodot nace vacío
const RUTA_MATERIAL_BASE = "res://materials/interactible_item_default_material_3d.tres" 

func _ready() -> void:
	if mesh == null:
		push_warning("Falta asignar la malla en el objeto interactuable: ", name)
		return
		
	if mesh.material_overlay == null:
		var recurso_base = load(RUTA_MATERIAL_BASE)
		if recurso_base:
			mesh.material_overlay = recurso_base.duplicate()
	else:
		mesh.material_overlay = mesh.material_overlay.duplicate()
			
	var mat: Material = mesh.material_overlay
	
	if mat != null and mat.next_pass != null:
		outline_material = mat.next_pass.duplicate() as ShaderMaterial
		mat.next_pass = outline_material
		outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 0))


# --- LÓGICA DE TEXTOS DINÁMICOS ---
func _obtener_texto_interaccion() -> String:
	# CASO 1: Es una Puerta, Cerradura o Mecanismo
	if es_puerta:
		var tiene_llave: bool = false
		
		# Verificamos si el jugador tiene la llave requerida en el inventario
		if item_clave_requerido != "":
			if Inventory.has_method("tiene_objeto"):
				tiene_llave = Inventory.tiene_objeto(item_clave_requerido)
			elif Inventory.has_method("has_item"):
				tiene_llave = Inventory.has_item(item_clave_requerido)
		else:
			tiene_llave = true
			
		if tiene_llave:
			if texto_con_objeto != "":
				return texto_con_objeto
			return "[ E ] Abrir " + item_name
		else:
			if texto_sin_objeto != "":
				return texto_sin_objeto
			var req_nombre = item_clave_requerido if item_clave_requerido != "" else "Llave"
			return "[ Requieres: " + req_nombre + " ]"

	# CASO 2: Objeto que se puede recoger (Ítem de inventario)
	if se_puede_recoger:
		if texto_recoger != "":
			return texto_recoger
		return "[ E ] Recoger " + item_name

	# CASO 3: Objeto estático / Inspeccionable (Piedra rúnica, cartel, estatua)
	if texto_estatico != "":
		return texto_estatico
	return "[ E ] Leer " + item_name


func set_highlight(active: bool) -> void:
	es_mirado = active
	_actualizar_estado_outline()


func _actualizar_estado_outline() -> void:
	if outline_material != null:
		if es_mirado and outline_habilitado:
			outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 1))
		else:
			outline_material.set_shader_parameter("outline_color", Color(1, 1, 1, 0))


func interactuar() -> bool:
	if has_node("InteractibleObjectsLigth"):
		$InteractibleObjectsLigth.apagar()

	if se_puede_recoger:
		var modelo_para_inventario: PackedScene = null
		
		if ruta_modelo3d != "":
			modelo_para_inventario = load(ruta_modelo3d)
			
		Inventory.agregar_objeto(item_name, item_description, item_icon, modelo_para_inventario)
		queue_free()
		return true # Indica que el objeto se ha recogido
	else:
		#print("Has interactuado con: ", item_name, " (Objeto estático / Puerta)")
		return false # Indica que NO es un objeto de recogida
