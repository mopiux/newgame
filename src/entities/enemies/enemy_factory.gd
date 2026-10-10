class_name EnemyFactory
## Maps the "behavior" field of data/enemies.json to a script class.


static func create(enemy_id: String, depth: int, elite: bool = false) -> Enemy:
	var data: Dictionary = Database.enemies.get(enemy_id, {})
	var e: Enemy
	match str(data.get("behavior", "")):
		"moth":
			e = Moth.new()
		"slug":
			e = Slug.new()
		"shade":
			e = Shade.new()
		"nest":
			e = Nest.new()
		"snuffer":
			e = Snuffer.new()
		"golem":
			e = Golem.new()
		"eye":
			e = GloomEye.new()
		"mimic":
			e = Mimic.new()
		"wraith":
			e = Wraith.new()
		_:
			push_error("EnemyFactory: unknown enemy %s" % enemy_id)
			e = Moth.new()
	e.setup(enemy_id, depth, elite)
	return e
