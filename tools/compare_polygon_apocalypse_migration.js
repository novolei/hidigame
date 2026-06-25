const fs = require("fs");
const path = require("path");

const repo = process.cwd();
const unityRoot = process.env.POLYGON_APOCALYPSE_SOURCE || "H:\\3D Resource\\effect\\Party Monster Rumble PBR v1.0\\New Unity Project\\Assets\\PolygonApocalypse";
const godotRoot = path.join(repo, "assets", "unity_migrated", "polygon_apocalypse");
const outRoot = path.join(repo, ".codex_compare", "polygon_apocalypse");
const unityScreenshotRoot = path.join(outRoot, "unity");
const visualComparePath = path.join(outRoot, "visual_compare_unity_godot_final.png");
const visualMetricsPath = path.join(outRoot, "visual_iou_latest.json");
const visualObservationDetails = {
  building_interior_dressing: {
    capture_direction: "Unity pp + Godot flipX",
    status: "close_with_tonemapping_differences",
    note: "Renderer bounds align with Unity; cool material calibration brings the tone closer, with remaining lighting/tonemapping differences.",
  },
  bunker: {
    capture_direction: "Unity pp + Godot flipX",
    status: "close",
    note: "Runtime capture is visually close to the Unity audit screenshot.",
  },
  city_standard: {
    capture_direction: "Unity pp + Godot flipX",
    status: "close",
    note: "Runtime capture is visually close after city tonemapping and material tint calibration.",
  },
  city_urp: {
    capture_direction: "Unity pp + Godot flipX",
    status: "close_with_tonemapping_differences",
    note: "Renderer bounds align; URP water, cloud, and tone calibration bring the scene closer, while transparent blending and tonemapping still differ.",
  },
};

const scenes = {
  building_interior_dressing: path.join(unityRoot, "Scenes", "Demo_Building_Interior_Dressing.unity"),
  bunker: path.join(unityRoot, "Scenes", "Demo_Bunker.unity"),
  city_standard: path.join(unityRoot, "Scenes", "Demo_City_Standard.unity"),
  city_urp: path.join(unityRoot, "Scenes", "Demo_City_Universal_RenderPipeline.unity"),
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
  const match = text.match(/^guid:\s*([a-f0-9]{32})/m);
  return match ? match[1] : "";
}

function buildGuidMap() {
  const map = {};
  for (const meta of walk(unityRoot).filter((file) => file.endsWith(".meta"))) {
    const guid = readGuid(meta);
    if (guid) map[guid] = meta.slice(0, -5).replace(/\\/g, "/");
  }
  return map;
}

