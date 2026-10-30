extends CanvasLayer

var village: Node2D
var service: Node
var social: Node
var shade: ColorRect
var window: Panel
var human_panel: Panel
var log_panel: Panel
var log_text: Label
var log_lines: Array[String] = []
var selected := "Creative"
var drafts: Dictionary = {}
var draft_keys: Dictionary = {}
var provider: OptionButton
var endpoint: LineEdit
var model: LineEdit
var reply_timeout: SpinBox
var reasoning: OptionButton
var api_key: LineEdit
var key_env: LineEdit
var personality: TextEdit
var social_toggle: CheckBox
var feedback: Label
var picture: TextureRect
var role_heading: Label
var human_to: OptionButton
var human_input: LineEdit
var test_ticket := -1000
var role_buttons: Dictionary = {}

func setup(v: Node2D, s: Node, talk: Node) -> void:
	village = v
	service = s
	social = talk
	layer = 10
	build()
	service.line_ready.connect(test_result)
	social.spoken.connect(add_log)

func button(text: String, pos: Vector2, size: Vector2, parent: Node, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size",17)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("285454") if state in ["hover","disabled"] else Color("183438")
		style.border_color = Color("c6ad6c") if state == "disabled" else Color("426762")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state,style)
	b.add_theme_color_override("font_disabled_color",Color("ffe6a6"))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func field(pos: Vector2, width: float, parent: Node) -> LineEdit:
	var f := LineEdit.new()
	f.position = pos
	f.size = Vector2(width,39)
	f.max_length = 500
	f.add_theme_font_size_override("font_size",17)
	parent.add_child(f)
	return f

func caption(text: String, pos: Vector2, parent: Node, size := 16) -> Label:
	return village.label(text,pos,size,parent,Color("d8e7df"))

