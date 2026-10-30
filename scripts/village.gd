extends Node2D

const Resident = preload("res://scripts/resident.gd")
const AIService = preload("res://scripts/ai_service.gd")
const Social = preload("res://scripts/social.gd")
const SettingsUI = preload("res://scripts/settings_ui.gd")
const ROLES = ["Governor", "Creative", "Research", "Operation", "Maintenance"]
const COLORS = [Color("3871b5"),Color("e47794"),Color("7da5dc"),Color("66915d"),Color("dfac45")]
const FOUNTAIN = Vector2(768,548)
const STEP = 20
const STARTS = [Vector2(768,400),Vector2(570,695),Vector2(670,720),Vector2(1020,700),Vector2(925,735)]
var graph := AStar2D.new()
var cells := {}
var residents: Array = []
var elapsed := 0.0
var time_scale := 1.0
var paused := false
var status: Label
var font := ThemeDB.fallback_font
var debug_paths := false
var gallery: Panel
var ai_service: Node
var social: Node
var settings_ui: CanvasLayer
var office_world: Node
var office_ui: CanvasLayer
var news_feed: Node
var news_ui: CanvasLayer
var hud: CanvasLayer
var plaza := PackedVector2Array([Vector2(475,365),Vector2(680,350),Vector2(768,320),Vector2(895,357),Vector2(1060,365),Vector2(1190,470),Vector2(1160,650),Vector2(1050,755),Vector2(870,825),Vector2(650,825),Vector2(490,760),Vector2(385,650),Vector2(375,475)])

func _ready() -> void:
	randomize()
	var background := Sprite2D.new()
	background.texture = preload("res://assets/village.png")
	background.centered = false
	background.z_index = -1
	add_child(background)
	build_navigation()
	for i in 5:
		var npc := Resident.new()
		npc.role = ROLES[i]
		npc.tint = COLORS[i]
		npc.speed = 32.0 + i * 3.5
		npc.position = graph.get_point_position(graph.get_closest_point(STARTS[i]))
		npc.rest = i * 0.6
		add_child(npc)
		residents.append(npc)
	build_ui()
	ai_service = AIService.new()
	ai_service.test_mode = "--self-test" in OS.get_cmdline_user_args() or "--social-test" in OS.get_cmdline_user_args() or "--beta-smoke" in OS.get_cmdline_user_args()
	add_child(ai_service)
	social = Social.new()
	add_child(social)
	social.setup(self,ai_service)
	settings_ui = SettingsUI.new()
	add_child(settings_ui)
	settings_ui.setup(self,ai_service,social)
	office_world = load("res://scripts/office_world.gd").new()
	add_child(office_world)
	office_world.setup(ai_service,ai_service.test_mode or "--office-test" in OS.get_cmdline_user_args())
	office_ui = load("res://scripts/office_ui.gd").new()
	add_child(office_ui)
	office_ui.setup(self,office_world)
	news_feed = load("res://scripts/news_feed.gd").new()
	add_child(news_feed)
	news_feed.setup(ai_service.test_mode or "--script" in OS.get_cmdline_args())
	social.news_feed = news_feed
	news_ui = load("res://scripts/news_ui.gd").new()
	add_child(news_ui)
	news_ui.setup(self,news_feed)
	tree_exiting.connect(func(): office_world.save_world())
	if "--beta-smoke" in OS.get_cmdline_user_args():
		var smoke = load("res://scripts/beta_smoke.gd").new()
		add_child(smoke)
		smoke.call_deferred("run",self)
	if "--self-test" in OS.get_cmdline_user_args():
		run_self_test()
	if "--social-test" in OS.get_cmdline_user_args():
		run_social_test()
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview()

func walkable(p: Vector2) -> bool:
	# Expanded footprint includes fountain flowers and the resident's body radius.
	var delta := (p - FOUNTAIN) / Vector2(137,90)
	return Geometry2D.is_point_in_polygon(p,plaza) and delta.length_squared() > 1.0

