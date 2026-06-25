const fs = require("fs");
const path = require("path");

const repo = process.cwd();
const defaultSourceRoot = "H:\\3D Resource\\effect\\Party Monster Rumble PBR v1.0\\New Unity Project\\Assets\\PolygonApocalypse";
const sourceRoot = process.env.POLYGON_APOCALYPSE_SOURCE || defaultSourceRoot;
const assetRoot = path.join(repo, "assets", "unity_migrated", "polygon_apocalypse");
const outDir = path.join(assetRoot, "layouts");
const materialsOutDir = path.join(assetRoot, "materials");
const texturesOutDir = path.join(assetRoot, "Textures");
const rendererBoundsPath = process.env.POLYGON_APOCALYPSE_RENDERER_BOUNDS || path.join(repo, ".codex_compare", "polygon_apocalypse", "unity", "unity_renderer_bounds.json");
const UNITY_BUILTIN_MESH_GUID = "0000000000000000e000000000000000";
const UNITY_BUILTIN_DEFAULT_MATERIAL_GUID = "0000000000000000f000000000000000";

const sceneFiles = {
  building_interior_dressing: path.join(sourceRoot, "Scenes", "Demo_Building_Interior_Dressing.unity"),
  bunker: path.join(sourceRoot, "Scenes", "Demo_Bunker.unity"),
  city_standard: path.join(sourceRoot, "Scenes", "Demo_City_Standard.unity"),
  city_urp: path.join(sourceRoot, "Scenes", "Demo_City_Universal_RenderPipeline.unity"),
};

const identityTransform = {
  position: [0, 0, 0],
  rotation: [0, 0, 0, 1],
  scale: [1, 1, 1],
};

function walk(dir, result = []) {
  if (!fs.existsSync(dir)) return result;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, result);
    else result.push(full);
  }
  return result;
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function readGuid(metaPath) {
  const text = fs.readFileSync(metaPath, "utf8");
  const match = text.match(/^guid:\s*([a-f0-9]{32})/m);
  return match ? match[1] : "";
}

function buildGuidMap() {
  const map = {};
  for (const meta of walk(sourceRoot).filter((file) => file.endsWith(".meta"))) {
    const guid = readGuid(meta);
    if (!guid) continue;
    map[guid] = meta.slice(0, -5);
  }
  return map;
}

function blockId(block) {
  const match = block.match(/^--- !u!\d+ &(-?\d+)/m);
  return match ? match[1] : "";
}

function componentType(block) {
  const match = block.match(/^--- !u!(\d+) &/m);
  return match ? match[1] : "";
}

function firstNumber(block, regex, fallback = 0) {
  const match = block.match(regex);
  return match ? Number(match[1]) : fallback;
}

function vector3(block, key, fallback = [0, 0, 0]) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`${escaped}: \\{x: ([^,]+), y: ([^,]+), z: ([^}]+)\\}`);
  const match = block.match(re);
  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : fallback.slice();
}

function color(block, key, fallback = [1, 1, 1, 1]) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`${escaped}: \\{r: ([^,]+), g: ([^,]+), b: ([^,]+), a: ([^}]+)\\}`);
  const match = block.match(re);
  return match ? [Number(match[1]), Number(match[2]), Number(match[3]), Number(match[4])] : fallback.slice();
}

function quat(block, key, fallback = [0, 0, 0, 1]) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`${escaped}: \\{x: ([^,]+), y: ([^,]+), z: ([^,]+), w: ([^}]+)\\}`);
  const match = block.match(re);
  return match ? normalizeQuat([Number(match[1]), Number(match[2]), Number(match[3]), Number(match[4])]) : fallback.slice();
}

function parseGuidList(text) {
  return Array.from(text.matchAll(/guid:\s*([a-f0-9]{32})/g)).map((match) => match[1]);
}

