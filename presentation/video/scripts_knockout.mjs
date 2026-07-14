// Knock out the EXTERIOR white of an image (flood-fill from the borders),
// preserving interior white (ECG line, pill labels). Writes an RGBA PNG.
// Usage: node scripts_knockout.mjs <in> <out> [threshold=236]
import sharp from "sharp";

const [, , inp, outp, thrArg] = process.argv;
const thr = Number(thrArg || 236);

const { data, info } = await sharp(inp).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
const { width, height } = info;
const isWhite = (i) => data[i] >= thr && data[i + 1] >= thr && data[i + 2] >= thr;

const visited = new Uint8Array(width * height);
const stack = [];
const push = (x, y) => {
  if (x < 0 || y < 0 || x >= width || y >= height) return;
  const p = y * width + x;
  if (visited[p]) return;
  visited[p] = 1;
  stack.push(p);
};
for (let x = 0; x < width; x++) { push(x, 0); push(x, height - 1); }
for (let y = 0; y < height; y++) { push(0, y); push(width - 1, y); }

let cleared = 0;
while (stack.length) {
  const p = stack.pop();
  if (!isWhite(p * 4)) continue;
  data[p * 4 + 3] = 0;
  cleared++;
  const x = p % width, y = (p / width) | 0;
  push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
}

// Soften the 1px cut edge a touch so no hard white fringe remains.
await sharp(data, { raw: { width, height, channels: 4 } })
  .png()
  .toFile(outp);
console.log(`wrote ${outp}  ${width}x${height}  cleared ${cleared}px (${((cleared / (width * height)) * 100).toFixed(1)}%)`);
