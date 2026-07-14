import fs from "node:fs";
import { pipeline } from "@huggingface/transformers";

// --- read mono 16k float32 WAV ---
function readWavF32(path) {
  const buf = fs.readFileSync(path);
  let off = 12; // skip RIFF....WAVE
  let dataOff = -1, dataLen = 0;
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

const audio = readWavF32("./out/voice16k.wav");
console.error(`samples: ${audio.length} (${(audio.length / 16000).toFixed(1)}s)`);

const asr = await pipeline("automatic-speech-recognition", "Xenova/whisper-small");
const out = await asr(audio, {
  language: "uzbek",
  task: "transcribe",
  return_timestamps: true,
  chunk_length_s: 30,
  stride_length_s: 5,
});

for (const c of out.chunks) {
  const [s, e] = c.timestamp;
  console.log(`${(s ?? 0).toFixed(2)}\t${(e ?? 0).toFixed(2)}\t${c.text.trim()}`);
}