function loadRendererBoundsByMap() {
  if (!fs.existsSync(rendererBoundsPath)) return {};
  const payload = JSON.parse(fs.readFileSync(rendererBoundsPath, "utf8").replace(/^\uFEFF/, ""));
  const result = {};
  for (const scene of payload.scenes || []) {
    const byPath = new Map();
    for (const renderer of scene.renderer_details || []) {
      const hierarchyPath = String(renderer.hierarchy_path || "");
      if (!hierarchyPath || !renderer.bounds) continue;
      if (!byPath.has(hierarchyPath)) byPath.set(hierarchyPath, []);
      byPath.get(hierarchyPath).push(renderer.bounds);
    }
    result[String(scene.map_id || "")] = byPath;
  }
  return result;
}

function normalizeQuat(q) {
  const length = Math.hypot(q[0], q[1], q[2], q[3]);
  if (!length) return [0, 0, 0, 1];
  return [q[0] / length, q[1] / length, q[2] / length, q[3] / length];
}

function multiplyQuat(a, b) {
  const [ax, ay, az, aw] = a;
  const [bx, by, bz, bw] = b;
  return normalizeQuat([
    aw * bx + ax * bw + ay * bz - az * by,
    aw * by - ax * bz + ay * bw + az * bx,
    aw * bz + ax * by - ay * bx + az * bw,
    aw * bw - ax * bx - ay * by - az * bz,
  ]);
}

function rotateVector(q, v) {
  const [x, y, z, w] = q;
  const uv = [
    y * v[2] - z * v[1],
    z * v[0] - x * v[2],
    x * v[1] - y * v[0],
  ];
  const uuv = [
    y * uv[2] - z * uv[1],
    z * uv[0] - x * uv[2],
    x * uv[1] - y * uv[0],
  ];
  return [
    v[0] + 2 * (w * uv[0] + uuv[0]),
    v[1] + 2 * (w * uv[1] + uuv[1]),
    v[2] + 2 * (w * uv[2] + uuv[2]),
  ];
}

function composeTransform(parent, local) {
  const scaled = [
    local.position[0] * parent.scale[0],
    local.position[1] * parent.scale[1],
    local.position[2] * parent.scale[2],
  ];
  const rotated = rotateVector(parent.rotation, scaled);
  return {
    position: [
      parent.position[0] + rotated[0],
      parent.position[1] + rotated[1],
      parent.position[2] + rotated[2],
    ],
    rotation: multiplyQuat(parent.rotation, local.rotation),
    scale: [
      parent.scale[0] * local.scale[0],
      parent.scale[1] * local.scale[1],
      parent.scale[2] * local.scale[2],
    ],
  };
}

function cloneTransform(transform) {
  return {
    position: transform.position.slice(),
    rotation: transform.rotation.slice(),
    scale: transform.scale.slice(),
  };
}

