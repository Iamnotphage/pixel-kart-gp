extends SceneTree
var game: Node
var output = "/tmp/pixel-kart-gp-visual"
func _initialize() -> void: call_deferred("run_visual")
func key(code: Key) -> void:
	var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); await process_frame
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + name + ".png")
func run_visual() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate(); game.test_mode = true
	root.add_child(game)
	await capture("01-menu")
	await key(KEY_TAB); assert(game.selected_character == 1)
	await key(KEY_ENTER); assert(game.state == "racing")
	await capture("02-countdown")
	game.model.countdown = 0
	for i in range(180): await process_frame
	var gas = InputEventKey.new(); gas.physical_keycode = KEY_W; gas.pressed = true
	Input.parse_input_event(gas)
	for i in range(90): await process_frame
	gas = InputEventKey.new(); gas.physical_keycode = KEY_W; gas.pressed = false
	Input.parse_input_event(gas)
	assert(game.model.racers[0].speed > 0)
	await capture("03-coast-racing")
	await key(KEY_ESCAPE); assert(game.state == "paused")
	var clock: float = game.model.clock
	for i in range(10): await process_frame
	assert(game.model.clock == clock)
	await capture("04-pause")
	await key(KEY_ESCAPE); assert(game.state == "racing")
	await key(KEY_H); assert(game.help_open)
	await capture("05-controls")
	await key(KEY_H)
	game.model.racers[0].lap = 3; game.model.racers[0].next_gate = 0; game.model.racers[0].pos = game.model.points[0]; game.model.racers[0].seg = 179
	await process_frame; await process_frame
	assert(game.state == "finished")
	await capture("06-results")
	await key(KEY_ESCAPE); await key(KEY_RIGHT); assert(game.selected_course == 1)
	await key(KEY_ENTER); game.model.countdown = 0; game.capture_mode = true
	for i in range(160): await process_frame
	await capture("07-canyon-racing")
	await key(KEY_R); assert(game.model.countdown > 2)
	print("VISUAL UI PASS: menu, character, start, live racing, pause/freeze, resume, help, result, course selection, restart")
	game.queue_free(); await process_frame; quit()
