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
var traffic_vehicles: Array[Node3D] = []
var pedestrians: Array[Node3D] = []
var traffic_speeds: Array[float] = []
var traffic_directions: Array[float] = []
var pedestrian_legs: Array = []
var signal_lamps: Array[MeshInstance3D] = []
var signal_clock := 0.0
var traffic_light_green := true
var game_started := false
var game_paused := false
var current_mission := 0
var mission_time := 90.0
var mission_distance := 0.0
var mission_target := 900.0
var mission_elapsed := 0.0
var menu_layer: Control
var hud_root: Control
var mission_label: Label
var timer_label: Label
var distance_label: Label
var pause_button: Button
var selected_car := 0
var car_paints: Array[Color] = [Color(0.025, 0.24, 0.48), Color(0.62, 0.045, 0.035), Color(0.035, 0.045, 0.06)]
var engine_player: AudioStreamPlayer
var exhaust_player: AudioStreamPlayer
var tire_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var exhaust_playback: AudioStreamGeneratorPlayback
var tire_playback: AudioStreamGeneratorPlayback
var engine_phase := 0.0
var exhaust_phase := 0.0
var tire_phase := 0.0
const AUDIO_RATE := 22050.0

const MAX_SPEED := 42.0
const ACCEL := 20.0
const BRAKE_POWER := 34.0
const DRAG := 4.5
const TURN_RATE := 1.55

func _ready() -> void:
	_build_world()
	_build_car()
	_build_camera()
	_setup_vehicle_audio()
	_build_ui()
	_show_main_menu()

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
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.53, 0.66, 0.77)
	env.fog_density = 0.0018
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
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

	_build_city_details()
	_build_city_life()
	_build_urban_details()

func _build_city_details() -> void:
	# Crosswalks, intersection markings and pedestrian islands.
	for z in [-72.0, -18.0, 36.0, 90.0]:
		for i in range(12):
			var x := -7.5 + float(i) * 1.35
			_visual_box(self, "CrosswalkStripe", Vector3(x, 0.075, z), Vector3(0.78, 0.025, 3.4), Color(0.86, 0.88, 0.86))
		_visual_box(self, "StopLineLeft", Vector3(-4.3, 0.078, z - 3.0), Vector3(7.8, 0.025, 0.16), Color(0.92, 0.91, 0.82))
		_visual_box(self, "StopLineRight", Vector3(4.3, 0.078, z - 3.0), Vector3(7.8, 0.025, 0.16), Color(0.92, 0.91, 0.82))
		_build_traffic_signal(-9.0, z - 4.5, true)
		_build_traffic_signal(9.0, z - 4.5, false)

	# Street furniture, planted areas and parking bays.
	for i in range(18):
		var z := -104.0 + float(i) * 12.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_build_planter(side * 10.0, z)
		if i % 3 == 0:
			_build_bench(-side * 10.0, z + 3.0)
		if i % 4 == 1:
			_build_bin(side * 9.9, z + 2.0)
		if i % 5 == 0:
			_build_parked_car(side * 7.15, z - 3.0, i)

	# Decorative road arrows and lane guidance.
	for z in [-48.0, 12.0, 72.0]:
		_visual_box(self, "LaneArrowStem", Vector3(-3.0, 0.085, z), Vector3(0.13, 0.025, 2.0), Color(0.78, 0.81, 0.80))
		_visual_box(self, "LaneArrowHead", Vector3(-3.0, 0.085, z + 1.0), Vector3(1.0, 0.025, 0.14), Color(0.78, 0.81, 0.80))

