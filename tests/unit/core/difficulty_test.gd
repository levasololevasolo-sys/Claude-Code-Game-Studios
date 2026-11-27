## Difficulty (GDD design/gdd/difficulty.md): «Былина» is identity, «Навь» and
## «Сказка» change enemy damage / hp / wind-ups, heals, embers and revives
## through the one helper; old saves migrate to «Былина».
extends GdUnitTestSuite

const KEYS: Array[String] = ["enemy_dmg", "enemy_hp", "heal", "embers", "windup"]

## Fixture table (not the shipped file): exact numbers are the point.
func _t() -> Dictionary:
	return { "default": "bylina", "order": ["skazka", "bylina", "nav"], "windup_keys": ["wind"], "windup_suffix": "_wind",
		"levels": {
			"skazka": { "enemy_dmg": 0.5, "enemy_hp": 0.8, "heal": 2.0, "embers": 1.0, "windup": 1.25, "revives": 1 },
			"bylina": { "enemy_dmg": 1.0, "enemy_hp": 1.0, "heal": 1.0, "embers": 1.0, "windup": 1.0, "revives": 0 },
			"nav": { "enemy_dmg": 1.5, "enemy_hp": 1.25, "heal": 0.5, "embers": 2.0, "windup": 0.8, "revives": 0 } } }

func after_test() -> void:
	Difficulty.current = Difficulty.DEFAULT

func test_bylina_is_identity_in_fixture_and_shipped_table() -> void:
	for t: Dictionary in [_t(), Difficulty.table()]:
		for k in KEYS:
			assert_float(Difficulty.value("bylina", k, t)).is_equal(1.0)
		assert_int(Difficulty.revives_for("bylina", t)).is_equal(0)
	assert_str(String(Difficulty.table().get("default"))).is_equal("bylina")

func test_unknown_level_and_missing_key_read_as_default() -> void:
	var t := _t()
	assert_str(Difficulty.normalize("", t)).is_equal("bylina")
	assert_str(Difficulty.normalize("ад", t)).is_equal("bylina")
	assert_float(Difficulty.value("nav", "no_such_key", t)).is_equal(1.0)
	assert_float(Difficulty.value("ад", "enemy_dmg", t)).is_equal(1.0)

func test_heal_and_embers_follow_level() -> void:
	var t := _t()
	assert_float(Difficulty.heal_for(20.0, "bylina", t)).is_equal(20.0)
	assert_float(Difficulty.heal_for(20.0, "nav", t)).is_equal(10.0)
	assert_float(Difficulty.heal_for(20.0, "skazka", t)).is_equal(40.0)
	assert_float(Difficulty.embers_mult_for(1.0, "bylina", t)).is_equal(1.0)
	assert_float(Difficulty.embers_mult_for(1.5, "nav", t)).is_equal(3.0)
	assert_int(Difficulty.revives_for("skazka", t)).is_equal(1)

func test_windups_scale_but_min_windup_and_row_stay() -> void:
	var t := _t()
	var row := { "wind": 0.5, "bash_wind": 0.4, "min_windup": 0.45, "wind_damp": 0.9, "hp": 30 }
	var hard := Difficulty.scale_windups(row, "nav", t)
	assert_float(float(hard.wind)).is_equal_approx(0.4, 0.0001)
	assert_float(float(hard.bash_wind)).is_equal_approx(0.32, 0.0001)
	assert_float(float(hard.min_windup)).is_equal(0.45)
	assert_float(float(hard.wind_damp)).is_equal(0.9)
	assert_float(float(row.wind)).is_equal(0.5)
	assert_bool(is_same(Difficulty.scale_windups(row, "bylina", t), row)).is_true()

func test_enemy_damage_and_hp_use_current_level() -> void:
	var t := Difficulty.table()
	Difficulty.current = "bylina"
	var a: Bat = auto_free(EnemyFixtures.make(Bat.new(), EnemyFixtures.bat(), 2, Vector2(800, 400)))
	var base_dmg := a.dmg_mult()
	var base_hp := a.max_hp
	Difficulty.current = "nav"
	var b: Bat = auto_free(EnemyFixtures.make(Bat.new(), EnemyFixtures.bat(), 2, Vector2(800, 400)))
	assert_float(b.dmg_mult()).is_equal_approx(base_dmg * Difficulty.value("nav", "enemy_dmg", t), 0.0001)
	assert_float(b.max_hp).is_equal_approx(base_hp * Difficulty.value("nav", "enemy_hp", t), 0.0001)
	assert_float(float(b.stats.wind)).is_equal_approx(float(EnemyFixtures.bat().wind) * Difficulty.value("nav", "windup", t), 0.0001)
	Difficulty.current = "skazka"
	assert_float(a.dmg_mult()).is_equal_approx(base_dmg * Difficulty.value("skazka", "enemy_dmg", t), 0.0001)

func test_shipped_hard_and_easy_point_the_right_way() -> void:
	var t := Difficulty.table()
	assert_float(Difficulty.value("nav", "enemy_dmg", t)).is_greater(1.0)
	assert_float(Difficulty.value("nav", "windup", t)).is_less(1.0)
	assert_float(Difficulty.value("nav", "heal", t)).is_less(1.0)
	assert_float(Difficulty.value("skazka", "enemy_dmg", t)).is_less(1.0)
	assert_float(Difficulty.value("skazka", "heal", t)).is_greater(1.0)
	assert_int(Difficulty.revives_for("skazka", t)).is_greater(0)

func test_save_migration_old_save_is_bylina() -> void:
	var d := SaveFile.migrate({ "version": 3, "meta": { "runs": 2 }, "run": null })
	assert_int(int(d.version)).is_equal(SaveFile.VERSION)
	assert_str(MetaState.from_dict(d.meta).difficulty).is_equal("bylina")
	var v1 := SaveFile.migrate({ "version": 1, "meta": { "embers": 3 } })
	assert_str(String(v1.meta.difficulty)).is_equal("bylina")

func test_new_save_has_no_level_and_roundtrips() -> void:
	var m := MetaState.from_dict({})
	assert_str(m.difficulty).is_equal("")
	assert_str(Difficulty.normalize(m.difficulty, Difficulty.table())).is_equal("bylina")
	m.difficulty = "nav"
	assert_str(MetaState.from_dict(m.to_dict()).difficulty).is_equal("nav")
	var kept := SaveFile.migrate({ "version": 3, "meta": { "difficulty": "skazka" } })
	assert_str(String(kept.meta.difficulty)).is_equal("skazka")

func test_choice_screen_only_on_new_save_without_check_flags() -> void:
	var m := MetaState.from_dict({})
	assert_bool(World.wants_difficulty_choice(PackedStringArray(), m, false)).is_true()
	assert_bool(World.wants_difficulty_choice(PackedStringArray(["--run-check=x"]), m, false)).is_false()
	assert_bool(World.wants_difficulty_choice(PackedStringArray(["--demo=x"]), m, false)).is_false()
	assert_bool(World.wants_difficulty_choice(PackedStringArray(), m, true)).is_false()
	m.difficulty = "bylina"
	assert_bool(World.wants_difficulty_choice(PackedStringArray(), m, false)).is_false()
