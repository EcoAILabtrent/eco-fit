import { parseMedia } from "@remotion/media-parser";
import { nodeReader } from "@remotion/media-parser/node";

async function probe(path) {
  const res = await parseMedia({
    src: path,
    reader: nodeReader,
    fields: {
      durationInSeconds: true,
      dimensions: true,
      fps: true,
      numberOfAudioChannels: true,
    },
  });
  return res;
}

const video = await probe("./public/screen.mp4");
const voice = await probe("./public/voice.mp3");
console.log("VIDEO", JSON.stringify(video));
console.log("VOICE", JSON.stringify(voice));