func _build_city_life() -> void:
	# Moving traffic stays in the two opposing lanes, away from the player's center lane.
	for i in range(8):
		var vehicle := Node3D.new()
		vehicle.name = "TrafficVehicle"
		var lane := -4.4 if i % 2 == 0 else 4.4
		vehicle.position = Vector3(lane, 0.0, -105.0 + float(i) * 29.0)
		var paint_colors := [Color(0.72, 0.12, 0.08), Color(0.08, 0.28, 0.62), Color(0.72, 0.72, 0.68), Color(0.08, 0.10, 0.13), Color(0.68, 0.48, 0.12)]
		var paint: Color = paint_colors[i % paint_colors.size()]
		_visual_box(vehicle, "TrafficBody", Vector3(0, 0.67, 0), Vector3(1.85, 0.68, 3.65), paint, 0.55, 0.3)
		_visual_box(vehicle, "TrafficCabin", Vector3(0, 1.17, -0.15), Vector3(1.48, 0.58, 1.85), Color(0.035, 0.09, 0.14), 0.45, 0.2)
		for side in [-1.0, 1.0]:
			for offset in [-1.12, 1.12]:
				var wheel := MeshInstance3D.new()
				var wheel_mesh := CylinderMesh.new()
				wheel_mesh.top_radius = 0.29
				wheel_mesh.bottom_radius = 0.29
				wheel_mesh.height = 0.16
				wheel.mesh = wheel_mesh
				wheel.rotation_degrees.z = 90
				wheel.position = Vector3(side * 0.91, 0.34, offset)
				wheel.material_override = _material(Color(0.012, 0.014, 0.018), 0.0, 0.9)
				vehicle.add_child(wheel)
		add_child(vehicle)
		traffic_vehicles.append(vehicle)
		traffic_speeds.append(5.0 + float(i % 3) * 1.2)
		traffic_directions.append(-1.0 if i % 2 == 0 else 1.0)

	# Pedestrians walk along both sidewalks; they are visual NPCs in this prototype.
	for i in range(12):
		var person := Node3D.new()
		person.name = "WalkingPedestrian"
		var side := -1.0 if i % 2 == 0 else 1.0
		person.position = Vector3(side * 10.0, 0.0, -100.0 + float(i) * 18.0)
		var shirt_colors := [Color(0.72, 0.18, 0.12), Color(0.12, 0.28, 0.68), Color(0.78, 0.62, 0.22), Color(0.16, 0.42, 0.28)]
		var torso := MeshInstance3D.new()
		var torso_mesh := CapsuleMesh.new()
		torso_mesh.radius = 0.23
		torso_mesh.height = 1.05
		torso.mesh = torso_mesh
		torso.material_override = _material(shirt_colors[i % shirt_colors.size()], 0.0, 0.8)
		torso.position = Vector3(0, 1.0, 0)
		person.add_child(torso)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.17
		head_mesh.height = 0.34
		head.mesh = head_mesh
		head.material_override = _material(Color(0.72, 0.52, 0.38), 0.0, 0.85)
		head.position = Vector3(0, 1.67, 0)
		person.add_child(head)
		var person_legs: Array[MeshInstance3D] = []
		for leg_x in [-0.10, 0.10]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CapsuleMesh.new()
			leg_mesh.radius = 0.075
			leg_mesh.height = 0.62
			leg.mesh = leg_mesh
			leg.material_override = _material(Color(0.08, 0.10, 0.15), 0.0, 0.9)
			leg.position = Vector3(leg_x, 0.38, 0)
			person.add_child(leg)
			person_legs.append(leg)
		add_child(person)
		pedestrians.append(person)
		pedestrian_legs.append(person_legs)

