// Knock out a low-saturation LIGHT background (white / grey checkerboard / soft
// shadow) via border flood-fill, keeping the saturated icon. Then trim margins.
// Usage: node scripts_knockout2.mjs <in> <out>
import sharp from "sharp";

const [, , inp, outp] = process.argv;
const { data, info } = await sharp(inp).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
const { width, height } = info;

// background = near-neutral (low chroma) and light/mid brightness
const isBg = (p) => {
  const i = p * 4, r = data[i], g = data[i + 1], b = data[i + 2];
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  return mx - mn < 14 && mn > 100;
};

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
  if (!isBg(p)) continue;
  data[p * 4 + 3] = 0;
  cleared++;
  const x = p % width, y = (p / width) | 0;
  push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
}

await sharp(data, { raw: { width, height, channels: 4 } })
  .trim({ threshold: 10 })
  .png()
  .toFile(outp);
console.log(`wrote ${outp}  cleared ${((cleared / (width * height)) * 100).toFixed(1)}%`);
