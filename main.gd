extends Node3D

var car: CharacterBody3D
var camera: Camera3D
var speed_label: Label
var gear_label: Label
var steer_left := false
var steer_right := false
var throttle := false
var brake := false
var speed := 0.0
var heading := 0.0

const MAX_SPEED := 42.0
const ACCEL := 20.0
const BRAKE_POWER := 34.0
const DRAG := 4.5
const TURN_RATE := 1.55

func _ready() -> void:
	_build_world()
	_build_car()
	_build_camera()
	_build_ui()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.55) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _visual_box(parent: Node3D, n: String, pos: Vector3, size: Vector3, color: Color, metallic: float = 0.0, roughness: float = 0.55) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = n
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color, metallic, roughness)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _solid_box(n: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = n
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = _material(color)
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.30, 0.53)
	sky_mat.sky_horizon_color = Color(0.60, 0.76, 0.91)
	sky_mat.ground_bottom_color = Color(0.12, 0.16, 0.14)
	sky_mat.ground_horizon_color = Color(0.42, 0.49, 0.48)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.88)
	env.ambient_light_energy = 0.85
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	_solid_box("CityGround", Vector3(0, -0.65, 0), Vector3(260, 1, 260), Color(0.16, 0.31, 0.19))
	_solid_box("AsphaltRoad", Vector3(0, -0.02, 0), Vector3(17, 0.12, 240), Color(0.075, 0.085, 0.105))
	_solid_box("SidewalkLeft", Vector3(-9.7, 0.0, 0), Vector3(2.2, 0.24, 240), Color(0.58, 0.60, 0.60))
	_solid_box("SidewalkRight", Vector3(9.7, 0.0, 0), Vector3(2.2, 0.24, 240), Color(0.58, 0.60, 0.60))
	_visual_box(self, "RoadEdgeLeft", Vector3(-8.55, 0.08, 0), Vector3(0.12, 0.08, 240), Color(0.88, 0.84, 0.68))
	_visual_box(self, "RoadEdgeRight", Vector3(8.55, 0.08, 0), Vector3(0.12, 0.08, 240), Color(0.88, 0.84, 0.68))

	for z in range(-112, 120, 12):
		_visual_box(self, "CenterLine", Vector3(0, 0.065, z), Vector3(0.16, 0.025, 5.2), Color(1.0, 0.91, 0.62))

	for i in range(24):
		var z := -112.0 + float(i) * 9.5
		var h_left := 9.0 + float((i * 7) % 8)
		var h_right := 10.0 + float((i * 5) % 9)
		var colors := [Color(0.31, 0.36, 0.43), Color(0.43, 0.37, 0.33), Color(0.34, 0.42, 0.44), Color(0.40, 0.40, 0.47)]
		_build_building(-18.0, z, h_left, colors[i % colors.size()], i)
		_build_building(18.0, z - 4.5, h_right, colors[(i + 2) % colors.size()], i + 3)
		if i % 2 == 0:
			_build_tree(-11.1, z + 2.5, 1.0 + float(i % 3) * 0.12)
			_build_tree(11.1, z - 2.5, 1.0 + float((i + 1) % 3) * 0.12)
		if i % 3 == 0:
			_build_streetlight(-10.8, z - 5.0)
			_build_streetlight(10.8, z - 1.0)

func _build_building(x: float, z: float, h: float, wall_color: Color, seed: int) -> void:
	var width := 11.5
	var depth := 8.2
	_visual_box(self, "ModernBuilding", Vector3(x, h * 0.5, z), Vector3(width, h, depth), wall_color, 0.12, 0.78)
	var road_side := 1.0 if x < 0.0 else -1.0
	var face_x := x + road_side * (width * 0.5 + 0.035)
	var glass := _material(Color(0.12, 0.42, 0.61), 0.38, 0.18)
	for floor_index in range(max(2, int(h / 2.8))):
		var wy := 1.7 + float(floor_index) * 2.7
		for col in range(3):
			var wz := z - 2.7 + float(col) * 2.7
			var window := MeshInstance3D.new()
			var pane := BoxMesh.new()
			pane.size = Vector3(0.07, 1.45, 1.75)
			window.mesh = pane
			window.material_override = glass
			window.position = Vector3(face_x, wy, wz)
			add_child(window)
			_visual_box(self, "WindowFrame", Vector3(face_x + road_side * 0.045, wy, wz), Vector3(0.08, 0.09, 1.9), Color(0.10, 0.13, 0.17))
	_visual_box(self, "BuildingCanopy", Vector3(x, 0.55, z), Vector3(width + 0.35, 0.35, depth + 0.35), Color(0.16, 0.19, 0.23), 0.25, 0.45)