func _process(delta: float) -> void:
	_update_vehicle_audio(delta)
	# Render-frame camera follow avoids visible stepping at the physics tick rate.
	if is_instance_valid(car) and is_instance_valid(camera):
		var forward := Vector3(sin(heading), 0.0, cos(heading))
		var camera_target := car.global_position + Vector3(0.0, 5.4, 0.0) - forward * 11.0
		camera.global_position = camera.global_position.lerp(camera_target, 1.0 - exp(-16.0 * delta))
		camera.look_at(car.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		camera.fov = lerpf(camera.fov, 68.0 + clampf(absf(speed) / MAX_SPEED, 0.0, 1.0) * 7.0, 1.0 - exp(-4.5 * delta))
	if game_started and not game_paused and current_mission > 0:
		mission_elapsed += delta
		mission_time = maxf(0.0, mission_time - delta)
		if timer_label:
			timer_label.text = "زمان: %02d" % int(ceil(mission_time))
		if mission_time <= 0.0:
			_finish_mission(false)
	# Opposing traffic flows in separate lanes and gently corrects its lane position.
	for i in range(traffic_vehicles.size()):
		var vehicle := traffic_vehicles[i]
		var direction: float = traffic_directions[i]
		vehicle.position.z += direction * traffic_speeds[i] * delta
		vehicle.position.x = (-4.4 if i % 2 == 0 else 4.4) + sin(Time.get_ticks_msec() * 0.0007 + float(i)) * 0.10
		if direction < 0.0 and vehicle.position.z < -125.0:
			vehicle.position.z = 125.0 + float(i % 3) * 8.0
		elif direction > 0.0 and vehicle.position.z > 125.0:
			vehicle.position.z = -125.0 - float(i % 3) * 8.0

	# Pedestrian NPCs walk with alternating leg motion rather than sliding.
	for i in range(pedestrians.size()):
		var person := pedestrians[i]
		var direction := 1.0 if i % 2 == 0 else -1.0
		person.position.z += direction * 0.75 * delta
		var gait := sin(Time.get_ticks_msec() * 0.008 + float(i) * 1.7)
		var legs: Array = pedestrian_legs[i]
		legs[0].rotation.x = gait * 0.48
		legs[1].rotation.x = -gait * 0.48
		person.rotation.y = 0.08 * sin(Time.get_ticks_msec() * 0.004 + float(i))
		if person.position.z > 118.0:
			person.position.z = -118.0
		elif person.position.z < -118.0:
			person.position.z = 118.0

	# Simple timed traffic-light cycle: green and red lamps alternate.
	signal_clock += delta
	if signal_clock >= 8.0:
		signal_clock = 0.0
		traffic_light_green = not traffic_light_green
	for lamp_index in range(signal_lamps.size()):
		var color := Color(0.04, 0.72, 0.20) if traffic_light_green else Color(0.9, 0.035, 0.025)
		if lamp_index % 3 == 0:
			color = Color(0.9, 0.035, 0.025) if traffic_light_green else Color(0.04, 0.72, 0.20)
		var lamp_material := _material(color, 0.0, 0.2)
		lamp_material.emission_enabled = true
		lamp_material.emission = color
		lamp_material.emission_energy_multiplier = 0.55
		signal_lamps[lamp_index].material_override = lamp_material

func _build_traffic_signal(x: float, z: float, faces_right: bool) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.075
	pole_mesh.height = 4.3
	pole.mesh = pole_mesh
	pole.material_override = _material(Color(0.10, 0.13, 0.16), 0.65, 0.35)
	pole.position = Vector3(x, 2.15, z)
	add_child(pole)
	var direction := 1.0 if faces_right else -1.0
	_visual_box(self, "SignalHousing", Vector3(x + direction * 0.42, 3.55, z), Vector3(0.48, 1.12, 0.34), Color(0.035, 0.045, 0.055), 0.35, 0.35)
	for j in range(3):
		var colors := [Color(0.9, 0.035, 0.025), Color(0.95, 0.55, 0.035), Color(0.04, 0.72, 0.20)]
		var lamp_mat := _material(colors[j], 0.0, 0.2)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = colors[j]
		lamp_mat.emission_energy_multiplier = 0.35
		var lamp := _visual_box(self, "SignalLamp", Vector3(x + direction * 0.42, 3.9 - float(j) * 0.34, z + 0.19), Vector3(0.25, 0.23, 0.035), colors[j], 0.0, 0.2)
		lamp.material_override = lamp_mat
		signal_lamps.append(lamp)

func _build_planter(x: float, z: float) -> void:
	_visual_box(self, "StonePlanter", Vector3(x, 0.28, z), Vector3(1.25, 0.48, 2.0), Color(0.28, 0.31, 0.32), 0.0, 0.9)
	_visual_box(self, "PlanterSoil", Vector3(x, 0.54, z), Vector3(1.08, 0.06, 1.82), Color(0.16, 0.11, 0.07))
	_build_tree(x, z, 0.65)

func _build_bench(x: float, z: float) -> void:
	_visual_box(self, "BenchSeat", Vector3(x, 0.55, z), Vector3(1.65, 0.12, 0.48), Color(0.30, 0.17, 0.09), 0.1, 0.7)
	_visual_box(self, "BenchBack", Vector3(x, 0.92, z - 0.19), Vector3(1.65, 0.62, 0.10), Color(0.28, 0.15, 0.08), 0.1, 0.7)
	for dx in [-0.62, 0.62]:
		_visual_box(self, "BenchLeg", Vector3(x + dx, 0.28, z), Vector3(0.09, 0.55, 0.10), Color(0.08, 0.10, 0.12), 0.7, 0.4)

func _build_bin(x: float, z: float) -> void:
	_visual_box(self, "StreetBin", Vector3(x, 0.48, z), Vector3(0.48, 0.92, 0.48), Color(0.10, 0.24, 0.20), 0.15, 0.75)
	_visual_box(self, "BinLid", Vector3(x, 0.96, z), Vector3(0.54, 0.08, 0.54), Color(0.07, 0.11, 0.10), 0.3, 0.5)

func _build_parked_car(x: float, z: float, variant: int) -> void:
	var colors := [Color(0.72, 0.73, 0.75), Color(0.08, 0.12, 0.18), Color(0.48, 0.08, 0.055), Color(0.72, 0.58, 0.30)]
	var paint: Color = colors[variant % colors.size()]
	_visual_box(self, "ParkedVehicleBody", Vector3(x, 0.68, z), Vector3(1.9, 0.68, 3.8), paint, 0.72, 0.28)
	_visual_box(self, "ParkedVehicleCabin", Vector3(x, 1.12, z - 0.12), Vector3(1.48, 0.58, 1.9), Color(0.035, 0.09, 0.13), 0.5, 0.18)
	for side in [-1.0, 1.0]:
		for offset in [-1.18, 1.18]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.32
			wheel_mesh.bottom_radius = 0.32
			wheel_mesh.height = 0.18
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x + side * 0.94, 0.36, z + offset)
			wheel.material_override = _material(Color(0.015, 0.018, 0.022), 0.0, 0.9)
			add_child(wheel)

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

	# Layered facade trim and architectural floor bands.
	for floor_index in range(max(2, int(h / 2.8))):
		var band_y := 0.72 + float(floor_index) * 2.7
		_visual_box(self, "FacadeFloorBand", Vector3(face_x + road_side * 0.07, band_y, z), Vector3(0.12, 0.10, depth + 0.15), Color(0.19, 0.23, 0.29), 0.35, 0.42)
	for col in range(4):
		var pillar_z := z - 3.7 + float(col) * 2.45
		_visual_box(self, "FacadeVerticalPier", Vector3(face_x + road_side * 0.09, h * 0.5, pillar_z), Vector3(0.16, h - 0.6, 0.16), Color(0.22, 0.26, 0.32), 0.2, 0.55)

	# Ground-floor glass storefront, canopy and illuminated shop sign.
	var shop_glass := _material(Color(0.035, 0.19, 0.25), 0.52, 0.12)
	var shop_window := MeshInstance3D.new()
	var shop_pane := BoxMesh.new()
	shop_pane.size = Vector3(0.075, 1.75, 4.9)
	shop_window.mesh = shop_pane
	shop_window.material_override = shop_glass
	shop_window.position = Vector3(face_x + road_side * 0.04, 1.75, z)
	add_child(shop_window)
	_visual_box(self, "ShopDoor", Vector3(face_x + road_side * 0.09, 1.25, z + 2.75), Vector3(0.12, 2.35, 0.95), Color(0.025, 0.11, 0.17), 0.45, 0.18)
	_visual_box(self, "ShopAwning", Vector3(face_x + road_side * 0.55, 2.85, z), Vector3(0.95, 0.16, 5.5), Color(0.68, 0.25, 0.12), 0.1, 0.65)
	_visual_box(self, "ShopSignBoard", Vector3(face_x + road_side * 0.14, 3.35, z), Vector3(0.18, 0.62, 4.7), Color(0.035, 0.07, 0.12), 0.2, 0.4)
	var sign := Label3D.new()
	sign.text = ["MARKET", "CAFE", "CITY STORE", "AUTO"][posmod(seed, 4)]
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color(0.92, 0.82, 0.56)
	sign.position = Vector3(face_x + road_side * 0.25, 3.34, z)
	sign.rotation.y = PI * 0.5 if road_side < 0.0 else -PI * 0.5
	add_child(sign)

	# Rooftop parapet and compact ventilation units.
	_visual_box(self, "RoofParapet", Vector3(x, h + 0.22, z), Vector3(width + 0.25, 0.42, depth + 0.25), Color(0.24, 0.27, 0.32), 0.18, 0.7)
	for unit in range(2):
		_visual_box(self, "RooftopVent", Vector3(x + float(unit) * 2.5 - 1.25, h + 0.62, z + 1.8), Vector3(1.25, 0.55, 1.1), Color(0.34, 0.38, 0.42), 0.5, 0.6)

	_build_building_extras(x, z, h, road_side, face_x, seed)