function sanitizeGodotFileName(name) {
  return name.replace(/[<>:"/\\|?*\x00-\x1f]/g, "_");
}

function toResGlb(assetPath) {
  const rel = path.relative(sourceRoot, assetPath).replace(/\\/g, "/");
  if (!rel.startsWith("Models/")) return "";
  const parsed = path.posix.parse(rel);
  return `res://assets/unity_migrated/polygon_apocalypse/${parsed.dir}/${parsed.name}.glb`;
}

function toOutputGlb(assetPath) {
  const rel = path.relative(sourceRoot, assetPath).replace(/\\/g, "/");
  const parsed = path.posix.parse(rel);
  return path.join(assetRoot, parsed.dir, `${parsed.name}.glb`);
}

function unityBuiltinMeshKind(fileId) {
  if (fileId === "10209") return "unity_plane_10";
  return "quad";
}

function toResTexture(assetPath) {
  const rel = path.relative(path.join(sourceRoot, "Textures"), assetPath).replace(/\\/g, "/");
  if (rel.startsWith("..")) return "";
  return `res://assets/unity_migrated/polygon_apocalypse/Textures/${rel}`;
}

function parseUnityFile(filePath, guidMap, rendererBoundsByPath = new Map()) {
  if (!fs.existsSync(filePath)) return { objects: [], lights: [], environment: {} };
  const text = fs.readFileSync(filePath, "utf8");
  const environment = parseRenderSettings(text);
  const blocks = text.split(/\n(?=--- !u!)/g);
  const gameObjects = {};
  const transforms = {};
  const meshFilters = {};
  const renderers = {};
  const lights = {};

  for (const block of blocks) {
    const id = blockId(block);
    if (!id) continue;
    const type = componentType(block);
    if (type === "1") {
      const name = (block.match(/m_Name:\s*(.*)/) || [null, ""])[1].trim();
      const active = firstNumber(block, /m_IsActive:\s*(-?\d+)/, 1) !== 0;
      gameObjects[id] = { name, active };
    } else if (type === "4") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const father = String(firstNumber(block, /m_Father: \{fileID: (-?\d+)\}/));
      transforms[id] = {
        gameObject,
        father: father === "0" ? "" : father,
        local: {
          position: vector3(block, "m_LocalPosition"),
          rotation: quat(block, "m_LocalRotation"),
          scale: vector3(block, "m_LocalScale", [1, 1, 1]),
        },
      };
    } else if (type === "33") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const match = block.match(/m_Mesh: \{fileID: (-?\d+), guid: ([a-f0-9]{32}), type: \d+\}/);
      if (match) meshFilters[gameObject] = { file_id: match[1], guid: match[2] };
    } else if (type === "23" || type === "137") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const materialSection = block.split("m_Materials:")[1] || "";
      renderers[gameObject] = {
        enabled: firstNumber(block, /m_Enabled:\s*(-?\d+)/, 1) !== 0,
        materials: parseGuidList(materialSection),
      };
      if (type === "137") {
        const match = block.match(/m_Mesh: \{fileID: (-?\d+), guid: ([a-f0-9]{32}), type: \d+\}/);
        if (match) meshFilters[gameObject] = { file_id: match[1], guid: match[2] };
      }
    } else if (type === "108") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      lights[gameObject] = {
        enabled: firstNumber(block, /m_Enabled:\s*(-?\d+)/, 1) !== 0,
        type: firstNumber(block, /m_Type:\s*(-?\d+)/, 2),
        color: color(block, "m_Color"),
        intensity: firstNumber(block, /m_Intensity:\s*([^\n]+)/, 1),
        range: firstNumber(block, /m_Range:\s*([^\n]+)/, 10),
        spot_angle: firstNumber(block, /m_SpotAngle:\s*([^\n]+)/, 30),
      };
    }
  }

  const worldCache = {};
  const localWorld = (transformId) => {
    if (!transforms[transformId]) return cloneTransform(identityTransform);
    if (worldCache[transformId]) return worldCache[transformId];
    const transform = transforms[transformId];
    const base = transform.father && transforms[transform.father] ? localWorld(transform.father) : identityTransform;
    worldCache[transformId] = composeTransform(base, transform.local);
    return worldCache[transformId];
  };

  const objects = [];
  const lightObjects = [];
  const activeCache = {};
  const isTransformActive = (transformId) => {
    if (!transforms[transformId]) return true;
    if (activeCache[transformId] !== undefined) return activeCache[transformId];
    const transform = transforms[transformId];
    const gameObject = gameObjects[transform.gameObject];
    const selfActive = gameObject ? gameObject.active : true;
    const parentActive = transform.father && transforms[transform.father] ? isTransformActive(transform.father) : true;
    activeCache[transformId] = selfActive && parentActive;
    return activeCache[transformId];
  };
  const hierarchyPath = (transformId) => {
    const names = [];
    let currentId = transformId;
    while (currentId && transforms[currentId]) {
      const transform = transforms[currentId];
      const gameObject = gameObjects[transform.gameObject];
      names.unshift(gameObject ? gameObject.name : "");
      currentId = transform.father || "";
    }
    return names.filter(Boolean).join("/");
  };

  for (const transformId of Object.keys(transforms)) {
    const transform = transforms[transformId];
    const gameObject = gameObjects[transform.gameObject] || { name: "" };
    if (!isTransformActive(transformId)) continue;

    const meshRef = meshFilters[transform.gameObject];
    const meshGuid = meshRef ? meshRef.guid : "";
    const renderer = renderers[transform.gameObject];
    if (meshGuid && renderer && renderer.enabled) {
      const assetPath = guidMap[meshGuid] || "";
      const glb = toResGlb(assetPath);
      if (glb || meshGuid === UNITY_BUILTIN_MESH_GUID) {
        const world = localWorld(transformId);
        const name = gameObject.name || (assetPath ? path.basename(assetPath, path.extname(assetPath)) : "UnityBuiltinQuad");
        const pathKey = hierarchyPath(transformId);
        const boundsQueue = rendererBoundsByPath.get(pathKey) || [];
        const unityBounds = boundsQueue.length ? boundsQueue.shift() : null;
        objects.push({
          name,
          hierarchy_path: pathKey,
          mesh_guid: meshGuid,
          mesh_file_id: meshRef ? meshRef.file_id : "",
          source_asset: assetPath.replace(/\\/g, "/"),
          scene: glb,
          builtin_mesh: glb ? "" : unityBuiltinMeshKind(meshRef ? meshRef.file_id : ""),
          material_guids: renderer.materials,
          position: world.position,
          rotation: world.rotation,
          scale: world.scale,
          transform_id: transformId,
          unity_bounds: unityBounds,
        });
      }
    }

    const light = lights[transform.gameObject];
    if (light && light.enabled) {
      const world = localWorld(transformId);
      lightObjects.push({
        name: gameObject.name || "UnityLight",
        type: light.type,
        color: light.color,
        intensity: light.intensity,
        range: light.range,
        spot_angle: light.spot_angle,
        position: world.position,
        rotation: world.rotation,
      });
    }
  }

  return { objects, lights: lightObjects, environment };
}