func _build_tree(x: float, z: float, scale_factor: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16 * scale_factor
	trunk_mesh.bottom_radius = 0.22 * scale_factor
	trunk_mesh.height = 1.7 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color(0.25, 0.16, 0.10))
	trunk.position = Vector3(x, 0.85 * scale_factor, z)
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0 * scale_factor
	crown_mesh.height = 2.0 * scale_factor
	crown.mesh = crown_mesh
	crown.material_override = _material(Color(0.10, 0.34, 0.19), 0.0, 0.9)
	crown.position = Vector3(x, 2.0 * scale_factor, z)
	add_child(crown)

func _build_streetlight(x: float, z: float) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 5.5
	pole.mesh = pole_mesh
	pole.material_override = _material(Color(0.12, 0.15, 0.19), 0.65, 0.35)
	pole.position = Vector3(x, 2.75, z)
	add_child(pole)
	var arm_dir := -1.0 if x < 0.0 else 1.0
	_visual_box(self, "LampArm", Vector3(x + arm_dir * 0.65, 5.35, z), Vector3(1.35, 0.08, 0.08), Color(0.12, 0.15, 0.19), 0.6, 0.35)
	var lamp_mat := _material(Color(1.0, 0.88, 0.57), 0.0, 0.2)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.72, 0.35)
	lamp_mat.emission_energy_multiplier = 0.5
	var lamp := _visual_box(self, "StreetLamp", Vector3(x + arm_dir * 1.2, 5.22, z), Vector3(0.42, 0.13, 0.35), Color(1.0, 0.88, 0.57), 0.0, 0.2)
	lamp.material_override = lamp_mat

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "PlayerCar"
	car.position = Vector3(0, 0.82, 35)
	add_child(car)

	# Low, wide sports-car chassis and sculpted body.
	_visual_box(car, "LowerChassis", Vector3(0, 0.02, 0), Vector3(2.12, 0.42, 4.45), Color(0.025, 0.035, 0.05), 0.65, 0.3)
	_visual_box(car, "SportsBody", Vector3(0, 0.28, 0), Vector3(2.28, 0.55, 4.25), Color(0.025, 0.24, 0.48), 0.82, 0.2)
	_visual_box(car, "FrontHood", Vector3(0, 0.56, 1.22), Vector3(2.12, 0.16, 1.22), Color(0.035, 0.31, 0.62), 0.78, 0.2)
	_visual_box(car, "RearDeck", Vector3(0, 0.55, -1.48), Vector3(2.08, 0.15, 0.78), Color(0.025, 0.20, 0.42), 0.78, 0.22)
	_visual_box(car, "Cabin", Vector3(0, 0.91, -0.12), Vector3(1.72, 0.78, 2.05), Color(0.035, 0.055, 0.085), 0.55, 0.18)
	_visual_box(car, "Roof", Vector3(0, 1.32, -0.22), Vector3(1.62, 0.13, 1.48), Color(0.025, 0.20, 0.37), 0.75, 0.18)

	# Panoramic front and rear glass.
	_visual_box(car, "Windshield", Vector3(0, 1.03, 0.83), Vector3(1.56, 0.48, 0.075), Color(0.035, 0.20, 0.29), 0.5, 0.12)
	_visual_box(car, "RearGlass", Vector3(0, 1.02, -1.08), Vector3(1.52, 0.43, 0.07), Color(0.035, 0.18, 0.27), 0.5, 0.12)
	for side in [-1.0, 1.0]:
		_visual_box(car, "SideWindow", Vector3(side * 0.875, 1.03, -0.15), Vector3(0.055, 0.43, 1.45), Color(0.055, 0.24, 0.34), 0.55, 0.14)
		_visual_box(car, "DoorSill", Vector3(side * 1.12, 0.18, -0.05), Vector3(0.08, 0.18, 2.1), Color(0.012, 0.02, 0.03), 0.55, 0.28)
		_visual_box(car, "Mirror", Vector3(side * 1.13, 0.87, 0.62), Vector3(0.24, 0.16, 0.30), Color(0.02, 0.10, 0.20), 0.7, 0.2)

	# Front grille, bumper, headlights and rear lights.
	_visual_box(car, "FrontBumper", Vector3(0, 0.12, 2.13), Vector3(2.22, 0.25, 0.18), Color(0.012, 0.018, 0.028), 0.5, 0.32)
	_visual_box(car, "FrontGrille", Vector3(0, 0.34, 2.145), Vector3(0.72, 0.22, 0.035), Color(0.008, 0.012, 0.018), 0.15, 0.45)
	for side in [-1.0, 1.0]:
		var headlight_mat := _material(Color(0.82, 0.94, 1.0), 0.1, 0.15)
		headlight_mat.emission_enabled = true
		headlight_mat.emission = Color(0.65, 0.85, 1.0)
		headlight_mat.emission_energy_multiplier = 0.65
		var headlamp := _visual_box(car, "LEDHeadlight", Vector3(side * 0.78, 0.48, 2.14), Vector3(0.48, 0.15, 0.055), Color(0.82, 0.94, 1.0), 0.1, 0.15)
		headlamp.material_override = headlight_mat
		var tail_mat := _material(Color(0.9, 0.025, 0.02), 0.15, 0.2)
		tail_mat.emission_enabled = true
		tail_mat.emission = Color(1.0, 0.015, 0.01)
		tail_mat.emission_energy_multiplier = 0.6
		var tail := _visual_box(car, "TailLight", Vector3(side * 0.78, 0.49, -2.14), Vector3(0.52, 0.13, 0.055), Color(0.9, 0.025, 0.02), 0.15, 0.2)
		tail.material_override = tail_mat
	_visual_box(car, "RearBumper", Vector3(0, 0.12, -2.15), Vector3(2.2, 0.24, 0.18), Color(0.012, 0.018, 0.028), 0.5, 0.32)
	_visual_box(car, "RearSpoiler", Vector3(0, 0.91, -1.91), Vector3(2.05, 0.10, 0.32), Color(0.018, 0.035, 0.06), 0.72, 0.25)
	for side in [-1.0, 1.0]:
		_visual_box(car, "SpoilerSupport", Vector3(side * 0.62, 0.75, -1.82), Vector3(0.07, 0.28, 0.08), Color(0.02, 0.025, 0.035))

	# Four detailed wheels with alloy rims.
	for x in [-1.13, 1.13]:
		for z in [-1.38, 1.38]:
			var wheel := MeshInstance3D.new()
			wheel.name = "PerformanceTyre"
			var tyre := CylinderMesh.new()
			tyre.top_radius = 0.40
			tyre.bottom_radius = 0.40
			tyre.height = 0.24
			wheel.mesh = tyre
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, -0.12, z)
			wheel.material_override = _material(Color(0.012, 0.014, 0.018), 0.05, 0.88)
			car.add_child(wheel)
			var rim := MeshInstance3D.new()
			var rim_mesh := CylinderMesh.new()
			rim_mesh.top_radius = 0.235
			rim_mesh.bottom_radius = 0.235
			rim_mesh.height = 0.255
			rim.mesh = rim_mesh
			rim.rotation_degrees.z = 90
			rim.position = Vector3(x * 1.012, -0.12, z)
			rim.material_override = _material(Color(0.55, 0.61, 0.68), 0.9, 0.22)
			car.add_child(rim)
			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.075
			hub_mesh.bottom_radius = 0.075
			hub_mesh.height = 0.27
			hub.mesh = hub_mesh
			hub.rotation_degrees.z = 90
			hub.position = Vector3(x * 1.025, -0.12, z)
			hub.material_override = _material(Color(0.04, 0.06, 0.08), 0.85, 0.2)
			car.add_child(hub)

	var collision := CollisionShape3D.new()
	var car_shape := BoxShape3D.new()
	car_shape.size = Vector3(2.15, 1.35, 4.35)
	collision.shape = car_shape
	car.add_child(collision)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 70
	add_child(camera)
	camera.global_position = car.global_position + Vector3(0, 5.2, -9.5)
	camera.look_at(car.global_position + Vector3(0, 0.8, 0))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var speed_panel := PanelContainer.new()
	speed_panel.position = Vector2(22, 18)
	speed_panel.custom_minimum_size = Vector2(190, 68)
	root.add_child(speed_panel)
	speed_label = Label.new()
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	speed_label.text = "0 km/h"
	speed_panel.add_child(speed_label)

	gear_label = Label.new()
	gear_label.position = Vector2(34, 91)
	gear_label.add_theme_font_size_override("font_size", 20)
	gear_label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	gear_label.text = "دنده: N"
	root.add_child(gear_label)

	_make_button(root, "◀", Vector2(28, -118), Vector2(100, 88), "left")
	_make_button(root, "▶", Vector2(142, -118), Vector2(100, 88), "right")
	_make_button(root, "گاز", Vector2(-252, -122), Vector2(112, 96), "gas")
	_make_button(root, "ترمز", Vector2(-128, -122), Vector2(112, 96), "brake")

