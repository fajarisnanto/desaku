extends Node

signal changed
const ROLES = ["Creative","Research","Operation","Maintenance"]
const CATALOG = {
 "workbench":{"name":"Work table","cost":14,"benefit":"capacity","points":12},
 "shelf":{"name":"Archive shelves","cost":10,"benefit":"knowledge","points":8},
 "lounge":{"name":"Rest corner","cost":12,"benefit":"comfort","points":12},
 "plants":{"name":"Indoor garden","cost":8,"benefit":"comfort","points":8},
 "lamp":{"name":"Task lighting","cost":8,"benefit":"capacity","points":6},
 "meeting":{"name":"Team meeting table","cost":16,"benefit":"community","points":12},
 "art":{"name":"Design easel","cost":18,"benefit":"knowledge","points":12,"role":"Creative"},
 "lab":{"name":"Discovery station","cost":18,"benefit":"knowledge","points":12,"role":"Research"},
 "board":{"name":"Planning board","cost":18,"benefit":"capacity","points":12,"role":"Operation"},
 "tools":{"name":"Repair station","cost":18,"benefit":"capacity","points":12,"role":"Maintenance"},
 "tea":{"name":"Tea station","cost":10,"benefit":"community","points":8},
 "desk":{"name":"Teammate desk","cost":12,"benefit":"capacity","points":8}
}
const SPECIALTIES = {
 "Creative":["Illustrator","Storyteller","Space designer"],
 "Research":["Botanist","Archivist","Experimenter"],
 "Operation":["Logistics coordinator","Community organizer","Resource planner"],
 "Maintenance":["Mechanic","Gardener","Safety inspector"]
}
var offices: Dictionary = {}
var history: Array = []
var enabled := true
var save_path := "user://offices.json"
var service: Node
var countdown := 5.0
var turn := 0
var pending_role := ""
var pending_actor := ""
var ticket := 1000000
var status := "Teams are surveying their empty offices."
var save_error := ""
var test_mode := false
var retry_until: Dictionary = {}
var autosave := 0.0
var save_blocked := false

func setup(api: Node, testing := false) -> void:
	service = api
	test_mode = testing
	reset()
	if not test_mode:
		load_world()
	service.plan_ready.connect(receive_plan)
	service.line_ready.connect(func(id: int, _role: String, _text: String, _source: String, detail: String):
		if id == ticket and not pending_role.is_empty():
			receive_plan(id,pending_role,{},detail)
	)

func reset() -> void:
	offices.clear()
	history.clear()
	for role in ROLES:
		offices[role] = {"materials":100.0,"items":[],"team":[],"project":{},"actor_turn":0,"last":"Surveying office requirements"}

func metrics(role: String) -> Dictionary:
	var values := {"comfort":20,"capacity":20,"knowledge":20,"community":20}
	for item in offices[role].items:
		var spec: Dictionary = CATALOG[item.kind]
		values[spec.benefit] = mini(100,int(values[spec.benefit])+int(spec.points))
	values.community = mini(100,int(values.community)+offices[role].team.size()*8)
	return values

func available(role: String) -> Dictionary:
	var options := {}
	for key in CATALOG:
		var copies := 0
		for item in offices[role].items:
			if item.kind == key:
				copies += 1
		if str(CATALOG[key].get("role",role)) == role and copies < (3 if key == "desk" else 1):
			options[key] = CATALOG[key]
	return options

func tick(delta: float) -> void:
	if not enabled or save_blocked:
		return
	autosave += delta
	if autosave >= 10:
		autosave = 0
		save_world()
	var completed := false
	for role in ROLES:
		var office: Dictionary = offices[role]
		office.materials = minf(140.0,float(office.materials)+delta*0.16)
		if not office.project.is_empty():
			office.project.remaining = maxf(0.0,float(office.project.remaining)-delta)
			if float(office.project.remaining) <= 0:
				var project: Dictionary = office.project
				if project.action == "build":
					office.items.append({"kind":project.item,"slot":project.slot,"builder":project.actor})
					log_event(role,project.actor+" completed "+str(CATALOG[project.item].name)+".")
				else:
					office.team.append({"name":project.member_name,"specialty":project.specialty,"decisions":0})
					log_event(role,project.member_name+" joined as "+project.specialty+"; ready to plan and build.")
				office.project = {}
				completed = true
	if completed:
		save_world()
		changed.emit()
	countdown -= delta
	if test_mode or countdown > 0 or not pending_role.is_empty():
		return
	if service.busy or Time.get_ticks_msec()-service.last_request_ms < 6500:
		return
	for attempt in 4:
		var role: String = ROLES[turn%4]
		turn += 1
		if int(service.profiles[role].mode) != 1 or not offices[role].project.is_empty():
			continue
		if Time.get_unix_time_from_system() < float(retry_until.get(role,0)):
			continue
		request_decision(role)
		return
	status = "Waiting for an enabled AI team or the next review."
	countdown = 8.0

