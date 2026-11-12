extends Node

# CHINOCK visual upgrade: smooth day/night lighting and practical vehicle/street lights.
var world_root: Node3D
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var elapsed := 0.0
const DAY_LENGTH := 240.0

func _ready() -> void:
	call_deferred("_setup_upgrade")

func _setup_upgrade() -> void:
	world_root = get_parent() as Node3D
	if world_root == null:
		return
	for child in world_root.get_children():
		if child is DirectionalLight3D:
			sun = child
		elif child is WorldEnvironment:
			world_environment = child
	_add_street_lights()
	_add_vehicle_headlights()
	_update_lighting()

func _process(delta: float) -> void:
	if world_root == null:
		return
	elapsed = fmod(elapsed + delta, DAY_LENGTH)
	_update_lighting()

func _update_lighting() -> void:
	if sun == null or world_environment == null:
		return
	var phase := elapsed / DAY_LENGTH * TAU
	var daylight := clampf(0.5 + 0.5 * sin(phase - PI * 0.5), 0.08, 1.0)
	var night := 1.0 - daylight
	sun.rotation_degrees = Vector3(-18.0 - daylight * 48.0, -30.0 + elapsed * 0.12, 0.0)
	sun.light_energy = 0.12 + daylight * 1.25
	sun.light_color = Color(1.0, 0.72 + daylight * 0.22, 0.55 + daylight * 0.42)
	var env := world_environment.environment
	if env:
		env.ambient_light_energy = 0.22 + daylight * 0.78
		env.fog_light_color = Color(0.035, 0.055, 0.12).lerp(Color(0.53, 0.66, 0.77), daylight)
	for light in get_tree().get_nodes_in_group("chinock_night_lights"):
		if light is OmniLight3D or light is SpotLight3D:
			light.visible = night > 0.38

func _add_street_lights() -> void:
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		var lamp := OmniLight3D.new()
		lamp.name = "CHINOCK_StreetGlow"
		lamp.position = Vector3(side * 10.6, 4.8, -105.0 + float(i) * 16.0)
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 1.25
		lamp.omni_range = 11.0
		lamp.shadow_enabled = false
		lamp.add_to_group("chinock_night_lights")
		world_root.add_child(lamp)

func _add_vehicle_headlights() -> void:
	var car := world_root.get_node_or_null("PlayerCar") as CharacterBody3D
	if car == null:
		return
	for side in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.name = "CHINOCK_Headlight"
		lamp.position = Vector3(side * 0.72, 0.48, 2.05)
		lamp.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
		lamp.light_color = Color(0.78, 0.88, 1.0)
		lamp.light_energy = 2.2
		lamp.spot_range = 34.0
		lamp.spot_angle = 32.0
		lamp.shadow_enabled = false
		lamp.add_to_group("chinock_night_lights")
		car.add_child(lamp)