func build_navigation() -> void:
	for y in range(320,841,STEP):
		for x in range(360,1201,STEP):
			var p := Vector2(x,y)
			if walkable(p):
				var id := graph.get_point_count()
				cells[Vector2i(x,y)] = id
				graph.add_point(id,p)
	for cell in cells:
		for offset in [Vector2i(STEP,0),Vector2i(0,STEP),Vector2i(STEP,STEP),Vector2i(-STEP,STEP)]:
			var other: Vector2i = cell + offset
			if not cells.has(other):
				continue
			# No diagonal corner cutting; verify the whole edge, not only endpoints.
			var legal := true
			for k in range(1,9):
				if not walkable(Vector2(cell).lerp(Vector2(other),float(k)/9.0)):
					legal = false
			if legal:
				graph.connect_points(cells[cell],cells[other])

func choose_destination(npc: Node2D) -> void:
	var origin := graph.get_closest_point(npc.position)
	var destination := randi_range(0,graph.get_point_count()-1)
	for attempt in 16:
		if graph.get_point_position(destination).distance_to(npc.position) > 130.0:
			break
		destination = randi_range(0,graph.get_point_count()-1)
	npc.route = graph.get_point_path(origin,destination)
	if not npc.route.is_empty():
		npc.route.remove_at(0)

func simulate(delta: float) -> void:
	for npc in residents:
		if npc.role != "Governor" and not npc.conversing and npc.route.is_empty() and npc.rest <= 0.0:
			choose_destination(npc)
		npc.advance(delta)

func _process(delta: float) -> void:
	if not paused and not settings_ui.is_modal_open() and not news_ui.shade.visible:
		office_world.tick(delta)
	if not paused and not settings_ui.is_modal_open() and not office_ui.shade.visible and not news_ui.shade.visible:
		elapsed += delta * time_scale
		social.tick(delta * time_scale)
		simulate(delta * time_scale)
	var walkers := 0
	for npc in residents:
		if npc.moving:
			walkers += 1
	status.text = "%d wandering · %d chatting · Governor: human" % [walkers,social.active.size()]
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if news_ui.shade.visible:
				news_ui.close()
			elif office_ui.shade.visible:
				office_ui.close()
			elif settings_ui.shade.visible:
				settings_ui.toggle_settings()
			elif settings_ui.human_panel.visible:
				settings_ui.toggle_human()
			elif gallery.visible:
				gallery.hide()
			else:
				get_tree().quit()
			return
		if settings_ui.is_modal_open():
			return
		if news_ui.shade.visible:
			if event.keycode == KEY_N:
				news_ui.close()
			return
		if office_ui.shade.visible:
			if event.keycode == KEY_O:
				office_ui.close()
			return
		match event.keycode:
			KEY_N: news_ui.open()
			KEY_O: office_ui.open()
			KEY_S: settings_ui.toggle_settings()
			KEY_G: settings_ui.toggle_human()
			KEY_L: settings_ui.log_panel.visible = not settings_ui.log_panel.visible
			KEY_C: gallery.visible = not gallery.visible
			KEY_SPACE: paused = not paused
			KEY_TAB: debug_paths = not debug_paths
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_ESCAPE: get_tree().quit()

