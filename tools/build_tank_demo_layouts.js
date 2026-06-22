const fs = require("fs");
const path = require("path");

const repo = process.cwd();
const sourceRoot = "C:\\Users\\aresr\\Tanks Complete Project\\Assets\\_Tanks";
const outDir = path.join(repo, "assets", "unity_migrated", "tanks_complete", "layouts");

const levelFiles = {
  desert: path.join(repo, "assets", "unity_migrated", "tanks_complete", "Prefabs", "Levels", "LevelDesert.prefab"),
  jungle: path.join(repo, "assets", "unity_migrated", "tanks_complete", "Prefabs", "Levels", "LevelJungle.prefab"),
  moon: path.join(repo, "assets", "unity_migrated", "tanks_complete", "Prefabs", "Levels", "LevelMoon.prefab"),
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

function readGuid(metaPath) {
  const text = fs.readFileSync(metaPath, "utf8");
  const match = text.match(/^guid:\s*([a-f0-9]+)/m);
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

function toResGlb(assetPath) {
  const rel = path.relative(sourceRoot, assetPath).replace(/\\/g, "/");
  if (!rel.startsWith("Art/Models/")) return "";
  const parsed = path.posix.parse(rel);
  return `res://assets/unity_migrated/tanks_complete/${parsed.dir}/${parsed.name}.glb`;
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

function quat(block, key, fallback = [0, 0, 0, 1]) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`${escaped}: \\{x: ([^,]+), y: ([^,]+), z: ([^,]+), w: ([^}]+)\\}`);
  const match = block.match(re);
  return match ? normalizeQuat([Number(match[1]), Number(match[2]), Number(match[3]), Number(match[4])]) : fallback.slice();
}

function parseGuidList(text) {
  return Array.from(text.matchAll(/guid:\s*([a-f0-9]{32})/g)).map((match) => match[1]);
}

function parseModificationBlocks(block) {
  const overrides = {};
  const re = /- target: \{fileID: (-?\d+), guid: ([a-f0-9]{32}), type: \d+\}\s+propertyPath: ([^\n]+)\s+value: ([^\n]*)\s+objectReference: \{fileID: (-?\d+), guid: ([a-f0-9]*), type: \d+\}/g;
  for (const match of block.matchAll(re)) {
    const target = match[1];
    const property = match[3].trim();
    const rawValue = match[4].trim();
    const objectGuid = match[6].trim();
    if (!overrides[target]) overrides[target] = {};
    const materialMatch = property.match(/^'?m_Materials\.Array\.data\[(\d+)\]'?$/);
    if (materialMatch && objectGuid) {
      if (!overrides[target].materials) overrides[target].materials = [];
      overrides[target].materials[Number(materialMatch[1])] = objectGuid;
      continue;
    }
    if (property === "m_Name") {
      overrides[target].name = rawValue;
      continue;
    }
    const value = Number(rawValue);
    if (!Number.isFinite(value)) continue;
    const vectorMatch = property.match(/^m_Local(Position|Rotation|Scale)\.([xyzw])$/);
    if (!vectorMatch) continue;
    const kind = vectorMatch[1].toLowerCase();
    const axis = vectorMatch[2];
    const key = kind === "position" ? "position" : kind === "rotation" ? "rotation" : "scale";
    if (!overrides[target][key]) {
      overrides[target][key] = key === "rotation" ? [0, 0, 0, 1] : key === "scale" ? [1, 1, 1] : [0, 0, 0];
    }
    const index = { x: 0, y: 1, z: 2, w: 3 }[axis];
    overrides[target][key][index] = value;
  }
  for (const target of Object.keys(overrides)) {
    if (overrides[target].rotation) overrides[target].rotation = normalizeQuat(overrides[target].rotation);
  }
  return overrides;
}

function applyOverride(base, override) {
  if (!override) return cloneTransform(base);
  return {
    position: override.position ? override.position.slice() : base.position.slice(),
    rotation: override.rotation ? normalizeQuat(override.rotation) : base.rotation.slice(),
    scale: override.scale ? override.scale.slice() : base.scale.slice(),
  };
}

function mergeOverrides(a, b) {
  const merged = {};
  for (const key of Object.keys(a || {})) merged[key] = { ...a[key] };
  for (const key of Object.keys(b || {})) merged[key] = { ...(merged[key] || {}), ...b[key] };
  return merged;
}

function cloneTransform(transform) {
  return {
    position: transform.position.slice(),
    rotation: transform.rotation.slice(),
    scale: transform.scale.slice(),
  };
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

function parsePrefab(prefabPath, guidMap, options = {}) {
  if (!prefabPath || !fs.existsSync(prefabPath)) return [];
  const parentTransform = options.parentTransform || identityTransform;
  const passedOverrides = options.overrides || {};
  const depth = options.depth || 0;
  if (depth > 8) return [];

  const text = fs.readFileSync(prefabPath, "utf8");
  const blocks = text.split(/\n(?=--- !u!)/g);
  const gameObjects = {};
  const transforms = {};
  const meshFilters = {};
  const renderers = {};
  const prefabInstances = [];

  for (const block of blocks) {
    const id = blockId(block);
    if (!id) continue;
    const type = componentType(block);
    if (type === "1") {
      const name = (block.match(/m_Name:\s*(.*)/) || [null, ""])[1].trim();
      gameObjects[id] = { name };
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
      const match = block.match(/m_Mesh: \{fileID: \d+, guid: ([a-f0-9]{32}), type: \d+\}/);
      if (match) meshFilters[gameObject] = match[1];
    } else if (type === "23") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const materialSection = block.split("m_Materials:")[1] || "";
      renderers[gameObject] = {
        id,
        materials: parseGuidList(materialSection),
      };
    } else if (type === "1001") {
      const source = block.match(/m_SourcePrefab: \{fileID: \d+, guid: ([a-f0-9]{32}), type: \d+\}/);
      if (!source) continue;
      const parent = String(firstNumber(block, /m_TransformParent: \{fileID: (-?\d+)\}/));
      prefabInstances.push({
        sourceGuid: source[1],
        parentTransformId: parent === "0" ? "" : parent,
        overrides: parseModificationBlocks(block),
      });
    }
  }

  for (const id of Object.keys(transforms)) {
    transforms[id].local = applyOverride(transforms[id].local, passedOverrides[id]);
  }
  for (const id of Object.keys(gameObjects)) {
    if (passedOverrides[id] && passedOverrides[id].name) gameObjects[id].name = passedOverrides[id].name;
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
  for (const transformId of Object.keys(transforms)) {
    const transform = transforms[transformId];
    const meshGuid = meshFilters[transform.gameObject];
    if (!meshGuid) continue;
    const assetPath = guidMap[meshGuid] || "";
    const glb = toResGlb(assetPath);
    if (!glb) continue;
    const world = composeTransform(parentTransform, localWorld(transformId));
    const name = (gameObjects[transform.gameObject] && gameObjects[transform.gameObject].name) || path.basename(assetPath, path.extname(assetPath));
    const renderer = renderers[transform.gameObject] || { id: "", materials: [] };
    const materialOverride = renderer.id && passedOverrides[renderer.id] && passedOverrides[renderer.id].materials
      ? passedOverrides[renderer.id].materials
      : [];
    objects.push({
      name,
      mesh_guid: meshGuid,
      source_asset: assetPath.replace(/\\/g, "/"),
      scene: glb,
      material_guids: materialOverride.length ? materialOverride : renderer.materials,
      position: world.position,
      rotation: world.rotation,
      scale: world.scale,
      prefab_source: prefabPath.replace(/\\/g, "/"),
      transform_id: transformId,
    });
  }

  for (const instance of prefabInstances) {
    const sourceAsset = guidMap[instance.sourceGuid] || "";
    const instanceParent = instance.parentTransformId && transforms[instance.parentTransformId]
      ? composeTransform(parentTransform, localWorld(instance.parentTransformId))
      : parentTransform;
    if (sourceAsset.endsWith(".prefab")) {
      objects.push(...parsePrefab(sourceAsset, guidMap, {
        parentTransform: instanceParent,
        overrides: instance.overrides,
        depth: depth + 1,
      }));
    } else {
      const glb = toResGlb(sourceAsset);
      if (!glb) continue;
      const transformOverride = Object.values(instance.overrides).find((entry) => entry.position || entry.rotation || entry.scale) || {};
      const materialOverride = Object.values(instance.overrides).find((entry) => entry.materials) || {};
      const instanceTransform = composeTransform(instanceParent, applyOverride(identityTransform, transformOverride));
      objects.push({
        name: transformOverride.name || path.basename(sourceAsset, path.extname(sourceAsset)),
        mesh_guid: instance.sourceGuid,
        source_asset: sourceAsset.replace(/\\/g, "/"),
        scene: glb,
        material_guids: materialOverride.materials || [],
        position: instanceTransform.position,
        rotation: instanceTransform.rotation,
        scale: instanceTransform.scale,
        prefab_source: prefabPath.replace(/\\/g, "/"),
      });
    }
  }

  return objects;
}

function materialGuidNames(guidMap, objects) {
  const result = {};
  const materialGuids = new Set(objects.flatMap((object) => object.material_guids || []));
  for (const guid of materialGuids) {
    const asset = guidMap[guid];
    if (asset) result[guid] = path.basename(asset, path.extname(asset));
  }
  return result;
}

function main() {
  fs.mkdirSync(outDir, { recursive: true });
  const guidMap = buildGuidMap();
  for (const [mapId, prefabPath] of Object.entries(levelFiles)) {
    const objects = parsePrefab(prefabPath, guidMap);
    const payload = {
      source: prefabPath.replace(/\\/g, "/"),
      generated_at: new Date().toISOString(),
      object_count: objects.length,
      material_guid_names: materialGuidNames(guidMap, objects),
      objects,
    };
    fs.writeFileSync(path.join(outDir, `${mapId}.json`), JSON.stringify(payload, null, 2));
    console.log(`${mapId}: ${objects.length} mesh objects`);
  }
}

main();
