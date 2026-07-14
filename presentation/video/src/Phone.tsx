import React from "react";
import {
  OffthreadVideo,
  Img,
  Sequence,
  staticFile,
  useCurrentFrame,
  interpolate,
  Easing,
} from "remotion";
import { sec, PHONE_SEGMENTS } from "./theme";

// Screen recording is 1080 x 2264 → aspect 0.4770
const SCREEN_H = 904;
const SCREEN_W = Math.round(SCREEN_H * (1080 / 2264)); // 431
const BEZEL = 15;
const BODY_W = SCREEN_W + BEZEL * 2;
const BODY_H = SCREEN_H + BEZEL * 2;

/** Subtle attention zoom during the two "wow" moments (daily-norm & AI advice). */
const useEmphasis = () => {
  const f = useCurrentFrame();
  const norm = interpolate(f, [sec(24), sec(26.5), sec(32.5), sec(34.5)], [1, 1.045, 1.045, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  const ai = interpolate(f, [sec(82.5), sec(85), sec(94), sec(96)], [1, 1.05, 1.05, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  return Math.max(norm, ai);
};

const Segments: React.FC = () => (
  <>
    {PHONE_SEGMENTS.map((seg, i) => {
      const from = sec(seg.w[0]);
      const len = sec(seg.w[1]) - from;
      if (seg.freeze) {
        return (
          <Sequence key={i} from={from} durationInFrames={len} layout="none">
            <Img
              src={staticFile("phone_end.png")}
              style={{ width: "100%", height: "100%", objectFit: "cover" }}
            />
          </Sequence>
        );
      }
      const srcDur = seg.s[1] - seg.s[0];
      const winDur = seg.w[1] - seg.w[0];
      const rate = srcDur / winDur;
      return (
        <Sequence key={i} from={from} durationInFrames={len} layout="none">
          <OffthreadVideo
            src={staticFile("screen.mp4")}
            muted
            trimBefore={sec(seg.s[0])}
            playbackRate={rate}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </Sequence>
      );
    })}
  </>
);

export const Phone: React.FC<{ cx: number; cy: number; island?: boolean }> = ({ cx, cy, island = true }) => {
  const zoom = useEmphasis();

  return (
    <div
      style={{
        position: "absolute",
        left: cx - BODY_W / 2,
        top: cy - BODY_H / 2,
        width: BODY_W,
        height: BODY_H,
      }}
    >
      {/* Metallic body */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 56,
          background: "#0d1116",
          boxShadow:
            "0 30px 70px rgba(16,50,36,0.28), 0 6px 18px rgba(16,50,36,0.16), inset 0 0 0 2px rgba(255,255,255,0.06), inset 0 0 0 7px #05070a",
        }}
      />
      {/* Side buttons */}
      <div style={{ position: "absolute", left: -3, top: 150, width: 4, height: 46, borderRadius: 3, background: "#20252c" }} />
      <div style={{ position: "absolute", left: -3, top: 210, width: 4, height: 78, borderRadius: 3, background: "#20252c" }} />
      <div style={{ position: "absolute", right: -3, top: 190, width: 4, height: 100, borderRadius: 3, background: "#20252c" }} />

      {/* Screen */}
      <div
        style={{
          position: "absolute",
          left: BEZEL,
          top: BEZEL,
          width: SCREEN_W,
          height: SCREEN_H,
          borderRadius: 42,
          overflow: "hidden",
          background: "#000",
        }}
      >
        <div style={{ position: "absolute", inset: 0, transform: `scale(${zoom})` }}>
          <Segments />
        </div>
        {/* Dynamic island (stat1 only — stat2 hides it) */}
        {island && (
          <div
            style={{
              position: "absolute",
              top: 16,
              left: "50%",
              transform: "translateX(-50%)",
              width: 108,
              height: 30,
              borderRadius: 18,
              background: "#000",
            }}
          />
        )}
      </div>
    </div>
  );
};

export const PHONE_LAYOUT = { BODY_W, BODY_H, SCREEN_W, SCREEN_H };
