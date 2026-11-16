extends Node3D

var car: CharacterBody3D
var camera: Camera3D
var city_root: Node3D
var speed_label: Label
var gear_label: Label
var touch_actions: Dictionary = {}
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
var car_paints: Array[Color] = [
	Color(0.025, 0.24, 0.48), Color(0.62, 0.045, 0.035),
	Color(0.035, 0.045, 0.06), Color(0.92, 0.92, 0.88),
	Color(0.78, 0.42, 0.08), Color(0.02, 0.42, 0.22),
	Color(0.28, 0.08, 0.48), Color(0.18, 0.48, 0.62),
	Color(0.48, 0.48, 0.50), Color(0.42, 0.12, 0.24)
]
var car_paint_names: Array[String] = ["آبی", "قرمز", "مشکی", "سفید", "طلایی", "سبز", "بنفش", "فیروزه‌ای", "نقره‌ای", "زرشکی"]
var paint_status_label: Label
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
const TURN_RATE := 2.15

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
	if parent == self and is_instance_valid(city_root):
		parent = city_root
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
	city_root.add_child(body)

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

	# All road and city geometry lives under one root so the city can loop seamlessly.
	city_root = Node3D.new()
	city_root.name = "EndlessCityRoot"
	add_child(city_root)

	_solid_box("CityGround", Vector3(0, -0.65, 0), Vector3(260, 1, 260), Color(0.16, 0.31, 0.19))
	_solid_box("AsphaltRoad", Vector3(0, -0.02, 0), Vector3(17, 0.12, 240), Color(0.075, 0.085, 0.105))
	# Main-road sidewalks are split into blocks so they stop at every cross street.
	# Never let the pavement continue across the perpendicular carriageway.
	for sidewalk_x in [-9.7, 9.7]:
		var sidewalk_start := -120.0
		for crossing_z in [-72.0, -18.0, 36.0, 90.0]:
			var sidewalk_end: float = crossing_z - 6.5
			if sidewalk_end > sidewalk_start:
				var sidewalk_length: float = sidewalk_end - sidewalk_start
				_solid_box("MainRoadSidewalkSegment", Vector3(sidewalk_x, 0.0, sidewalk_start + sidewalk_length * 0.5), Vector3(2.2, 0.24, sidewalk_length), Color(0.58, 0.60, 0.60))
			sidewalk_start = crossing_z + 6.5
		if sidewalk_start < 120.0:
			var sidewalk_length: float = 120.0 - sidewalk_start
			_solid_box("MainRoadSidewalkSegment", Vector3(sidewalk_x, 0.0, sidewalk_start + sidewalk_length * 0.5), Vector3(2.2, 0.24, sidewalk_length), Color(0.58, 0.60, 0.60))

	# Connected east-west avenues turn the old single corridor into a compact street grid.
	for avenue_x in [-84.0, -56.0, -28.0, 28.0, 56.0, 84.0]:
		_solid_box("NorthSouthAvenue", Vector3(avenue_x, -0.015, 0), Vector3(11.5, 0.11, 240), Color(0.075, 0.085, 0.105))
		# Break the center marking around intersections so it does not run through zebra crossings.
		for dash_z in range(-112, 120, 12):
			var clear_of_crossing := true
			for crossing_z in [-72.0, -18.0, 36.0, 90.0]:
				if absf(float(dash_z) - crossing_z) < 12.0:
					clear_of_crossing = false
					break
			if clear_of_crossing:
				_visual_box(self, "AvenueCenterDash", Vector3(avenue_x, 0.06, dash_z), Vector3(0.13, 0.025, 5.2), Color(0.92, 0.82, 0.55))
	for cross_z in [-72.0, -18.0, 36.0, 90.0]:
		_solid_box("EastWestStreet", Vector3(0, -0.01, cross_z), Vector3(240, 0.11, 11.5), Color(0.075, 0.085, 0.105))
		# Break the center marking around each avenue crossing.
		for dash_x in range(-112, 120, 12):
			var clear_of_avenue := true
			for avenue_x in [-84.0, -56.0, -28.0, 28.0, 56.0, 84.0]:
				if absf(float(dash_x) - avenue_x) < 12.0:
					clear_of_avenue = false
					break
			if clear_of_avenue:
				_visual_box(self, "CrossStreetDash", Vector3(dash_x, 0.06, cross_z), Vector3(5.2, 0.025, 0.13), Color(0.92, 0.82, 0.55))
		for side_z in [-7.2, 7.2]:
			# Build sidewalk in separate blocks; leave openings over every road.
			var sidewalk_start := -120.0
			for road_x in [-84.0, -56.0, -28.0, 0.0, 28.0, 56.0, 84.0]:
				var opening_half := 9.0 if road_x == 0.0 else 6.5
				var sidewalk_end: float = road_x - opening_half
				if sidewalk_end > sidewalk_start:
					var segment_length: float = sidewalk_end - sidewalk_start
					_solid_box("CrossStreetSidewalk", Vector3(sidewalk_start + segment_length * 0.5, 0.0, cross_z + side_z), Vector3(segment_length, 0.22, 1.8), Color(0.55, 0.57, 0.57))
				sidewalk_start = road_x + opening_half
			if sidewalk_start < 120.0:
				var segment_length: float = 120.0 - sidewalk_start
				_solid_box("CrossStreetSidewalk", Vector3(sidewalk_start + segment_length * 0.5, 0.0, cross_z + side_z), Vector3(segment_length, 0.22, 1.8), Color(0.55, 0.57, 0.57))
	_visual_box(self, "RoadEdgeLeft", Vector3(-8.55, 0.08, 0), Vector3(0.12, 0.08, 240), Color(0.88, 0.84, 0.68))
	_visual_box(self, "RoadEdgeRight", Vector3(8.55, 0.08, 0), Vector3(0.12, 0.08, 240), Color(0.88, 0.84, 0.68))

	for z in range(-112, 120, 12):
		var clear_of_crossing := true
		for crossing_z in [-72, -18, 36, 90]:
			if absf(float(z) - float(crossing_z)) < 14.0:
				clear_of_crossing = false
				break
		if clear_of_crossing:
			_visual_box(self, "CenterLine", Vector3(0, 0.065, z), Vector3(0.16, 0.025, 5.2), Color(1.0, 0.91, 0.62))

	for i in range(24):
		var z := -112.0 + float(i) * 9.5
		var h_left := 9.0 + float((i * 7) % 8)
		var h_right := 10.0 + float((i * 5) % 9)
		var colors := [Color(0.31, 0.36, 0.43), Color(0.43, 0.37, 0.33), Color(0.34, 0.42, 0.44), Color(0.40, 0.40, 0.47)]
		# Keep the crossing approaches clear: buildings close to an east-west road
		# would otherwise protrude into its carriageway.
		var near_crossing := false
		for crossing_z in [-72.0, -18.0, 36.0, 90.0]:
			if absf(z - crossing_z) < 10.0 or absf((z - 4.5) - crossing_z) < 10.0:
				near_crossing = true
				break
		if not near_crossing:
			_build_building(-18.0, z, h_left, colors[i % colors.size()], i)
			_build_building(18.0, z - 4.5, h_right, colors[(i + 2) % colors.size()], i + 3)
		if i % 2 == 0 and not near_crossing:
			_build_tree(-11.1, z + 2.5, 1.0 + float(i % 3) * 0.12)
			_build_tree(11.1, z - 2.5, 1.0 + float((i + 1) % 3) * 0.12)
		if i % 3 == 0:
			_build_streetlight(-10.8, z - 5.0)
			_build_streetlight(10.8, z - 1.0)

	_build_city_details()
	_build_city_life()
	_build_urban_details()
	_build_grid_district()
	_build_grid_traffic_controls()
	_build_grid_intersection_markings()


