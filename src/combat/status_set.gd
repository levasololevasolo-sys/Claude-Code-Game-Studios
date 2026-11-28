## The god statuses on one enemy (GDD gods-and-runes §3.7-3.9, §3.14, F1, F2, F6).
## Pure data + timers: no nodes, no autoloads; every number comes from `tune`
## (Tune.data in the game, a fixture in tests) and the build context `ctx`
## (RunBuild.ctx(), StatusSet.default_ctx() without a hero). Enemy owns one and
## turns what tick()/add_*() report into hits (Enemy._tick_status, _discharge).
class_name StatusSet
extends RefCounted

## Below this a timer counts as ended (frame-sum rounding guard).
const EPS: float = 0.0001

## Seconds of burning left; time accumulated toward the next 0.25 s tick.
var burn: float = 0.0
var burn_tick: float = 0.0
## Perun charges (0 .. shock_stacks-1; a discharge resets to 0).
var shock: int = 0
## Stribog cuts (0 .. cut_max) and seconds until they all fade.
var cuts: int = 0
var cut_t: float = 0.0
## Seconds of curse left.
var curse: float = 0.0
## Seconds of roots left; seconds of root immunity left (starts when roots end).
var root: float = 0.0
var immune: float = 0.0
## Gods-expansion statuses (§3.2): seconds left of each; blind_immune starts
## when blind ends; steam_cd is Kupala's per-enemy steam cooldown.
var wet: float = 0.0
var thread: float = 0.0
var blind: float = 0.0
var blind_immune: float = 0.0
var halo: float = 0.0
var yar: float = 0.0
var gloom: float = 0.0
var prey: float = 0.0
var expose: float = 0.0
var steam_cd: float = 0.0
## Firestorm feed and firewind timers (seconds of burning since last trigger).
var feed_t: float = 0.0
var firewind_t: float = 0.0
## Words over the enemy: {text: String, god: String, t: float}. One per god.
var words: Array[Dictionary] = []
## Short effects: {kind: "bolt"|"burst"|"dry", t: float, to: Vector2 (world)}.
var fx: Array[Dictionary] = []
var _root_immune_len: float = 2.0
var _word_cd: Dictionary = {}

## Context used when there is no hero/build: no duos, base numbers.
static func default_ctx(tune: Dictionary) -> Dictionary:
	return { "shock_need": int(tune.get("shock_stacks", 3)), "jumps_bonus": 0, "root_mult": 1.0,
		"duos": {}, "mods": {} }

# ---------------- queries ----------------

func burning() -> bool:
	return burn > EPS

func cursed() -> bool:
	return curse > EPS

func rooted() -> bool:
	return root > EPS

## Any god status (for «Заточенный край», §3.6). Stun is not a god status.
func has_god_status() -> bool:
	return burning() or shock > 0 or cuts > 0 or cursed() or rooted() or wet > EPS or thread > EPS \
		or blind > EPS or halo > EPS or yar > EPS or gloom > EPS or prey > EPS or expose > EPS

func blinded() -> bool:
	return blind > EPS

## Sets one of the timer statuses of gods-expansion §3.2 to the longer of the
## old and `dur` (blind: nothing lands during its immunity). True if it landed.
func add_timer(st: String, dur: float) -> bool:
	if dur <= 0.0:
		return false
	if st == "blind" and blind_immune > EPS and blind <= EPS:
		return false
	set(st, maxf(float(get(st)), dur))
	return true

# ---------------- applying (§3.7 "Повторное наложение") ----------------

## Burning: the longer wins. Returns true when the enemy was not burning.
func add_burn(dur: float) -> bool:
	if dur <= 0.0:
		return false
	var fresh := not burning()
	burn = maxf(burn, dur)
	return fresh

## Curse: the longer wins. Returns true when the enemy was not cursed.
func add_curse(dur: float) -> bool:
	if dur <= 0.0:
		return false
	var fresh := not cursed()
	curse = maxf(curse, dur)
	return fresh

## Roots: the longer wins; nothing lands during immunity. `immune_len` is the
## immunity that starts when these roots end. Returns true if roots landed.
func add_root(dur: float, immune_len: float) -> bool:
	if dur <= 0.0 or immune > EPS:
		return false
	root = maxf(root, dur)
	_root_immune_len = immune_len
	return true

## Tears the roots off at once (Рвущий ветер); immunity starts.
func break_roots() -> void:
	if rooted():
		root = 0.0
		immune = _root_immune_len

## Cuts: +n up to `cap`; the shared timer is refreshed even at the cap.
## Returns how many cuts were really added.
func add_cuts(n: int, cap: int, time: float) -> int:
	if n <= 0:
		return 0
	var before := cuts
	cuts = mini(cap, cuts + n)
	cut_t = time
	return cuts - before

## Removes all cuts and returns how many there were (the burst, §3.9).
func take_cuts() -> int:
	var n := cuts
	cuts = 0
	cut_t = 0.0
	return n

## Charges: +n; at `need` the charges reset and true is returned (discharge now).
func add_shock(n: int, need: int) -> bool:
	if n <= 0:
		return false
	shock += n
	if shock >= maxi(need, 1):
		shock = 0
		return true
	return false

# ---------------- time ----------------

