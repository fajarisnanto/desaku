extends Node

signal line_ready(ticket: int, role: String, text: String, source: String, detail: String)
const ROLES = ["Creative", "Research", "Operation", "Maintenance"]
const PERSONALITIES = {
	"Creative": "You are a cheerful artist. Notice colors, share playful ideas, and ask about others' day.",
	"Research": "You are a curious, kind scholar. Enjoy discoveries, books, and thoughtful questions without lecturing.",
	"Operation": "You are a friendly, practical coordinator. Check how everyone is doing and suggest breaks or shared plans.",
	"Maintenance": "You are a warm, resourceful mechanic. Enjoy fixing things, gentle humor, and helping your neighbors."
}
var profiles: Dictionary = {}
var session_keys: Dictionary = {}
var config_path := "user://residents.json"
var busy := false
var last_request_ms := -6000
var test_mode := false

func _ready() -> void:
	reset_defaults()
	if not test_mode:
		load_settings()

func reset_defaults() -> void:
	profiles.clear()
	for role in ROLES:
		profiles[role] = {"mode":0,"endpoint":"http://localhost:11434/v1/chat/completions","model":"","key_env":"VILLAGE_"+role.to_upper()+"_API_KEY","personality":PERSONALITIES[role],"social":true}

func normalized(role: String, data: Dictionary) -> Dictionary:
	var p: Dictionary = profiles[role].duplicate()
	for key in ["endpoint","model","key_env","personality"]:
		if data.get(key) is String:
			p[key] = str(data[key]).substr(0,4000 if key == "personality" else 500).strip_edges()
	if data.get("mode") is int or data.get("mode") is float:
		p.mode = clampi(int(data.mode),0,1)
	if data.get("social") is bool:
		p.social = data.social
	return p

func load_settings() -> void:
	if not FileAccess.file_exists(config_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary:
		return
	for role in ROLES:
		if parsed.get(role) is Dictionary:
			profiles[role] = normalized(role,parsed[role])

func save_profile(role: String, data: Dictionary, key: String) -> Error:
	if not role in ROLES:
		return ERR_INVALID_PARAMETER
	var candidate := normalized(role,data)
	var previous: Dictionary = profiles[role]
	profiles[role] = candidate
	var file := FileAccess.open(config_path,FileAccess.WRITE)
	if file == null:
		profiles[role] = previous
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profiles,"\t"))
	file.close()
	session_keys[role] = key.strip_edges()
	return OK

func endpoint_valid(url: String) -> bool:
	if "@" in url or "\n" in url or "\r" in url or "#" in url:
		return false
	if url.begins_with("https://"):
		return url.trim_prefix("https://").split("/")[0].length() > 0
	if not url.begins_with("http://"):
		return false
	var host := url.trim_prefix("http://").split("/")[0].split(":")[0]
	return host in ["localhost","127.0.0.1"]

func validation_error(p: Dictionary) -> String:
	if int(p.mode) == 0:
		return ""
	if not endpoint_valid(str(p.endpoint)):
		return "Use an HTTPS endpoint, or HTTP on localhost / 127.0.0.1."
	if str(p.model).strip_edges().is_empty():
		return "Enter the model name provided by your server."
	return ""

func request_line(role: String, context: String, fallback: String, ticket: int, override_profile: Dictionary = {}, override_key: String = "") -> void:
	# The human Governor is deliberately excluded at the service boundary.
	if not role in ROLES:
		line_ready.emit(ticket,role,"","Human","The Governor speaks only through your input.")
		return
	var p: Dictionary = profiles[role].duplicate() if override_profile.is_empty() else normalized(role,override_profile)
	if int(p.mode) == 0:
		line_ready.emit(ticket,role,fallback,"Offline","Scripted small talk")
		return
	var issue := validation_error(p)
	if not issue.is_empty():
		line_ready.emit(ticket,role,fallback,"Fallback",issue)
		return
	if busy or (not test_mode and Time.get_ticks_msec()-last_request_ms < 6000):
		line_ready.emit(ticket,role,fallback,"Fallback","API pacing: using offline dialogue for this turn.")
		return
	var key := override_key if not override_profile.is_empty() else str(session_keys.get(role,""))
	if key.is_empty() and not str(p.key_env).is_empty():
		key = OS.get_environment(str(p.key_env))
	if "\n" in key or "\r" in key:
		line_ready.emit(ticket,role,fallback,"Fallback","Invalid API key format.")
		return
	var request := HTTPRequest.new()
	request.timeout = 12.0 if not test_mode else 1.0
	request.body_size_limit = 65536
	request.max_redirects = 0
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json","Accept: application/json"])
	if not key.is_empty():
		headers.append("Authorization: Bearer "+key)
	var system := "You are "+role+", an AI resident of Fountain Commons. "+str(p.personality)+" Reply as yourself in one friendly sentence, at most 22 words. Only dialogue; no role labels, narration, markdown or stage directions. Never write the Governor's words. The Governor is a human. Do not request or mention credentials. You have no tools and cannot take external actions."
	var body := JSON.stringify({"model":p.model,"stream":false,"max_tokens":96,"messages":[{"role":"system","content":system},{"role":"user","content":context.substr(0,3500)}]})
	busy = true
	last_request_ms = Time.get_ticks_msec()
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
		busy = false
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			var reason := "API unavailable (HTTP %d). Using offline dialogue." % code
			if result == HTTPRequest.RESULT_TIMEOUT:
				reason = "API timed out. Using offline dialogue."
			line_ready.emit(ticket,role,fallback,"Fallback",reason)
			return
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		var answer := extract_answer(data)
		if answer.is_empty():
			line_ready.emit(ticket,role,fallback,"Fallback","API returned no usable dialogue.")
		else:
			line_ready.emit(ticket,role,answer,"API","Connected · "+str(p.model))
	)
	var err := request.request(str(p.endpoint),headers,HTTPClient.METHOD_POST,body)
	if err != OK:
		busy = false
		request.queue_free()
		line_ready.emit(ticket,role,fallback,"Fallback","Could not start API request.")

func extract_answer(data: Variant) -> String:
	if not data is Dictionary or not data.get("choices") is Array or data.choices.is_empty():
		return ""
	var choice = data.choices[0]
	if not choice is Dictionary or not choice.get("message") is Dictionary:
		return ""
	var content = choice.message.get("content")
	if not content is String:
		return ""
	return str(content).replace("\n"," ").replace("\r"," ").strip_edges().trim_prefix('"').trim_suffix('"').substr(0,180)
