extends RefCounted
# Closed-circuit physics and race rules. No renderer dependencies.
const N = 180
const ROAD_WIDTH = 94.0
const LAPS = 3
var course = 0
var points: Array[Vector2] = []
var lengths: Array[float] = []
var total_length = 0.0
var racers: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var boxes: Array[Dictionary] = []
var clock = 0.0
var countdown = 3.0
var finished = false
var finish_time = 0.0
var finish_rank = 0
var last_event = ""
var event_timer = 0.0
var rng = RandomNumberGenerator.new()

func setup(which: int, character: int = 0) -> void:
	course = which
	rng.seed = 8451 + which
	points.clear(); lengths.clear(); racers.clear(); hazards.clear(); boxes.clear()
	total_length = 0.0; clock = 0.0; countdown = 3.0; finished = false; finish_rank = 0; finish_time = 0.0
	last_event = ""; event_timer = 0.0
	for i in range(N):
		var a = TAU * float(i) / N
		var p: Vector2
		if course == 0:
			p = Vector2(1024 + 680*cos(a) + 60*cos(3*a), 1024 + 640*sin(a))
		else:
			p = Vector2(1024 + 630*cos(a) + 160*cos(2*a), 1024 + 650*sin(a) - 75*sin(3*a))
		points.append(p)
	for i in range(N):
		lengths.append(total_length)
		total_length += points[i].distance_to(points[(i+1)%N])
	for i in range(8):
		var idx = posmod(N-2-i*2,N)
		var tangent = (points[(idx+1)%N]-points[idx]).normalized()
		var pos = points[idx] + Vector2(tangent.y,-tangent.x)*(-20 if i%2 == 0 else 20)
		racers.append({"pos":pos,"angle":tangent.angle(),"speed":0.0,"vel":Vector2.ZERO,"seg":idx,"progress":float(-2-i*2)/N*total_length,"lap":0,"next_gate":0,"boost":0.0,"spin":0.0,"drift":0.0,"item":"","color": character if i == 0 else (i+character)%8,"done":false,"finish":0.0,"offroad":false})
	for i in [12,49,85,123,159]:
		for lane in [-35,0,35]:
			var t = (points[(i+1)%N]-points[i]).normalized()
			boxes.append({"pos":points[i]+Vector2(t.y,-t.x)*lane,"cooldown":0.0})

func nearest(pos: Vector2) -> Dictionary:
	var best = INF
	var index = 0
	var blend = 0.0
	for i in range(N):
		var a = points[i]
		var edge = points[(i+1)%N]-a
		var t = clampf((pos-a).dot(edge)/edge.length_squared(),0,1)
		var d = pos.distance_squared_to(a+edge*t)
		if d < best:
			best = d; index = i; blend = t
	return {"seg":index,"distance":sqrt(best),"along":lengths[index]+blend*points[index].distance_to(points[(index+1)%N])}

func rank() -> int:
	if finished: return finish_rank
	var result = 1
	for i in range(1,8):
		if racers[i].progress > racers[0].progress: result += 1
	return result

func event(message: String) -> void:
	last_event = message; event_timer = 2.4

func use_item(index: int) -> void:
	var r = racers[index]
	if r.item == "" or r.done: return
	var kind: String = r.item
	r.item = ""
	var direction = Vector2.from_angle(r.angle)
	if kind == "BOOST":
		r.boost = 2.0
	else:
		hazards.append({"pos":r.pos+direction*(28 if kind == "BOLT" else -26),"vel":direction*360 if kind == "BOLT" else Vector2.ZERO,"kind":kind,"life":5.0 if kind == "BOLT" else 12.0,"owner":index})
	if index == 0: event(kind + "!")

