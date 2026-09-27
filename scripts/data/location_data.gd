class_name LocationData
extends Resource
## An expedition destination shown on the region map.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost_food: int = 1
@export var cost_water: int = 1
## Position of the marker on the map texture (pixels).
@export var map_position: Vector2 = Vector2.ZERO
@export var marker_radius: float = 14.0
## Only playable locations can be visited in this build.
@export var playable: bool = false
## Large region scene the expedition starts in.
@export_file("*.tscn") var region_scene: String = ""
