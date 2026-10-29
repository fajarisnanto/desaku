extends Node

signal spoken(role: String, text: String, source: String, detail: String)
var village: Node2D
var service: Node
var active: Array = []
var cooldowns: Dictionary = {}
var resident_cooldowns: Dictionary = {}
var timer := 0.0
var scan := 0.0
var step := 0
var pending := false
var ticket := 0
var transcript := ""
var conversation_count := 0
var enabled := true
const REPLIES = {
	"Creative": ["The fountain light is lovely today. Shall I paint something for our next village gathering?","A splash of color always helps. What has inspired you lately?","I'd love that! Let's swap ideas at the Lantern Pub later."],
	"Research": ["I've been reading by the fountain. Have you noticed how peaceful the water sounds?","That's a lovely thought. A short walk often brings my best ideas.","I'd enjoy that! I'll bring a curious story from my latest book."],
	"Operation": ["Everything is ticking along nicely. Have you had a chance to take a proper break?","Good company makes a busy day easier. Shall we meet in the garden later?","Sounds like a plan. I'll save us a table at the pub."],
	"Maintenance": ["The fountain is running beautifully. How is your day going?","A little tinkering and a little tea make a fine day. Need a hand with anything?","Count me in! I'll put my tools away and join you later."]
}

func setup(owner_village: Node2D, ai_service: Node) -> void:
	village = owner_village
	service = ai_service
	service.line_ready.connect(receive_line)

func greeting() -> String:
	var hour := int(Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system())+7*3600).hour)
	if hour < 12:
		return "Good morning"
	if hour < 18:
		return "Good afternoon"
	return "Good evening"

func tick(delta: float) -> void:
	for key in cooldowns:
		cooldowns[key] = maxf(0.0,float(cooldowns[key])-delta)
	for key in resident_cooldowns:
		resident_cooldowns[key] = maxf(0.0,float(resident_cooldowns[key])-delta)
	if not active.is_empty():
		if pending:
			return
		timer -= delta
		if timer <= 0:
			advance_conversation()
		return
	if not enabled:
		return
	scan -= delta
	if scan > 0:
		return
	scan = 0.5
	for i in range(1,village.residents.size()):
		var a = village.residents[i]
		if not bool(service.profiles[a.role].social) or float(resident_cooldowns.get(a.role,0.0)) > 0:
			continue
		for j in range(i+1,village.residents.size()+1):
			var b = village.residents[j%village.residents.size()]
			if b.role != "Governor" and not bool(service.profiles[b.role].social):
				continue
			if float(resident_cooldowns.get(b.role,0.0)) > 0 or float(cooldowns.get(pair_key(a,b),0.0)) > 0:
				continue
			if a.position.distance_to(b.position) <= 145 and clear_sight(a.position,b.position):
				begin(a,b)
				return

func pair_key(a: Node2D, b: Node2D) -> String:
	var names := [a.role,b.role]
	names.sort()
	return str(names[0])+":"+str(names[1])

func clear_sight(a: Vector2, b: Vector2) -> bool:
	for i in range(1,12):
		if not village.walkable(a.lerp(b,float(i)/12.0)):
			return false
	return true

func begin(a: Node2D, b: Node2D, human_text := "") -> void:
	finish()
	active = [a,b]
	conversation_count += 1
	for npc in active:
		npc.conversing = true
		npc.moving = false
	a.facing = 1.0 if b.position.x >= a.position.x else -1.0
	b.facing = -a.facing
	step = 0
	pending = false
	timer = 5.5
	transcript = ""
	if not human_text.is_empty():
		say(a,human_text,"Human","")
	else:
		var greetings := [greeting()+", "+str(b.role)+"! ","Hi, "+str(b.role)+"! ","Hey, "+str(b.role)+"! Nice to see you. "]
		var fallback := str(greetings[randi_range(0,greetings.size()-1)])+str(REPLIES[a.role][0])
		pending = true
		ticket += 1
		service.request_line(a.role,"You just met "+str(b.role)+" near the village fountain. Greet them and start a friendly conversation in your own personality. It is "+greeting().to_lower()+" time in Jakarta.",fallback,ticket)

func say(npc: Node2D, text: String, source: String, detail: String) -> void:
	for other in village.residents:
		other.clear_speech()
	npc.speak(text)
	transcript += str(npc.role)+": "+text+"\n"
	spoken.emit(npc.role,text,source,detail)

func advance_conversation() -> void:
	if active.size() != 2:
		return
	step += 1
	if step >= 3 or (step >= 2 and active[0].role == "Governor") or active[1].role == "Governor":
		finish()
		return
	var speaker = active[step%2]
	var listener = active[(step+1)%2]
	pending = true
	ticket += 1
	var fallback: String = REPLIES[speaker.role][step]
	var context := "You are speaking with "+str(listener.role)+" near the village fountain. It is "+greeting().to_lower()+" time in Jakarta. Continue this friendly small talk, responding to the last line:\n"+transcript
	service.request_line(speaker.role,context,fallback,ticket)

func receive_line(id: int, role: String, text: String, source: String, detail: String) -> void:
	if id != ticket or not pending or active.is_empty():
		return
	pending = false
	var speaker = active[step%2]
	if speaker.role != role:
		return
	say(speaker,text,source,detail)
	timer = 6.5

func finish() -> void:
	if active.size() == 2:
		cooldowns[pair_key(active[0],active[1])] = 55.0
	for npc in active:
		npc.conversing = false
		npc.clear_speech()
		npc.rest = 1.0
		resident_cooldowns[npc.role] = 16.0
	active.clear()
	pending = false
	ticket += 1

func human_say(role: String, text: String) -> void:
	if not role in service.ROLES or text.strip_edges().is_empty():
		return
	for npc in village.residents:
		if npc.role == role:
			begin(village.residents[0],npc,text.strip_edges().substr(0,180))
			timer = 3.5
			return