func panel(pos: Vector2, size: Vector2, parent: Node) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.12,0.14,0.94)
	style.border_color = Color(0.82,0.72,0.44,0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	return p

func label(text: String, pos: Vector2, size: int, parent: Node, color := Color("f5e7c8")) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func build_ui() -> void:
	var ui := CanvasLayer.new()
	hud = ui
	add_child(ui)
	var title := panel(Vector2(25,25),Vector2(343,105),ui)
	label("F O U N T A I N   C O M M O N S",Vector2(18,15),18,title)
	label("An AI village",Vector2(18,39),29,title)
	label("STAGE 03   /   LIVING OFFICES",Vector2(19,78),12,title,Color("9fbdba"))
	var footer := panel(Vector2(25,934),Vector2(1486,65),ui)
	status = label("",Vector2(20,10),17,footer)
	label("Four AI neighbors. You are the Governor.",Vector2(20,36),13,footer,Color("9fbdba"))
	label("O offices  S settings  G speak  SPACE pause  F11 full",Vector2(1010,25),12,footer,Color("bbcec7"))
	for i in 5:
		label("●  " + ROLES[i],Vector2(430+i*113,26),14,footer,COLORS[i].lightened(0.4))
	var names := ["TOWNHALL","CREATIVE","RESEARCH","OPERATION","MAINTENANCE","THE LANTERN PUB","GARDEN"]
	var locations := [Vector2(768,237),Vector2(268,370),Vector2(1295,390),Vector2(209,645),Vector2(1350,664),Vector2(246,912),Vector2(1240,884)]
	for i in names.size():
		var width := font.get_string_size(names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x + 24
		var plaque := panel(locations[i]-Vector2(width/2,0),Vector2(width,27),ui)
		label(names[i],Vector2(12,4),13,plaque)
		if i in [1,2,3,4]:
			var office_role: String = ROLES[i]
			plaque.mouse_filter = Control.MOUSE_FILTER_STOP
			plaque.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			plaque.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					office_ui.open(office_role)
			)
	gallery = panel(Vector2(48,160),Vector2(1440,705),ui)
	gallery.visible = false
	label("THE RESIDENTS OF FOUNTAIN COMMONS",Vector2(35,26),27,gallery)
	label("Adapted from your original character lineup",Vector2(35,65),17,gallery,Color("a4bfba"))
	label("Press C to return to the village",Vector2(1100,35),16,gallery,Color("a4bfba"))
	var descriptions := ["Crown, crystal staff & royal cape","Paintbrush, palette & pink ponytail","Silver hair, spectacles & spellbook","Green field uniform & expedition kit","Goggles, workshop apron & wrench"]
	for i in 5:
		var card := panel(Vector2(25+i*281,112),Vector2(266,560),gallery)
		var portrait := TextureRect.new()
		portrait.texture = Resident.portrait(i)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.position = Vector2(10,15)
		portrait.size = Vector2(246,445)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card.add_child(portrait)
		label(ROLES[i],Vector2(18,470),23,card,COLORS[i].lightened(0.3))
		label(descriptions[i],Vector2(18,511),12,card,Color("bbcec7"))

func _draw() -> void:
	# Water rings and jets are drawn over the painted basin.
	for ring in 5:
		var progress := fmod(elapsed * 0.35 + ring * 0.2,1.0)
		var points := PackedVector2Array()
		for j in 65:
			var angle := TAU*j/64.0
			points.append(Vector2(768,540)+Vector2(cos(angle)*65,sin(angle)*28)*progress)
		draw_polyline(points,Color(0.75,1.0,0.98,(1.0-progress)*0.65),1.5,true)
	for jet in 7:
		var a := float(jet)/7.0*TAU
		var points := PackedVector2Array()
		for j in 25:
			var p := float(j)/24.0
			points.append(Vector2(768,526)+Vector2(cos(a)*25*p,sin(a)*11*p-30*sin(PI*p)))
		draw_polyline(points,Color(0.77,1,1,0.55),1.4,true)
		var t := fmod(elapsed*0.8+jet*0.14,1.0)
		var drop := Vector2(768,526)+Vector2(cos(a)*25*t,sin(a)*11*t-30*sin(PI*t))
		draw_circle(drop,1.8,Color(0.9,1,1,0.9))
	# Tiny warm motes add life without obstructing navigation.
	for i in 22:
		var x := 400+fmod(i*137.3+elapsed*5,740)
		var y := 390+fmod(i*73.7+sin(elapsed*0.4+i)*12,420)
		draw_circle(Vector2(x,y),1.5,Color(1,0.93,0.67,0.2+0.15*sin(elapsed+i)))
	if debug_paths:
		draw_polyline(plaza+PackedVector2Array([plaza[0]]),Color(0.2,1,0.7,0.6),2,true)
		for npc in residents:
			if not npc.route.is_empty():
				draw_polyline(PackedVector2Array([npc.position])+npc.route,npc.tint.lightened(0.3),2,true)

func run_self_test() -> void:
	seed(20261029)
	var failed := false
	for i in 5:
		var image: Image = Resident.TEXTURES[i].get_image()
		var used: Rect2 = Resident.regions[i]
		print("SPRITE ",ROLES[i]," ",image.get_size()," bounds=",used)
		if not image.is_invisible() and image.get_pixel(0,0).a < 0.01 and used.has_area():
			continue
		push_error("Invalid transparent sprite: " + ROLES[i])
		failed = true
	# Ten simulated minutes, sampling every resident at 20 Hz.
	for tick in 12000:
		simulate(0.05)
		for npc in residents:
			if not walkable(npc.position):
				push_error("Resident left walkable space: " + npc.role)
				failed = true
	for npc in residents:
		print("TEST ",npc.role,": ",npc.journeys," destinations reached")
		if npc.role != "Governor" and npc.journeys < 5:
			failed = true
		if npc.role == "Governor" and npc.journeys != 0:
			failed = true
	print("NAVIGATION TEST: ","FAIL" if failed else "PASS", " | nodes=",graph.get_point_count()," | 60,000 position checks")
	get_tree().quit(1 if failed else 0)

func run_social_test() -> void:
	seed(20261030)
	var failures: Array[String] = []
	var lines: Array = []
	social.spoken.connect(func(role: String, text: String, source: String, _detail: String): lines.append({"role":role,"text":text,"source":source}))
	var governor_start: Vector2 = residents[0].position
	if ai_service.profiles.has("Governor") or ai_service.profiles.size() != 4:
		failures.append("Governor must have no AI profile")
	if social.clear_sight(Vector2(600,540),Vector2(940,540)):
		failures.append("Conversation line of sight crosses fountain")
	for tick in 12000:
		social.tick(0.05)
		simulate(0.05)
		for npc in residents:
			if not walkable(npc.position):
				failures.append("Resident left navigation area")
	if social.conversation_count < 3:
		failures.append("Too few proximity conversations")
	if residents[0].position != governor_start or residents[0].journeys != 0:
		failures.append("Governor moved autonomously")
	for line in lines:
		if line.role == "Governor":
			failures.append("Governor spoke autonomously")
	var count_before := lines.size()
	social.human_say("Creative","Hello, this is the human Governor.")
	for tick in 260:
		social.tick(0.05)
		simulate(0.05)
	if lines.size() < count_before+2 or lines[count_before].text != "Hello, this is the human Governor." or lines[count_before+1].role != "Creative":
		failures.append("Human conversation did not produce user line and AI reply")
	social.finish()
	for role in ai_service.ROLES:
		ai_service.profiles[role].social = false
	var chats_before: int = social.conversation_count
	for tick in 200:
		social.tick(0.05)
	if social.conversation_count != chats_before:
		failures.append("Disabled social residents initiated a conversation")
	print("SOCIAL TEST: ","PASS" if failures.is_empty() else "FAIL", " | conversations=",social.conversation_count," | lines=",lines.size()," | Governor is human and stationary | proximity, cooldowns, line of sight, opt-out and manual reply verified")
	for issue in failures:
		push_error(issue)
	get_tree().quit(0 if failures.is_empty() else 1)

func capture_preview() -> void:
	await get_tree().create_timer(3.0).timeout
	if "--gallery" in OS.get_cmdline_user_args():
		gallery.visible = true
	if "--settings" in OS.get_cmdline_user_args():
		settings_ui.toggle_settings()
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("VILLAGE_CAPTURE_PATH")
	if not path.is_empty():
		get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
