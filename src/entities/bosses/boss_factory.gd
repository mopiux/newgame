class_name BossFactory


static func create(boss_id: String, depth: int) -> Boss:
	var b: Boss
	match boss_id:
		"moth_mother":
			b = MothMother.new()
		"great_snuffer":
			b = GreatSnuffer.new()
		"penumbra":
			b = PenumbraBoss.new()
		_:
			push_error("BossFactory: unknown boss " + boss_id)
			b = MothMother.new()
			boss_id = "moth_mother"
	b.setup(boss_id, depth)
	return b
