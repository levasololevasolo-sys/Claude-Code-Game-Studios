## Unit tests for StatusSet and the status multipliers of DamageRules
## (GDD gods-and-runes §3.7-3.9, F1-F3, F6; AC 2-9, 12, 16).
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0
## Fixture tuning: the GDD §7 defaults (formulas are tested, not shipped numbers).
const TUNE := { "burn_dps": 5.0, "burn_tick": 0.25, "burn_time": 3.0, "shock_stacks": 3, "shock_dmg": 22.0,
	"firestorm_feed": 1.0, "cut_max": 5, "cut_time": 5.0, "cut_burst": 9.0, "curse_time": 6.0,
	"curse_mult": 1.3, "root_time": 1.5, "root_immune": 2.0 }

func _ctx(duos: Array = [], need: int = 3) -> Dictionary:
	var d := {}
	for id: String in duos:
		d[id] = {}
	return { "shock_need": need, "jumps_bonus": 0, "root_mult": 1.0, "duos": d, "mods": {} }

func _run(s: StatusSet, seconds: float, ctx: Dictionary) -> float:
	var total := 0.0
	for i in roundi(seconds / DT):
		total += float(s.tick(DT, TUNE, ctx).burn)
	return total

func _view(o: Dictionary = {}) -> Dictionary:
	var v := { "x": 100.0, "face": 1, "weight": 1.0, "kb_scale": 1.0 }
	v.merge(o, true)
	return v

# ---- burn (F1, AC 4) ----

func test_burn_default_deals_15_over_3_s() -> void:
	var s := StatusSet.new()
	s.add_burn(3.0)
	assert_float(_run(s, 3.0, _ctx())).is_equal_approx(15.0, 1.25)
	assert_bool(s.burning()).is_false()

func test_burn_reapply_takes_longer() -> void:
	var s := StatusSet.new()
	s.add_burn(3.0)
	assert_bool(s.add_burn(1.0)).is_false()
	assert_float(s.burn).is_equal_approx(3.0, 0.0001)

# ---- charge (AC 2) ----

func test_shock_discharges_on_third_charge() -> void:
	var s := StatusSet.new()
	assert_bool(s.add_shock(1, 3)).is_false()
	assert_bool(s.add_shock(1, 3)).is_false()
	assert_bool(s.add_shock(1, 3)).is_true()
	assert_int(s.shock).is_equal(0)

func test_shock_with_storm_discharges_on_second() -> void:
	var s := StatusSet.new()
	assert_bool(s.add_shock(1, 2)).is_false()
	assert_bool(s.add_shock(1, 2)).is_true()

# ---- discharge (F3, AC 3) ----

func test_discharge_damage_origin_and_jump() -> void:
	assert_float(StatusSet.discharge_dmg(22.0, 0, false, 0.0, 0.7)).is_equal_approx(22.0, 0.0001)
	assert_float(StatusSet.discharge_dmg(22.0, 1, false, 0.0, 0.7)).is_equal_approx(15.4, 0.0001)
	assert_float(StatusSet.discharge_dmg(22.0, 0, true, 2.0, 0.7)).is_equal_approx(44.0, 0.0001)

func test_chain_reaches_250_not_350() -> void:
	var pts: Array[Vector2] = [Vector2(250, 0)]
	assert_array(StatusSet.chain(Vector2.ZERO, pts, 1, 300.0)).is_equal([0])
	var far: Array[Vector2] = [Vector2(350, 0)]
	assert_array(StatusSet.chain(Vector2.ZERO, far, 1, 300.0)).is_empty()

func test_chain_goes_to_nearest_unvisited() -> void:
	var pts: Array[Vector2] = [Vector2(500, 0), Vector2(200, 0), Vector2(250, 0)]
	assert_array(StatusSet.chain(Vector2.ZERO, pts, 3, 300.0)).is_equal([1, 2, 0])

func test_jumps_example_raskaty_storm() -> void:
	# F3 example: «Раскаты» ур.1 (+2) + «Буря» (+1) + base 1 = 4
	var c := _ctx(["duo_storm"], 2)
	c.jumps_bonus = 3
	assert_int(StatusSet.discharge_jumps(c, false, false, 0, 1)).is_equal(4)

# ---- cuts (§3.9, F2, AC 6-8) ----

func test_cuts_stack_cap_and_fade() -> void:
	var s := StatusSet.new()
	for i in 3:
		s.add_cuts(1, 5, 5.0)
	assert_int(s.cuts).is_equal(3)
	for i in 4:
		s.add_cuts(1, 5, 5.0)
	assert_int(s.cuts).is_equal(5)
	var dmg := _run(s, 5.0, _ctx())
	assert_int(s.cuts).is_equal(0)
	assert_float(dmg).is_equal(0.0)