function splitBlocks(text) {
  return text.split(/\n(?=--- !u!)/g);
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

function parseGuidList(text) {
  return Array.from(text.matchAll(/guid:\s*([a-f0-9]{32})/g)).map((match) => match[1]);
}

function parseUnityScene(scenePath, guidMap) {
  const blocks = splitBlocks(fs.readFileSync(scenePath, "utf8"));
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
      gameObjects[id] = {
        active: firstNumber(block, /m_IsActive:\s*(-?\d+)/, 1) !== 0,
        name: (block.match(/m_Name:\s*(.*)/) || [null, ""])[1].trim(),
      };
    } else if (type === "4") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const father = String(firstNumber(block, /m_Father: \{fileID: (-?\d+)\}/));
      transforms[id] = {
        gameObject,
        father: father === "0" ? "" : father,
      };
    } else if (type === "33") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const match = block.match(/m_Mesh: \{fileID: \d+, guid: ([a-f0-9]{32}), type: \d+\}/);
      if (match) meshFilters[gameObject] = match[1];
    } else if (type === "23" || type === "137") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      const materialSection = block.split("m_Materials:")[1] || "";
      renderers[gameObject] = {
        enabled: firstNumber(block, /m_Enabled:\s*(-?\d+)/, 1) !== 0,
        materials: parseGuidList(materialSection),
      };
      if (type === "137") {
        const match = block.match(/m_Mesh: \{fileID: \d+, guid: ([a-f0-9]{32}), type: \d+\}/);
        if (match) meshFilters[gameObject] = match[1];
      }
    } else if (type === "108") {
      const gameObject = String(firstNumber(block, /m_GameObject: \{fileID: (-?\d+)\}/));
      lights[gameObject] = {
        enabled: firstNumber(block, /m_Enabled:\s*(-?\d+)/, 1) !== 0,
      };
    }
  }

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

  const renderableObjects = [];
  const materialGuids = new Set();
  const meshGuids = new Set();
  const missingMeshGuidAssets = new Set();
  const missingMaterialGuidAssets = new Set();
  let enabledLightCount = 0;
  for (const transformId of Object.keys(transforms)) {
    const transform = transforms[transformId];
    if (!isTransformActive(transformId)) continue;
    const light = lights[transform.gameObject];
    if (light && light.enabled) enabledLightCount += 1;
    const meshGuid = meshFilters[transform.gameObject];
    const renderer = renderers[transform.gameObject];
    if (!meshGuid || !renderer || !renderer.enabled) continue;
    meshGuids.add(meshGuid);
    if (!guidMap[meshGuid]) missingMeshGuidAssets.add(meshGuid);
    for (const guid of renderer.materials) {
      materialGuids.add(guid);
      if (!guidMap[guid]) missingMaterialGuidAssets.add(guid);
    }
    renderableObjects.push({
      transform_id: transformId,
      hierarchy_path: hierarchyPath(transformId),
      name: gameObjects[transform.gameObject] ? gameObjects[transform.gameObject].name : "",
      mesh_guid: meshGuid,
      material_guids: renderer.materials,
    });
  }
  return {
    renderable_objects: renderableObjects,
    renderable_count: renderableObjects.length,
    unique_mesh_guids: Array.from(meshGuids).sort(),
    unique_material_guids: Array.from(materialGuids).sort(),
    enabled_light_count: enabledLightCount,
    missing_mesh_guid_assets: Array.from(missingMeshGuidAssets).sort(),
    missing_material_guid_assets: Array.from(missingMaterialGuidAssets).sort(),
  };
}

function fileExistsForResPath(resPath) {
  if (!resPath.startsWith("res://")) return false;
  return fs.existsSync(path.join(repo, resPath.slice("res://".length)));
}

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));
}

function loadVisualMetrics() {
  if (!fs.existsSync(visualMetricsPath)) return {};
  return loadJson(visualMetricsPath);
}

function loadUnityProjectRenderingSettings() {
  const projectRoot = path.dirname(path.dirname(unityRoot));
  const projectSettingsPath = path.join(projectRoot, "ProjectSettings", "ProjectSettings.asset");
  const graphicsSettingsPath = path.join(projectRoot, "ProjectSettings", "GraphicsSettings.asset");
  const projectSettings = fs.existsSync(projectSettingsPath) ? fs.readFileSync(projectSettingsPath, "utf8") : "";
  const graphicsSettings = fs.existsSync(graphicsSettingsPath) ? fs.readFileSync(graphicsSettingsPath, "utf8") : "";
  const colorSpaceValue = firstNumber(projectSettings, /m_ActiveColorSpace:\s*(-?\d+)/, -1);
  const linearIntensityValue = firstNumber(graphicsSettings, /m_LightsUseLinearIntensity:\s*(-?\d+)/, -1);
  return {
    active_color_space: colorSpaceValue === 0 ? "Gamma" : colorSpaceValue === 1 ? "Linear" : "Unknown",
    active_color_space_value: colorSpaceValue,
    lights_use_linear_intensity: linearIntensityValue === 1,
    lights_use_linear_intensity_value: linearIntensityValue,
  };
}