function parseRenderSettings(text) {
  return {
    ambient_mode: firstNumber(text, /m_AmbientMode:\s*(-?\d+)/, 0),
    ambient_intensity: firstNumber(text, /m_AmbientIntensity:\s*([^\n]+)/, 1),
    ambient_sky_color: color(text, "m_AmbientSkyColor", [0.212, 0.227, 0.259, 1]),
    ambient_equator_color: color(text, "m_AmbientEquatorColor", [0.114, 0.125, 0.133, 1]),
    ambient_ground_color: color(text, "m_AmbientGroundColor", [0.047, 0.043, 0.035, 1]),
    reflection_intensity: firstNumber(text, /m_ReflectionIntensity:\s*([^\n]+)/, 1),
    fog_enabled: firstNumber(text, /m_Fog:\s*(-?\d+)/, 0) !== 0,
    fog_color: color(text, "m_FogColor", [0.5, 0.5, 0.5, 1]),
    fog_density: firstNumber(text, /m_FogDensity:\s*([^\n]+)/, 0.01),
  };
}

function parseMaterial(matPath, guidMap) {
  const text = fs.readFileSync(matPath, "utf8");
  const name = (text.match(/m_Name:\s*(.*)/) || [null, path.basename(matPath, ".mat")])[1].trim();
  const shaderMatch = text.match(/m_Shader: \{fileID: -?\d+, guid: ([a-f0-9]{32}), type: \d+\}/);
  const shaderKeywordsMatch = text.match(/m_ShaderKeywords:\s*(.*)/);
  const mainTex = text.match(/- _MainTex:\s*\n\s*m_Texture: \{fileID: \d+, guid: ([a-f0-9]{32}), type: \d+\}/);
  const normalTex = text.match(/- _BumpMap:\s*\n\s*m_Texture: \{fileID: \d+, guid: ([a-f0-9]{32}), type: \d+\}/);
  const colorMatch = text.match(/- _Color: \{r: ([^,]+), g: ([^,]+), b: ([^,]+), a: ([^}]+)\}/);
  const emissionMatch = text.match(/- _EmissionColor: \{r: ([^,]+), g: ([^,]+), b: ([^,]+), a: ([^}]+)\}/);
  const metallicMatch = text.match(/- _Metallic:\s*([^\n]+)/);
  const glossMatch = text.match(/- _Glossiness:\s*([^\n]+)/);
  const modeMatch = text.match(/- _Mode:\s*([^\n]+)/);
  const cutoffMatch = text.match(/- _Cutoff:\s*([^\n]+)/);
  const cullMatch = text.match(/- _Cull:\s*([^\n]+)/);
  const distanceMatch = text.match(/- _Distance:\s*([^\n]+)/);
  const offsetMatch = text.match(/- _Offset:\s*([^\n]+)/);
  const falloffMatch = text.match(/- _Falloff:\s*([^\n]+)/);
  const meta = fs.existsSync(matPath + ".meta") ? readGuid(matPath + ".meta") : "";
  const unityCull = cullMatch ? Number(cullMatch[1]) : 2;
  return {
    guid: meta,
    name,
    shader_guid: shaderMatch ? shaderMatch[1] : "",
    shader_asset: shaderMatch && guidMap[shaderMatch[1]] ? guidMap[shaderMatch[1]] : "",
    shader_keywords: shaderKeywordsMatch ? shaderKeywordsMatch[1].trim() : "",
    main_texture_guid: mainTex ? mainTex[1] : "",
    main_texture: mainTex && guidMap[mainTex[1]] ? guidMap[mainTex[1]] : "",
    normal_texture_guid: normalTex ? normalTex[1] : "",
    normal_texture: normalTex && guidMap[normalTex[1]] ? guidMap[normalTex[1]] : "",
    color: colorMatch ? colorMatch.slice(1, 5).map(Number) : [1, 1, 1, 1],
    emission_color: emissionMatch ? emissionMatch.slice(1, 5).map(Number) : [0, 0, 0, 1],
    sky_color_top: color(text, "- _ColorTop", [1, 1, 1, 1]),
    sky_color_bottom: color(text, "- _ColorBottom", [1, 1, 1, 1]),
    sky_distance: distanceMatch ? Number(distanceMatch[1]) : 1,
    sky_offset: offsetMatch ? Number(offsetMatch[1]) : 0,
    sky_falloff: falloffMatch ? Number(falloffMatch[1]) : 1,
    metallic: metallicMatch ? Number(metallicMatch[1]) : 0,
    roughness: glossMatch ? Math.max(0, Math.min(1, 1 - Number(glossMatch[1]))) : 0.8,
    alpha_mode: modeMatch ? Number(modeMatch[1]) : 0,
    alpha_cutoff: cutoffMatch ? Number(cutoffMatch[1]) : 0.5,
    cull_mode: unityCull === 0 ? 2 : unityCull === 1 ? 1 : 0,
    source_asset: matPath.replace(/\\/g, "/"),
  };
}

