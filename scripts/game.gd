extends Node2D
const RaceModel = preload("res://scripts/race_model.gd")
const COLORS = [Color("ff665b"),Color("6bdfd5"),Color("c6a0ff"),Color("ffce52"),Color("81d36b"),Color("62a7fa"),Color("ed91c9"),Color("fb984d")]
const NAMES = ["NOVA","MINT","LUNA","SPARK","FERN","COBALT","ROSIE","EMBER"]
const COURSES = ["CLOVER COAST","COPPER CANYON"]
var model = RaceModel.new()
var state = "menu"
var selected_course = 0
var selected_character = 0
var menu_focus = 0
var test_mode = false
var help_open = false
var muted = false
var anim = 0.0
var camera = Vector2.ZERO
var heading = Vector2.DOWN
var ground: ColorRect
var material_ground: ShaderMaterial
var maps: Array[Texture2D] = []
var karts: Array[Texture2D] = []
var font: Font
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var engine: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var engine_phase = 0.0
var decorations: Array[Dictionary] = []
var previous_event = ""
var last_count = 4
var best_times: Dictionary = {}
var capture_mode = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	for i in range(2): maps.append(load("res://assets/course_%d.png" % i))
	for i in range(8): karts.append(load("res://assets/kart_%d.png" % i))
	ground = ColorRect.new(); ground.size = Vector2(640,360); ground.mouse_filter = Control.MOUSE_FILTER_IGNORE; ground.z_index = -1
	material_ground = ShaderMaterial.new(); material_ground.shader = load("res://assets/ground.gdshader")
	ground.material = material_ground; add_child(ground)
	music = AudioStreamPlayer.new(); add_child(music)
	var song = load("res://assets/pixel_parade.wav").duplicate() as AudioStreamWAV
	song.loop_mode = AudioStreamWAV.LOOP_FORWARD; song.loop_end = song.data.size()/2
	music.stream = song; music.volume_db = -8
	sfx = AudioStreamPlayer.new(); add_child(sfx); sfx.volume_db = -10
	engine = AudioStreamPlayer.new(); add_child(engine); engine.volume_db = -23
	var generator = AudioStreamGenerator.new(); generator.mix_rate = 22050; generator.buffer_length = 0.15
	engine.stream = generator
	if not test_mode:
		music.play(); engine.play(); engine_playback = engine.get_stream_playback()
	load_times()
	preview_course()
	if "--race-preview" in OS.get_cmdline_user_args():
		start_race(); model.countdown = 0; capture_mode = true
	if "--canyon-preview" in OS.get_cmdline_user_args():
		selected_course = 1; start_race(); model.countdown = 0; capture_mode = true

func preview_course() -> void:
	model.setup(selected_course,selected_character)
	material_ground.set_shader_parameter("track_map",maps[selected_course])
	decorations.clear()
	for i in range(0,180,5):
		var tangent = (model.points[(i+1)%180]-model.points[i]).normalized()
		for side in [-1,1]:
			decorations.append({"pos":model.points[i]+Vector2(tangent.y,-tangent.x)*float(side)*(150+20*sin(i)),"kind":i%3})
	camera = model.racers[0].pos-Vector2.from_angle(model.racers[0].angle)*42
	heading = Vector2.from_angle(model.racers[0].angle)

func start_race() -> void:
	preview_course(); state = "racing"; help_open = false; previous_event = ""; last_count = 4

func tone(freq: float, duration: float = 0.12) -> void:
	if test_mode or muted: return
	var sound = AudioStreamWAV.new(); sound.format = AudioStreamWAV.FORMAT_16_BITS; sound.mix_rate = 22050
	var bytes = PackedByteArray(); bytes.resize(int(duration*22050)*2)
	for j in range(bytes.size()/2):
		var sample = int(sin(float(j)/22050*freq*TAU)*6000*(1-float(j)/(bytes.size()/2)))
		bytes.encode_s16(j*2,sample)
	sound.data = bytes; sfx.stream = sound; sfx.play()

