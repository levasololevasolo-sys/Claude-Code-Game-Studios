## Снежница's frost needle (GDD bestiary §3.4 card 4, B5): an EnemyShot drawn as
## an ice needle. A needle that hurts the hero gives a frost mark (Snezhnitsa
## hooks Player.hurt_taken); one that reaches him during his hurt i-frames
## still sticks: no damage, but +1 mark (so a full volley of 3 can freeze him).
## A dash, a parry (reflect) or the freeze guard stop the mark.
class_name FrostNeedle
extends EnemyShot

func step(dt: float) -> void:
	super.step(dt)
	if reflected or life <= 0.0 or world == null:
		return
	var p: Player = world.player
	if p == null or p.dead or p.inv <= 0.0 or p.dash_t > 0.0 or p.parrying():
		return
	var pc := p.position - Vector2(0, Player.H / 2.0)
	if position.distance_to(pc) < r + Tune.f("shot_hit_r"):
		p.add_frost()
		life = 0.0

## Drawn needle sprite (DrawnEnemyVisual.fx "snezhnitsa"/"needle"), {} = code lines.
var _sprite: Dictionary = {}
var _sprite_checked: bool = false

func _draw() -> void:
	var d := vel.normalized() if vel != Vector2.ZERO else Vector2.RIGHT
	if not _sprite_checked:
		_sprite_checked = true
		_sprite = DrawnEnemyVisual.fx("snezhnitsa", "needle")
	if not _sprite.is_empty():
		draw_circle(Vector2.ZERO, r * 2.5, Color(color, 0.2))
		draw_set_transform(Vector2.ZERO, d.angle(), Vector2.ONE * float(_sprite.scale))
		draw_texture(_sprite.tex, -(_sprite.origin as Vector2))
		draw_set_transform(Vector2.ZERO)
		return
	draw_circle(Vector2.ZERO, r * 3.0, Color(color, 0.25))
	draw_line(-d * 26.0, d * 10.0, Color("#2c3b52"), 7.0)
	draw_line(-d * 24.0, d * 9.0, color, 4.0)
	draw_line(-d * 6.0, d * 11.0, Color.WHITE, 2.5)