function copyTextureIfNeeded(texturePath) {
  if (!texturePath || !fs.existsSync(texturePath)) return "";
  const resPath = toResTexture(texturePath);
  if (!resPath) return "";
  const rel = resPath.replace("res://assets/unity_migrated/polygon_apocalypse/Textures/", "");
  const out = path.join(texturesOutDir, rel);
  ensureDir(path.dirname(out));
  const sourceStat = fs.statSync(texturePath);
  if (fs.existsSync(out)) {
    const outputStat = fs.statSync(out);
    if (outputStat.size === sourceStat.size) {
      return resPath;
    }
  }
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      fs.copyFileSync(texturePath, out);
      return resPath;
    } catch (error) {
      if (fs.existsSync(out) && fs.statSync(out).size === sourceStat.size) {
        return resPath;
      }
      if (attempt === 3) throw error;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 150);
    }
  }
  return resPath;
}

function writeGodotMaterial(material) {
  if (!material.guid) return "";
  ensureDir(materialsOutDir);
  const fileName = `M_${sanitizeGodotFileName(material.name)}_${material.guid.slice(0, 8)}.tres`;
  const outPath = path.join(materialsOutDir, fileName);
  const resPath = `res://assets/unity_migrated/polygon_apocalypse/materials/${fileName}`;
  if (material.shader_asset.endsWith("SkyGradient.shader")) {
    writeSkyGradientMaterial(material, outPath);
    return resPath;
  }
  const albedoTexture = copyTextureIfNeeded(material.main_texture);
  const normalTexture = copyTextureIfNeeded(material.normal_texture);
  const ext = [];
  if (albedoTexture) ext.push(`[ext_resource type="Texture2D" path="${albedoTexture}" id="1_albedo"]`);
  if (normalTexture) ext.push(`[ext_resource type="Texture2D" path="${normalTexture}" id="2_normal"]`);
  const [r, g, b, a] = material.color;
  const lines = [
    `[gd_resource type="StandardMaterial3D" format=3]`,
    ...ext,
    ``,
    `[resource]`,
    `resource_name = "${material.name.replace(/"/g, "'")}"`,
    `albedo_color = Color(${r}, ${g}, ${b}, ${a})`,
    `metallic = ${Number.isFinite(material.metallic) ? material.metallic : 0}`,
    `roughness = ${Number.isFinite(material.roughness) ? material.roughness : 0.8}`,
    `cull_mode = ${Number.isFinite(material.cull_mode) ? material.cull_mode : 0}`,
  ];
  if (material.alpha_mode === 1) {
    lines.push(`transparency = 2`);
    lines.push(`alpha_scissor_threshold = ${Number.isFinite(material.alpha_cutoff) ? material.alpha_cutoff : 0.5}`);
  } else if (material.alpha_mode === 2 || material.alpha_mode === 3) {
    lines.push(`transparency = 1`);
  }
  if (albedoTexture) lines.push(`albedo_texture = ExtResource("1_albedo")`);
  if (normalTexture) {
    lines.push(`normal_enabled = true`);
    lines.push(`normal_texture = ExtResource("2_normal")`);
  }
  if (_unityUnlitEffectLike(material, albedoTexture)) {
    lines.push(`shading_mode = 0`);
    lines.push(`disable_receive_shadows = true`);
  }
  if (material.name.startsWith("PolygonApocalypse_Background_")) {
    lines.push(`shading_mode = 0`);
    lines.push(`disable_receive_shadows = true`);
  }
  if (_unityEmissionEnabled(material) && _hasVisibleEmission(material.emission_color)) {
    const [er, eg, eb, ea] = material.emission_color;
    lines.push(`emission_enabled = true`);
    lines.push(`emission = Color(${er}, ${eg}, ${eb}, ${ea})`);
    lines.push(`emission_energy_multiplier = ${_unityUnlitEffectLike(material, albedoTexture) ? 1.35 : 1.0}`);
  }
  fs.writeFileSync(outPath, lines.join("\n") + "\n", "utf8");
  return resPath;
}

