extends Node2D

const TEXTURES = [preload("res://assets/governor.png"), preload("res://assets/creative.png"), preload("res://assets/research.png"), preload("res://assets/operation.png"), preload("res://assets/maintenance.png")]
const ROLES = ["Governor", "Creative", "Research", "Operation", "Maintenance"]
const WALK_SHADER = preload("res://scripts/resident_walk.gdshader")
static var regions: Array[Rect2] = []
var role := "Governor"
var tint := Color("3871b5")
var route := PackedVector2Array()
var speed := 38.0
var rest := 1.0
var phase := 0.0
var facing := 1.0
var moving := false
var player_controlled := false
var journeys := 0
var font := ThemeDB.fallback_font
var visual: MeshInstance2D
var walk_material: ShaderMaterial
var walk_blend := 0.0
var conversing := false
var speech_panel: Panel
var speech_label: Label
var speech_time := 0.0

static func prepare_regions() -> void:
	if not regions.is_empty():
		return
	for i in 5:
		var img: Image = TEXTURES[i].get_image()
		var used := img.get_used_rect()
		assert(used.has_area(),"Missing character image")
		regions.append(Rect2(used))

static func portrait(index: int) -> AtlasTexture:
	prepare_regions()
	var tex := AtlasTexture.new()
	tex.atlas = TEXTURES[index]
	tex.region = regions[index]
	tex.filter_clip = true
	return tex

func _ready() -> void:
	prepare_regions()
	var index := ROLES.find(role)
	var region: Rect2 = regions[index]
	var texture: Texture2D = TEXTURES[index]
	var height := 128.0 if index == 0 else 108.0
	var width := height * region.size.x / region.size.y
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const COLS := 20
	const ROWS := 30
	for y in range(ROWS+1):
		for x in range(COLS+1):
			var uv := Vector2(float(x)/COLS,float(y)/ROWS)
			vertices.append(Vector3((uv.x-0.5)*width,(uv.y-1.0)*height,0))
			uvs.append((region.position+uv*region.size)/Vector2(texture.get_size()))
	for y in ROWS:
		for x in COLS:
			var a := y*(COLS+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+COLS+1,a+1,a+COLS+2,a+COLS+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	visual = MeshInstance2D.new()
	visual.mesh = mesh
	visual.texture = texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	walk_material = ShaderMaterial.new()
	walk_material.shader = WALK_SHADER
	walk_material.set_shader_parameter("uv_origin",region.position/Vector2(texture.get_size()))
	walk_material.set_shader_parameter("uv_size",region.size/Vector2(texture.get_size()))
	visual.material = walk_material
	add_child(visual)
	phase = index * 1.7
	speech_panel = Panel.new()
	speech_panel.position = Vector2(-130,-250)
	speech_panel.size = Vector2(260,118)
	speech_panel.z_index = 2000
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color("fcf4dc")
	bubble.border_color = tint
	bubble.set_border_width_all(2)
	bubble.set_corner_radius_all(12)
	speech_panel.add_theme_stylebox_override("panel",bubble)
	speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_label = Label.new()
	speech_label.position = Vector2(10,7)
	speech_label.size = Vector2(240,104)
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.add_theme_color_override("font_color",Color("193238"))
	speech_label.add_theme_font_size_override("font_size",15)
	speech_label.clip_text = true
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_panel.add_child(speech_label)
	add_child(speech_panel)
	speech_panel.hide()

func speak(text: String) -> void:
	speech_label.text = text.substr(0,180)
	speech_time = 7.5
	speech_panel.show()

func clear_speech() -> void:
	speech_time = 0.0
	if speech_panel:
		speech_panel.hide()

func advance(delta: float) -> void:
	phase += delta * 7.0
	speech_time = maxf(0.0,speech_time-delta)
	if speech_time <= 0.0:
		speech_panel.hide()
	moving = (not route.is_empty() and not conversing and role != "Governor") or (role == "Governor" and player_controlled and not conversing)
	if moving:
		var target := route[0]
		var offset := target - position
		if absf(offset.x) > 0.5:
			facing = signf(offset.x)
		position = position.move_toward(target, speed * delta)
		if position.distance_to(target) < 0.1:
			route.remove_at(0)
			if route.is_empty():
				journeys += 1
				rest = randf_range(1.5, 4.5)
	else:
		rest -= delta
	walk_blend = move_toward(walk_blend,1.0 if moving else 0.0,delta*5.0)
	if visual:
		visual.scale.x = facing
		walk_material.set_shader_parameter("phase",phase)
		walk_material.set_shader_parameter("walking",walk_blend)
	z_index = int(position.y)
	queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * i/48.0
		points.append(Vector2(cos(a)*23,sin(a)*7+1))
	draw_colored_polygon(points,Color(0.05,0.12,0.13,0.26))
	var display_name := "Governor · You" if role == "Governor" else role
	var width := font.get_string_size(display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	var box := StyleBoxFlat.new()
	box.bg_color=Color(0.035,0.10,0.13,0.91)
	box.border_color=tint.lightened(0.2)
	box.border_width_bottom=2
	box.set_corner_radius_all(6)
	draw_style_box(box,Rect2(-width/2-9,11,width+18,24))
	draw_string(font,Vector2(-width/2,27),display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff5df"))