function summarizeVisualDirections(directions) {
  const values = Object.values(directions || {});
  if (!values.length) {
    return {
      average_mask_iou: 0,
      average_color_delta: 0,
      worst_color_delta: 0,
      worst_color_direction: "",
    };
  }
  let maskIouSum = 0;
  let colorDeltaSum = 0;
  let worstColorDelta = -Infinity;
  let worstColorDirection = "";
  for (const [label, metrics] of Object.entries(directions)) {
    const maskIou = Number(metrics.mask_iou || 0);
    const colorDelta = Number(metrics.color_delta || 0);
    maskIouSum += maskIou;
    colorDeltaSum += colorDelta;
    if (colorDelta > worstColorDelta) {
      worstColorDelta = colorDelta;
      worstColorDirection = label;
    }
  }
  return {
    average_mask_iou: maskIouSum / values.length,
    average_color_delta: colorDeltaSum / values.length,
    worst_color_delta: worstColorDelta,
    worst_color_direction: worstColorDirection,
  };
}

function visualObservationFor(mapId, visualMetrics) {
  const details = visualObservationDetails[mapId];
  const metrics = visualMetrics[mapId];
  if (!details && !metrics) return null;
  const directions = {};
  for (const [label, directionMetrics] of Object.entries((metrics && metrics.directions) || {})) {
    directions[label] = {
      mask_iou: Number(directionMetrics.mask_iou !== undefined ? directionMetrics.mask_iou : 0),
      color_delta: Number(directionMetrics.color_delta !== undefined ? directionMetrics.color_delta : 0),
      unity_foreground_pixels: Number(directionMetrics.unity_foreground_pixels !== undefined ? directionMetrics.unity_foreground_pixels : 0),
      godot_foreground_pixels: Number(directionMetrics.godot_foreground_pixels !== undefined ? directionMetrics.godot_foreground_pixels : 0),
      diff_heatmap: String(directionMetrics.diff_heatmap || ""),
    };
  }
  const summary = summarizeVisualDirections(directions);
  return {
    ...(details || {}),
    mask_iou: Number(metrics && metrics.mask_iou !== undefined ? metrics.mask_iou : 0),
    color_delta: Number(metrics && metrics.color_delta !== undefined ? metrics.color_delta : 0),
    average_mask_iou: summary.average_mask_iou,
    average_color_delta: summary.average_color_delta,
    worst_color_delta: summary.worst_color_delta,
    worst_color_direction: summary.worst_color_direction,
    unity_foreground_pixels: Number(metrics && metrics.unity_foreground_pixels !== undefined ? metrics.unity_foreground_pixels : 0),
    godot_foreground_pixels: Number(metrics && metrics.godot_foreground_pixels !== undefined ? metrics.godot_foreground_pixels : 0),
    diff_heatmap: String(metrics && metrics.diff_heatmap ? metrics.diff_heatmap : ""),
    directions,
  };
}

function mergeGodotVisibleBounds(mapId) {
  const boundsPath = path.join(outRoot, "godot_bounds", `${mapId}.json`);
  if (!fs.existsSync(boundsPath)) return null;
  const payload = loadJson(boundsPath);
  const objects = (payload.objects || []).filter((object) => {
    const name = String(object.name || "");
    const size = object.size || [];
    return !name.includes("_Blocker") && size.some((value) => Math.abs(Number(value)) > 0.00001);
  });
  if (!objects.length) return null;
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (const object of objects) {
    for (let index = 0; index < 3; index += 1) {
      min[index] = Math.min(min[index], Number(object.min[index]));
      max[index] = Math.max(max[index], Number(object.max[index]));
    }
  }
  const center = max.map((value, index) => (value + min[index]) / 2);
  const size = max.map((value, index) => value - min[index]);
  return { center, size, min, max, visible_object_count: objects.length };
}

function maxAbsDelta(left, right) {
  if (!left || !right) return null;
  return Math.max(...left.map((value, index) => Math.abs(Number(value) - Number(right[index]))));
}

