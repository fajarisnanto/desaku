extends CanvasLayer

var village: Node
var world: Node
var shade: ColorRect
var room: Control
var selected := "Operation"
var heading: Label
var summary: Label
var project_label: Label
var progress: ProgressBar
var reason: Label
var team_text: Label
var journal: RichTextLabel
var inventory: Label
var metrics_text: Label
var toggle: Button
var tabs: Dictionary = {}

func setup(owner_village: Node, office_world: Node) -> void:
	village = owner_village
	world = office_world
	layer = 12
	village.settings_ui.button("Offices  [O]",Vector2(1080,276),Vector2(190,42),village.hud,func(): open())
	shade = ColorRect.new()
	shade.color = Color(0.015,0.04,0.06,0.94)
	shade.size = Vector2(1536,1024)
	add_child(shade)
	shade.visible = false
	var panel = village.panel(Vector2(35,35),Vector2(1466,954),shade)
	village.label("D E S A K U   /   L I V I N G   O F F I C E S",Vector2(28,20),15,panel,Color("b8cdbd"))
	heading = village.label("",Vector2(28,49),32,panel)
	village.settings_ui.button("Back to village",Vector2(1240,28),Vector2(195,40),panel,close)
	for i in 4:
		var role: String = world.ROLES[i]
		tabs[role] = village.settings_ui.button(role,Vector2(28+i*217,105),Vector2(205,42),panel,func(): select(role))
	toggle = village.settings_ui.button("",Vector2(1050,105),Vector2(385,42),panel,func():
		if world.save_blocked:
			return
		world.enabled = not world.enabled
		world.save_world()
	)
	var room_panel = village.panel(Vector2(28,166),Vector2(860,594),panel)
	room = load("res://scripts/office_room.gd").new()
	room.position = Vector2(15,45)
	room.size = Vector2(830,530)
	room.world = world
	room_panel.add_child(room)
	summary = village.label("",Vector2(20,15),16,room_panel,Color("b8d0c9"))
	metrics_text = village.label("",Vector2(20,558),15,room_panel,Color("ead5a6"))
	var activity = village.panel(Vector2(910,166),Vector2(525,594),panel)
	village.label("TEAM AT WORK",Vector2(22,18),18,activity,Color("e4c98f"))
	project_label = village.label("",Vector2(22,52),19,activity)
	progress = ProgressBar.new()
	progress.position = Vector2(22,88)
	progress.size = Vector2(480,15)
	progress.show_percentage = false
	activity.add_child(progress)
	reason = text_label(Vector2(22,118),Vector2(480,108),activity,16)
	village.label("PEOPLE & RESPONSIBILITIES",Vector2(22,240),17,activity,Color("e4c98f"))
	team_text = text_label(Vector2(22,278),Vector2(480,165),activity,16)
	village.label("COMPLETED WORKSPACE",Vector2(22,454),17,activity,Color("e4c98f"))
	inventory = text_label(Vector2(22,490),Vector2(480,85),activity,14)
	var bottom = village.panel(Vector2(28,778),Vector2(1407,150),panel)
	village.label("VILLAGE JOURNAL",Vector2(18,13),16,bottom,Color("e4c98f"))
	journal = RichTextLabel.new()
	journal.position = Vector2(18,40)
	journal.size = Vector2(1370,100)
	journal.add_theme_font_size_override("normal_font_size",14)
	journal.bbcode_enabled = false
	bottom.add_child(journal)

func text_label(pos: Vector2, area: Vector2, parent: Node, font_size: int) -> Label:
	var label = village.label("",pos,font_size,parent)
	label.size = area
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func open(role := "") -> void:
	if role in world.ROLES:
		selected = role
	village.settings_ui.shade.hide()
	village.settings_ui.human_panel.hide()
	village.gallery.hide()
	shade.show()
	refresh()

func close() -> void:
	shade.hide()

func select(role: String) -> void:
	selected = role
	refresh()

func _process(_delta: float) -> void:
	if shade != null and shade.visible:
		refresh()

func refresh() -> void:
	var office: Dictionary = world.offices[selected]
	heading.text = selected+" / a place to grow"
	room.role = selected
	for role in tabs:
		tabs[role].disabled = role == selected
	toggle.text = "Autonomy: active · click to pause" if world.enabled else "Autonomy: paused · click to resume"
	toggle.disabled = world.save_blocked
	summary.text = "%d / 12 spaces furnished     •     %d materials     •     %d teammates" % [office.items.size(),int(office.materials),office.team.size()]
	var values: Dictionary = world.metrics(selected)
	metrics_text.text = "Comfort %d     Work capacity %d     Knowledge %d     Community %d" % [values.comfort,values.capacity,values.knowledge,values.community]
	project_label.text = "Considering the next improvement"
	progress.value = 0
	if not office.project.is_empty():
		var project: Dictionary = office.project
		project_label.text = ("Building "+str(world.CATALOG[project.item].name) if project.action == "build" else "Welcoming "+str(project.member_name))
		progress.value = 100*(1.0-float(project.remaining)/float(project.duration))
	elif world.pending_role == selected:
		project_label.text = "Thinking about this office…"
	elif int(world.service.profiles[selected].mode) != 1:
		project_label.text = "Connect this resident in AI settings"
	reason.text = str(office.last)
	if not world.enabled:
		reason.text = "Autonomy paused. Plans and construction will resume when enabled."
	if not world.save_error.is_empty():
		reason.text = world.save_error
	team_text.text = selected+" lead — department direction\n"
	for member in office.team:
		team_text.text += str(member.name)+" — "+str(member.specialty)+"\n   "+str(member.decisions)+" planning turns\n"
	if office.team.is_empty():
		team_text.text += "No teammates yet. The lead can prepare a desk and recruit for a specific need."
	var names: Array[String] = []
	for item in office.items:
		names.append(str(world.CATALOG[item.kind].name))
	inventory.text = "An empty office, ready for the team's ideas." if names.is_empty() else ", ".join(names)
	var lines: Array[String] = []
	for entry in world.history.slice(0,12):
		lines.append(str(entry.time).right(8)+"  "+str(entry.role)+" · "+str(entry.text))
	journal.text = "Teams are surveying their offices. First decisions arrive shortly." if lines.is_empty() else "\n".join(lines)
