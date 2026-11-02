extends Node3D

# This is only the initial project setup.
# The frog, pond and insects are temporary placeholder meshes.

@onready var game_camera: Camera3D = $Camera3D


func _ready() -> void:
    # Keep the camera fixed and pointed towards the middle of the pond.
    game_camera.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
