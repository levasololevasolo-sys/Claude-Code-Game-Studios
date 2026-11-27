## Fixed-size particle pool for the hit / death / spawn effects (vfx-spec §2).
## Struct-of-arrays, no nodes per particle: add() writes a free slot (or, when
## full, the oldest one), step() moves everything. Drops that reach their floor
## turn into short floor splats (capped by splat_cap, the oldest go first);
## shards bounce once and lie. Drawing is VfxLayer's job; this is pure data, so
## tests drive it tick by tick.
class_name VfxPool
extends RefCounted

enum Shape { DROP, STREAK, SHARD, MIST, FLASH, RING, SPLAT, EMBER, RIPPLE }

const F_SPLAT: int = 1
const F_LANDED: int = 2

var cap: int = 0
var splat_cap: int = 0
var splat_life: float = 2.2
var pos: PackedVector2Array = []
var vel: PackedVector2Array = []
## Seconds left; <= 0 = free slot.
var life: PackedFloat32Array = []
var life0: PackedFloat32Array = []
var size: PackedFloat32Array = []
var size_end: PackedFloat32Array = []
var col: PackedColorArray = []
var col_end: PackedColorArray = []
var shape: PackedInt32Array = []
var grav: PackedFloat32Array = []
var drag: PackedFloat32Array = []
var floor_y: PackedFloat32Array = []
var bounce: PackedFloat32Array = []
var rot: PackedFloat32Array = []
var spin: PackedFloat32Array = []
## Streak length (s of travel) or shard aspect.
var lenk: PackedFloat32Array = []
var flags: PackedInt32Array = []
var _next: int = 0
var _alive: int = 0
var _splats: Array[int] = []

func _init(p_cap: int, p_splat_cap: int = 0) -> void:
	cap = maxi(p_cap, 1)
	splat_cap = maxi(p_splat_cap, 0)
	pos.resize(cap)
	vel.resize(cap)
	life.resize(cap)
	life0.resize(cap)
	size.resize(cap)
	size_end.resize(cap)
	col.resize(cap)
	col_end.resize(cap)
	shape.resize(cap)
	grav.resize(cap)
	drag.resize(cap)
	floor_y.resize(cap)
	bounce.resize(cap)
	rot.resize(cap)
	spin.resize(cap)
	lenk.resize(cap)
	flags.resize(cap)

## Live particles right now.
func alive() -> int:
	return _alive

## Live floor splats right now.
func splats() -> int:
	return _splats.size()

## Adds one particle; returns its slot. When the pool is full the oldest slot
## is reused, so a pool never holds more than `cap`.
func add(p_shape: int, p: Vector2, v: Vector2, p_life: float, p_size: float, c: Color, opts: Dictionary = {}) -> int:
	var i := _free_slot()
	if life[i] <= 0.0:
		_alive += 1
	elif shape[i] == Shape.SPLAT:
		_splats.erase(i)
	shape[i] = p_shape
	pos[i] = p
	vel[i] = v
	life[i] = maxf(p_life, 0.001)
	life0[i] = life[i]
	size[i] = p_size
	size_end[i] = float(opts.get("size_end", 1.0))
	col[i] = c
	col_end[i] = opts.get("col_end", Color(c, 0.0)) as Color
	grav[i] = float(opts.get("grav", 0.0))
	drag[i] = float(opts.get("drag", 0.0))
	floor_y[i] = float(opts.get("floor_y", INF))
	bounce[i] = float(opts.get("bounce", 0.0))
	rot[i] = float(opts.get("rot", 0.0))
	spin[i] = float(opts.get("spin", 0.0))
	lenk[i] = float(opts.get("len", 1.0))
	flags[i] = F_SPLAT if bool(opts.get("splat", false)) else 0
	if p_shape == Shape.SPLAT:
		_track_splat(i)
	return i

func _free_slot() -> int:
	for k in cap:
		var i := (_next + k) % cap
		if life[i] <= 0.0:
			_next = (i + 1) % cap
			return i
	var j := _next
	_next = (_next + 1) % cap
	return j

func _track_splat(i: int) -> void:
	_splats.append(i)
	while splat_cap > 0 and _splats.size() > splat_cap:
		var old: int = _splats.pop_front()
		if life[old] > 0.0:
			life[old] = 0.0
			_alive -= 1
	if splat_cap == 0:
		_splats.erase(i)
		life[i] = 0.0
		_alive -= 1

## Moves every live particle by dt: gravity, drag, spin, floor contact, ageing.
func step(dt: float) -> void:
	if _alive <= 0:
		return
	for i in cap:
		if life[i] <= 0.0:
			continue
		life[i] -= dt
		if life[i] <= 0.0:
			_kill(i)
			continue
		var s := shape[i]
		if s == Shape.SPLAT or (flags[i] & F_LANDED) != 0:
			continue
		var v := vel[i]
		v.y += grav[i] * dt
		v *= maxf(0.0, 1.0 - drag[i] * dt)
		var p := pos[i] + v * dt
		rot[i] += spin[i] * dt
		if p.y >= floor_y[i] and v.y > 0.0:
			p.y = floor_y[i]
			if (flags[i] & F_SPLAT) != 0:
				_to_splat(i, p, v)
				continue
			if bounce[i] > 0.0 and absf(v.y) > 60.0:
				v = Vector2(v.x * 0.5, -v.y * bounce[i])
				spin[i] *= 0.5
			elif s == Shape.SHARD or s == Shape.DROP:
				v = Vector2.ZERO
				spin[i] = 0.0
				flags[i] |= F_LANDED
				life[i] = minf(life[i] + 0.6, life0[i])
		vel[i] = v
		pos[i] = p

func _to_splat(i: int, p: Vector2, v: Vector2) -> void:
	shape[i] = Shape.SPLAT
	pos[i] = p
	vel[i] = Vector2.ZERO
	# Wider for a faster drop, flattened on the floor.
	size[i] = size[i] * (1.4 + clampf(v.length() / 600.0, 0.0, 1.2))
	size_end[i] = 1.25
	life[i] = splat_life
	life0[i] = splat_life
	col_end[i] = Color(col[i], 0.0)
	_track_splat(i)

func _kill(i: int) -> void:
	life[i] = 0.0
	_alive -= 1
	if shape[i] == Shape.SPLAT:
		_splats.erase(i)

## Age 0..1 of slot i (0 = just born).
func age(i: int) -> float:
	return 1.0 - life[i] / life0[i]

## Frees every particle.
func clear() -> void:
	for i in cap:
		life[i] = 0.0
	_alive = 0
	_splats.clear()
