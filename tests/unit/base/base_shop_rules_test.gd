## Shop rules of the base (armor-and-hero-progression §3.2, §4.1; economy-and-meta §3.4).
extends GdUnitTestSuite

const CFG := {
	"e1": 150, "g": 2.0, "r1": 12, "gr": 2.0, "hearts": [0, 0, 1, 2], "hearts_res": "cores",
	"cost_scale": 1.0, "max_tier": 4, "even_gap": 2,
	"slots": {
		"head": { "name": "Голова", "res1": "gears", "res": "pearls", "parts": [] },
		"torso": { "name": "Торс", "res1": "gears", "res": "gears", "parts": [] },
	},
}
const BASE := {
	"up_cost_scale": 1.0,
	"amulets": { "ring": {}, "beam": { "gears": 14, "cores": 1 } },
	"kapishe": { "reroll": { "prices": [60, 250] } },
}

func _rich() -> MetaState:
	var m := MetaState.new()
	m.embers = 10000
	m.res = { "gears": 500, "bronze": 500, "pearls": 500, "cores": 10 }
	m.armor = { "head": 0, "torso": 0 }
	return m

func test_armor_price_tier_3_matches_formula() -> void:
	var p := ShopRules.armor_price("head", 3, CFG)
	assert_int(int(p.embers)).is_equal(600)
	assert_dict(p.res).is_equal({ "pearls": 48, "cores": 1 })

func test_armor_price_tier_1_is_paid_in_iron() -> void:
	assert_dict(ShopRules.armor_price("head", 1, CFG).res).is_equal({ "gears": 12 })

func test_buy_armor_takes_the_price_and_raises_the_tier() -> void:
	var m := _rich()
	assert_bool(ShopRules.buy_armor(m, "torso", CFG)).is_true()
	assert_int(int(m.armor.torso)).is_equal(1)
	assert_int(m.embers).is_equal(9850)
	assert_int(int(m.res.gears)).is_equal(488)

func test_even_growth_blocks_tier_3_while_a_slot_is_at_0() -> void:
	var m := _rich()
	ShopRules.buy_armor(m, "torso", CFG)
	ShopRules.buy_armor(m, "torso", CFG)
	assert_bool(ShopRules.buy_armor(m, "torso", CFG)).is_false()
	assert_str(ShopRules.armor_block(m, "torso", CFG)).starts_with("Сначала")
	assert_int(int(m.armor.torso)).is_equal(2)

func test_short_bank_blocks_and_takes_nothing() -> void:
	var m := MetaState.new()
	m.armor = { "head": 0, "torso": 0 }
	m.embers = 100
	assert_bool(ShopRules.buy_armor(m, "head", CFG)).is_false()
	assert_str(ShopRules.armor_block(m, "head", CFG)).starts_with("Не хватает")
	assert_int(m.embers).is_equal(100)

func test_max_tier_is_final() -> void:
	var m := _rich()
	m.armor = { "head": 4, "torso": 4 }
	assert_str(ShopRules.armor_block(m, "head", CFG)).is_equal("Уже на максимуме")

func test_amulet_bought_once_then_worn_free() -> void:
	var m := _rich()
	assert_bool(ShopRules.take_amulet(m, "beam", BASE)).is_true()
	assert_str(m.lantern).is_equal("beam")
	assert_int(int(m.res.cores)).is_equal(9)
	ShopRules.take_amulet(m, "ring", BASE)
	assert_bool(ShopRules.take_amulet(m, "beam", BASE)).is_true()
	assert_int(int(m.res.cores)).is_equal(9)

func test_kapishe_reroll_levels_then_stops() -> void:
	var m := _rich()
	assert_bool(ShopRules.buy_up(m, "reroll", BASE)).is_true()
	assert_bool(ShopRules.buy_up(m, "reroll", BASE)).is_true()
	assert_bool(ShopRules.buy_up(m, "reroll", BASE)).is_false()
	assert_int(int(m.up.reroll)).is_equal(2)
	assert_int(m.embers).is_equal(10000 - 310)
