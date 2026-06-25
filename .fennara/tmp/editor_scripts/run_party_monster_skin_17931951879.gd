@tool
extends RefCounted

func run(ctx) -> void:
	var paths: Array[String] = [
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_Albedo.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_Albedo.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Albedo01.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Albedo02.png",
	]
	for path: String in paths:
		var image: Image = Image.load_from_file(path)
		if image == null:
			ctx.error("failed_to_load=%s" % path)
			return
		var width: int = image.get_width()
		var height: int = image.get_height()
		var step_x: int = max(1, width / 64)
		var step_y: int = max(1, height / 64)
		var min_alpha: float = 1.0
		var max_alpha: float = 0.0
		var low_alpha_count: int = 0
		var sample_count: int = 0
		for y: int in range(0, height, step_y):
			for x: int in range(0, width, step_x):
				var pixel: Color = image.get_pixel(x, y)
				min_alpha = minf(min_alpha, pixel.a)
				max_alpha = maxf(max_alpha, pixel.a)
				if pixel.a < 0.98:
					low_alpha_count += 1
				sample_count += 1
		ctx.log("path=%s size=%dx%d detect_alpha=%d sampled_min_a=%.3f sampled_max_a=%.3f low_alpha_samples=%d/%d" % [path, width, height, image.detect_alpha(), min_alpha, max_alpha, low_alpha_count, sample_count])