func build() -> void:
	button("AI settings  [S]",Vector2(1080,25),Vector2(190,44),self,toggle_settings)
	button("Speak as Governor  [G]",Vector2(1280,25),Vector2(230,44),self,toggle_human)
	log_panel = village.panel(Vector2(1040,83),Vector2(470,185),self)
	caption("VILLAGE VOICES",Vector2(18,12),log_panel,17)
	log_text = caption("Neighbors will greet each other when they meet.\nGovernor replies are always written by you.",Vector2(18,44),log_panel,15)
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.size = Vector2(435,132)
	log_text.set_deferred("size",Vector2(435,132))
	log_text.clip_text = true
	shade = ColorRect.new()
	shade.color = Color(0.015,0.035,0.05,0.72)
	shade.size = Vector2(1536,1024)
	shade.visible = false
	add_child(shade)
	window = village.panel(Vector2(143,100),Vector2(1250,800),shade)
	caption("RESIDENT AI SETTINGS",Vector2(30,22),window,28)
	caption("Four AI residents. The Governor is you — no AI profile or automatic replies.",Vector2(30,66),window,17)
	button("Close",Vector2(1120,24),Vector2(100,40),window,toggle_settings)
	for i in 4:
		var role: String = service.ROLES[i]
		role_buttons[role] = button(role,Vector2(30,120+i*54),Vector2(255,43),window,func(): select_role(role))
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.position = Vector2(47,361)
	picture.size = Vector2(220,300)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	window.add_child(picture)
	role_heading = caption("",Vector2(30,681),window,24)
	caption("Settings save on this computer.\nAPI keys stay in this session only.",Vector2(30,724),window,14)
	caption("Dialogue provider",Vector2(330,115),window)
	provider = OptionButton.new()
	provider.add_item("Offline small talk — no connection needed",0)
	provider.add_item("Chat-completions API — local or hosted model",1)
	provider.position = Vector2(330,140)
	provider.size = Vector2(860,40)
	window.add_child(provider)
	social_toggle = CheckBox.new()
	social_toggle.text = "Join nearby conversations"
	social_toggle.position = Vector2(905,106)
	window.add_child(social_toggle)
	caption("Full chat-completions endpoint URL",Vector2(330,198),window)
	endpoint = field(Vector2(330,224),860,window)
	caption("Model name (as listed by your server)",Vector2(330,278),window)
	model = field(Vector2(330,304),410,window)
	model.placeholder_text = "Model ID from your server"
	caption("Timeout (seconds)",Vector2(760,278),window)
	reply_timeout = SpinBox.new()
	reply_timeout.min_value = 5
	reply_timeout.max_value = 180
	reply_timeout.step = 1
	reply_timeout.position = Vector2(760,304)
	reply_timeout.size = Vector2(165,39)
	window.add_child(reply_timeout)
	caption("Thinking",Vector2(945,278),window)
	reasoning = OptionButton.new()
	reasoning.add_item("Provider default")
	reasoning.add_item("Off (Qwen / Ollama)")
	reasoning.position = Vector2(945,304)
	reasoning.size = Vector2(245,39)
	window.add_child(reasoning)
	caption("API key — optional, kept only until you quit",Vector2(330,356),window)
	api_key = field(Vector2(330,382),405,window)
	api_key.secret = true
	api_key.placeholder_text = "Leave blank for a local server"
	caption("Or read the key from this environment variable",Vector2(760,356),window)
	key_env = field(Vector2(760,382),430,window)
	caption("Personality and conversation style",Vector2(330,434),window)
	personality = TextEdit.new()
	personality.position = Vector2(330,460)
	personality.size = Vector2(860,112)
	personality.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	personality.add_theme_font_size_override("font_size",17)
	window.add_child(personality)
	var note := caption("API mode sends this personality and recent village dialogue to your endpoint. Hosted providers may charge. Offline mode uses built-in lines; personality instructions apply to API mode.",Vector2(330,586),window,15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.clip_text = true
	note.size = Vector2(860,50)
	note.set_deferred("size",Vector2(860,50))
	button("Test this connection",Vector2(330,648),Vector2(220,43),window,test_connection)
	button("Save this resident",Vector2(570,648),Vector2(220,43),window,save_current)
	feedback = caption("",Vector2(330,709),window,16)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.clip_text = true
	feedback.size = Vector2(860,70)
	human_panel = village.panel(Vector2(418,600),Vector2(700,290),self)
	human_panel.visible = false
	caption("SPEAK AS GOVERNOR",Vector2(24,20),human_panel,24)
	caption("Your words, sent to the selected resident. No generated Governor dialogue.",Vector2(24,61),human_panel,15)
	human_to = OptionButton.new()
	for role in service.ROLES:
		human_to.add_item(role)
	human_to.position = Vector2(24,98)
	human_to.size = Vector2(250,38)
	human_panel.add_child(human_to)
	human_input = field(Vector2(24,151),650,human_panel)
	human_input.max_length = 180
	human_input.placeholder_text = "Good morning! How is your day going?"
	human_input.text_submitted.connect(func(_text: String): send_human())
	button("Say it",Vector2(24,220),Vector2(130,42),human_panel,send_human)
	button("Close",Vector2(550,220),Vector2(125,42),human_panel,toggle_human)
	load_role()

func snapshot() -> Dictionary:
	return {"mode":provider.selected,"endpoint":endpoint.text.strip_edges(),"model":model.text.strip_edges(),"key_env":key_env.text.strip_edges(),"personality":personality.text.substr(0,4000),"social":social_toggle.button_pressed,"timeout_seconds":int(reply_timeout.value),"reasoning_effort":"none" if reasoning.selected == 1 else ""}

func stash() -> void:
	drafts[selected] = snapshot()
	draft_keys[selected] = api_key.text

func select_role(role: String) -> void:
	stash()
	selected = role
	load_role()

func load_role() -> void:
	var p: Dictionary = drafts.get(selected,service.profiles[selected])
	provider.select(int(p.mode))
	endpoint.text = str(p.endpoint)
	model.text = str(p.model)
	reply_timeout.value = float(p.get("timeout_seconds",12))
	reasoning.select(1 if str(p.get("reasoning_effort","")) == "none" else 0)
	key_env.text = str(p.key_env)
	personality.text = str(p.personality)
	social_toggle.button_pressed = bool(p.social)
	api_key.text = str(draft_keys.get(selected,service.session_keys.get(selected,"")))
	picture.texture = village.Resident.portrait(service.ROLES.find(selected)+1)
	role_heading.text = selected
	feedback.text = "Edit this resident, then Save. Testing sends one request using these fields."
	for role in role_buttons:
		role_buttons[role].disabled = role == selected

func toggle_settings() -> void:
	shade.visible = not shade.visible
	if shade.visible:
		# Refresh externally saved profiles; retain deliberate unsaved edits.
		if not service.test_mode:
			service.load_settings()
		load_role()
		human_panel.visible = false
		village.gallery.visible = false
	else:
		stash()
		window.get_viewport().gui_release_focus()

func toggle_human() -> void:
	human_panel.visible = not human_panel.visible
	if human_panel.visible:
		shade.visible = false
		village.gallery.visible = false
		human_input.grab_focus()
	else:
		human_panel.get_viewport().gui_release_focus()

func save_current() -> void:
	var p := snapshot()
	var issue: String = service.validation_error(p)
	if not issue.is_empty():
		feedback.text = issue
		return
	var error: Error = service.save_profile(selected,p,api_key.text)
	if error != OK:
		feedback.text = "Could not save settings. Check write access to the app data folder."
		return
	stash()
	feedback.text = selected+" saved. "+("Offline dialogue is active." if int(p.mode)==0 else "API dialogue is active. Keys are not saved to disk.")
	if not bool(p.social):
		for npc in social.active:
			if npc.role == selected:
				social.finish()
				break

func test_connection() -> void:
	test_ticket -= 1
	feedback.text = "Testing "+selected+"…"
	service.request_line(selected,"Greet the human Governor in one short sentence.","Hello, Governor! It's lovely to see you.",test_ticket,snapshot(),api_key.text)

func test_result(id: int, role: String, text: String, source: String, detail: String) -> void:
	if id == test_ticket and role == selected:
		feedback.text = source+": "+detail+"\n"+text

func send_human() -> void:
	if human_input.text.strip_edges().is_empty():
		return
	social.human_say(service.ROLES[human_to.selected],human_input.text)
	human_input.clear()
	human_panel.visible = false
	human_panel.get_viewport().gui_release_focus()

func add_log(role: String, text: String, source: String, detail: String) -> void:
	log_lines.append(role+" ["+source+"]: "+text.substr(0,130))
	if not detail.is_empty() and source == "Fallback":
		log_lines.append("Connection: "+detail)
	if source == "API / News":
		log_lines.append("Source: "+detail)
	while log_lines.size() > 2:
		log_lines.pop_front()
	log_text.text = "\n".join(log_lines)

func is_modal_open() -> bool:
	return shade.visible or human_panel.visible
