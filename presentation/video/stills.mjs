// Batch-render stills from a single bundle. Usage:
//   node stills.mjs <compId> <frame1> <frame2> ...
import { bundle } from "@remotion/bundler";
import { selectComposition, renderStill } from "@remotion/renderer";
import path from "path";
import fs from "fs";

const compId = process.argv[2] || "stat2";
const frames = process.argv.slice(3).map(Number);

const outDir = path.resolve("out", compId + "_stills");
fs.mkdirSync(outDir, { recursive: true });

console.log("Bundling…");
const serveUrl = await bundle({
  entryPoint: path.resolve("src/index.ts"),
  onProgress: (p) => {
    if (p % 25 === 0) process.stdout.write(`bundle ${p}%\r`);
  },
});
console.log("\nBundled. Selecting composition", compId);
const composition = await selectComposition({ serveUrl, id: compId });

for (const frame of frames) {
  const output = path.join(outDir, `f${frame}.png`);
  await renderStill({
    composition,
    serveUrl,
    output,
    frame,
    imageFormat: "png",
    scale: 1,
    chromiumOptions: { gl: "angle" },
  });
  console.log("still", frame, "->", output);
}
console.log("DONE");
