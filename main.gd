extends Node3D

var car: CharacterBody3D
var camera: Camera3D
var speed_label: Label
var steer_left := false
var steer_right := false
var throttle := false
var brake := false
var speed := 0.0
var heading := 0.0

const MAX_SPEED := 34.0
const ACCEL := 18.0
const BRAKE_POWER := 30.0
const DRAG := 5.0
const TURN_RATE := 1.65

func _ready() -> void:
	_build_world()
	_build_car()
	_build_camera()
	_build_ui()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.88)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)

	_box("Ground", Vector3(0, -0.6, 0), Vector3(240, 1, 240), Color(0.18, 0.42, 0.20))
	_box("Road", Vector3(0, -0.02, 0), Vector3(16, 0.12, 220), Color(0.12, 0.13, 0.15))
	for z in range(-100, 110, 12):
		_box("LaneMark", Vector3(0, 0.06, z), Vector3(0.22, 0.025, 5), Color(0.95, 0.9, 0.65))
	_box("SidewalkL", Vector3(-9, 0.0, 0), Vector3(2, 0.25, 220), Color(0.48, 0.48, 0.46))
	_box("SidewalkR", Vector3(9, 0.0, 0), Vector3(2, 0.25, 220), Color(0.48, 0.48, 0.46))

	for i in range(22):
		var z := -100.0 + i * 9.0
		var h1 := 8.0 + float((i * 7) % 9)
		var h2 := 7.0 + float((i * 5) % 11)
		_box("BuildingL", Vector3(-17, h1 / 2.0, z), Vector3(12, h1, 7), Color(0.34, 0.39, 0.48))
		_box("BuildingR", Vector3(17, h2 / 2.0, z - 4), Vector3(12, h2, 7), Color(0.48, 0.40, 0.34))
		_box("WindowStripL", Vector3(-10.88, h1 * 0.55, z), Vector3(0.08, h1 * 0.55, 4.8), Color(0.35, 0.68, 0.82))
		_box("WindowStripR", Vector3(10.88, h2 * 0.55, z - 4), Vector3(0.08, h2 * 0.55, 4.8), Color(0.35, 0.68, 0.82))

func _box(n: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = n
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "PlayerCar"
	car.position = Vector3(0, 0.8, 35)
	add_child(car)

	_car_part(Vector3(0, 0.15, 0), Vector3(2.2, 0.65, 4.2), Color(0.78, 0.04, 0.035))
	_car_part(Vector3(0, 0.68, -0.25), Vector3(1.75, 0.7, 2.0), Color(0.10, 0.16, 0.22))
	for x in [-1.12, 1.12]:
		for z in [-1.35, 1.35]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.38
			cyl.bottom_radius = 0.38
			cyl.height = 0.22
			wheel.mesh = cyl
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, -0.12, z)
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.025, 0.025, 0.03)
			wheel.material_override = wm
			car.add_child(wheel)
	var collision := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(2.1, 1.25, 4.0)
	collision.shape = cs
	car.add_child(collision)

func _car_part(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.45
	mat.roughness = 0.28
	mesh.material_override = mat
	mesh.position = pos
	car.add_child(mesh)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 75
	add_child(camera)
	camera.global_position = car.global_position + Vector3(0, 5, 10)
	camera.look_at(car.global_position)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	speed_label = Label.new()
	speed_label.position = Vector2(28, 24)
	speed_label.add_theme_font_size_override("font_size", 32)
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	speed_label.text = "0 km/h"
	root.add_child(speed_label)

	_make_button(root, "◀", Vector2(35, -120), Vector2(100, 90), "left")
	_make_button(root, "▶", Vector2(150, -120), Vector2(100, 90), "right")
	_make_button(root, "گاز", Vector2(-245, -130), Vector2(110, 100), "gas")
	_make_button(root, "ترمز", Vector2(-125, -130), Vector2(100, 100), "brake")

func _make_button(root: Control, caption: String, offset: Vector2, button_size: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = caption
	button.size = button_size
	button.anchor_left = 0 if offset.x >= 0 else 1
	button.anchor_right = 0 if offset.x >= 0 else 1
	button.anchor_top = 1
	button.anchor_bottom = 1
	button.position = offset
	button.add_theme_font_size_override("font_size", 26)
	button.modulate = Color(1, 1, 1, 0.82)
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

	var target := car.global_position + Vector3(0, 4.6, 0) - forward * 8.5
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	camera.look_at(car.global_position + Vector3(0, 1.1, 0))
	speed_label.text = str(round(abs(speed) * 3.6)) + " km/h"
