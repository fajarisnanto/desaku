extends Node
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func capture(scene: Node, name_text: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := OS.get_environment("DESAKU_CAPTURE_DIR")
	if not folder.is_empty():
		get_viewport().get_texture().get_image().save_png(folder.path_join(name_text+".png"))
func run(scene: Node) -> void:
	var world = scene.office_world
	world.save_path="user://beta-export-office.json"
	scene.ai_service.config_path="user://beta-export-profile.json"
	if "--beta-restore" in OS.get_cmdline_user_args():
		world.load_world()
		scene.ai_service.load_settings()
		check(world.offices.Operation.team.size()==1,"Exported restart lost teammate")
		check(world.offices.Operation.items.size()==3,"Exported restart lost furniture")
		check(world.offices.Operation.project.get("actor")=="Nara","Exported restart lost construction")
		check(scene.ai_service.profiles.Operation.model=="saved-beta-model","Exported restart lost AI profile")
	else:
		world.reset()
		for i in 3:
			var kind: String=["board","desk","lounge"][i]
			check(world.apply_plan("Operation",{"action":"build","item":kind,"slot":i,"reason":"Exported smoke test"},"Operation lead").is_empty(),"Exported build failed")
			world.tick(25)
		check(world.apply_plan("Operation",{"action":"recruit","name":"Nara","specialty":"Resource planner","reason":"Coordinate resources"},"Operation lead").is_empty(),"Exported recruitment failed")
		world.tick(17)
		check(world.apply_plan("Operation",{"action":"build","item":"plants","slot":4,"reason":"Comfort matters"},"Nara").is_empty(),"Exported teammate build failed")
		world.enabled=false
		world.test_mode=false
		world.save_world()
		check(world.save_error.is_empty(),"Exported save failed")
		world.test_mode=true
		check(scene.ai_service.save_profile("Operation",{"model":"saved-beta-model"},"")==OK,"Exported profile save failed")
		for role in world.ROLES:
			scene.office_ui.open(role)
			await capture(scene,"office-"+role.to_lower())
			scene.office_ui.close()
		scene.news_feed.stories=[{"title":"UI test fixture: international AI research update","source":"Microsoft Research","topic":"AI / Research","published":int(Time.get_unix_time_from_system()),"fetched":int(Time.get_unix_time_from_system()),"date_label":"Published","url":"https://www.microsoft.com/en-us/research/"}]
		scene.news_ui.open()
		scene.news_ui.show_item(0)
		await capture(scene,"news")
		scene.news_ui.close()
		scene.settings_ui.toggle_settings()
		scene.settings_ui.select_role("Operation")
		await capture(scene,"settings")
		scene.settings_ui.toggle_settings()
		# Real-time rendered soak; office actions remain paused and providers offline.
		await get_tree().create_timer(30).timeout
		await capture(scene,"village")
	world.test_mode=true
	for issue in failures: push_error(issue)
	print("EXPORTED BETA TEST: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
