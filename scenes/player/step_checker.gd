extends Node3D


@onready var lower_ray = $LowerRay
@onready var upper_ray = $UpperRay

func can_step() -> bool:

	return lower_ray.is_colliding() and !upper_ray.is_colliding()
