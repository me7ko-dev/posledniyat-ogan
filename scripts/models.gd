extends RefCounted
## Моделите на Kenney (CC0): Survival Kit (предмети) и Mini Characters (човечета).
## Тук е и монетата, която е проста фигура.

const PROP_SCALE := 2.2  # предметите от Survival Kit са малки — уголемяваме ги
const CHAR_SCALE := 2.0  # човечетата от Mini Characters
const CHARACTERS := [
	"character-male-a", "character-male-b", "character-male-c", "character-male-d",
	"character-male-e", "character-male-f", "character-female-a", "character-female-b",
	"character-female-c", "character-female-d", "character-female-e", "character-female-f",
]

static var _coin_mesh: CylinderMesh


static func prop(model: String, extra := 1.0) -> Node3D:
	var n: Node3D = load("res://models/survival/%s.glb" % model).instantiate()
	n.scale = Vector3.ONE * PROP_SCALE * extra
	return n


static func character(model: String) -> Node3D:
	var n: Node3D = load("res://models/characters/%s.glb" % model).instantiate()
	n.scale = Vector3.ONE * CHAR_SCALE
	return n


static func coin() -> MeshInstance3D:
	if _coin_mesh == null:
		_coin_mesh = CylinderMesh.new()
		_coin_mesh.top_radius = 0.16
		_coin_mesh.bottom_radius = 0.16
		_coin_mesh.height = 0.05
		_coin_mesh.radial_segments = 16
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#f5c542")
		m.metallic = 0.6
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color("#7a5a10")
		_coin_mesh.material = m
	var c := MeshInstance3D.new()
	c.mesh = _coin_mesh
	return c


## Мека кръгла точка — за пламъци, искри и сняг.
static func soft_dot(px := 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


static func unshaded(color: Color, billboard := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m
