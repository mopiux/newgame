class_name EventSystem
## Applies the choices of data/events.json. Each option has optional
## "requires" (flame / sparks / max_flame minimums) and a list of "effects".


static func can_choose(option: Dictionary, run: RunState) -> bool:
	var req: Dictionary = option.get("requires", {})
	if req.has("flame") and run.flame <= float(req.flame):
		return false
	if req.has("sparks") and run.sparks < int(req.sparks):
		return false
	if req.has("max_flame") and run.stats.get_stat("max_flame") <= float(req.max_flame):
		return false
	if req.has("relics") and run.relics.size() < int(req.relics):
		return false
	return true


## Applies the option and returns the localisation key of the outcome text.
static func apply(option: Dictionary, run: RunState, player: Player, room: Room) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunRng.derive(run.run_seed, "event-%d-%d" % [run.depth, run.rooms_cleared + run.relics.size()])
	var effects: Array = option.get("effects", [])
	if option.has("gamble"):
		var g: Dictionary = option.gamble
		effects = g.get("win", []) if rng.randf() < float(g.get("chance", 0.5)) else g.get("lose", [])
		var key: String = g.get("win_text", "") if effects == g.get("win", []) else g.get("lose_text", "")
		_apply_effects(effects, run, player, room, rng)
		return key
	_apply_effects(effects, run, player, room, rng)
	return str(option.get("result", ""))


static func _apply_effects(effects: Array, run: RunState, player: Player, room: Room, rng: RandomNumberGenerator) -> void:
	for e in effects:
		match str(e.get("type", "")):
			"flame":
				var v := float(e.value)
				if v >= 0.0:
					player.add_flame(v)
				else:
					player.spend_flame(minf(-v, run.flame - 1.0))
			"flame_full":
				player.add_flame(player.max_flame())
			"max_flame":
				run.add_curse("event_max", {"max_flame": ["add", float(e.value)]})
				if float(e.value) > 0.0:
					player.add_flame(float(e.value))
				Events.player_flame_changed.emit(run.flame, player.max_flame())
			"stat":
				run.add_curse("event_" + str(e.stat), {str(e.stat): [str(e.get("op", "mul")), float(e.value)]})
			"sparks":
				Game.add_sparks(int(e.value))
			"relic":
				var rar: Array = e.get("rarity", [])
				var ids := RelicPool.roll(run, rng, 1, rar)
				if not ids.is_empty():
					Game.grant_relic(ids[0])
			"remove_relic":
				if not run.relics.is_empty():
					var idx := rng.randi_range(0, run.relics.size() - 1)
					var lost: String = run.relics[idx]
					run.relics.remove_at(idx)
					run.build_stats()
					player.relic_fx.refresh()
					run.flame = minf(run.flame, player.max_flame())
					Events.toast.emit(tr_static("TOAST_RELIC_LOST") % tr_static(str(Database.relics.get(lost, {}).get("name", lost))), UITheme.CURSE)
					Events.relic_gained.emit("")
			"embers":
				if room:
					room.drop_embers(player.global_position + Vector2(0, -20), int(e.value))
			"spawn":
				if room:
					var wave: Array = []
					for i in int(e.get("count", 1)):
						wave.append({"id": str(e.id), "elite": bool(e.get("elite", false))})
					room.waves = [wave]
					room.combat_active = true
					room._wave_delay = 0.5
					room._set_doors_locked(true)
			"reveal_map":
				Game.reveal_map()


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)