func request_decision(role: String) -> void:
	var office: Dictionary = offices[role]
	var actor_index: int = int(office.actor_turn) % (office.team.size()+1)
	pending_actor = role+" lead"
	var specialty := "Office lead: decide what this department needs first."
	if actor_index > 0:
		var member: Dictionary = office.team[actor_index-1]
		pending_actor = str(member.name)
		specialty = str(member.specialty)+": contribute independent ideas to your team."
		member.decisions = int(member.decisions)+1
	office.actor_turn = int(office.actor_turn)+1
	pending_role = role
	ticket += 1
	status = pending_actor+" is assessing "+role+" needs…"
	var occupied: Array = []
	for item in office.items:
		occupied.append(item.slot)
	var free_slots: Array = []
	for slot in 12:
		if not slot in occupied:
			free_slots.append(slot)
	var desks := 0
	for item in office.items:
		if item.kind == "desk":
			desks += 1
	var can_recruit: bool = office.items.size() >= 2 and desks > office.team.size() and office.team.size() < 3 and float(office.materials) >= 20
	var mission: String = {"Creative":"Design art, stories and welcoming spaces","Research":"Investigate nature and share useful knowledge","Operation":"Coordinate supplies, schedules and community projects","Maintenance":"Maintain tools, paths, lamps and the fountain"}[role]
	var prompt := "ACTOR: "+pending_actor+". Specialty: "+specialty+". MISSION: "+mission+".\nAssess your actual office below. Choose ONE improvement, explaining the unmet need. Prefer a department-specific station, comfortable surroundings and useful teamwork over duplicate furniture. If there is a specific job to delegate, prepare a desk then recruit. Recruits take their own planning turns and accelerate construction. You may wait when satisfied.\nCURRENT STATE: "+JSON.stringify({"materials":int(office.materials),"completed":office.items,"team":office.team,"wellbeing":metrics(role),"free_slots":free_slots,"recruitment_ready":can_recruit,"last_decision":office.last})+"\nAVAILABLE BUILD ITEMS (only these keys allowed): "+JSON.stringify(available(role))+"\nSPECIALTIES: "+JSON.stringify(SPECIALTIES[role])+"\nJSON fields for build: action=build, item=one available key, slot=one free_slots integer, reason=short specific reason. For recruit (only when recruitment_ready): action=recruit, name=short unique personal name, specialty=exact allowed specialty, reason=specific job. For wait: action=wait, reason=why. Recruitment costs 20 and needs a free desk. Maximum 3 teammates; Governor is never AI. Return only JSON. Do not reuse a completed item or occupied slot."
	if available(role).is_empty() or free_slots.is_empty():
		prompt += "\nIMPORTANT: This office cannot build any more furnishings. Choose recruit if recruitment_ready is true and a useful job exists; otherwise choose wait. Do not choose build."
	service.request_plan(role,prompt,ticket)
	changed.emit()

func receive_plan(id: int, role: String, plan: Dictionary, detail: String) -> void:
	if id != ticket or role != pending_role:
		return
	pending_role = ""
	var problem := ""
	if plan.is_empty():
		problem = detail
	elif not enabled:
		problem = "Autonomy paused; decision deferred."
	else:
		problem = apply_plan(role,plan,pending_actor)
	if not problem.is_empty():
		status = role+": "+problem
		offices[role].last = problem
		log_event(role,problem)
		retry_until[role] = Time.get_unix_time_from_system()+40
	else:
		status = role+": "+str(offices[role].last)
	countdown = 12.0
	save_world()
	changed.emit()