func _process(delta: float) -> void:
	var dt = minf(delta,0.04)
	anim += dt
	if state == "racing" and not help_open:
		var throttle = 1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0
		var steer = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var brake = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
		var drift = Input.is_physical_key_pressed(KEY_SHIFT)
		if Input.get_connected_joypads().size() > 0:
			var axis = Input.get_joy_axis(0,JOY_AXIS_LEFT_X)
			if absf(axis) > 0.12: steer = axis
			if Input.is_joy_button_pressed(0,JOY_BUTTON_A) or Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT) > 0.1: throttle = 1.0
			drift = drift or Input.is_joy_button_pressed(0,JOY_BUTTON_RIGHT_SHOULDER)
			brake = brake or Input.is_joy_button_pressed(0,JOY_BUTTON_B)
		if capture_mode:
			var r = model.racers[0]
			var near = model.nearest(r.pos)
			var target = model.points[(near.seg+5)%180]
			steer = -clampf(wrapf((target-r.pos).angle()-r.angle,-PI,PI)*2.5,-1,1); throttle = 1
		model.step(dt,throttle,steer,drift,brake)
		if model.last_event != previous_event and model.event_timer > 0:
			previous_event = model.last_event; tone(880 if "TURBO" in previous_event else 660)
		var count = int(ceil(model.countdown))
		if count != last_count:
			last_count = count; tone(1046 if count == 0 else 523,0.18)
		if model.finished:
			state = "finished"; save_time(); tone(1320,0.35)
	if state == "menu":
		var index = int(anim*3)%180
		var p: Vector2 = model.points[index]
		heading = (model.points[(index+3)%180]-p).normalized()
		camera = p-heading*42
	else:
		var r = model.racers[0]
		heading = Vector2.from_angle(r.angle)
		camera = r.pos-heading*42
	material_ground.set_shader_parameter("camera",camera)
	material_ground.set_shader_parameter("forward_dir",heading)
	update_engine()
	queue_redraw()

func update_engine() -> void:
	if engine_playback == null: return
	var amount = engine_playback.get_frames_available()
	var speed: float = model.racers[0].speed
	for i in range(amount):
		engine_phase = fmod(engine_phase+(40+speed*0.45)/22050,1.0)
		var value = (engine_phase*2-1)*0.22 if state == "racing" and model.countdown == 0 and not muted else 0.0
		engine_playback.push_frame(Vector2(value,value))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode
		if key == KEY_M:
			muted = not muted; music.stream_paused = muted
		if key == KEY_H or key == KEY_F1:
			help_open = not help_open; return
		if help_open:
			if key == KEY_ESCAPE or key == KEY_ENTER: help_open = false
			return
		if state == "menu":
			if key == KEY_LEFT or key == KEY_RIGHT or key == KEY_A or key == KEY_D:
				selected_course = 1-selected_course; preview_course(); tone(440)
			if key == KEY_TAB or key == KEY_UP or key == KEY_DOWN:
				selected_character = (selected_character+1)%8; preview_course(); tone(660)
			if key == KEY_ENTER or key == KEY_SPACE: start_race()
		elif key == KEY_ESCAPE or key == KEY_P:
			if state == "racing": state = "paused"
			elif state == "paused": state = "racing"
			elif state == "finished": state = "menu"; preview_course()
		elif key == KEY_R:
			start_race()
		elif state == "paused" and key == KEY_Q:
			state = "menu"; preview_course()
		elif state == "racing":
			if key == KEY_SPACE and model.countdown == 0: model.use_item(0); tone(990)
			if key == KEY_BACKSPACE: model.rescue()
		elif state == "finished" and key == KEY_ENTER: start_race()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			if state == "menu" or state == "finished": start_race()
			else: state = "paused" if state == "racing" else "racing"
		elif event.button_index == JOY_BUTTON_X and state == "racing": model.use_item(0)
		elif state == "menu":
			if event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT: selected_course = 1-selected_course; preview_course()
			if event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_DPAD_DOWN: selected_character = (selected_character+1)%8; preview_course()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m = get_global_mouse_position()
		if state == "menu":
			if Rect2(32,143,280,90).has_point(m): selected_course = 0; preview_course()
			elif Rect2(328,143,280,90).has_point(m): selected_course = 1; preview_course()
			elif Rect2(32,243,350,56).has_point(m): selected_character = (selected_character+1)%8; preview_course()
			elif Rect2(408,249,200,42).has_point(m): start_race()
			elif Rect2(430,324,180,24).has_point(m): help_open = true
		elif state == "finished": start_race()

