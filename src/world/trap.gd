## A secret-pocket trap (GDD room-generation-and-doors §3.10): spikes rise from
## the floor, a log drops from the ceiling. Cycle idle -> warn (>= 0.5 s: glow)
## -> active (hurts the hero in its strip) -> idle. Numbers in tuning (trap_*).
class_name Trap
extends Node2D

var world: World
var kind: String = "spikes"
## Strip width px; position = left end on the floor.
var width: float = 80.0
var phase: String = "idle"
var t: float = 0.0
## Seconds into the cycle at start (traps of one pocket are out of step).
var offset: float = 0.0
var _hit: bool = false

func _ready() -> void:
	t = Tune.f("trap_idle") - offset
	if kind == "thorns":
		phase = "active"
		t = 0.0

## Advances the cycle by dt; returns the phase (pure; tests drive it).
func step(dt: float) -> String:
	if kind == "thorns":
		# Level thorns `^` (level-structure §3.2): always out, hurt again every thorn_cd.
		t -= dt
		if t <= 0.0 and _hit:
			_hit = false
		return phase
	t -= dt
	if t <= 0.0:
		match phase:
			"idle":
				phase = "warn"
				t += Tune.f("trap_warn")
			"warn":
				phase = "active"
				_hit = false
				t += Tune.f("trap_active")
			_:
				phase = "idle"
				t += Tune.f("trap_idle")
	return phase

func _physics_process(dt: float) -> void:
	step(dt)
	var p := world.player if world else null
	if phase == "active" and not _hit and p and is_instance_valid(p) and not p.dead:
		var reach := 50.0 if kind == "spikes" else 150.0
		if p.position.x > position.x - Player.W / 2.0 and p.position.x < position.x + width + Player.W / 2.0 \
				and p.position.y > position.y - reach and p.position.y <= position.y + 4.0:
			_hit = true
			if kind == "thorns":
				t = float((Tune.data.get("level", {}) as Dictionary).get("thorn_cd", 0.6))
				p.hurt(Hit.make(Hit.Kind.CONTACT, float((Tune.data.get("level", {}) as Dictionary).get("thorn_dmg", 10)), position.x + width / 2.0, 0.0))
				return
			p.hurt(Hit.make(Hit.Kind.CONTACT, Tune.f("trap_dmg") if kind == "spikes" else Tune.f("log_dmg"), position.x + width / 2.0, 0.0))
	queue_redraw()

func _draw() -> void:
	if kind == "thorns":
		var n := int(width / 14.0)
		for i in n:
			var x := i * 14.0 + 1.0
			var hgt := 22.0 + Room._h(i, int(position.x)) * 14.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 6, -hgt), Vector2(x + 13, 0)]), Color("#3b2a22"))
			draw_line(Vector2(x + 6, -hgt), Vector2(x + 6, -hgt * 0.5), Color("#c9b38a", 0.7), 1.5)
		return
	var warn := Color(1.0, 0.85, 0.3, 0.5 + 0.4 * sin(t * 30.0))
	if kind == "spikes":
		var up := 34.0 if phase == "active" else (8.0 if phase == "warn" else 3.0)
		var n := int(width / 16.0)
		for i in n:
			var x := i * 16.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 8, -up), Vector2(x + 16, 0)]), Color("#b9c2c9"))
		if phase == "warn":
			draw_rect(Rect2(0, -4, width, 4), warn)
	else:
		var y := -150.0 if phase != "active" else -150.0 + minf(1.0, (Tune.f("trap_active") - t) / 0.15) * 110.0
		draw_line(Vector2(width / 2.0, -200), Vector2(width / 2.0, y), Color("#6b5a3a"), 2.0)
		draw_rect(Rect2(0, y, width, 36), Color("#6b4524"))
		if phase == "warn":
			draw_rect(Rect2(0, y, width, 36), warn, false, 3.0)
			draw_rect(Rect2(0, -6, width, 6), Color(warn, 0.4))