func apply_plan(role: String, plan: Dictionary, actor: String) -> String:
	if not role in ROLES:
		return "Unknown office."
	var office: Dictionary = offices[role]
	if not office.project.is_empty():
		return "A project is already underway."
	var action := str(plan.get("action",""))
	var reason := str(plan.get("reason","")).strip_edges().substr(0,240)
	if reason.is_empty():
		return "Decision needs a reason."
	if action == "wait":
		office.last = actor+" is reflecting: "+reason
		log_event(role,office.last)
		retry_until[role] = Time.get_unix_time_from_system()+90
		return ""
	var cost := 0
	var duration := 0.0
	var project := {"action":action,"actor":actor,"reason":reason}
	if action == "build":
		var item := str(plan.get("item",""))
		if not item in available(role):
			return "Unknown or unsuitable furnishing; no materials spent."
		var raw_slot: Variant = plan.get("slot",-1)
		if not (raw_slot is int or raw_slot is float) or float(raw_slot) != floor(float(raw_slot)):
			return "Invalid floor position."
		var slot := int(raw_slot)
		if slot < 0 or slot >= 12:
			return "Floor position is outside the office."
		var copies := 0
		for existing in office.items:
			if int(existing.slot) == slot:
				return "That floor position is already occupied."
			if existing.kind == item:
				copies += 1
		if copies >= (3 if item == "desk" else 1):
			return "This office already has enough of that furnishing."
		cost = int(CATALOG[item].cost)
		duration = 22.0 / (1.0+office.team.size()*0.3)
		project.item = item
		project.slot = slot
	elif action == "recruit":
		if office.team.size() >= 3:
			return "Team capacity reached."
		var desks := 0
		for item in office.items:
			if item.kind == "desk":
				desks += 1
		if office.items.size() < 2 or desks <= office.team.size():
			return "Prepare useful workspace and a free teammate desk before recruiting."
		var name_text := str(plan.get("name","")).strip_edges().substr(0,24)
		var specialty := str(plan.get("specialty",""))
		if name_text.length() < 2 or "governor" in name_text.to_lower() or "\n" in name_text or "\r" in name_text or not specialty in SPECIALTIES[role]:
			return "Recruit needs a valid name and department specialty."
		for other_role in ROLES:
			if name_text.to_lower() == other_role.to_lower():
				return "Choose a personal name distinct from department leads."
			var other_project: Dictionary = offices[other_role].project
			if other_project.get("action") == "recruit" and str(other_project.get("member_name","")).to_lower() == name_text.to_lower():
				return "A recruitment is already underway for that name."
			for member in offices[other_role].team:
				if str(member.name).to_lower() == name_text.to_lower():
					return "A teammate already uses that name."
		cost = 20
		duration = 16.0
		project.member_name = name_text
		project.specialty = specialty
	else:
		return "Unsupported action; nothing changed."
	if float(office.materials) < cost:
		return "Saving materials for this project."
	office.materials -= cost
	project.remaining = duration
	project.duration = duration
	office.project = project
	office.last = actor+": "+reason
	log_event(role,("Building "+str(CATALOG[project.item].name) if action == "build" else "Recruiting "+str(project.member_name))+" — "+reason)
	return ""

func log_event(role: String, text: String) -> void:
	history.push_front({"role":role,"text":text.substr(0,350),"time":Time.get_datetime_string_from_system()})
	if history.size() > 80:
		history.resize(80)

func save_world() -> void:
	if test_mode or save_blocked:
		return
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file == null:
		save_error = "Office save failed; progress is only in memory."
		return
	file.store_string(JSON.stringify({"version":1,"enabled":enabled,"offices":offices,"history":history},"\t"))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))
	save_error = "" if err == OK else "Office save failed; progress is only in memory."

func load_world() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = decode_json(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("offices") is Dictionary:
		save_error = "Office save could not be read. Existing file preserved; saving disabled for this session."
		save_blocked = true
		enabled = false
		return
	for role in ROLES:
		var entry = data.offices.get(role,{})
		if not entry is Dictionary or not entry.get("items",[]) is Array or not entry.get("team",[]) is Array or not entry.get("project",{}) is Dictionary:
			save_error = "Invalid office save. Existing file preserved; saving disabled for this session."
			save_blocked = true
			enabled = false
			return
	enabled = bool(data.get("enabled",true))
	# Rebuild saved furnishings and teams through the same action validation.
	for role in ROLES:
		var saved = data.offices.get(role,{})
		if not saved is Dictionary:
			continue
		var office: Dictionary = offices[role]
		for item in saved.get("items",[]).slice(0,12):
			if item is Dictionary:
				office.materials = 140.0
				if apply_plan(role,{"action":"build","item":item.get("kind",""),"slot":item.get("slot",-1),"reason":"Restored workspace"},str(item.get("builder",role))).is_empty():
					office.items.append({"kind":office.project.item,"slot":office.project.slot,"builder":office.project.actor})
					office.project = {}
		for member in saved.get("team",[]).slice(0,3):
			if member is Dictionary:
				office.materials = 140.0
				if apply_plan(role,{"action":"recruit","name":member.get("name",""),"specialty":member.get("specialty",""),"reason":"Restored teammate"},role).is_empty():
					office.team.append({"name":office.project.member_name,"specialty":office.project.specialty,"decisions":maxi(0,int(member.get("decisions",0)))})
					office.project = {}
		var pending = saved.get("project",{})
		if pending is Dictionary and not pending.is_empty():
			office.materials = 140.0
			var restored: Dictionary = pending.duplicate()
			if restored.get("action") == "recruit":
				restored.name = restored.get("member_name","")
			if restored.get("action") in ["build","recruit"] and apply_plan(role,restored,str(pending.get("actor",role))).is_empty():
				office.project.remaining = clampf(float(pending.get("remaining",1)),0,float(office.project.duration))
		office.materials = clampf(float(saved.get("materials",100)),0,140)
		office.actor_turn = maxi(0,int(saved.get("actor_turn",0)))
		office.last = str(saved.get("last","Restored office")).substr(0,350)
	history = []
	if data.get("history") is Array:
		for entry in data.history.slice(0,80):
			if entry is Dictionary and entry.get("role") in ROLES:
				history.append({"role":entry.role,"text":str(entry.get("text","")).substr(0,350),"time":str(entry.get("time","")).substr(0,30)})


func decode_json(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data
