extends SceneTree
func _initialize() -> void:
	var Model = load("res://scripts/race_model.gd")
	var failed = false
	for course in range(2):
		var m = Model.new(); m.setup(course,0); m.countdown = 0
		var frames = 0
		while not m.finished and frames < 18000:
			var r = m.racers[0]
			var near = m.nearest(r.pos)
			var target: Vector2 = m.points[(near.seg+5)%180]
			var error = wrapf((target-r.pos).angle()-r.angle,-PI,PI)
			var steer = -clampf(error*2.5,-1,1)
			if r.item != "": m.use_item(0)
			m.step(1.0/60,1.0,steer,false,false)
			frames += 1
		print("CIRCUIT %d: finished=%s lap=%d rank=%d time=%.2f frames=%d ai_laps=%s" % [course,m.finished,m.racers[0].lap,m.rank(),m.clock,frames,str(m.racers.slice(1).map(func(r):return r.lap))])
		if not m.finished or m.racers[0].lap != 4 or m.rank() < 1 or m.rank()>8: failed = true
	quit(1 if failed else 0)
