@tool
extends RefCounted

func run(ctx) -> void:
	var paths: Array[String] = [
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_MetallicSmoothness.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_MetallicSmoothness.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_AO.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_AO.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/SAM01.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/SAM02.png",
	]
	for path: String in paths:
		var image: Image = Image.load_from_file(path)
		if image == null:
			ctx.error("failed_to_load=%s" % path)
			return
		var width: int = image.get_width()
		var height: int = image.get_height()
		var step_x: int = maxi(1, int(width / 64))
		var step_y: int = maxi(1, int(height / 64))
		var min_rgba: Color = Color(1.0, 1.0, 1.0, 1.0)
		var max_rgba: Color = Color(0.0, 0.0, 0.0, 0.0)
		var sum_rgba: Color = Color(0.0, 0.0, 0.0, 0.0)
		var sample_count: int = 0
		for y: int in range(0, height, step_y):
			for x: int in range(0, width, step_x):
				var p: Color = image.get_pixel(x, y)
				min_rgba.r = minf(min_rgba.r, p.r)
				min_rgba.g = minf(min_rgba.g, p.g)
				min_rgba.b = minf(min_rgba.b, p.b)
				min_rgba.a = minf(min_rgba.a, p.a)
				max_rgba.r = maxf(max_rgba.r, p.r)
				max_rgba.g = maxf(max_rgba.g, p.g)
				max_rgba.b = maxf(max_rgba.b, p.b)
				max_rgba.a = maxf(max_rgba.a, p.a)
				sum_rgba += p
				sample_count += 1
		var mean_rgba: Color = sum_rgba / float(sample_count)
		ctx.log("path=%s alpha=%d min=%s max=%s mean=%s" % [path, image.detect_alpha(), str(min_rgba), str(max_rgba), str(mean_rgba)])
