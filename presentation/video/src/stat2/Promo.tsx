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
import { C, CAPTIONS, FPS, VOICE_OFFSET_S } from "../theme";
import { Phone } from "../Phone";
import { SidePanel } from "./scenes";
import { rajdhani } from "./fonts";

const M = globalThis.Math;

const Background: React.FC = () => (
  <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
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

// Borderless caption — centered, with a typewriter reveal that does NOT reflow.
// The full text is always laid out (untyped chars are transparent), so the line
// wrapping is fixed from the start; `text-wrap: balance` splits long lines evenly
// and the green caret marks the typing position with a zero-width (no-shift) span.
const Captions: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = f / fps;
  const active = CAPTIONS.find((c) => t >= c.start && t < c.end);
  if (!active) return null;
  const local = t - active.start;
  const rem = active.end - t;
  const chars = active.text.length;
  const typeDur = M.min(3.2, M.max(1.2, chars * 0.045)); // seconds to fully type
  const shown = M.min(chars, M.floor((local / typeDur) * chars));
  const typing = local < typeDur && shown < chars;
  const op = M.min(1, local / 0.22, rem / 0.3);
  const rise = interpolate(local, [0, 0.4], [10, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const caretOn = M.floor(f / 8) % 2 === 0;
  const letters = active.text.split("");
  return (
    <div
      style={{
        // raised to sit level with the lower part of the phone (phone bottom ≈ y1007)
        position: "absolute",
        top: 846,
        height: 176,
        left: 690,
        right: 40,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          maxWidth: 920,
          opacity: op,
          transform: `translateY(${rise}px)`,
          fontFamily: rajdhani,
          fontWeight: 600,
          fontSize: 40,
          lineHeight: 1.32,
          color: C.ink,
          textAlign: "center",
          textWrap: "balance",
        }}
      >
        {letters.map((ch, i) => (
          <React.Fragment key={i}>
            {typing && i === shown && (
              <span
                style={{
                  display: "inline-block",
                  width: 0,
                  overflow: "visible",
                  color: C.green,
                  fontWeight: 800,
                  opacity: caretOn ? 1 : 0.25,
                }}
              >
                ▍
              </span>
            )}
            <span style={{ color: i < shown ? C.ink : "transparent" }}>{ch}</span>
          </React.Fragment>
        ))}
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

export const EcoHealthPromoStat2: React.FC = () => {
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

        {/* Phone on the left — no dynamic island */}
        <Phone cx={400} cy={540} island={false} />

        {/* Content panel on the right */}
        <div style={{ position: "absolute", left: 700, top: 96, width: 1160, bottom: 150 }}>
          <SidePanel />
        </div>

        <Captions />
        <ProgressBar />
      </AbsoluteFill>

      <Audio src={staticFile("voice.mp3")} startFrom={M.round(VOICE_OFFSET_S * FPS)} volume={voiceFade} />
    </AbsoluteFill>
  );
};
