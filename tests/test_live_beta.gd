extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	var api = load("res://scripts/ai_service.gd").new()
	root.add_child(api)
	var profiles = JSON.parse_string(FileAccess.get_file_as_string("res://presets/qwen-residents.json"))
	for role in api.ROLES: api.profiles[role] = api.normalized(role,profiles[role])
	var world = load("res://scripts/office_world.gd").new()
	root.add_child(world)
	world.setup(api,true)
	for role in world.ROLES:
		api.last_request_ms = -6000
		world.call_deferred("request_decision",role)
		var result: Array = await api.plan_ready
		check(not result[2].is_empty(),role+" returned no plan")
		check(not world.offices[role].project.is_empty(),role+" did not start first project")
		world.tick(30)
		print("LIVE FIRST PROJECT ",role,": ",JSON.stringify(result[2]))
	# Prepared operational workspace isolates the live recruitment decision.
	world.reset()
	var slot := 0
	for item in world.available("Operation").keys():
		world.offices.Operation.materials=140.0
		world.apply_plan("Operation",{"action":"build","item":item,"slot":slot,"reason":"Prepared operational workspace"},"Operation lead")
		world.tick(30)
		slot+=1
	var recruited := false
	for attempt in 8:
		world.offices.Operation.materials=140.0
		api.last_request_ms=-6000
		world.call_deferred("request_decision","Operation")
		var result: Array = await api.plan_ready
		print("LIVE TEAM DECISION: ",JSON.stringify(result[2])," | ",world.offices.Operation.last)
		world.tick(30)
		if not world.offices.Operation.team.is_empty():
			recruited=true
			world.offices.Operation.actor_turn=1
			api.last_request_ms=-6000
			world.call_deferred("request_decision","Operation")
			var member_result: Array = await api.plan_ready
			print("LIVE RECRUIT ",world.pending_actor,": ",JSON.stringify(member_result[2]))
			check(not member_result[2].is_empty(),"Recruit returned no independent decision")
			check(str(world.offices.Operation.last).begins_with(world.pending_actor+":" ) or str(world.offices.Operation.last).begins_with(world.pending_actor+" is reflecting:"),"Recruit decision was rejected instead of applied")
			check(world.offices.Operation.team[0].decisions==1,"Recruit did not receive planning turn")
			break
	check(recruited,"Qwen did not recruit after office prerequisites")
	var feed=load("res://scripts/news_feed.gd").new()
	root.add_child(feed)
	feed.setup(false)
	await process_frame
	var start := Time.get_ticks_msec()
	while feed.refreshing and Time.get_ticks_msec()-start<100000:
		await process_frame
	print("LIVE NEWS: ",JSON.stringify(feed.reports)," | entries=",feed.stories.size())
	check(not feed.refreshing,"News fetch timed out")
	check(not feed.stories.is_empty(),"No live dated headlines fetched")
	if not feed.stories.is_empty():
		var story: Dictionary=feed.select_story("Research")
		api.last_request_ms=-6000
		api.call_deferred("request_line","Research","Discuss this headline with Creative."+feed.context_for(story),"fallback",44)
		var reply: Array=await api.line_ready
		print("LIVE NEWS DIALOGUE: ",reply)
		check(reply[3]=="API","News dialogue did not use model")
	print("LIVE BETA TEST: ","PASS" if failures.is_empty() else "FAIL")
	for problem in failures: push_error(problem)
	quit(0 if failures.is_empty() else 1)
