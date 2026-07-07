extends OmniLight3D

var getedItem: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Inventory.tiene_objeto("Esfera de Energía") and not getedItem:
		visible = true
	elif getedItem:
		visible = true
	else: 
		visible = false