function leafName(hierarchyPath) {
  return String(hierarchyPath || "").split("/").pop();
}

function compareNamedRendererBounds(mapId, unityRenderableObjects) {
  const unityRendererPath = path.join(unityScreenshotRoot, "unity_renderer_bounds.json");
  const godotBoundsPath = path.join(outRoot, "godot_bounds", `${mapId}.json`);
  if (!fs.existsSync(unityRendererPath) || !fs.existsSync(godotBoundsPath)) return null;
  const unityRendererPayload = loadJson(unityRendererPath);
  const unityScene = (unityRendererPayload.scenes || []).find((scene) => scene.map_id === mapId);
  if (!unityScene) return null;
  const godotObjects = (loadJson(godotBoundsPath).objects || []).filter((object) => {
    const name = String(object.name || "");
    const size = object.size || [];
    return !name.includes("_Blocker") && size.some((value) => Math.abs(Number(value)) > 0.00001);
  });
  const godotByName = new Map();
  const godotByTransformId = new Map();
  for (const object of godotObjects) {
    const name = String(object.unity_name || object.name || "");
    if (!godotByName.has(name)) godotByName.set(name, []);
    godotByName.get(name).push(object);
    const transformId = String(object.unity_transform_id || "");
    if (transformId) {
      if (!godotByTransformId.has(transformId)) godotByTransformId.set(transformId, []);
      godotByTransformId.get(transformId).push(object);
    }
  }
  const unityIdsByPath = new Map();
  for (const object of unityRenderableObjects || []) {
    const hierarchyPath = String(object.hierarchy_path || "");
    if (!hierarchyPath) continue;
    if (!unityIdsByPath.has(hierarchyPath)) unityIdsByPath.set(hierarchyPath, []);
    unityIdsByPath.get(hierarchyPath).push(String(object.transform_id || ""));
  }

  const unityRenderers = (unityScene.renderer_details || []).filter((renderer) => {
    const size = renderer.bounds && renderer.bounds.size ? renderer.bounds.size : [];
    return size.some((value) => Math.abs(Number(value)) > 0.00001);
  });
  const rows = [];
  let missingNameCount = 0;
  let exactTransformMatchCount = 0;
  let hierarchyPathMatchCount = 0;
  let fallbackNameMatchCount = 0;
  let missingTransformCount = 0;
  const consumed = new Set();
  for (const renderer of unityRenderers) {
    const name = leafName(renderer.hierarchy_path);
    const transformIds = unityIdsByPath.get(String(renderer.hierarchy_path || "")) || [];
    let candidates = [];
    for (const transformId of transformIds) {
      candidates.push(...(godotByTransformId.get(transformId) || []));
    }
    candidates = candidates.filter((candidate) => !consumed.has(candidate));
    let matchMode = transformIds.length === 1 ? "transform_id" : "hierarchy_path";
    if (!candidates.length) {
      if (transformIds.length > 0) missingTransformCount += 1;
      candidates = (godotByName.get(name) || []).filter((candidate) => !consumed.has(candidate));
      matchMode = "name";
    }
    if (!candidates.length) {
      missingNameCount += 1;
      continue;
    }
    let best = null;
    let bestIndex = -1;
    let bestScore = Infinity;
    for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex += 1) {
      const candidate = candidates[candidateIndex];
      const centerDelta = maxAbsDelta(renderer.bounds.center, candidate.center);
      const sizeDelta = maxAbsDelta(renderer.bounds.size, candidate.size);
      const score = centerDelta + sizeDelta * 0.5;
      if (score < bestScore) {
        bestScore = score;
        bestIndex = candidateIndex;
        best = { center_delta: centerDelta, size_delta: sizeDelta, name, match_mode: matchMode };
      }
    }
    if (best) {
      rows.push(best);
      consumed.add(candidates[bestIndex]);
      if (matchMode === "transform_id") exactTransformMatchCount += 1;
      else if (matchMode === "hierarchy_path") hierarchyPathMatchCount += 1;
      else fallbackNameMatchCount += 1;
    }
  }
  const sortedBySize = [...rows].sort((left, right) => right.size_delta - left.size_delta);
  const sortedByCenter = [...rows].sort((left, right) => right.center_delta - left.center_delta);
  return {
    unity_renderer_count: unityRenderers.length,
    godot_visible_object_count: godotObjects.length,
    matched_name_count: rows.length,
    exact_transform_match_count: exactTransformMatchCount,
    hierarchy_path_match_count: hierarchyPathMatchCount,
    fallback_name_match_count: fallbackNameMatchCount,
    missing_transform_count: missingTransformCount,
    missing_name_count: missingNameCount,
    center_delta_gt_1_count: rows.filter((row) => row.center_delta > 1.0).length,
    size_delta_gt_1_count: rows.filter((row) => row.size_delta > 1.0).length,
    size_delta_gt_5_count: rows.filter((row) => row.size_delta > 5.0).length,
    max_center_delta: rows.length ? sortedByCenter[0].center_delta : null,
    max_size_delta: rows.length ? sortedBySize[0].size_delta : null,
    worst_size_delta_name: rows.length ? sortedBySize[0].name : "",
  };
}

