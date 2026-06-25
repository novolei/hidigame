@tool
extends RefCounted

func run(ctx) -> void:
	var names: Array[String] = []
	var constants: Dictionary = {
		"LINEAR": Environment.TONE_MAPPER_LINEAR,
		"REINHARDT": Environment.TONE_MAPPER_REINHARDT,
		"FILMIC": Environment.TONE_MAPPER_FILMIC,
		"ACES": Environment.TONE_MAPPER_ACES,
		"AGX": Environment.TONE_MAPPER_AGX,
	}
	for key: String in constants.keys():
		names.append("%s=%s" % [key, str(constants[key])])
	names.sort()
	ctx.log(",".join(names))