func _build_building_extras(x: float, z: float, h: float, road_side: float, face_x: float, seed: int) -> void:
	# Add depth to selected facades without creating an excessive number of objects.
	var floors: int = maxi(2, int(h / 2.8))
	if seed % 3 == 0:
		for floor_index in range(1, floors, 2):
			var balcony_y := 1.05 + float(floor_index) * 2.7
			var balcony_x := face_x + road_side * 0.72
			_visual_box(self, "BalconySlab", Vector3(balcony_x, balcony_y, z), Vector3(1.25, 0.12, 2.25), Color(0.27, 0.30, 0.34), 0.25, 0.65)
			_visual_box(self, "BalconyRailTop", Vector3(balcony_x + road_side * 0.55, balcony_y + 0.48, z), Vector3(0.07, 0.07, 2.25), Color(0.12, 0.16, 0.20), 0.7, 0.3)
			for rail_z in [-0.98, -0.33, 0.33, 0.98]:
				_visual_box(self, "BalconyRailPost", Vector3(balcony_x + road_side * 0.55, balcony_y + 0.24, z + rail_z), Vector3(0.06, 0.48, 0.06), Color(0.16, 0.20, 0.24), 0.65, 0.35)
	if seed % 2 == 0:
		for floor_index in range(1, floors, 2):
			var ac_y := 1.25 + float(floor_index) * 2.7
			_visual_box(self, "ExteriorACUnit", Vector3(face_x + road_side * 0.28, ac_y, z - 2.65), Vector3(0.42, 0.34, 0.72), Color(0.48, 0.52, 0.55), 0.35, 0.7)
			_visual_box(self, "ACVent", Vector3(face_x + road_side * 0.51, ac_y, z - 2.65), Vector3(0.035, 0.23, 0.48), Color(0.12, 0.15, 0.17), 0.15, 0.8)
	if seed % 4 == 1:
		var sign_x := face_x + road_side * 0.22
		_visual_box(self, "RooftopBillboardPost", Vector3(sign_x, h + 1.15, z), Vector3(0.12, 1.8, 0.12), Color(0.13, 0.16, 0.20), 0.55, 0.4)
		_visual_box(self, "RooftopBillboard", Vector3(sign_x, h + 2.15, z), Vector3(0.18, 1.25, 4.2), Color(0.035, 0.12, 0.20), 0.35, 0.35)
		var billboard_text := Label3D.new()
		billboard_text.text = ["CHINOK CITY", "DRIVE SAFE", "OPEN 24 HOURS"][posmod(seed, 3)]
		billboard_text.font_size = 48
		billboard_text.pixel_size = 0.006
		billboard_text.modulate = Color(0.88, 0.94, 1.0)
		billboard_text.position = Vector3(sign_x + road_side * 0.12, h + 2.15, z)
		billboard_text.rotation.y = PI * 0.5 if road_side < 0.0 else -PI * 0.5
		add_child(billboard_text)

