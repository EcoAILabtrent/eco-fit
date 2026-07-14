import React from "react";
import {
  AbsoluteFill,
  Audio,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  Easing,
} from "remotion";
import { C, CAPTIONS, DURATION_S, FPS, VOICE_OFFSET_S } from "./theme";
import { manrope, lora } from "./lib";
import { Phone } from "./Phone";
import { SidePanel } from "./scenes";

const Background: React.FC = () => (
  <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
    {/* soft, edgeless tonal shapes (no hard rings, no thin lines) */}
    <div
      style={{
        position: "absolute",
        top: -320,
        right: -220,
        width: 900,
        height: 900,
        borderRadius: "50%",
        background: C.bgAlt,
        filter: "blur(50px)",
      }}
    />
    <div
      style={{
        position: "absolute",
        bottom: -360,
        right: 180,
        width: 720,
        height: 720,
        borderRadius: "50%",
        background: C.bgAlt,
        opacity: 0.7,
        filter: "blur(60px)",
      }}
    />
    {/* gentle halo grounding the phone on the left */}
    <div
      style={{
        position: "absolute",
        left: -80,
        top: 120,
        width: 900,
        height: 900,
        borderRadius: "50%",
        background: "#ffffff",
        opacity: 0.55,
        filter: "blur(90px)",
      }}
    />
  </AbsoluteFill>
);

const BrandMark: React.FC = () => (
  <div
    style={{
      position: "absolute",
      top: 46,
      left: 726,
      display: "flex",
      alignItems: "center",
      gap: 14,
    }}
  >
    <div
      style={{
        width: 40,
        height: 40,
        borderRadius: 12,
        background: C.green,
        display: "grid",
        placeItems: "center",
        fontSize: 22,
      }}
    >
      🌿
    </div>
    <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 30, color: C.ink, letterSpacing: -0.5 }}>
      Eco <span style={{ color: C.green }}>Health</span>
    </div>
  </div>
);

const Captions: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = f / fps;
  const active = CAPTIONS.find((c) => t >= c.start && t < c.end);
  if (!active) return null;
  const local = t - active.start;
  const rem = active.end - t;
  const op = Math.min(1, local / 0.25, rem / 0.25);
  return (
    <div
      style={{
        // constrained to the right column so it never overlaps the phone
        position: "absolute",
        bottom: 60,
        left: 690,
        right: 40,
        display: "flex",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          opacity: op,
          maxWidth: 1120,
          textAlign: "center",
          fontFamily: manrope,
          fontWeight: 600,
          fontSize: 34,
          lineHeight: 1.35,
          color: C.ink,
          background: "rgba(255,255,255,0.94)",
          border: `1px solid ${C.line}`,
          padding: "16px 34px",
          borderRadius: 20,
          boxShadow: C.shadowSoft,
        }}
      >
        {active.text}
      </div>
    </div>
  );
};

const ProgressBar: React.FC = () => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const p = f / durationInFrames;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 6, background: C.line }}>
      <div style={{ height: "100%", width: `${p * 100}%`, background: C.green }} />
    </div>
  );
};

export const EcoHealthPromo: React.FC = () => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const master = interpolate(
    f,
    [0, 18, durationInFrames - 24, durationInFrames],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.ease) }
  );
  const voiceFade = interpolate(f, [durationInFrames - 30, durationInFrames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: C.bg }}>
      <AbsoluteFill style={{ opacity: master }}>
        <Background />

        {/* Phone on the left */}
        <Phone cx={400} cy={540} />

        {/* Content panel on the right */}
        <div style={{ position: "absolute", left: 700, top: 96, width: 1160, bottom: 150 }}>
          <SidePanel />
        </div>

        <BrandMark />
        <Captions />
        <ProgressBar />
      </AbsoluteFill>

      <Audio src={staticFile("voice.mp3")} startFrom={Math.round(VOICE_OFFSET_S * FPS)} volume={voiceFade} />
    </AbsoluteFill>
  );
};

void lora;
void DURATION_S;