## Advances every timer by `dt`. Order (F6): statuses tick first (burning may
## end), then the firestorm feed. Returns {burn: damage of the burn ticks this
## step, feed: true = one fed charge now, firewind: true = spread fire now}.
func tick(dt: float, tune: Dictionary, ctx: Dictionary) -> Dictionary:
	var out := { "burn": 0.0, "feed": false, "firewind": false }
	var duos: Dictionary = ctx.get("duos", {})
	if burning():
		var step := minf(dt, burn)
		burn -= dt
		burn_tick += step
		var tick_len := float(tune.get("burn_tick", 0.25))
		while burn_tick >= tick_len - EPS:
			burn_tick -= tick_len
			out.burn += float(tune.get("burn_dps", 5.0)) * tick_len
	if not burning():
		burn = 0.0
		burn_tick = 0.0
	curse = maxf(0.0, curse - dt)
	for k: String in ["wet", "thread", "halo", "yar", "gloom", "prey", "expose"]:
		set(k, maxf(0.0, float(get(k)) - dt))
	steam_cd = maxf(0.0, steam_cd - dt)
	if blind > EPS:
		blind -= dt
		if blind <= EPS:
			blind = 0.0
			blind_immune = float(tune.get("blind_immune", 3.0))
	else:
		blind_immune = maxf(0.0, blind_immune - dt)
	if rooted():
		root -= dt
		if root <= EPS:
			root = 0.0
			immune = _root_immune_len
	else:
		immune = maxf(0.0, immune - dt)
	if cuts > 0:
		cut_t -= dt
		if cut_t <= EPS:
			cuts = 0
			cut_t = 0.0
	# Огненные корни: a rooted enemy burns for as long as the roots hold.
	if duos.has("duo_cleanse") and rooted():
		burn = maxf(burn, root)
	if duos.has("duo_firestorm") and burning():
		feed_t += dt
		var feed := float(tune.get("firestorm_feed", 1.0))
		if feed_t >= feed - EPS:
			feed_t -= feed
			out.feed = true
	else:
		feed_t = 0.0
	if duos.has("duo_firewind") and burning():
		firewind_t += dt
		var period := float((duos["duo_firewind"] as Dictionary).get("period", 1.0))
		if firewind_t >= period - EPS:
			firewind_t -= period
			out.firewind = true
	else:
		firewind_t = 0.0
	for k: String in _word_cd.keys():
		_word_cd[k] = float(_word_cd[k]) - dt
	for w: Dictionary in words:
		w.t -= dt
	words.assign(words.filter(func(w: Dictionary) -> bool: return w.t > 0.0))
	for f: Dictionary in fx:
		f.t -= dt
	fx.assign(fx.filter(func(f: Dictionary) -> bool: return f.t > 0.0))
	return out

# ---------------- words and effects (§3.14) ----------------

## Shows `text` in the god's colour. Without `always`, at most once per
## `cooldown` s per god (charges and cuts pass always = true, with their count).
func say(text: String, god: String, life: float, cooldown: float, always: bool = false) -> bool:
	if not always and float(_word_cd.get(god, 0.0)) > 0.0:
		return false
	words.assign(words.filter(func(w: Dictionary) -> bool: return w.god != god))
	words.append({ "text": text, "god": god, "t": life })
	_word_cd[god] = cooldown
	return true

## Adds a short effect (lightning bolt to `to`, burst splash, dry stems blink).
func add_fx(kind: String, life: float, to: Vector2 = Vector2.ZERO) -> void:
	fx.append({ "kind": kind, "t": life, "to": to })

# ---------------- pure rules ----------------

## §3.8 / F3: number of jumps of one discharge. A discharge fed by Огненная гроза
## never jumps (loop cap, §3.8 p.5).
static func discharge_jumps(ctx: Dictionary, fed: bool, origin_rooted: bool, extra: int, base: int) -> int:
	if fed:
		return 0
	var j := base + int(ctx.get("jumps_bonus", 0)) + extra
	if origin_rooted and (ctx.get("duos", {}) as Dictionary).has("duo_lifebolt"):
		j += int((ctx.duos["duo_lifebolt"] as Dictionary).get("jumps", 1))
	return j

## F3: damage of the discharge on chain member `index` (0 = the origin) before
## the target's multipliers. Чёрная молния doubles it on cursed targets.
static func discharge_dmg(shock_dmg: float, index: int, cursed_target: bool, black_mult: float, jump_mult: float) -> float:
	var d := shock_dmg * (1.0 if index == 0 else jump_mult)
	if cursed_target and black_mult > 0.0:
		d *= black_mult
	return d

## §3.8 p.3: indices of `points` hit by the chain from `origin`: each jump goes to
## the nearest not yet struck point within `r` of the last struck one.
static func chain(origin: Vector2, points: Array[Vector2], jumps: int, r: float) -> Array[int]:
	var out: Array[int] = []
	var cur := origin
	for j in jumps:
		var best := -1
		var best_d := r
		for i in points.size():
			if i in out:
				continue
			var d := cur.distance_to(points[i])
			if d <= best_d:
				best_d = d
				best = i
		if best < 0:
			break
		out.append(best)
		cur = points[best]
	return out

## F2: burst damage of `n` cuts with multiplier `k` (vow, Рвущий ветер).
static func burst_dmg(cut_burst: float, n: int, k: float) -> float:
	return cut_burst * float(n) * k

## F6: true when the firestorm loop sustains itself on one enemy.
static func loop_alive(stacks_needed: int, feed: float, burn_time: float, level_mult: float) -> bool:
	return float(stacks_needed) * feed < burn_time * level_mult