func _build_urban_details() -> void:
	# Sidewalk paving joints, curb stones and drains add scale to the street.
	for z in range(-116, 120, 4):
		_visual_box(self, "LeftPavingJoint", Vector3(-9.65, 0.132, float(z)), Vector3(2.0, 0.012, 0.035), Color(0.43, 0.46, 0.47))
		_visual_box(self, "RightPavingJoint", Vector3(9.65, 0.132, float(z)), Vector3(2.0, 0.012, 0.035), Color(0.43, 0.46, 0.47))
		if z % 12 == 0:
			_visual_box(self, "RoadDrain", Vector3(-8.48, 0.09, float(z)), Vector3(0.18, 0.025, 0.9), Color(0.055, 0.065, 0.075), 0.65, 0.8)
			_visual_box(self, "RoadDrainRight", Vector3(8.48, 0.09, float(z)), Vector3(0.18, 0.025, 0.9), Color(0.055, 0.065, 0.075), 0.65, 0.8)

	# Small street signs, bollards and parking markings.
	for i in range(12):
		var z := -100.0 + float(i) * 18.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.045
		post_mesh.bottom_radius = 0.06
		post_mesh.height = 2.4
		post.mesh = post_mesh
		post.material_override = _material(Color(0.12, 0.15, 0.18), 0.7, 0.35)
		post.position = Vector3(side * 10.65, 1.2, z)
		add_child(post)
		_visual_box(self, "StreetNameSign", Vector3(side * 10.65, 2.25, z), Vector3(0.12, 0.42, 1.5), Color(0.035, 0.22, 0.18), 0.15, 0.45)
	for z in [-94.0, -40.0, 14.0, 68.0]:
		for i in range(3):
			var x := 5.2 + float(i) * 1.05
			_visual_box(self, "ParkingBayLine", Vector3(x, 0.085, z), Vector3(0.055, 0.02, 5.0), Color(0.76, 0.80, 0.79))

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

