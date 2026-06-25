const fs = require("fs");
const path = require("path");
const cp = require("child_process");

const repo = process.cwd();
const manifestPath = path.join(repo, "assets", "unity_migrated", "polygon_apocalypse", "used_models.json");
const converter = process.env.FBX2GLTF || path.join(repo, ".codex_tools", "FBX2glTF", "FBX2glTF-windows-x86_64", "FBX2glTF-windows-x86_64.exe");
const limit = Number(process.env.POLYGON_APOCALYPSE_CONVERT_LIMIT || "0");

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function run(command, args) {
  const result = cp.spawnSync(command, args, { stdio: "pipe", encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")}\n${result.stdout}\n${result.stderr}`);
  }
  return result;
}

function main() {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Missing ${manifestPath}. Run node tools/build_polygon_apocalypse_layouts.js first.`);
  }
  if (!fs.existsSync(converter)) {
    throw new Error(`Missing FBX2glTF converter: ${converter}`);
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const models = Array.isArray(manifest.models) ? manifest.models : [];
  let converted = 0;
  let skipped = 0;
  let failed = 0;
  const failures = [];

  for (const model of models) {
    const source = String(model.source || "");
    const output = String(model.output || "");
    if (!source || !output) continue;
    if (limit > 0 && converted >= limit) break;
    if (fs.existsSync(output)) {
      skipped += 1;
      continue;
    }
    ensureDir(path.dirname(output));
    try {
      run(converter, ["--binary", "--input", source, "--output", output]);
      converted += 1;
      if (converted % 25 === 0) {
        console.log(`converted ${converted}, skipped ${skipped}, failed ${failed}`);
      }
    } catch (error) {
      failed += 1;
      failures.push({ source, output, error: String(error.message || error) });
      console.warn(`FAILED ${source}`);
    }
  }

  const reportPath = path.join(repo, "assets", "unity_migrated", "polygon_apocalypse", "conversion_report.json");
  fs.writeFileSync(reportPath, JSON.stringify({
    generated_at: new Date().toISOString(),
    converter,
    converted,
    skipped,
    failed,
    failures,
  }, null, 2));
  console.log(`PolygonApocalypse conversion complete: converted=${converted}, skipped=${skipped}, failed=${failed}`);
  if (failed > 0) process.exitCode = 1;
}

main();