func _build_grid_district() -> void:
	# Fill the new street-grid blocks with compact, varied city buildings.
	var district_x := [-70.0, -42.0, 42.0, 70.0]
	var district_z := [-45.0, 9.0, 63.0]
	var facade_colors := [Color(0.34, 0.39, 0.46), Color(0.46, 0.38, 0.31), Color(0.31, 0.43, 0.44), Color(0.42, 0.42, 0.49), Color(0.38, 0.35, 0.33)]
	var building_seed := 40
	for x in district_x:
		for z in district_z:
			var height := 11.0 + float(posmod(building_seed * 7, 10))
			var wall: Color = facade_colors[posmod(building_seed, facade_colors.size())]
			_build_building(x, z, height, wall, building_seed)
			# Trees and low planters soften the space between each block and the road.
			var tree_side := -1.0 if x < 0.0 else 1.0
			_build_tree(x + tree_side * 7.2, z - 7.0, 0.78 + float(building_seed % 3) * 0.08)
			_build_tree(x + tree_side * 7.2, z + 7.0, 0.82)
			building_seed += 1

func _build_city_details() -> void:
	# Traffic signals only; all zebra crossings are generated once by
	# _build_grid_intersection_markings() to prevent duplicate markings.
	for crossing_z in [-72.0, -18.0, 36.0, 90.0]:
		_build_traffic_signal(-9.0, crossing_z - 4.5, true)
		_build_traffic_signal(9.0, crossing_z - 4.5, false)

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
			# Keep parked vehicles in the roadside parking strip, never in the driving lanes.
			_build_parked_car(side * 13.0, z - 3.0, i)

	# Decorative road arrows and lane guidance.
	for z in [-48.0, 12.0, 72.0]:
		_visual_box(self, "LaneArrowStem", Vector3(-3.0, 0.085, z), Vector3(0.13, 0.025, 2.0), Color(0.78, 0.81, 0.80))
		_visual_box(self, "LaneArrowHead", Vector3(-3.0, 0.085, z + 1.0), Vector3(1.0, 0.025, 0.14), Color(0.78, 0.81, 0.80))