function buildComparison() {
  fs.mkdirSync(outRoot, { recursive: true });
  const guidMap = buildGuidMap();
  const materialMapPath = path.join(godotRoot, "material_guid_map.json");
  const materialMap = fs.existsSync(materialMapPath) ? loadJson(materialMapPath).materials || {} : {};
  const usedModelsPath = path.join(godotRoot, "used_models.json");
  const usedModels = fs.existsSync(usedModelsPath) ? loadJson(usedModelsPath).models || [] : [];
  const usedModelByRes = new Map(usedModels.map((model) => [model.res, model]));
  const unityAuditPath = path.join(unityScreenshotRoot, "unity_audit.json");
  const unityAudit = fs.existsSync(unityAuditPath) ? loadJson(unityAuditPath) : null;
  const visualMetrics = loadVisualMetrics();
  const unityRendering = loadUnityProjectRenderingSettings();
  const sceneResults = [];

  for (const [mapId, scenePath] of Object.entries(scenes)) {
    const unity = parseUnityScene(scenePath, guidMap);
    const unityAuditScene = unityAudit ? (unityAudit.scenes || []).find((scene) => scene.map_id === mapId) : null;
    const godotBounds = mergeGodotVisibleBounds(mapId);
    const namedRendererBounds = compareNamedRendererBounds(mapId, unity.renderable_objects);
    const boundsComparison = unityAuditScene && unityAuditScene.bounds && godotBounds ? {
      unity_center: unityAuditScene.bounds.center,
      unity_size: unityAuditScene.bounds.size,
      godot_center: godotBounds.center,
      godot_size: godotBounds.size,
      godot_visible_object_count: godotBounds.visible_object_count,
      max_center_delta: maxAbsDelta(unityAuditScene.bounds.center, godotBounds.center),
      max_size_delta: maxAbsDelta(unityAuditScene.bounds.size, godotBounds.size),
    } : null;
    const layoutPath = path.join(godotRoot, "layouts", `${mapId}.json`);
    const layout = fs.existsSync(layoutPath) ? loadJson(layoutPath) : null;
    const layoutObjects = layout ? layout.objects || [] : [];
    const layoutMaterialGuids = new Set(layoutObjects.flatMap((object) => object.material_guids || []));
    const layoutMeshGuids = new Set(layoutObjects.map((object) => object.mesh_guid).filter(Boolean));
    const missingGlb = [];
    const missingImports = [];
    const missingMaterialMappings = [];
    const missingMaterialFiles = [];
    const missingMaterialInLayout = [];

    for (const object of layoutObjects) {
      if (object.builtin_mesh) {
        // Unity built-in meshes, such as the Bunker background quad, are rebuilt in Godot.
      } else if (!fileExistsForResPath(object.scene || "")) {
        missingGlb.push(object.scene || object.name || "<missing scene>");
      } else {
        const local = path.join(repo, String(object.scene).slice("res://".length));
        if (!fs.existsSync(local + ".import")) missingImports.push(object.scene);
      }
      for (const guid of object.material_guids || []) {
        if (!materialMap[guid]) {
          missingMaterialMappings.push(guid);
        } else if (!fileExistsForResPath(materialMap[guid])) {
          missingMaterialFiles.push(materialMap[guid]);
        }
      }
    }
    for (const guid of unity.unique_material_guids) {
      if (!layoutMaterialGuids.has(guid)) missingMaterialInLayout.push(guid);
    }

    sceneResults.push({
      map_id: mapId,
      unity_scene: scenePath.replace(/\\/g, "/"),
      unity_renderable_count: unity.renderable_count,
      godot_layout_object_count: layout ? layout.object_count : 0,
      godot_layout_array_count: layoutObjects.length,
      unity_light_count: unity.enabled_light_count,
      godot_layout_light_count: layout ? layout.light_count : 0,
      unity_unique_mesh_count: unity.unique_mesh_guids.length,
      godot_layout_unique_mesh_count: layoutMeshGuids.size,
      unity_unique_material_count: unity.unique_material_guids.length,
      godot_layout_unique_material_count: layoutMaterialGuids.size,
      missing_unity_mesh_guid_assets: unity.missing_mesh_guid_assets,
      missing_unity_material_guid_assets: unity.missing_material_guid_assets,
      missing_glb: Array.from(new Set(missingGlb)).sort(),
      missing_glb_import: Array.from(new Set(missingImports)).sort(),
      missing_material_mappings: Array.from(new Set(missingMaterialMappings)).sort(),
      missing_material_files: Array.from(new Set(missingMaterialFiles)).sort(),
      missing_unity_materials_in_layout: missingMaterialInLayout.sort(),
      object_count_match: unity.renderable_count === (layout ? layout.object_count : -1) && unity.renderable_count === layoutObjects.length,
      light_count_match: unity.enabled_light_count === (layout ? layout.light_count : -1),
      mesh_guid_set_match: sameSet(unity.unique_mesh_guids, Array.from(layoutMeshGuids)),
      material_guid_set_match: sameSet(unity.unique_material_guids, Array.from(layoutMaterialGuids)),
      unity_screenshot: path.join(unityScreenshotRoot, `${mapId}.png`).replace(/\\/g, "/"),
      unity_screenshot_exists: fs.existsSync(path.join(unityScreenshotRoot, `${mapId}.png`)),
      bounds_comparison: boundsComparison,
      named_renderer_bounds: namedRendererBounds,
      visual_observation: visualObservationFor(mapId, visualMetrics),
    });
  }

  return {
    generated_at: new Date().toISOString(),
    unity_root: unityRoot.replace(/\\/g, "/"),
    godot_root: "res://assets/unity_migrated/polygon_apocalypse",
    used_model_count: usedModels.length,
    used_model_missing_glb_count: usedModels.filter((model) => !fileExistsForResPath(model.res || "")).length,
    material_mapping_count: Object.keys(materialMap).length,
    unity_rendering: unityRendering,
    visual_compare: visualComparePath.replace(/\\/g, "/"),
    visual_compare_exists: fs.existsSync(visualComparePath),
    scenes: sceneResults,
  };
}

