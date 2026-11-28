## Regression (BUG: broken attack animations): the up strike ends pointing up
## and the down strike pointing down (they pointed behind the hero), and long
## weapons rest upright instead of sinking into the floor.
extends GdUnitTestSuite

func _hero(body: String) -> Player:
	var p: Player = auto_free(Player.new())
	p.weapon = Weapon.from_dict({ "id": body })
	p.face = 1
	return p

func test_up_strike_ends_pointing_up() -> void:
	var p := _hero("blade")
	p.atk_dir = "up"
	p.atk_dur = 0.3
	p.atk_t = 0.0001
	var a := p._blade_angle()
	# forward-up quadrant around straight up (-PI/2), not behind (< -2.0)
	assert_float(a).is_between(-2.0, -1.2)

func test_down_strike_ends_pointing_down() -> void:
	var p := _hero("blade")
	p.atk_dir = "down"
	p.atk_dur = 0.3
	p.atk_t = 0.0001
	assert_float(p._blade_angle()).is_between(1.2, 2.0)

func test_spear_rests_upright() -> void:
	var p := _hero("spear")
	p.atk_t = 0.0
	assert_float(p._blade_angle()).is_less(-0.8)