func _build_grid_intersection_markings() -> void:
	# Two correctly oriented zebra crossings at each grid intersection.
	var avenues := [-84.0, -56.0, -28.0, 0.0, 28.0, 56.0, 84.0]
	var crossings := [-72.0, -18.0, 36.0, 90.0]
	var stripe_color := Color(0.96, 0.97, 0.96)
	var line_color := Color(0.96, 0.91, 0.76)
	for avenue_x in avenues:
		for crossing_z in crossings:
			for side in [-1.0, 1.0]:
				# Cross the north/south avenue: bars lie on the east/west road.
				for stripe in range(5):
					var stripe_x: float = avenue_x + side * (6.35 + float(stripe) * 0.82)
					_visual_box(self, "GridZebraStripe", Vector3(stripe_x, 0.112, crossing_z), Vector3(0.78, 0.045, 10.8), stripe_color)
				_visual_box(self, "GridStopLine", Vector3(avenue_x + side * 6.05, 0.115, crossing_z), Vector3(0.18, 0.045, 10.5), line_color)
				# Cross the east/west street: bars span the north/south avenue.
				for stripe in range(5):
					var stripe_z: float = crossing_z + side * (6.35 + float(stripe) * 0.82)
					_visual_box(self, "GridZebraStripe", Vector3(avenue_x, 0.112, stripe_z), Vector3(10.8, 0.045, 0.78), stripe_color)
				_visual_box(self, "GridStopLine", Vector3(avenue_x, 0.115, crossing_z + side * 6.05), Vector3(10.5, 0.045, 0.18), line_color)



func _build_grid_traffic_controls() -> void:
	# Put signs directly beside the main road so they are visible from the driving camera.
	for i in range(8):
		var z := -88.0 + float(i) * 24.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_build_road_sign(side * 9.35, z, "50", Color(0.92, 0.94, 0.96))
	for z in [-72.0, -18.0, 36.0, 90.0]:
		_build_road_sign(-9.35, z + 5.0, "STOP", Color(0.82, 0.06, 0.045))

	# Add traffic signals at selected crossings in the expanded street grid.
	for crossing in [[-56.0, -18.0], [28.0, -18.0], [-56.0, 36.0], [28.0, 36.0]]:
		var cx: float = crossing[0]
		var cz: float = crossing[1]
		_build_traffic_signal(cx - 7.0, cz - 7.0, true)
		_build_traffic_signal(cx + 7.0, cz + 7.0, false)

func _build_road_sign(x: float, z: float, caption: String, board_color: Color) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.045
	post_mesh.bottom_radius = 0.065
	post_mesh.height = 2.8
	post.mesh = post_mesh
	post.material_override = _material(Color(0.12, 0.15, 0.18), 0.65, 0.35)
	post.position = Vector3(x, 1.4, z)
	city_root.add_child(post)

	var board := _visual_box(self, "RoadSignBoard", Vector3(x, 2.55, z), Vector3(1.35, 0.92, 0.16), board_color, 0.05, 0.4)
	board.material_override = _material(board_color, 0.05, 0.4)

	# Duplicate the lettering on both faces so the sign can be read from either direction.
	for face in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = caption
		label.font_size = 64
		label.pixel_size = 0.008
		label.modulate = Color(0.07, 0.09, 0.11) if caption != "STOP" else Color.WHITE
		label.position = Vector3(x, 2.55, z + face * 0.09)
		label.rotation.y = 0.0 if face > 0.0 else PI
		label.outline_size = 8
		label.outline_modulate = Color(0.95, 0.95, 0.95) if caption == "50" else Color(0.18, 0.02, 0.02)
		city_root.add_child(label)
