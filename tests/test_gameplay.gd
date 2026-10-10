extends TestCase
## Gameplay rules that do not need a running scene.


func test_light_falloff_matches_shader_rules() -> void:
	near(Lights.falloff(0.0, 50.0), 1.0, 0.0001, "full at centre")
	near(Lights.falloff(50.0, 50.0), 0.0, 0.0001, "zero at radius")
	near(Lights.falloff(25.0, 50.0), 0.5, 0.0001, "smoothstep midpoint")
	near(Lights.falloff(10.0, 0.0), 0.0, 0.0001, "zero radius")
	check(Lights.falloff(10.0, 50.0) > Lights.falloff(30.0, 50.0), "monotonic")


func test_relic_pool_respects_unlocks_and_ownership() -> void:
	var saved := SaveManager.profile
	SaveManager.profile = SaveManager.default_profile()
	var r := RunState.create("POOL", "oil", 0)
	for i in 30:
		var ids := RelicPool.roll(r, RunRng.make(i, "pool"), 3)
		eq(ids.size(), 3, "three offers")
		var uniq := {}
		for id in ids:
			uniq[id] = true
			eq(int(Database.relics[id].get("tier", 0)), 0, "locked tiers never offered")
		eq(uniq.size(), ids.size(), "no duplicate offers")
		r.seen_relics_run.clear()
	r.add_relic("prism")
	for i in 30:
		var ids2 := RelicPool.roll(r, RunRng.make(i, "pool2"), 3)
		check(not ids2.has("prism"), "owned non-stackable relic not offered again")
		r.seen_relics_run.clear()
	SaveManager.profile.lamps = ["market", "archive"]
	var tiers := {}
	for i in 60:
		for id in RelicPool.roll(r, RunRng.make(i, "pool3"), 3):
			tiers[int(Database.relics[id].get("tier", 0))] = true
		r.seen_relics_run.clear()
	check(tiers.has(1) and tiers.has(2), "unlocked tiers appear")
	SaveManager.profile = saved


func test_event_requirements() -> void:
	var r := RunState.create("EV", "oil", 0)
	r.flame = 10.0
	check(not EventSystem.can_choose({"requires": {"flame": 25}}, r), "flame requirement")
	r.flame = 50.0
	check(EventSystem.can_choose({"requires": {"flame": 25}}, r), "flame requirement met")
	check(not EventSystem.can_choose({"requires": {"sparks": 3}}, r), "sparks requirement")
	check(not EventSystem.can_choose({"requires": {"relics": 1}}, r), "relic requirement")
	check(EventSystem.can_choose({}, r), "no requirement")


func test_prices_are_positive() -> void:
	for id in Database.relics:
		check(RelicPool.price(id) > 0, "price for " + id)
	for l in Database.lamps:
		check(int(l.cost) > 0, "lamp cost " + str(l.id))


func test_event_weights_follow_their_events() -> void:
	var saved_run = Game.run
	Game.run = RunState.create("WEIGHTS", "oil", 0)
	Game.run.depth = 1
	var counts := {}
	for i in 4000:
		var id := Game.pick_event(RunRng.make(i, "w"))
		counts[id] = int(counts.get(id, 0)) + 1
	Game.run = saved_run
	# wax_fountain (weight 2) must show up about twice as often as chandler_ghost (weight 1)
	var ratio := float(counts.get("wax_fountain", 0)) / maxf(1.0, float(counts.get("chandler_ghost", 0)))
	check(ratio > 1.6 and ratio < 2.5, "weight ratio fountain/ghost ~2 (got %.2f)" % ratio)
	check(not counts.has("mirror_hall"), "locked tier-1 events never picked")


func test_new_relic_hooks_on_a_live_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var holder := Node2D.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(holder)
	var r := RunState.create("HOOKS", "oil", 0)
	var p := Player.new()
	p.setup(r)
	holder.add_child(p)
	var fx := p.relic_fx
	# Aceite bendito: lighting a brazier refunds flame, stacking
	r.flame = 40.0
	fx.on_brazier_lit(holder)
	near(r.flame, 40.0, 0.001, "no refund without blessed oil")
	r.add_relic("blessed_oil")
	fx.on_brazier_lit(holder)
	near(r.flame, 46.0, 0.001, "blessed oil refunds 6")
	r.add_relic("blessed_oil")
	fx.on_brazier_lit(holder)
	near(r.flame, 58.0, 0.001, "two blessed oils refund 12")
	# Fósforo blanco: the flare burns, other hits do not
	var shot_info := {"damage": 10.0, "kind": "shot"}
	fx.modify_hit(holder, shot_info)
	check(not shot_info.has("burn"), "plain shot does not burn")
	r.add_relic("white_phosphor")
	var flare_info := {"damage": 10.0, "kind": "flare"}
	fx.modify_hit(holder, flare_info)
	check(float(flare_info.get("burn", 0.0)) >= 12.0, "white phosphor flare burns")
	near(r.stats.get_stat("flare_damage"), 22.0 * 1.5, 0.01, "white phosphor flare damage")
	# Farol de bolsillo: higher light floor
	var floor_before := r.stats.get_stat("light_min")
	r.add_relic("pocket_lamp")
	near(r.stats.get_stat("light_min"), floor_before + 16.0, 0.01, "pocket lamp light floor")
	# Espejo de mano: a struck orb comes back as a player shot
	var orb := Projectile.new()
	orb.team = "enemy"
	orb.velocity = Vector2(90, 0)
	check(fx.reflect_shot(orb) == null, "no reflection without the mirror")
	r.add_relic("hand_mirror")
	var back := fx.reflect_shot(orb)
	if check(back != null, "mirror reflects the orb"):
		eq(back.team, "player", "reflected shot belongs to the player")
		check(back.velocity.normalized().is_equal_approx(Vector2.LEFT), "reflected shot flies back")
		check(back.damage > 0.0, "reflected shot deals damage")
	orb.free()
	holder.queue_free()