func _make_button(root: Control, caption: String, offset: Vector2, button_size: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = caption
	button.size = button_size
	button.anchor_left = 0 if offset.x >= 0 else 1
	button.anchor_right = 0 if offset.x >= 0 else 1
	button.anchor_top = 1
	button.anchor_bottom = 1
	button.position = offset
	button.add_theme_font_size_override("font_size", 27)
	button.modulate = Color(0.88, 0.94, 1.0, 0.9)
	root.add_child(button)
	button.button_down.connect(func(): _set_action(action, true))
	button.button_up.connect(func(): _set_action(action, false))

func _set_action(action: String, value: bool) -> void:
	match action:
		"left": steer_left = value
		"right": steer_right = value
		"gas": throttle = value
		"brake": brake = value

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			throttle = event.pressed
		if event.keycode == KEY_S or event.keycode == KEY_DOWN:
			brake = event.pressed
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			steer_left = event.pressed
		if event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			steer_right = event.pressed

func _physics_process(delta: float) -> void:
	if throttle:
		speed = move_toward(speed, MAX_SPEED, ACCEL * delta)
	elif brake:
		speed = move_toward(speed, 0.0, BRAKE_POWER * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)

	var steer := float(steer_right) - float(steer_left)
	if abs(speed) > 0.2:
		heading -= steer * TURN_RATE * delta * clamp(abs(speed) / 8.0, 0.25, 1.0)
	car.rotation.y = heading
	var forward := Vector3(sin(heading), 0, cos(heading))
	car.velocity = forward * speed
	car.velocity.y = -1.0
	car.move_and_slide()

	var target := car.global_position + Vector3(0, 5.0, 0) - forward * 9.2
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-4.5 * delta))
	camera.look_at(car.global_position + Vector3(0, 1.0, 0))
	speed_label.text = str(round(abs(speed) * 3.6)) + " km/h"
	if abs(speed) < 0.5:
		gear_label.text = "دنده: N"
	elif abs(speed) < 12.0:
		gear_label.text = "دنده: 1"
	elif abs(speed) < 23.0:
		gear_label.text = "دنده: 2"
	elif abs(speed) < 34.0:
		gear_label.text = "دنده: 3"
	else:
		gear_label.text = "دنده: 4"
