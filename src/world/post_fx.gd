## Full-screen post-processing layer (visual-upgrade-plan §2.4, §2.6): bloom,
## grading, vignette and grain from assets/shaders/post_fx.gdshader, set from the
## "post" block of a visuals.json style. Sits above the world and below the HUD.
class_name PostFx
extends CanvasLayer

const SHADER_PATH: String = "res://assets/shaders/post_fx.gdshader"
const LAYER: int = 1

## Builds the layer for one visuals.json "post" block.
static func make(post: Dictionary) -> PostFx:
	var l := PostFx.new()
	l.layer = LAYER
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH) as Shader
	m.set_shader_parameter("vignette", float(post.get("vignette", 0.3)))
	m.set_shader_parameter("vignette_col", Color(String(post.get("vignette_col", "#070a14"))))
	m.set_shader_parameter("shadow_tint", Color(String(post.get("shadow", "#1a2a50"))))
	m.set_shader_parameter("light_tint", Color(String(post.get("light", "#ffd8a0"))))
	m.set_shader_parameter("sat", float(post.get("sat", 0.95)))
	m.set_shader_parameter("glow_thr", float(post.get("glow_thr", 0.65)))
	m.set_shader_parameter("glow", float(post.get("glow", 0.7)))
	m.set_shader_parameter("grain", float(post.get("grain", 0.035)))
	r.material = m
	l.add_child(r)
	return l
