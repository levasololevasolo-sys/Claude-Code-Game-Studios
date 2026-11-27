## Fixture rows for the enemy state machine tests (copies of the GDD §3.4
## numbers; tests inject them so they do not read assets/data/enemies.json).
class_name EnemyFixtures
extends RefCounted

const DT: float = 1.0 / 60.0

static func crawler() -> Dictionary:
	return { "w": 58, "h": 32, "hp": 34, "flies": false, "weight": 1, "contact": 12, "charge_contact_mult": 1.5,
		"speed": 95, "range_x": 420, "range_y": 140, "wind": 0.5, "charge": 640, "charge_time": 0.6, "wall_stop": 40,
		"recover": 0.7, "recover_damp": 0.85, "cd_min": 1.2, "cd_max": 2.4, "leap_tier": 2, "leap_dy": 80,
		"leap_range_x": 320, "crouch": 0.4, "leap_up": 980, "leap_side_mult": 1.6, "leap_side_max": 520,
		"leap_time": 1.2, "leap_min_air": 0.2, "leap_recover": 0.6 }

static func bat() -> Dictionary:
	return { "w": 50, "h": 30, "hp": 20, "flies": true, "weight": 0.6, "contact": 10, "hover_dx": 180, "hover_dy": 220,
		"hover_bob": 20, "hover_bob_freq": 2, "hover_gain": 2.2, "hover_resp": 3, "hover_max_x": 220, "hover_max_y": 200,
		"wind": 0.55, "wind_damp": 0.9, "wind_rise": 40, "aim_dy": 24, "swoop": 540, "swoop_time": 0.85, "swoop_floor": 10,
		"cd_min": 1.6, "cd_max": 2.8, "spit_tier": 2, "spit_chance": 0.45, "spit_count": 3, "spit_spread": 0.25,
		"spit_speed": 280, "spit_dmg": 10, "spit_r": 8, "spit_life": 3, "spit_cd_min": 1.8, "spit_cd_max": 3.0 }

static func sentry() -> Dictionary:
	return { "w": 40, "h": 76, "hp": 50, "flies": false, "weight": 1.8, "contact": 8, "front_shield": true, "shield_block": 0.0,
		"turn": 0.7, "walk_speed": 65, "stop": 80, "bash_range": 115, "bash_wind": 0.6, "bash_dmg": 16, "bash_push": 420,
		"bash_cd": 2.0, "bash_hit_x": 120, "bash_hit_y": 80, "bash_recover": 0.5, "recover_damp": 0.85 }

static func thrower() -> Dictionary:
	return { "w": 36, "h": 70, "hp": 34, "flies": false, "weight": 1.1, "contact": 6, "keep_min": 300, "keep_max": 520,
		"walk_speed": 75, "back_speed": 70, "flee_range": 220, "flee_speed": 140, "corner_px": 110, "fire_range": 950,
		"aim": 0.8, "fire": 2.6, "fire_jitter": 0.15, "lob_speed": 380, "lob_t_min": 0.7, "lob_t_max": 1.4, "lob_grav": 900,
		"shot_dmg": 12, "shot_r": 10, "shot_life": 4, "muzzle_x": 14, "muzzle_y": 66, "shove_range": 95, "shove_wind": 0.4,
		"shove_dmg": 8, "shove_push": 300, "shove_cd": 1.6, "shove_hit_x": 100, "shove_hit_y": 80 }

static func bloat() -> Dictionary:
	return { "w": 56, "h": 56, "hp": 26, "flies": true, "weight": 0.8, "contact": 0, "speed": 75, "bob": 30, "bob_freq": 3,
		"target_dy": 40, "trigger": 120, "fuse": 0.85, "swell_damp": 0.9, "death_fuse": 0.35, "radius": 125, "dmg": 22,
		"enemy_mult": 2, "enemy_kb": 500, "blast_time": 0.35, "blast_shake": 12 }

static func balvan() -> Dictionary:
	return { "w": 40, "h": 72, "hp": 24, "flies": false, "weight": 1.2, "contact": 0, "color": "#8a6a4a", "eye": "#c2502a",
		"speed": 90, "swing_range": 85, "range_y": 90, "wind": 0.7, "swing_time": 0.25, "reach": 70, "swing_dmg": 9.6,
		"swing_step": 60, "recover": 0.6, "cd_min": 0.8, "cd_max": 1.6 }

static func shishiga() -> Dictionary:
	return { "w": 30, "h": 32, "hp": 12, "flies": false, "weight": 0.5, "contact": 0, "speed": 120, "leap_range": 320,
		"range_y": 120, "crouch": 0.6, "leap_speed": 420, "leap_up": 480, "leap_time": 1.2, "leap_min_air": 0.15,
		"leap_dmg": 3, "cling_dmg": 3, "cling_tick": 0.5, "cling_time": 3.0, "cling_dx": 4, "cling_dy": 50,
		"shaken_stun": 0.8, "shaken_push": 260, "shaken_up": 300, "recover": 0.5, "cd_min": 1.0, "cd_max": 2.0 }

static func bognitsa() -> Dictionary:
	return { "w": 64, "h": 58, "hp": 36, "flies": false, "weight": 1.4, "contact": 0, "hummock_w": 120, "hummock_h": 26,
		"stand_time": 0.4, "shake": 0.5, "dive_time": 0.7, "rise": 0.5, "rise_dx": 120, "speed": 80, "reach": 100,
		"range_y": 90, "wind": 0.6, "swipe_time": 0.25, "swipe_dmg": 13.2, "recover": 0.6, "cd_min": 0.9, "cd_max": 1.7 }

static func vodyanitsa() -> Dictionary:
	return { "w": 34, "h": 84, "hp": 27, "flies": false, "weight": 0.9, "contact": 0, "speed": 85, "keep_dx": 400,
		"song": 0.8, "song_r": 260, "ward_frac": 0.25, "ward_time": 6, "song_cd": 5, "song_break_cd": 2.0,
		"push_range": 160, "push_wind": 0.5, "push_time": 0.2, "push_dmg": 6, "push_hit_x": 110, "push_hit_y": 90,
		"push_knock": 380, "push_cd": 1.5 }

## A set-up enemy outside the tree: fixture row, fixed seed, given tier and position.
static func make(e: Enemy, row: Dictionary, tier: int, at: Vector2) -> Enemy:
	e.stats = row
	e.tier = tier
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = 42
	e.position = at
	e.setup()
	return e

## Runs think() for `seconds`, returns the states visited in order (no repeats).
static func run(e: Enemy, seconds: float, hero: Vector2) -> Array[String]:
	var seen: Array[String] = [e.st]
	var n := roundi(seconds / DT)
	for i in n:
		e.call("think", DT, hero)
		if seen[seen.size() - 1] != e.st:
			seen.append(e.st)
	return seen

## Ticks until the state changes; returns seconds spent (or -1 after `limit` s).
static func time_in_state(e: Enemy, hero: Vector2, limit: float) -> float:
	var s := e.st
	var n := 0
	while e.st == s:
		e.call("think", DT, hero)
		n += 1
		if n * DT > limit:
			return -1.0
	return n * DT

## time_in_state() for kinds whose think() takes a third argument (Водяница's allies).
static func time_in_state_with(e: Enemy, hero: Vector2, extra: Variant, limit: float) -> float:
	var s := e.st
	var n := 0
	while e.st == s:
		e.call("think", DT, hero, extra)
		n += 1
		if n * DT > limit:
			return -1.0
	return n * DT
