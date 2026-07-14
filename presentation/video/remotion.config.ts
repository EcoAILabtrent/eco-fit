import { Config } from "@remotion/cli/config";

Config.setVideoImageFormat("jpeg");
Config.setJpegQuality(100);
Config.setOverwriteOutput(true);
Config.setConcurrency(2);
// H.264 with good quality for social / store uploads
Config.setCodec("h264");
Config.setCrf(16);
