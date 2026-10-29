extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.office_world.test_mode = true
	await process_frame
	scene.set_process(false)
	var ui = scene.settings_ui
	var api = scene.ai_service
	api.config_path = "user://ui-test-residents.json"
	api.reset_defaults()
	ui.load_role()
	ui.toggle_settings()
	assert(ui.shade.visible)
	ui.personality.text = "UI-test artist personality"
	ui.api_key.text = "temporary-ui-test-key"
	ui.select_role("Research")
	ui.personality.text = "UI-test researcher personality"
	ui.save_current()
	ui.select_role("Creative")
	assert(ui.personality.text == "UI-test artist personality")
	ui.save_current()
	assert(api.profiles.Creative.personality == "UI-test artist personality")
	assert(api.profiles.Research.personality == "UI-test researcher personality")
	assert(not FileAccess.get_file_as_string(api.config_path).contains("temporary-ui-test-key"))
	ui.test_connection()
	assert(ui.feedback.text.begins_with("Offline:"))
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	scene._unhandled_key_input(event)
	assert(not scene.paused)
	ui.toggle_settings()
	ui.toggle_human()
	assert(ui.human_panel.visible)
	ui.human_to.select(1)
	ui.human_input.text = "Hello from a human."
	ui.send_human()
	assert(not ui.human_panel.visible)
	assert(scene.social.transcript == "Governor: Hello from a human.\n")
	assert(scene.social.active[1].role == "Research")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(api.config_path))
	print("UI TEST: PASS | four profiles, independent drafts, save, session-only key, offline test, modal keyboard guard and human message routing")
	quit(0)
