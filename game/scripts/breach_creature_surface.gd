extends RefCounted

# Fine skin relief supplements the mesh; no new bitmap or replacement of the original skin.
# Applied to the Breach's existing duplicated material, so wound tint still owns emission.
static func apply(material: StandardMaterial3D) -> void:
	var pores := FastNoiseLite.new()
	pores.seed = 12
	pores.frequency = 0.16
	pores.fractal_octaves = 3
	var normal := NoiseTexture2D.new()
	normal.width = 512
	normal.height = 512
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 0.35
	normal.noise = pores
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = 0.35
	var patches := FastNoiseLite.new()
	patches.seed = 47
	patches.frequency = 0.035
	patches.fractal_octaves = 2
	var rough := NoiseTexture2D.new()
	rough.width = 256
	rough.height = 256
	rough.seamless = true
	rough.noise = patches
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.45, 0.45))
	ramp.set_color(1, Color(0.95, 0.95, 0.95))
	rough.color_ramp = ramp
	material.roughness_texture = rough
	material.roughness = 0.72
	material.metallic_specular = 0.55