function _hasVisibleEmission(value) {
  if (!Array.isArray(value) || value.length < 3) return false;
  return value[0] > 0.001 || value[1] > 0.001 || value[2] > 0.001;
}

function _unityEmissionEnabled(material) {
  return String(material.shader_keywords || "").split(/\s+/).includes("_EMISSION");
}

function _unityUnlitEffectLike(material, albedoTexture) {
  const keywords = String(material.shader_keywords || "").split(/\s+/);
  return !albedoTexture
    && _unityEmissionEnabled(material)
    && keywords.includes("_SPECULARHIGHLIGHTS_OFF")
    && keywords.includes("_GLOSSYREFLECTIONS_OFF");
}

function writeSkyGradientMaterial(material, outPath) {
  const shaderCode = [
    "shader_type spatial;",
    "render_mode unshaded, cull_back, depth_draw_opaque;",
    "",
    "uniform vec4 color_top : source_color;",
    "uniform vec4 color_bottom : source_color;",
    "uniform float offset = 0.0;",
    "uniform float distance = 1.0;",
    "uniform float falloff = 1.0;",
    "",
    "varying float world_y;",
    "",
    "void vertex() {",
    "    world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;",
    "}",
    "",
    "void fragment() {",
    "    float safe_distance = max(abs(distance), 0.001);",
    "    float factor = clamp((offset + world_y) / safe_distance, 0.0, 1.0);",
    "    factor = clamp(pow(factor, max(falloff, 0.001)), 0.0, 1.0);",
    "    vec4 sky_color = mix(color_bottom, color_top, factor);",
    "    ALBEDO = sky_color.rgb;",
    "    EMISSION = sky_color.rgb;",
    "    ALPHA = 1.0;",
    "    ROUGHNESS = 1.0;",
    "}",
  ].join("\n");
  const [tr, tg, tb, ta] = material.sky_color_top;
  const [br, bg, bb, ba] = material.sky_color_bottom;
  const lines = [
    `[gd_resource type="ShaderMaterial" load_steps=2 format=3]`,
    ``,
    `[sub_resource type="Shader" id="Shader_sky_gradient"]`,
    `code = ${JSON.stringify(shaderCode)}`,
    ``,
    `[resource]`,
    `resource_name = "${material.name.replace(/"/g, "'")}"`,
    `shader = SubResource("Shader_sky_gradient")`,
    `shader_parameter/color_top = Color(${tr}, ${tg}, ${tb}, ${ta})`,
    `shader_parameter/color_bottom = Color(${br}, ${bg}, ${bb}, ${ba})`,
    `shader_parameter/offset = ${Number.isFinite(material.sky_offset) ? material.sky_offset : 0}`,
    `shader_parameter/distance = ${Number.isFinite(material.sky_distance) ? material.sky_distance : 1}`,
    `shader_parameter/falloff = ${Number.isFinite(material.sky_falloff) ? material.sky_falloff : 1}`,
  ];
  fs.writeFileSync(outPath, lines.join("\n") + "\n", "utf8");
}

