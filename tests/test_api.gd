extends SceneTree

const Service = preload("res://scripts/ai_service.gd")
var service: Node
var failures: Array[String] = []
var ticket := 10000

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func ask(p: Dictionary, key := "test-session-key", role := "Creative") -> Array:
	ticket += 1
	service.call_deferred("request_line",role,"A neighbor says hello.","Offline fallback line",ticket,p,key)
	return await service.line_ready

func plan_at(endpoint: String) -> Array:
	service.profiles.Creative.endpoint = endpoint
	ticket += 1
	service.call_deferred("request_plan","Creative","Plan an office improvement.",ticket)
	return await service.plan_ready

func run() -> void:
	service = Service.new()
	service.test_mode = true
	service.config_path = "user://integration-test-residents.json"
	root.add_child(service)
	var base := OS.get_environment("VILLAGE_TEST_BASE")
	check(base.begins_with("http://127.0.0.1:"),"Local fixture URL is required")
	if not failures.is_empty():
		quit(1)
		return
	var p: Dictionary = service.profiles.Creative.duplicate()
	p.mode = 1
	p.model = "mock-village"
	p.endpoint = base+"/v1/chat/completions"
	p.personality = "Friendly creative personality."
	p.timeout_seconds = 90
	p.reasoning_effort = "none"
	check(service.save_profile("Creative",p,"test-session-key") == OK,"Save profile failed")
	var saved := FileAccess.get_file_as_string(service.config_path)
	check(not "test-session-key" in saved,"Session key leaked into persisted settings")
	check(not "Governor" in saved,"Governor profile must not be persisted")
	service.reset_defaults()
	service.load_settings()
	check(service.profiles.Creative.personality == p.personality and service.profiles.Creative.model == "mock-village","Settings did not survive reload")
	check(service.profiles.Creative.timeout_seconds == 90 and service.profiles.Creative.reasoning_effort == "none","Qwen options did not survive reload")
	check(service.save_profile("Governor",p,"test-session-key") == ERR_INVALID_PARAMETER,"Governor accepted AI configuration")
	var result := await ask(p)
	check(result[3] == "API" and result[2] == "Hello, neighbor! Shall we take a walk?","Successful API response was not parsed")
	result = await ask(p,"wrong-test-key")
	check(result[3] == "Fallback" and "401" in str(result[4]),"Authentication failure did not fall back")
	for suffix in ["/malformed","/empty","/redirect","/slow"]:
		p.endpoint = base+suffix
		result = await ask(p)
		check(result[3] == "Fallback" and result[2] == "Offline fallback line","Bad response/timeout did not fall back: "+suffix)
	p.endpoint = "http://example.com/v1/chat/completions"
	result = await ask(p)
	check(result[3] == "Fallback","Remote plaintext endpoint was accepted")
	p.endpoint = base+"/v1/chat/completions"
	p.model = ""
	result = await ask(p)
	check(result[3] == "Fallback","Empty model was accepted")
	result = await ask(p,"","Governor")
	check(result[3] == "Human" and str(result[2]).is_empty(),"Governor generated a reply")
	p.mode = 0
	result = await ask(p)
	check(result[3] == "Offline","Offline mode attempted network dialogue")
	var f := FileAccess.open(service.config_path,FileAccess.WRITE)
	f.store_string('{"Creative":{"mode":"bad","social":"bad","model":42},"Governor":{"mode":1}}')
	f.close()
	service.reset_defaults()
	service.load_settings()
	check(service.profiles.Creative.mode == 0 and service.profiles.Creative.social == true,"Malformed settings did not preserve safe defaults")
	service.profiles.Creative = service.normalized("Creative",{"mode":1,"model":"mock-village","endpoint":base+"/plan","reasoning_effort":"none"})
	service.session_keys.Creative = "test-session-key"
	result = await plan_at(base+"/plan")
	check(result[2].get("action") == "build","Office JSON plan was not parsed")
	for suffix in ["/plan-invalid","/plan-malformed","/plan-slow"]:
		result = await plan_at(base+suffix)
		check(result[2].is_empty(),"Invalid office response must not become an action: "+suffix)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.config_path))
	print("API INTEGRATION: ","PASS" if failures.is_empty() else "FAIL"," | authenticated request, response parsing, 401, malformed/empty output, timeout, redirects, validation, persistence, no saved keys, Governor exclusion")
	quit(0 if failures.is_empty() else 1)