func step(dt: float, throttle: float, steer: float, drift_pressed: bool, brake: bool) -> void:
	if finished: return
	event_timer = maxf(0,event_timer-dt)
	if countdown > 0:
		countdown = maxf(0,countdown-dt)
		return
	clock += dt
	for b in boxes: b.cooldown = maxf(0,b.cooldown-dt)
	for i in range(8):
		var r = racers[i]
		if r.done: continue
		var gas = throttle if i == 0 else 1.0
		var turn = -steer
		var slide = drift_pressed if i == 0 else false
		var stop = brake if i == 0 else false
		var near = nearest(r.pos)
		var previous_seg: int = r.seg
		r.seg = near.seg
		r.offroad = near.distance > ROAD_WIDTH
		if i > 0:
			var target = points[(r.seg+5)%N]
			var offset = sin(float(i)*5.1)*23
			var tang = (points[(r.seg+6)%N]-points[(r.seg+5)%N]).normalized()
			target += Vector2(tang.y,-tang.x)*offset
			var error = wrapf((target-r.pos).angle()-r.angle,-PI,PI)
			turn = clampf(error*2.5,-1,1)
			if absf(error) > 0.65: gas = 0.50
			if r.item != "" and rng.randf() < dt*0.12: use_item(i)
		r.boost = maxf(0,r.boost-dt); r.spin = maxf(0,r.spin-dt)
		var top = (202.0 if i == 0 else 171.0 + i*2.1) + (90.0 if r.boost > 0 else 0.0)
		if r.offroad: top *= 0.48
		if stop: top *= 0.25
		if r.spin > 0: top *= 0.18; turn = 2.2
		r.speed = move_toward(r.speed,top*gas,(95.0 if gas > 0 else 80.0)*dt)
		r.angle += turn * (1.65 if slide else 1.37) * clampf(r.speed/65.0,0,1.0)*dt
		var direction = Vector2.from_angle(r.angle)
		r.vel = r.vel.lerp(direction*r.speed,minf(1,dt*(3.1 if slide else 9.0)))
		r.pos += r.vel*dt
		if r.pos.x < 80 or r.pos.x > 1968 or r.pos.y < 80 or r.pos.y > 1968:
			r.pos = r.pos.clamp(Vector2(80,80),Vector2(1968,1968)); r.speed *= 0.7
		if slide and absf(turn) > 0.15 and r.speed > 90 and not r.offroad:
			r.drift = minf(2.5,r.drift+dt)
		elif r.drift > 0:
			if r.drift > 0.65:
				r.boost = 0.75 + r.drift*0.3
				if i == 0: event("MINI TURBO!")
			r.drift = 0.0
		# Ordered quarter-track gates block skipped laps / backwards line crossings.
		var gate = int(r.next_gate)
		var gate_index = gate*(N/4)
		var crossed_gate = r.pos.distance_to(points[gate_index]) < 135 and near.distance < 115
		if gate == 0: crossed_gate = previous_seg > N-12 and near.seg < 12 and near.distance < 115
		if crossed_gate:
			r.next_gate = (gate+1)%4
			if gate == 0:
				r.lap += 1
				if r.lap > LAPS:
					r.done = true; r.finish = clock
					if i == 0:
						finish_rank = rank(); finished = true; finish_time = clock
				elif i == 0 and r.lap > 1: event("FINAL LAP!" if r.lap == LAPS else "LAP 2 / 3")
		var along: float = near.along
		# Before first gate, this is the short approach to the start line.
		if r.lap == 0: r.progress = along-total_length
		else: r.progress = (r.lap-1)*total_length+along
		for b in boxes:
			if b.cooldown == 0 and r.item == "" and r.pos.distance_to(b.pos) < 25:
				r.item = ["BOOST","BOLT","OIL"][rng.randi_range(0,2)]
				b.cooldown = 5.0
				if i == 0: event(r.item + " READY  [SPACE]")
	for i in range(8):
		for j in range(i+1,8):
			var delta: Vector2 = racers[i].pos-racers[j].pos
			if delta.length() < 22 and delta.length() > 0.01:
				var push = delta.normalized()*(22-delta.length())*0.5
				racers[i].pos += push; racers[j].pos -= push
	for h in hazards:
		h.life -= dt; h.pos += h.vel*dt
		for i in range(8):
			if i != h.owner and racers[i].pos.distance_to(h.pos) < 25:
				racers[i].spin = 1.25; h.life = 0
				if i == 0: event("SPUN OUT!")
	hazards = hazards.filter(func(h): return h.life > 0)

func rescue() -> void:
	var r = racers[0]
	var i: int = r.seg
	r.pos = points[i]
	r.angle = (points[(i+1)%N]-points[i]).angle()
	r.speed = 0; r.vel = Vector2.ZERO; r.spin = 0
	clock += 3
	event("BACK ON TRACK  +3 SEC")