function writeBuiltinDefaultMaterial() {
  ensureDir(materialsOutDir);
  const fileName = "M_Unity_Builtin_Default.tres";
  const outPath = path.join(materialsOutDir, fileName);
  const resPath = `res://assets/unity_migrated/polygon_apocalypse/materials/${fileName}`;
  const lines = [
    `[gd_resource type="StandardMaterial3D" format=3]`,
    ``,
    `[resource]`,
    `resource_name = "Unity_Builtin_Default"`,
    `albedo_color = Color(0.5, 0.5, 0.5, 1.0)`,
    `metallic = 0.0`,
    `roughness = 0.8`,
    `cull_mode = 0`,
  ];
  fs.writeFileSync(outPath, lines.join("\n") + "\n", "utf8");
  return resPath;
}

function writeMaterials(guidMap) {
  const materialMap = {};
  const materialNameMap = {};
  const materialFiles = walk(path.join(sourceRoot, "Materials")).filter((file) => file.endsWith(".mat"));
  for (const matPath of materialFiles) {
    const material = parseMaterial(matPath, guidMap);
    const resPath = writeGodotMaterial(material);
    if (!material.guid || !resPath) continue;
    materialMap[material.guid] = resPath;
    materialNameMap[material.guid] = material.name;
  }
  materialMap[UNITY_BUILTIN_DEFAULT_MATERIAL_GUID] = writeBuiltinDefaultMaterial();
  materialNameMap[UNITY_BUILTIN_DEFAULT_MATERIAL_GUID] = "Unity_Builtin_Default";
  fs.writeFileSync(path.join(assetRoot, "material_guid_map.json"), JSON.stringify({
    generated_at: new Date().toISOString(),
    source_root: sourceRoot.replace(/\\/g, "/"),
    materials: materialMap,
    names: materialNameMap,
  }, null, 2));
  return { materialMap, materialNameMap };
}