func _setup_vehicle_audio() -> void:
	# Lightweight synthesized engine and tyre sounds; no external audio files required.
	var engine_stream := AudioStreamGenerator.new()
	engine_stream.mix_rate = int(AUDIO_RATE)
	engine_stream.buffer_length = 0.18
	engine_player = AudioStreamPlayer.new()
	engine_player.name = "CHINOCK_EngineAudio"
	engine_player.stream = engine_stream
	engine_player.volume_db = -80.0
	car.add_child(engine_player)
	engine_player.play()
	engine_playback = engine_player.get_stream_playback() as AudioStreamGeneratorPlayback

	var exhaust_stream := AudioStreamGenerator.new()
	exhaust_stream.mix_rate = int(AUDIO_RATE)
	exhaust_stream.buffer_length = 0.18
	exhaust_player = AudioStreamPlayer.new()
	exhaust_player.name = "CHINOCK_ExhaustAudio"
	exhaust_player.stream = exhaust_stream
	exhaust_player.volume_db = -80.0
	car.add_child(exhaust_player)
	exhaust_player.play()
	exhaust_playback = exhaust_player.get_stream_playback() as AudioStreamGeneratorPlayback

	var tire_stream := AudioStreamGenerator.new()
	tire_stream.mix_rate = int(AUDIO_RATE)
	tire_stream.buffer_length = 0.18
	tire_player = AudioStreamPlayer.new()
	tire_player.name = "CHINOCK_TyreAudio"
	tire_player.stream = tire_stream
	tire_player.volume_db = -80.0
	car.add_child(tire_player)
	tire_player.play()
	tire_playback = tire_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _update_vehicle_audio(_delta: float) -> void:
	if engine_playback == null or exhaust_playback == null or tire_playback == null:
		return
	var frames := engine_playback.get_frames_available()
	if frames > 0:
		var engine_buffer := PackedVector2Array()
		engine_buffer.resize(frames)
		var rpm_factor := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
		var frequency := 72.0 + rpm_factor * 145.0 + (18.0 if throttle else 0.0)
		var amplitude := 0.10 + (0.045 if throttle else 0.0)
		if not game_started:
			amplitude = 0.0
		for i in range(frames):
			var sample := sin(engine_phase) * 0.72 + sin(engine_phase * 2.01) * 0.20 + sin(engine_phase * 3.0) * 0.08
			engine_buffer[i] = Vector2(sample * amplitude, sample * amplitude)
			engine_phase = fmod(engine_phase + TAU * frequency / AUDIO_RATE, TAU)
		engine_playback.push_buffer(engine_buffer)
	engine_player.volume_db = lerpf(engine_player.volume_db, -20.0 if game_started else -80.0, 0.12)

	# Independent exhaust channel: low combustion pulses when accelerating.
	var exhaust_frames := exhaust_playback.get_frames_available()
	if exhaust_frames > 0:
		var exhaust_buffer := PackedVector2Array()
		exhaust_buffer.resize(exhaust_frames)
		var rpm := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
		var exhaust_frequency := 58.0 + rpm * 82.0 + (24.0 if throttle else 0.0)
		var exhaust_level := 0.0
		if game_started and not game_paused and throttle:
			exhaust_level = 0.16 + rpm * 0.07
		for i in range(exhaust_frames):
			var pulse := sin(exhaust_phase) * 0.58 + sin(exhaust_phase * 2.0) * 0.27 + sin(exhaust_phase * 4.03) * 0.15
			var sputter := 0.82 + 0.18 * sin(exhaust_phase * 0.37)
			var sample := pulse * sputter * exhaust_level
			exhaust_buffer[i] = Vector2(sample, sample)
			exhaust_phase = fmod(exhaust_phase + TAU * exhaust_frequency / AUDIO_RATE, TAU)
		exhaust_playback.push_buffer(exhaust_buffer)
		exhaust_player.volume_db = lerpf(exhaust_player.volume_db, -10.0 if game_started and not game_paused and throttle else -80.0, 0.18)

	var tire_frames := tire_playback.get_frames_available()
	if tire_frames > 0:
		var tire_buffer := PackedVector2Array()
		tire_buffer.resize(tire_frames)
		var steer_amount := absf(float(steer_right) - float(steer_left))
		var speed_factor := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
		var tire_level := 0.0
		if game_started and not game_paused and absf(speed) > 2.5 and steer_amount > 0.05:
			# Make tyre scrub audible during ordinary turns, not only extreme skids.
			tire_level = clampf(0.22 + speed_factor * steer_amount * 0.72, 0.22, 0.78)
		if game_started and not game_paused and brake and absf(speed) > 5.0:
			tire_level = maxf(tire_level, 0.30 + speed_factor * 0.30)
		var tire_frequency := 210.0 + absf(speed) * 3.0
		for i in range(tire_frames):
			# A rough, noise-like friction layer plus a faint high tyre squeal.
			var noise_sample := randf_range(-1.0, 1.0)
			var texture := sin(tire_phase * 1.03) * 0.16 + sin(tire_phase * 2.71) * 0.12 + sin(tire_phase * 4.83) * 0.10
			var squeal_tone := sin(tire_phase * 8.7) * 0.12
			var sample := (noise_sample * 0.62 + texture + squeal_tone) * tire_level
			tire_buffer[i] = Vector2(sample, sample)
			tire_phase = fmod(tire_phase + TAU * tire_frequency / AUDIO_RATE, TAU)
		tire_playback.push_buffer(tire_buffer)
	var tire_active := game_started and not game_paused and (tire_level > 0.0)
	tire_player.volume_db = lerpf(tire_player.volume_db, -2.0 if tire_active else -80.0, 0.22)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	hud_root = root

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
	_build_logo(root)
	mission_label = Label.new()
	mission_label.position = Vector2(24, 128)
	mission_label.add_theme_font_size_override("font_size", 19)
	mission_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	mission_label.text = "رانندگی آزاد"
	root.add_child(mission_label)
	timer_label = Label.new()
	timer_label.position = Vector2(24, 158)
	timer_label.add_theme_font_size_override("font_size", 19)
	timer_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	timer_label.text = ""
	root.add_child(timer_label)
	distance_label = Label.new()
	distance_label.position = Vector2(24, 188)
	distance_label.add_theme_font_size_override("font_size", 18)
	distance_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	distance_label.text = "مسافت: ۰ متر"
	root.add_child(distance_label)
	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.position = Vector2(-88, 112)
	pause_button.size = Vector2(64, 58)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.add_theme_font_size_override("font_size", 26)
	root.add_child(pause_button)
	pause_button.pressed.connect(_toggle_pause)

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
	if not game_started or game_paused:
		return
	if throttle:
		speed = move_toward(speed, MAX_SPEED, ACCEL * delta)
	elif brake:
		speed = move_toward(speed, 0.0, BRAKE_POWER * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)

	# Automatic emergency braking when the player is about to hit a traffic car.
	for vehicle in traffic_vehicles:
		var relative := vehicle.global_position - car.global_position
		if abs(relative.x) < 2.25 and abs(relative.z) < 4.7 and abs(speed) > 0.0:
			speed = move_toward(speed, 0.0, BRAKE_POWER * delta * 1.8)
	var steer := float(steer_right) - float(steer_left)
	if abs(speed) > 0.2:
		heading -= steer * TURN_RATE * delta * clamp(abs(speed) / 8.0, 0.25, 1.0)
	car.rotation.y = heading
	car.rotation.z = lerpf(car.rotation.z, -steer * 0.045, 1.0 - exp(-5.5 * delta))
	var forward := Vector3(sin(heading), 0, cos(heading))
	car.velocity = forward * speed
	car.velocity.y = -1.0
	car.move_and_slide()
	mission_distance += absf(speed) * delta
	if car.global_position.z > 112.0:
		car.global_position.z = -112.0
	elif car.global_position.z < -112.0:
		car.global_position.z = 112.0
	car.global_position.x = clampf(car.global_position.x, -7.2, 7.2)
	if distance_label:
		distance_label.text = "مسافت: %d متر" % int(mission_distance)
	if current_mission > 0 and mission_distance >= mission_target:
		_finish_mission(true)

	# Camera is updated in _process for smooth render-frame following.
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