func test_cut_burst_formula() -> void:
	assert_float(StatusSet.burst_dmg(9.0, 5, 1.0)).is_equal_approx(45.0, 0.0001)
	assert_float(StatusSet.burst_dmg(9.0, 2, 1.0)).is_equal_approx(18.0, 0.0001)
	assert_float(StatusSet.burst_dmg(9.0, 3, 1.0)).is_equal_approx(27.0, 0.0001)
	var s := StatusSet.new()
	s.add_cuts(4, 5, 5.0)
	assert_int(s.take_cuts()).is_equal(4)
	assert_int(s.cuts).is_equal(0)

# ---- roots (AC 9) ----

func test_roots_last_then_immunity_blocks_new_roots() -> void:
	var s := StatusSet.new()
	assert_bool(s.add_root(1.5, 2.0)).is_true()
	_run(s, 1.4, _ctx())
	assert_bool(s.rooted()).is_true()
	_run(s, 0.2, _ctx())
	assert_bool(s.rooted()).is_false()
	assert_bool(s.add_root(1.5, 2.0)).is_false()
	_run(s, 2.0, _ctx())
	assert_bool(s.add_root(1.5, 2.0)).is_true()

# ---- multipliers (AC 5, 12) ----

func test_cursed_target_takes_14_3_from_11() -> void:
	var h := Hit.make(Hit.Kind.STRIKE, 11.0, 50.0, 0.0)
	assert_float(DamageRules.final(h, _view({ "cursed": true }), TUNE)).is_equal_approx(14.3, 0.0001)

func test_edge_on_clean_and_burning_target() -> void:
	var h := Hit.make(Hit.Kind.STRIKE, 11.0, 50.0, 0.0)
	h.mods = { "edge": 1.5 }
	assert_float(DamageRules.final(h, _view({ "clean": true }), TUNE)).is_equal_approx(16.5, 0.0001)
	assert_float(DamageRules.final(h, _view({ "clean": false, "burning": true }), TUNE)).is_equal_approx(11.0, 0.0001)

func test_reaper_skips_burn_ticks() -> void:
	var t := Hit.make(Hit.Kind.TICK, 1.25, 50.0, 0.0)
	t.mods = { "reaper": 2.0 }
	assert_float(DamageRules.final(t, _view({ "rooted": true }), TUNE)).is_equal_approx(1.25, 0.0001)
	var h := Hit.make(Hit.Kind.STRIKE, 11.0, 50.0, 0.0)
	h.mods = { "reaper": 2.0 }
	assert_float(DamageRules.final(h, _view({ "rooted": true }), TUNE)).is_equal_approx(22.0, 0.0001)

func test_has_god_status_ignores_stun() -> void:
	var s := StatusSet.new()
	assert_bool(s.has_god_status()).is_false()
	s.add_cuts(1, 5, 5.0)
	assert_bool(s.has_god_status()).is_true()

# ---- firestorm loop cap (F6, §3.8 p.5, AC 16) ----

## Simulates one enemy with Огненная гроза: the hero's discharge sets it on fire
## (burn_time); feed charges discharge with fed = true (only self burns, no jumps).
## Returns [seconds the burn lasted after the hero's discharge, fed discharges, jumps of fed discharges].
func _loop(need: int, seconds: float) -> Array:
	var s := StatusSet.new()
	var ctx := _ctx(["duo_firestorm"] + (["duo_storm"] if need == 2 else []), need)
	s.add_burn(3.0)
	var last_burning := 0.0
	var fed := 0
	var jumps := 0
	for i in roundi(seconds / DT):
		var r := s.tick(DT, TUNE, ctx)
		if bool(r.feed) and s.add_shock(1, need):
			fed += 1
			jumps += StatusSet.discharge_jumps(ctx, true, false, 0, 1)
			s.add_burn(3.0)
		if s.burning():
			last_burning = (i + 1) * DT
	return [last_burning, fed, jumps]

func test_firestorm_without_storm_dies_within_3_1_s() -> void:
	var r := _loop(3, 10.0)
	assert_float(r[0]).is_less_equal(3.1)
	assert_int(r[1]).is_equal(0)

func test_firestorm_with_storm_lives_but_never_jumps() -> void:
	var r := _loop(2, 10.0)
	assert_float(r[0]).is_greater(9.9)
	assert_int(r[1]).is_greater(3)
	assert_int(r[2]).is_equal(0)

func test_loop_alive_formula() -> void:
	assert_bool(StatusSet.loop_alive(3, 1.0, 3.0, 1.0)).is_false()
	assert_bool(StatusSet.loop_alive(2, 1.0, 3.0, 1.0)).is_true()
