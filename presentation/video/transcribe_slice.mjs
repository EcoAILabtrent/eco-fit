import fs from "node:fs";
import { pipeline } from "@huggingface/transformers";

function readWavF32(path) {
  const buf = fs.readFileSync(path);
  let off = 12, dataOff = -1, dataLen = 0;
  while (off + 8 <= buf.length) {
    const id = buf.toString("ascii", off, off + 4);
    const sz = buf.readUInt32LE(off + 4);
    if (id === "data") { dataOff = off + 8; dataLen = sz; break; }
    off += 8 + sz + (sz & 1);
  }
  const n = Math.floor(dataLen / 4);
  const f32 = new Float32Array(n);
  for (let i = 0; i < n; i++) f32[i] = buf.readFloatLE(dataOff + i * 4);
  return f32;
}

const file = process.argv[2];
const offset = parseFloat(process.argv[3] || "0");
const audio = readWavF32(file);
console.error(`samples: ${audio.length} (${(audio.length / 16000).toFixed(1)}s), offset ${offset}`);

const asr = await pipeline("automatic-speech-recognition", "Xenova/whisper-small");
const out = await asr(audio, {
  language: "uzbek", task: "transcribe", return_timestamps: true,
  chunk_length_s: 20, stride_length_s: 4,
});
for (const c of out.chunks) {
  const [s, e] = c.timestamp;
  console.log(`${((s ?? 0) + offset).toFixed(2)}\t${((e ?? 0) + offset).toFixed(2)}\t${c.text.trim()}`);
}
