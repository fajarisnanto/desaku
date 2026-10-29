extends SceneTree
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var api = load("res://scripts/ai_service.gd").new()
	api.test_mode = true
	root.add_child(api)
	var world = load("res://scripts/office_world.gd").new()
	root.add_child(world)
	world.setup(api,true)
	check(world.offices.size()==4 and not world.offices.has("Governor"),"Four offices, human governor")
	var before: float = world.offices.Operation.materials
	check(not world.apply_plan("Operation",{"action":"build","item":"lab","slot":0,"reason":"wrong department"},"lead").is_empty(),"Reject inappropriate station")
	check(not world.apply_plan("Operation",{"action":"build","item":"desk","slot":99,"reason":"outside"},"lead").is_empty(),"Reject invalid position")
	check(not world.apply_plan("Operation",{"action":"recruit","name":"Governor","specialty":"Resource planner","reason":"test"},"lead").is_empty(),"Reject human recruitment")
	check(world.offices.Operation.materials==before,"Invalid actions spend nothing")
	for slot in 2:
		check(world.apply_plan("Operation",{"action":"build","item":"desk" if slot==0 else "board","slot":slot,"reason":"Prepare workplace"},"Operation lead").is_empty(),"Valid construction")
		world.tick(23)
	check(world.offices.Operation.items.size()==2,"Construction completes")
	check(world.metrics("Operation").capacity>20,"Furnishing improves capacity")
	check(not world.apply_plan("Operation",{"action":"build","item":"plants","slot":0,"reason":"occupied"},"lead").is_empty(),"Reject collision")
	check(world.apply_plan("Operation",{"action":"recruit","name":"Nara","specialty":"Resource planner","reason":"Coordinate supplies"},"lead").is_empty(),"Recruit for a useful specialty")
	world.tick(17)
	check(world.offices.Operation.team.size()==1,"Recruit joins")
	check(world.apply_plan("Operation",{"action":"build","item":"plants","slot":2,"reason":"Improve comfort"},"Nara").is_empty(),"Teammate can build")
	check(world.offices.Operation.project.duration<22,"Team speeds construction")
	world.enabled=false
	var remaining: float = world.offices.Operation.project.remaining
	world.tick(100)
	check(world.offices.Operation.project.remaining==remaining,"Pause freezes construction")
	world.save_path="user://office-regression.json"
	world.test_mode=false
	world.save_world()
	check(world.save_error.is_empty(),"Save succeeds")
	var restored = load("res://scripts/office_world.gd").new()
	root.add_child(restored)
	restored.setup(api,true)
	restored.save_path=world.save_path
	restored.load_world()
	check(restored.offices.Operation.items.size()==2,"Restore completed furnishings")
	check(restored.offices.Operation.team.size()==1,"Restore team")
	check(restored.offices.Operation.project.actor=="Nara","Restore recruited builder")
	check(is_equal_approx(float(restored.offices.Operation.project.remaining),remaining),"Restore construction progress")
	check(not restored.enabled,"Persist autonomy pause")
	restored.test_mode=false
	restored.save_world()
	check(restored.save_error.is_empty(),"Repeated save succeeds")
	var broken := FileAccess.open(world.save_path,FileAccess.WRITE)
	broken.store_string("{invalid")
	broken.close()
	restored.load_world()
	check(restored.save_blocked and not restored.enabled,"Malformed save blocks autonomy and writes")
	restored.save_world()
	check(FileAccess.get_file_as_string(world.save_path)=="{invalid","Malformed original remains intact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path))
	print("OFFICE TEST: ","PASS" if failures.is_empty() else "FAIL", " | construction, metrics, recruitment, team building, pause, persistence, invalid plans")
	for issue in failures:
		push_error(issue)
	quit(0 if failures.is_empty() else 1)