func _show_main_menu() -> void:
	game_started = false
	game_paused = false
	var overlay := ColorRect.new()
	overlay.name = "MainMenuOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.025, 0.045, 0.90)
	hud_root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -250)
	panel.size = Vector2(600, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.09, 0.97)
	style.border_color = Color(0.82, 0.58, 0.22, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "CHINOCK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.76, 0.34))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "شهر زنده | رانندگی آزاد و مأموریت‌ها"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.89, 0.98))
	column.add_child(subtitle)
	_add_menu_button(column, "شروع رانندگی آزاد", _start_free_drive)
	_add_menu_button(column, "مأموریت سرعت – ۹۰ ثانیه", _start_time_trial)
	_add_menu_button(column, "انتخاب رنگ خودرو", _cycle_car_paint)
	var note := Label.new()
	note.text = "نسخه آزمایشی آفلاین • کنترل لمسی و کیبورد"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	column.add_child(note)

func _add_menu_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", 23)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.16, 0.23, 1.0)
	normal.border_color = Color(0.72, 0.48, 0.19, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	parent.add_child(button)
	button.pressed.connect(action)

func _clear_menu() -> void:
	var old_menu := hud_root.get_node_or_null("MainMenuOverlay")
	if old_menu:
		old_menu.queue_free()
	var result_menu := hud_root.get_node_or_null("ResultOverlay")
	if result_menu:
		result_menu.queue_free()

func _start_free_drive() -> void:
	_clear_menu()
	current_mission = 0
	mission_time = 0.0
	mission_distance = 0.0
	mission_label.text = "رانندگی آزاد"
	timer_label.text = "بدون محدودیت زمانی"
	game_started = true
	game_paused = false

func _start_time_trial() -> void:
	_clear_menu()
	current_mission = 1
	mission_time = 90.0
	mission_elapsed = 0.0
	mission_distance = 0.0
	mission_target = 900.0
	mission_label.text = "مأموریت سرعت: رسیدن به ۹۰۰ متر"
	timer_label.text = "زمان: ۹۰"
	game_started = true
	game_paused = false

func _cycle_car_paint() -> void:
	selected_car = (selected_car + 1) % car_paints.size()
	var body := car.get_node_or_null("SportsBody") as MeshInstance3D
	var hood := car.get_node_or_null("FrontHood") as MeshInstance3D
	var roof := car.get_node_or_null("Roof") as MeshInstance3D
	if body:
		body.material_override = _material(car_paints[selected_car], 0.82, 0.2)
	if hood:
		hood.material_override = _material(car_paints[selected_car].lightened(0.12), 0.78, 0.2)
	if roof:
		roof.material_override = _material(car_paints[selected_car].darkened(0.18), 0.75, 0.18)
	# Paint changes immediately while the menu stays open.

func _toggle_pause() -> void:
	if not game_started:
		return
	game_paused = not game_paused
	if game_paused:
		_show_pause_menu()
	else:
		_clear_menu()

func _show_pause_menu() -> void:
	_clear_menu()
	var overlay := ColorRect.new()
	overlay.name = "MainMenuOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.02, 0.04, 0.78)
	hud_root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -125)
	panel.size = Vector2(420, 250)
	var column := VBoxContainer.new()
	panel.add_child(column)
	overlay.add_child(panel)
	var title := Label.new()
	title.text = "بازی متوقف شد"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	_add_menu_button(column, "ادامه بازی", func(): _toggle_pause())
	_add_menu_button(column, "بازگشت به منوی اصلی", func():
		game_started = false
		game_paused = false
		_clear_menu()
		_show_main_menu()
	)

func _finish_mission(success: bool) -> void:
	if not game_started:
		return
	game_started = false
	game_paused = true
	var overlay := ColorRect.new()
	overlay.name = "ResultOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.02, 0.04, 0.82)
	hud_root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -150)
	panel.size = Vector2(480, 300)
	var column := VBoxContainer.new()
	panel.add_child(column)
	overlay.add_child(panel)
	var title := Label.new()
	title.text = "مأموریت موفق!" if success else "زمان مأموریت تمام شد"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var detail := Label.new()
	detail.text = "مسافت طی‌شده: %d متر" % int(mission_distance)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	_add_menu_button(column, "تلاش دوباره", _start_time_trial)
	_add_menu_button(column, "منوی اصلی", func():
		game_paused = false
		_clear_menu()
		_show_main_menu()
	)


func _build_logo(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(-292, 18)
	panel.size = Vector2(270, 76)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.075, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.82, 0.20, 0.95)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.18, 0.48, 1.0, 0.45)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var logo := Label.new()
	logo.text = "✦  CHINOCK"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 32)
	logo.add_theme_color_override("font_color", Color(1.0, 0.35, 0.88))
	panel.add_child(logo)
