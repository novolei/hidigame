@tool
extends RefCounted

func run(ctx) -> void:
	var paths: Array[String] = [
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_Albedo.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_Albedo.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Albedo01.png",
		"res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set01_Mask01.png"
	]
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			ctx.log("texture_missing=%s" % path)
			continue
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			ctx.log("image_empty=%s" % path)
			continue
		if image.is_compressed():
			var decompress_result: int = image.decompress()
			if decompress_result != OK:
				ctx.log("image_compressed_unreadable=%s result=%d" % [path.get_file(), decompress_result])
				continue
		var size: Vector2i = image.get_size()
		var center: Color = image.get_pixel(int(float(size.x) * 0.5), int(float(size.y) * 0.5))
		var accum: Vector3 = Vector3.ZERO
		var samples: int = 0
		var step_y: int = max(1, int(float(size.y) / 8.0))
		var step_x: int = max(1, int(float(size.x) / 8.0))
		for y: int in range(0, size.y, step_y):
			for x: int in range(0, size.x, step_x):
				var pixel: Color = image.get_pixel(x, y)
				accum += Vector3(pixel.r, pixel.g, pixel.b)
				samples += 1
		var mean: Vector3 = accum / float(max(samples, 1))
		ctx.log("texture=%s size=%s center=(%.3f,%.3f,%.3f) mean=(%.3f,%.3f,%.3f)" % [path.get_file(), str(size), center.r, center.g, center.b, mean.x, mean.y, mean.z])