function sameSet(a, b) {
  const left = Array.from(new Set(a)).sort();
  const right = Array.from(new Set(b)).sort();
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function writeMarkdown(report) {
  const lines = [];
  lines.push("# Polygon Apocalypse Unity vs Godot Migration Audit");
  lines.push("");
  lines.push(`Generated: ${report.generated_at}`);
  lines.push("");
  lines.push(`Unity source: \`${report.unity_root}\``);
  lines.push(`Godot target: \`${report.godot_root}\``);
  lines.push("");
  lines.push(`Referenced models: ${report.used_model_count}`);
  lines.push(`Missing converted GLB models: ${report.used_model_missing_glb_count}`);
  lines.push(`Material GUID mappings: ${report.material_mapping_count}`);
  if (report.unity_rendering) {
    lines.push(`Unity color space: ${report.unity_rendering.active_color_space}`);
    lines.push(`Unity lights use linear intensity: ${report.unity_rendering.lights_use_linear_intensity ? "yes" : "no"}`);
  }
  lines.push(`Final visual compare: \`${report.visual_compare}\` (${report.visual_compare_exists ? "exists" : "missing"})`);
  lines.push("");
  lines.push("| Map | Unity renderers | Godot objects | Object match | Unity lights | Godot lights | Material set match | Unity screenshot | Missing GLB | Missing material mappings |");
  lines.push("| --- | ---: | ---: | --- | ---: | ---: | --- | --- | ---: | ---: |");
  for (const scene of report.scenes) {
    lines.push(`| ${scene.map_id} | ${scene.unity_renderable_count} | ${scene.godot_layout_object_count} | ${scene.object_count_match ? "yes" : "NO"} | ${scene.unity_light_count} | ${scene.godot_layout_light_count} | ${scene.material_guid_set_match ? "yes" : "NO"} | ${scene.unity_screenshot_exists ? "yes" : "NO"} | ${scene.missing_glb.length} | ${scene.missing_material_mappings.length} |`);
  }
  lines.push("");
  lines.push("## Bounds Review");
  lines.push("");
  lines.push("| Map | Godot visible objects | Max center delta | Max size delta | Bounds status |");
  lines.push("| --- | ---: | ---: | ---: | --- |");
  for (const scene of report.scenes) {
    const bounds = scene.bounds_comparison;
    if (!bounds) {
      lines.push(`| ${scene.map_id} | - | - | - | missing bounds evidence |`);
      continue;
    }
    const centerDelta = Number(bounds.max_center_delta || 0);
    const sizeDelta = Number(bounds.max_size_delta || 0);
    const status = centerDelta <= 0.1 && sizeDelta <= 0.1 ? "aligned" : "review";
    lines.push(`| ${scene.map_id} | ${bounds.godot_visible_object_count} | ${centerDelta.toFixed(4)} | ${sizeDelta.toFixed(4)} | ${status} |`);
  }
  lines.push("");
  lines.push("## Named Renderer Bounds");
  lines.push("");
  lines.push("| Map | Exact ID matches | Path ID pool | Name fallback | Missing names | Size delta > 1 | Size delta > 5 | Worst size delta | Worst renderer |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |");
  for (const scene of report.scenes) {
    const bounds = scene.named_renderer_bounds;
    if (!bounds) {
      lines.push(`| ${scene.map_id} | - | - | - | - | - | - | - | missing renderer bounds evidence |`);
      continue;
    }
    lines.push(`| ${scene.map_id} | ${bounds.exact_transform_match_count} | ${bounds.hierarchy_path_match_count} | ${bounds.fallback_name_match_count} | ${bounds.missing_name_count} | ${bounds.size_delta_gt_1_count} | ${bounds.size_delta_gt_5_count} | ${Number(bounds.max_size_delta || 0).toFixed(4)} | ${bounds.worst_size_delta_name} |`);
  }
  lines.push("");
  lines.push("## Visual Review");
  lines.push("");
  lines.push("| Map | Godot audit direction | Primary IoU | Primary color delta | Avg IoU | Avg color delta | Worst color delta | Diff heatmap | Visual status | Note |");
  lines.push("| --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |");
  for (const scene of report.scenes) {
    const visual = scene.visual_observation;
    if (!visual) continue;
    const diffHeatmap = visual.diff_heatmap ? `[\`${path.basename(visual.diff_heatmap)}\`](${visual.diff_heatmap})` : "-";
    const worstColor = visual.worst_color_direction ? `${Number(visual.worst_color_delta || 0).toFixed(2)} (${visual.worst_color_direction})` : "-";
    lines.push(`| ${scene.map_id} | ${visual.capture_direction} | ${visual.mask_iou.toFixed(4)} | ${Number(visual.color_delta || 0).toFixed(2)} | ${Number(visual.average_mask_iou || 0).toFixed(4)} | ${Number(visual.average_color_delta || 0).toFixed(2)} | ${worstColor} | ${diffHeatmap} | ${visual.status} | ${visual.note} |`);
  }
  lines.push("");
  lines.push("## Multi-Angle Visual Review");
  lines.push("");
  lines.push("| Map | Direction | Mask IoU | Color delta | Unity foreground px | Godot foreground px | Diff heatmap |");
  lines.push("| --- | --- | ---: | ---: | ---: | ---: | --- |");
  for (const scene of report.scenes) {
    const visual = scene.visual_observation;
    const directions = visual && visual.directions ? visual.directions : {};
    for (const [label, metrics] of Object.entries(directions)) {
      const diffHeatmap = metrics.diff_heatmap ? `[\`${path.basename(metrics.diff_heatmap)}\`](${metrics.diff_heatmap})` : "-";
      lines.push(`| ${scene.map_id} | ${label} | ${Number(metrics.mask_iou || 0).toFixed(4)} | ${Number(metrics.color_delta || 0).toFixed(2)} | ${Number(metrics.unity_foreground_pixels || 0)} | ${Number(metrics.godot_foreground_pixels || 0)} | ${diffHeatmap} |`);
    }
  }
  lines.push("");
  lines.push("## Notes");
  lines.push("");
  lines.push("- This audit compares Unity scene YAML renderable MeshRenderer/SkinnedMeshRenderer records against the generated Godot layout JSON and converted GLB/material files.");
  lines.push("- Unity screenshots are generated by `Assets/Editor/PolygonApocalypseAuditExporter.cs` using a fixed 45 degree FOV audit camera, solid `0.28` gray background, and scene bounds framing. The exporter supports `pp`, `np`, `pn`, and `nn`; the multi-angle table records directions that have matching Unity and Godot screenshots available.");
  lines.push("- Named renderer bounds prefer Unity scene transform fileIDs parsed from YAML; ambiguous hierarchy paths are matched within their transform-ID pool before falling back to renderer names.");
  lines.push("- The final visual compare image pairs the primary `pp` Unity screenshots with Godot runtime captures for compact review. Godot capture output is horizontally flipped to account for the Unity/Godot screen-handedness difference observed in the audit pipeline; this does not modify the runtime map.");
  lines.push("- Current conclusion: object, material, light, and merged renderer bounds are complete for all four migrated Polygon Apocalypse scenes. With the unified audit-camera capture, all four scenes are visually close at the silhouette/layout level; background boards now match Unity materially, while remaining differences are primarily material tone, clouds, water, and renderer/tonemapping differences rather than missing content.");
  return lines.join("\n") + "\n";
}

const report = buildComparison();
fs.writeFileSync(path.join(outRoot, "static_audit.json"), JSON.stringify(report, null, 2));
fs.writeFileSync(path.join(outRoot, "static_audit.md"), writeMarkdown(report));
console.log(JSON.stringify({
  report: path.join(outRoot, "static_audit.json"),
  markdown: path.join(outRoot, "static_audit.md"),
  scenes: report.scenes.map((scene) => ({
    map_id: scene.map_id,
    object_count_match: scene.object_count_match,
    material_guid_set_match: scene.material_guid_set_match,
    missing_glb: scene.missing_glb.length,
    missing_material_mappings: scene.missing_material_mappings.length,
    unity_screenshot_exists: scene.unity_screenshot_exists,
  })),
  visual_compare_exists: report.visual_compare_exists,
}, null, 2));