func project(pos: Vector2) -> Vector3:
	var relative = pos-camera
	var depth = relative.dot(heading)
	if depth < 8: return Vector3(-999,-999,0)
	var right = Vector2(heading.y,-heading.x)
	return Vector3(320+relative.dot(right)*330/depth,108+6500/depth,330/depth)

func text_at(text: String, pos: Vector2, size: int = 16, color: Color = Color("fff0d0")) -> void:
	draw_string(font,pos+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("12233b"))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center_text(text: String, y: float, size: int = 16, color: Color = Color("fff0d0")) -> void:
	text_at(text,Vector2((640-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2,y),size,color)

func panel(rect: Rect2, color: Color = Color("17253de8"), outline: Color = Color("627488")) -> void:
	draw_rect(Rect2(rect.position+Vector2(3,4),rect.size),Color("0b1726aa"))
	draw_rect(rect,color); draw_rect(rect,outline,false,2)

func _draw() -> void:
	if model.racers.is_empty(): return
	# Pixel skyline and parallax clouds.
	draw_rect(Rect2(0,0,640,109),Color("86ced3") if selected_course == 0 else Color("e4b69b"))
	for i in range(12):
		var x = fposmod(i*71-heading.angle()*65,780)-70
		var height = 20+sin(i*2.4)*14
		draw_rect(Rect2(x,108-height,75,height),Color("468c8c") if selected_course == 0 else Color("b07979"))
		draw_rect(Rect2(x+12,98-height,40,12),Color("5b9e9a") if selected_course == 0 else Color("c48a86"))
	for i in range(5):
		var x = fposmod(i*157-anim*2-heading.angle()*25,820)-80
		draw_rect(Rect2(x,35+i%2*18,70,10),Color("f4ecd4")); draw_rect(Rect2(x+15,27+i%2*18,34,10),Color("f4ecd4"))
	var objects: Array[Dictionary] = []
	for decor in decorations: objects.append({"pos":decor.pos,"type":"decor","data":decor})
	for b in model.boxes:
		if b.cooldown == 0: objects.append({"pos":b.pos,"type":"box","data":b})
	for h in model.hazards: objects.append({"pos":h.pos,"type":"hazard","data":h})
	for i in range(8):
		if i != 0 or state == "menu": objects.append({"pos":model.racers[i].pos,"type":"kart","data":model.racers[i]})
	objects.sort_custom(func(a,b): return a.pos.distance_squared_to(camera)>b.pos.distance_squared_to(camera))
	for obj in objects:
		var s = project(obj.pos)
		if s.z <= 0 or s.x < -100 or s.x > 740 or s.y > 430: continue
		var scale = minf(s.z,5)
		var origin = Vector2(s.x,s.y)
		if obj.type == "kart":
			var sz = Vector2(20,25)*scale
			draw_texture_rect(karts[obj.data.color],Rect2(origin-Vector2(sz.x/2,sz.y),sz),false)
		elif obj.type == "box":
			var sz = 16*scale
			var p = origin-Vector2(sz/2,sz+3+sin(anim*4)*2)
			draw_rect(Rect2(p,Vector2(sz,sz)),Color("fae575")); draw_rect(Rect2(p+Vector2(2,2)*scale,Vector2(sz-4*scale,sz-4*scale)),Color("bd77d6"))
			if scale > 0.35: text_at("?",p+Vector2(4,13)*scale,int(14*scale),Color.WHITE)
		elif obj.type == "hazard":
			if obj.data.kind == "OIL": pixel_ellipse(origin,Vector2(14,5)*scale,Color("1c253a"))
			else:
				draw_rect(Rect2(origin-Vector2(6,10)*scale,Vector2(12,12)*scale),Color("6bfff0"))
		else:
			draw_decoration(origin,scale,int(obj.data.kind))
	if state != "menu":
		draw_player()
		draw_hud()
	if state == "menu": draw_menu()
	if state == "paused": draw_pause()
	if state == "finished": draw_results()
	if help_open: draw_help()

func pixel_ellipse(pos: Vector2, size: Vector2, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(16): pts.append(pos+Vector2(cos(i*TAU/16)*size.x,sin(i*TAU/16)*size.y))
	draw_colored_polygon(pts,color)

func draw_decoration(p: Vector2, s: float, kind: int) -> void:
	if selected_course == 0:
		draw_rect(Rect2(p-Vector2(3,33)*s,Vector2(6,33)*s),Color("85644f"))
		for j in range(3):
			draw_rect(Rect2(p-Vector2(17-j*4,30+j*10)*s,Vector2(34-j*8,14)*s),Color("21674f") if j%2 == 0 else Color("3dad67"))
		if kind == 0: draw_rect(Rect2(p-Vector2(7,46)*s,Vector2(5,5)*s),Color("ffe286"))
	else:
		draw_rect(Rect2(p-Vector2(17,23)*s,Vector2(34,23)*s),Color("905a63"))
		draw_rect(Rect2(p-Vector2(12,34)*s,Vector2(24,27)*s),Color("c18170"))
		draw_rect(Rect2(p-Vector2(9,34)*s,Vector2(18,6)*s),Color("e4ab7d"))

func draw_player() -> void:
	var r = model.racers[0]
	var s = project(r.pos)
	var bob = sin(anim*25)*minf(1,r.speed/150)
	var origin = Vector2(s.x,s.y+bob)
	if r.boost > 0:
		for side in [-1,1]:
			draw_rect(Rect2(origin+Vector2(side*22-5,-7),Vector2(10,13+sin(anim*55)*6)),Color("fff09c"))
			draw_rect(Rect2(origin+Vector2(side*22-3,0),Vector2(6,15)),Color("ff9c54"))
	if r.drift > 0.1:
		for i in range(5):
			var x = origin.x+sin(i*12+anim*18)*35
			var y = origin.y+5+i*2
			draw_rect(Rect2(x,y,4,3),Color("70edff") if r.drift > 0.65 else Color("ffe185"))
	if r.offroad and r.speed > 30:
		for i in range(4): draw_rect(Rect2(origin+Vector2(sin(anim*20+i)*40,i*4),Vector2(12,6)),Color("c8be88aa"))
	var size = Vector2(80,100)
	if r.spin > 0:
		draw_set_transform(origin-Vector2(0,40),sin(anim*30)*0.35)
		draw_texture_rect(karts[r.color],Rect2(Vector2(-40,-60),size),false)
		draw_set_transform(Vector2.ZERO)
	else: draw_texture_rect(karts[r.color],Rect2(origin-Vector2(40,100),size),false)

func draw_hud() -> void:
	var r = model.racers[0]
	panel(Rect2(12,10,98,53),Color("15253eea"),Color("fbd672"))
	text_at(str(model.rank()),Vector2(22,50),38,Color("ffe083")); text_at("/ 8",Vector2(61,47),18)
	panel(Rect2(122,10,150,53)); text_at("LAP %d / 3" % mini(3,maxi(1,r.lap)),Vector2(134,33),19)
	text_at(format_time(model.clock),Vector2(134,53),14,Color("91dbdc"))
	panel(Rect2(446,10,182,53)); text_at("ITEM  [SPACE]",Vector2(458,31),12,Color("9bb9c5"))
	text_at(r.item if r.item != "" else "GRAB A BOX",Vector2(458,53),19,COLORS[r.color] if r.item != "" else Color("fff0d0"))
	panel(Rect2(12,300,174,48)); text_at("%03d" % int(r.speed*0.65),Vector2(23,332),27)
	text_at("km/h",Vector2(82,331),13,Color("9bd4cf"))
	text_at("OFF ROAD" if r.offroad else ("TURBO!" if r.boost > 0 else "DRIFT"),Vector2(121,317),10,Color("ffce74"))
	draw_rect(Rect2(122,325,52,8),Color("39455a")); draw_rect(Rect2(122,325,52*minf(1,r.drift/0.65),8),Color("7beced"))
	draw_minimap(Rect2(518,236,110,112))
	text_at("SHIFT drift   SPACE item   ESC pause",Vector2(205,346),12)
	if model.countdown > 0:
		center_text(str(int(ceil(model.countdown))),185,68,Color("ffe185"))
		center_text("GET READY",222,17)
	elif model.clock < 1:
		center_text("GO!",160,48,Color("79efc9"))
	if model.event_timer > 0:
		center_text(model.last_event,91,19,Color("ffe58d"))

func draw_minimap(rect: Rect2) -> void:
	panel(rect,Color("15253edc"),Color("638d96"))
	var pts = PackedVector2Array()
	for p in model.points: pts.append(rect.position+Vector2(5,5)+p/2048*(rect.size-Vector2(10,10)))
	pts.append(pts[0]); draw_polyline(pts,Color("a9b5aa"),4)
	var start = rect.position+Vector2(5,5)+model.points[0]/2048*(rect.size-Vector2(10,10))
	draw_rect(Rect2(start-Vector2(2,3),Vector2(5,6)),Color.WHITE)
	for i in range(7,-1,-1):
		var pos = rect.position+Vector2(5,5)+model.racers[i].pos/2048*(rect.size-Vector2(10,10))
		draw_rect(Rect2(pos-Vector2(2,2),Vector2(5,5)),COLORS[model.racers[i].color])
		if i == 0: draw_rect(Rect2(pos-Vector2(3,3),Vector2(7,7)),Color.WHITE,false,1)

func draw_menu() -> void:
	draw_rect(Rect2(0,0,640,360),Color("0d203769"))
	text_at("ORIGINAL 16-BIT CIRCUIT RACING",Vector2(35,31),12,Color("83e4d4"))
	text_at("PIXEL KART",Vector2(31,78),45,Color("ffedb4"))
	text_at("GP",Vector2(334,78),45,Color("ffb65f"))
	text_at("8 RACERS  /  3 LAPS  /  ONE CHECKERED FLAG",Vector2(35,103),13)
	text_at("01  PICK YOUR CIRCUIT",Vector2(35,133),12,Color("83e4d4"))
	for c in range(2):
		var rect = Rect2(32+c*296,143,280,90)
		panel(rect,Color("192b44f2"),Color("ffe28a") if c == selected_course else Color("53728a"))
		text_at(COURSES[c],rect.position+Vector2(13,26),20,Color("ffe28a") if c == selected_course else Color("c7d0cb"))
		text_at("FLOWING TURNS / SEASIDE" if c == 0 else "TIGHT BENDS / DESERT",rect.position+Vector2(13,47),11,Color("9bbbc4"))
		text_at("<  SELECTED  >" if c == selected_course else "CLICK TO SELECT",rect.position+Vector2(13,74),12,Color("87decc"))
		var tiny = maps[c]
		draw_texture_rect(tiny,Rect2(rect.position+Vector2(212,51),Vector2(51,30)),false)
	panel(Rect2(32,243,350,56),Color("192b44f2"))
	draw_texture_rect(karts[selected_character],Rect2(44,247,38,48),false)
	text_at("02  DRIVER: " + NAMES[selected_character],Vector2(94,267),16,COLORS[selected_character])
	text_at("TAB / CLICK TO CHANGE",Vector2(94,286),11,Color("b9c5ce"))
	panel(Rect2(408,249,200,42),Color("eab864"),Color("fff0b5")); text_at("START RACE  >",Vector2(428,276),19,Color("17253d"))
	text_at("ARROWS / WASD steer & drive",Vector2(35,325),12)
	text_at("ENTER race   H how to play",Vector2(35,343),12,Color("8cbed0"))
	text_at("[H] CONTROLS",Vector2(482,342),12,Color("ffe18d"))
	var best = float(best_times.get(str(selected_course),0))
	if best > 0: text_at("BEST " + format_time(best),Vector2(444,110),13,Color("ffe18d"))

func draw_pause() -> void:
	draw_rect(Rect2(0,0,640,360),Color("0d182cab")); panel(Rect2(145,86,350,195))
	center_text("PIT STOP",126,35,Color("ffdf8a"))
	center_text("ESC / P   RESUME",166,17)
	center_text("R   RESTART RACE",196,17)
	center_text("Q   COURSE SELECT",226,17)
	center_text("H controls    M music / sound",257,13,Color("9fd6d5"))

func draw_results() -> void:
	draw_rect(Rect2(0,0,640,360),Color("10243cbd")); panel(Rect2(126,42,388,276),Color("192b44f5"),Color("ffe18d"))
	center_text("CHECKERED FLAG!",82,29,Color("ffe18d"))
	center_text("%s FINISHES #%d" % [NAMES[selected_character],model.finish_rank],118,20,COLORS[selected_character])
	center_text(COURSES[selected_course] + "  /  3 LAPS",151,14)
	center_text(format_time(model.finish_time),197,39,Color("86e6d5"))
	center_text("BEST  " + format_time(float(best_times.get(str(selected_course),model.finish_time))),223,14)
	center_text("ENTER / R   RACE AGAIN",264,17)
	center_text("ESC   PICK COURSE & DRIVER",290,14,Color("a6c8d0"))

func draw_help() -> void:
	draw_rect(Rect2(0,0,640,360),Color("0c1a2eea")); panel(Rect2(57,26,526,309),Color("1a2b44"),Color("85dbd3"))
	center_text("LEARN THE LINE",62,29,Color("ffe18d"))
	var lines = ["W / UP: accelerate     S / DOWN: brake", "A D / LEFT RIGHT: steer     SHIFT: hold drift", "Release a blue-spark drift for a MINI TURBO.", "SPACE: use item    BACKSPACE: rescue (+3 sec)", "BOOST: speed burst   BOLT: fire ahead   OIL: drop trap", "Cross ordered checkpoints. Cut grass and lose speed.", "ESC / P: pause    R: restart    M: mute", "PAD: A / RT gas, B brake, stick steer, RB drift, X item"]
	for i in range(lines.size()): text_at(lines[i],Vector2(79,95+i*24),13,Color("f6e9d1") if i%2 == 0 else Color("9ed4d1"))
	center_text("H / ESC / ENTER TO CLOSE",316,13,Color("ffe18d"))

func format_time(value: float) -> String:
	return "%02d:%05.2f" % [int(value/60),fmod(value,60)]

func save_time() -> void:
	var key = str(selected_course)
	if not best_times.has(key) or model.finish_time < float(best_times[key]):
		best_times[key] = model.finish_time
		if not test_mode:
			var file = FileAccess.open("user://records.json",FileAccess.WRITE)
			if file: file.store_string(JSON.stringify(best_times))

func load_times() -> void:
	if test_mode: return
	if FileAccess.file_exists("user://records.json"):
		var value = JSON.parse_string(FileAccess.get_file_as_string("user://records.json"))
		if value is Dictionary: best_times = value
