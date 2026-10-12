extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: " + label)
	else: failures += 1; push_error("FAIL: " + label)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game); game.set_process(false)
	check(game.state == "menu","main scene opens course and driver selection")
	game.start_race()
	var m = game.model
	check(m.racers.size() == 8 and m.boxes.size() == 15,"eight karts and fifteen item boxes")
	check(m.points.size() == 180 and m.total_length > 4000,"closed circuit geometry")
	var start: Vector2 = m.racers[0].pos
	m.step(0.1,1,0,false,false)
	check(m.racers[0].pos == start,"countdown prevents early movement")
	m.countdown = 0
	for i in range(90): m.step(1.0/60,1,0,false,false)
	check(m.racers[0].speed > 90 and m.racers[0].pos.distance_to(start)>50,"accelerator moves kart")
	var angle: float = m.racers[0].angle
	m.step(0.1,1,1,false,false)
	check(m.racers[0].angle < angle,"right steering turns screen-right")
	m.racers[0].item = "BOOST"; m.use_item(0)
	check(m.racers[0].boost > 0 and m.racers[0].item == "","boost consumes item")
	m.racers[0].item = "BOLT"; m.use_item(0)
	check(m.hazards.size() == 1 and m.hazards[0].vel.length() > 0,"bolt projectile travels")
	m.racers[0].item = "OIL"; m.use_item(0)
	check(m.hazards.size() == 2 and m.hazards[1].vel == Vector2.ZERO,"oil is stationary trap")
	m.racers[0].drift = 0.8; m.racers[0].boost = 0
	m.step(0.01,1,0,false,false)
	check(m.racers[0].boost > 0,"charged drift release gives mini turbo")
	m.racers[0].pos = Vector2(100,100); m.step(0.01,1,0,false,false)
	check(m.racers[0].offroad,"off-road detection")
	m.rescue()
	check(m.nearest(m.racers[0].pos).distance < 1 and m.racers[0].speed == 0,"rescue resets onto circuit")
	m.setup(0,0); m.countdown = 0
	m.racers[0].lap = 1; m.racers[0].next_gate = 1
	m.racers[0].pos = m.points[0]; m.step(0.01,0,0,false,false)
	check(m.racers[0].lap == 1,"finish line cannot count without ordered checkpoints")
	var key = InputEventKey.new(); key.physical_keycode = KEY_ESCAPE; key.pressed = true
	game._unhandled_input(key)
	check(game.state == "paused","Escape pauses")
	game._unhandled_input(key)
	check(game.state == "racing","Escape resumes")
	game.selected_course = 1; game.selected_character = 3; game.start_race()
	check(m.course == 1 and m.racers[0].color == 3 and m.clock == 0,"course driver and restart reset")
	game.queue_free(); await process_frame; await process_frame
	print("SMOKE TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
