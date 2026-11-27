## Living grass, sedge and reeds on the floor tops of a room (vfx-spec §4.1):
## tufts sway in the wind, bend away from the hero and walking enemies, whip
## when a strike passes through them and lean with the frost gusts. Back tufts
## draw behind the actors, a few short front tufts over their feet (art-bible
## §6: the near layer never covers the centre). Visual only.
class_name VfxGrass
extends Node2D

const PUSH_R: float = 34.0
const ACTOR_DY: float = 26.0

## The "grass" block of a vfx.json world style.
var spec: Dictionary = {}
## World rect drawn and simulated (set by Vfx from the camera).
var view: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)
## [[feet position, velocity], ...] of things that push the grass.
var actors: Array = []
## Gust lean, radians (frost).
var gust: float = 0.0
var x: PackedFloat32Array = []
var y: PackedFloat32Array = []
var h: PackedFloat32Array = []
var nb: PackedInt32Array = []
var seed_k: PackedFloat32Array = []
var a: PackedFloat32Array = []
var av: PackedFloat32Array = []
var front: PackedByteArray = []
var _front_node: Node2D
var _t: float = 0.0

func _ready() -> void:
	z_index = -1
	_front_node = Node2D.new()
	_front_node.z_index = 1
	_front_node.z_as_relative = false
	_front_node.draw.connect(_draw_set.bind(true, _front_node))
	add_child(_front_node)

## Places tufts on the ground (minus solids standing on it), solid tops and
## one-way platform tops of `layout`.
func build(layout: Dictionary, ground: float) -> void:
	var w := float(layout.get("w", 2000.0))
	var spans: Array = []
	var cuts: Array = []
	for r: Rect2 in layout.get("solids", []):
		if r.end.y >= ground - 1.0 and r.position.y < ground:
			cuts.append(Vector2(r.position.x, r.end.x))
		spans.append(Vector3(r.position.x + 4.0, r.end.x - 4.0, r.position.y))
	for p: Vector3 in layout.get("plats", []):
		spans.append(Vector3(p.x + 6.0, p.x + p.z - 6.0, p.y))
	spans.push_front(Vector3(0.0, w, ground))
	var ev: Array = spec.get("every", [20, 40])
	var hh: Array = spec.get("h", [12, 28])
	var bl: Array = spec.get("blades", [3, 5])
	var k := 0
	for s: Vector3 in spans:
		var cx := s.x + 6.0
		while cx < s.y:
			k += 1
			var free := true
			if s.z == ground:
				for c: Vector2 in cuts:
					if cx > c.x - 4.0 and cx < c.y + 4.0:
						free = false
			if free:
				var fr := Room._h(k, 11) < float(spec.get("front_chance", 0.2))
				x.append(cx)
				y.append(s.z + 1.0)
				h.append(lerpf(float(hh[0]), float(hh[1]), Room._h(k, 12)) * (float(spec.get("front_h", 0.6)) if fr else 1.0))
				nb.append(int(lerpf(float(bl[0]), float(bl[1]) + 0.99, Room._h(k, 13))))
				seed_k.append(Room._h(k, 14))
				a.append(0.0)
				av.append(0.0)
				front.append(1 if fr else 0)
			cx += lerpf(float(ev[0]), float(ev[1]), Room._h(k, 15))

## A strike through `r` whips the tufts inside it towards `face`.
func slash(r: Rect2, face: int) -> void:
	var rr := r.grow(18.0)
	var s := float(spec.get("slash", 7.0))
	for i in x.size():
		if rr.has_point(Vector2(x[i], y[i] - 4.0)):
			av[i] += face * s * (0.6 + 0.4 * seed_k[i])

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_tick(dt)
	Vfx.cost_us += Time.get_ticks_usec() - t0

func _tick(dt: float) -> void:
	var fx := get_parent() as Vfx
	if fx and fx.fixed_dt > 0.0:
		dt = fx.fixed_dt
	_t += dt
	var stiff := float(spec.get("stiff", 55.0))
	var damp := float(spec.get("damp", 5.0))
	var push := float(spec.get("push", 0.9))
	var wind := float(spec.get("wind", 0.05))
	var x0 := view.position.x
	var x1 := view.end.x
	for i in x.size():
		var tx := x[i]
		if tx < x0 or tx > x1:
			continue
		var target := wind * sin(_t * 1.7 + tx * 0.013) + gust * (0.75 + 0.25 * sin(_t * 9.0 + tx * 0.05))
		for ac: Array in actors:
			var fp: Vector2 = ac[0]
			var d := tx - fp.x
			if absf(d) < PUSH_R and absf(fp.y - y[i]) < ACTOR_DY:
				var vx: float = (ac[1] as Vector2).x
				target += signf(d if d != 0.0 else vx) * (1.0 - absf(d) / PUSH_R) * push + clampf(vx * 0.0012, -0.4, 0.4)
		av[i] += (target - a[i]) * stiff * dt
		av[i] *= maxf(0.0, 1.0 - damp * dt)
		a[i] = clampf(a[i] + av[i] * dt, -1.3, 1.3)
	queue_redraw()
	_front_node.queue_redraw()

func _draw() -> void:
	_draw_set(false, self)

func _draw_set(fr: bool, on: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_draw_tufts(fr, on)
	Vfx.cost_us += Time.get_ticks_usec() - t0

func _draw_tufts(fr: bool, on: CanvasItem) -> void:
	var cols: Array = spec.get("col", ["#24392f", "#4d5f3a"])
	var c0 := Color(String(cols[0]))
	var c1 := Color(String(cols[1 if cols.size() > 1 else 0]))
	var tip := Color(String(spec.get("tip", "#7d9a7f")))
	var head_s := String(spec.get("head", ""))
	var head := Color(head_s) if head_s != "" else Color.TRANSPARENT
	var head_p := float(spec.get("head_chance", 0.0))
	var x0 := view.position.x
	var x1 := view.end.x
	for i in x.size():
		if (front[i] == 1) != fr or x[i] < x0 or x[i] > x1:
			continue
		var n := nb[i]
		var sk := seed_k[i]
		var base_c := c0.lerp(c1, sk)
		if fr:
			base_c = base_c.darkened(0.35)
		for b in n:
			var hb := Room._h(i * 7 + b, 21)
			var bx := x[i] + (b - (n - 1) * 0.5) * 3.0
			var lean := a[i] * (0.75 + 0.5 * hb) + (hb - 0.5) * 0.5
			var bh := h[i] * (0.55 + 0.45 * Room._h(i * 7 + b, 22))
			var root := Vector2(bx, y[i])
			var mid := root + Vector2(sin(lean * 0.4), -cos(lean * 0.4)) * bh * 0.5
			var top := mid + Vector2(sin(lean), -cos(lean)) * bh * 0.5
			on.draw_line(root, mid, base_c, 2.2, false)
			on.draw_line(mid, top, base_c.lerp(tip, 0.55), 1.5, false)
			if head.a > 0.0 and b == 0 and sk < head_p:
				on.draw_set_transform(top, lean, Vector2(0.45, 1.0))
				on.draw_circle(Vector2.ZERO, 4.0, head)
				on.draw_set_transform(Vector2.ZERO)