function writeManifest(sceneSummaries, usedModelPaths) {
  const lines = [
    "# Polygon Apocalypse Migration Manifest",
    "",
    "Generated from the Unity asset pack under:",
    "",
    `- \`${sourceRoot.replace(/\\/g, "/")}\``,
    "",
    "Godot runtime entrypoints:",
    "",
    "- `res://scripts/polygon_apocalypse_map.gd`",
    "- `res://scenes/level/maps/polygon_apocalypse_bunker.tscn`",
    "- `res://scenes/level/maps/polygon_apocalypse_building_interior_dressing.tscn`",
    "- `res://scenes/level/maps/polygon_apocalypse_city_standard.tscn`",
    "- `res://scenes/level/maps/polygon_apocalypse_city_urp.tscn`",
    "",
    "Layouts:",
    "",
  ];
  for (const summary of sceneSummaries) {
    lines.push(`- \`${summary.layout}\`: ${summary.object_count} mesh objects, ${summary.light_count} lights`);
  }
  lines.push("");
  lines.push(`Referenced source FBX models: ${usedModelPaths.length}`);
  lines.push("");
  lines.push("Unity `.unity`, `.prefab`, and `.mat` files are not loaded directly by Godot. The layout JSON stores resolved mesh/material GUID references and the Godot map script rebuilds a static scene at runtime.");
  fs.writeFileSync(path.join(assetRoot, "MIGRATION_MANIFEST.md"), lines.join("\n") + "\n", "utf8");
}

function main() {
  ensureDir(outDir);
  ensureDir(assetRoot);
  const guidMap = buildGuidMap();
  const { materialNameMap } = writeMaterials(guidMap);
  const rendererBoundsByMap = loadRendererBoundsByMap();
  const usedModels = new Map();
  const sceneSummaries = [];

  for (const [mapId, scenePath] of Object.entries(sceneFiles)) {
    const parsed = parseUnityFile(scenePath, guidMap, rendererBoundsByMap[mapId] || new Map());
    for (const object of parsed.objects) {
      if (object.source_asset && object.scene) {
        usedModels.set(object.source_asset, {
          source: object.source_asset,
          output: toOutputGlb(object.source_asset).replace(/\\/g, "/"),
          res: object.scene,
        });
      }
    }
    const payload = {
      source: scenePath.replace(/\\/g, "/"),
      generated_at: new Date().toISOString(),
      object_count: parsed.objects.length,
      light_count: parsed.lights.length,
      material_guid_names: materialNameMap,
      environment: parsed.environment,
      objects: parsed.objects,
      lights: parsed.lights,
    };
    const layout = path.join(outDir, `${mapId}.json`);
    fs.writeFileSync(layout, JSON.stringify(payload, null, 2));
    sceneSummaries.push({ layout: `layouts/${mapId}.json`, object_count: parsed.objects.length, light_count: parsed.lights.length });
    console.log(`${mapId}: ${parsed.objects.length} mesh objects, ${parsed.lights.length} lights`);
  }

  const usedModelPaths = Array.from(usedModels.values()).sort((a, b) => a.source.localeCompare(b.source));
  fs.writeFileSync(path.join(assetRoot, "used_models.json"), JSON.stringify({
    generated_at: new Date().toISOString(),
    source_root: sourceRoot.replace(/\\/g, "/"),
    models: usedModelPaths,
  }, null, 2));
  writeManifest(sceneSummaries, usedModelPaths);
  console.log(`Used FBX models: ${usedModelPaths.length}`);
}

main();
