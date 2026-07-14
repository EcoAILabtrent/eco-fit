import React from "react";
import { Img, staticFile, useCurrentFrame } from "remotion";
import { C } from "../theme";
import { usePop, useReveal, CountUp } from "../lib";
import { orbitron, rajdhani } from "./fonts";

const M = globalThis.Math;

// ---------------------------------------------------------------------------
// App logo — the bare Eco Health mark (transparent bg, no white tile/frame)
// ---------------------------------------------------------------------------
export const Logo: React.FC<{ size?: number; style?: React.CSSProperties }> = ({
  size = 128,
  style,
}) => (
  <Img
    src={staticFile("ecohealthlogo_t.png")}
    style={{
      width: size,
      height: size,
      objectFit: "contain",
      display: "block",
      filter: "drop-shadow(0 10px 22px rgba(16,60,40,0.16))",
      ...style,
    }}
  />
);

// ---------------------------------------------------------------------------
// Tag — kicker replacement: bigger, no leading dash (Orbitron heading font)
// ---------------------------------------------------------------------------
export const Tag: React.FC<{ children: React.ReactNode; color?: string; size?: number }> = ({
  children,
  color = C.green,
  size = 25,
}) => (
  <div
    style={{
      fontFamily: orbitron,
      fontWeight: 700,
      letterSpacing: 2,
      textTransform: "uppercase",
      fontSize: size,
      color,
      textAlign: "center",
    }}
  >
    {children}
  </div>
);

// ---------------------------------------------------------------------------
// Animated pill — white pill with a light running cyclically around the border
// ---------------------------------------------------------------------------
export const Pill: React.FC<{ children: React.ReactNode; color?: string; delay?: number }> = ({
  children,
  color = C.green,
  delay = 0,
}) => {
  const pop = usePop(delay);
  const f = useCurrentFrame();
  const float = M.sin((f - delay) / 26) * 3; // gentle continuous float
  const angle = (((f - delay) * 3.2) % 360 + 360) % 360; // running light around the border
  const bw = 3; // border thickness
  return (
    <span
      style={{
        position: "relative",
        display: "inline-flex",
        padding: bw,
        borderRadius: 999,
        // faint base ring + one bright travelling segment
        background: `conic-gradient(from ${angle}deg, ${color}22 0deg, ${color} 26deg, ${color}22 60deg, ${color}22 360deg)`,
        boxShadow: C.shadowSoft,
        opacity: pop,
        transform: `translateY(${(1 - pop) * 18 + float}px) scale(${0.9 + pop * 0.1})`,
      }}
    >
      <span
        style={{
          display: "inline-flex",
          alignItems: "center",
          padding: "13px 28px",
          borderRadius: 999,
          background: "#ffffff",
          color: C.ink,
          fontFamily: rajdhani,
          fontWeight: 700,
          fontSize: 30,
          letterSpacing: 0.4,
          whiteSpace: "nowrap",
        }}
      >
        {children}
      </span>
    </span>
  );
};

// ---------------------------------------------------------------------------
// Full-bleed photo card (real image background + legibility scrim + white title)
//   - staggered pop entrance + slow Ken-Burns zoom = "animation per card"
// ---------------------------------------------------------------------------
export const PhotoCard: React.FC<{
  src: string;
  title: string;
  subtitle: string;
  delay?: number;
  objectPosition?: string;
  width?: number;
  height?: number;
}> = ({ src, title, subtitle, delay = 0, objectPosition = "center", width = 344, height = 300 }) => {
  const pop = usePop(delay);
  const f = useCurrentFrame();
  const zoom = 1.06 + 0.03 * M.sin((f - delay) / 55); // slow, always-moving Ken Burns
  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: 28,
        overflow: "hidden",
        boxShadow: C.shadow,
        border: `1px solid ${C.line}`,
        opacity: pop,
        transform: `translateY(${(1 - pop) * 34}px) scale(${0.95 + pop * 0.05})`,
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition,
          transform: `scale(${zoom})`,
        }}
      />
      {/* scrim for text legibility (top + faint bottom) */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "linear-gradient(to bottom, rgba(6,20,14,0.66) 0%, rgba(6,20,14,0.22) 40%, rgba(6,20,14,0.04) 64%, rgba(6,20,14,0.34) 100%)",
        }}
      />
      <div style={{ position: "absolute", left: 26, right: 20, top: 22 }}>
        <div
          style={{
            fontFamily: orbitron,
            fontWeight: 800,
            fontSize: 33,
            color: "#ffffff",
            letterSpacing: 0.5,
            textShadow: "0 2px 12px rgba(0,0,0,0.55)",
          }}
        >
          {title}
        </div>
        <div
          style={{
            fontFamily: rajdhani,
            fontWeight: 600,
            fontSize: 25,
            color: "rgba(255,255,255,0.94)",
            marginTop: 4,
            textShadow: "0 2px 10px rgba(0,0,0,0.55)",
          }}
        >
          {subtitle}
        </div>
      </div>
    </div>
  );
};

// ---------------------------------------------------------------------------
// Photo stat card — real image background + scrim + label + big number
//   (home dashboard metrics). Left-heavy scrim keeps the number crisp.
// ---------------------------------------------------------------------------
export const PhotoStatCard: React.FC<{
  src: string;
  label: string;
  value: number;
  unit?: string;
  delay?: number;
  objectPosition?: string;
  width?: number;
  height?: number;
  labelSize?: number;
  numSize?: number;
  pad?: number;
}> = ({
  src,
  label,
  value,
  unit = "",
  delay = 0,
  objectPosition = "center",
  width = 358,
  height = 200,
  labelSize = 26,
  numSize = 46,
  pad = 26,
}) => {
  const pop = usePop(delay);
  const f = useCurrentFrame();
  const zoom = 1.06 + 0.03 * M.sin((f - delay) / 55);
  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: 24,
        overflow: "hidden",
        boxShadow: C.shadow,
        border: `1px solid ${C.line}`,
        opacity: pop,
        transform: `translateY(${(1 - pop) * 30}px) scale(${0.95 + pop * 0.05})`,
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition,
          transform: `scale(${zoom})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "linear-gradient(100deg, rgba(6,20,14,0.80) 0%, rgba(6,20,14,0.52) 42%, rgba(6,20,14,0.14) 100%)",
        }}
      />
      <div style={{ position: "absolute", left: pad, top: pad - 2, right: 14 }}>
        <div
          style={{
            fontFamily: rajdhani,
            fontWeight: 600,
            fontSize: labelSize,
            color: "rgba(255,255,255,0.92)",
            textShadow: "0 2px 8px rgba(0,0,0,0.5)",
          }}
        >
          {label}
        </div>
        <div
          style={{
            fontFamily: orbitron,
            fontWeight: 800,
            fontSize: numSize,
            color: "#ffffff",
            marginTop: 4,
            textShadow: "0 2px 10px rgba(0,0,0,0.55)",
          }}
        >
          <CountUp to={value} delay={delay + 4} />{" "}
          {unit && <span style={{ fontSize: numSize * 0.46, fontWeight: 600, fontFamily: rajdhani }}>{unit}</span>}
        </div>
      </div>
    </div>
  );
};

// ---------------------------------------------------------------------------
// Disease circle — a possible consequence of the shown deficiencies
// ---------------------------------------------------------------------------
export const DiseaseCircle: React.FC<{
  src: string;
  name: string;
  caption?: string;
  size?: number;
  delay?: number;
}> = ({ src, name, caption = "Ehtimoliy oqibat", size = 300, delay = 0 }) => {
  const pop = usePop(delay);
  const f = useCurrentFrame();
  const pulse = 1 + 0.02 * M.sin((f - delay) / 20);
  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 16,
        opacity: pop,
        transform: `translateY(${(1 - pop) * 26}px) scale(${(0.94 + pop * 0.06) * pulse})`,
      }}
    >
      <div
        style={{
          fontFamily: rajdhani,
          fontWeight: 700,
          fontSize: 24,
          letterSpacing: 1.5,
          textTransform: "uppercase",
          color: C.danger,
        }}
      >
        ⚠ {caption}
      </div>
      <div
        style={{
          width: size,
          height: size,
          borderRadius: "50%",
          overflow: "hidden",
          background: "#ffffff",
          boxShadow: `0 0 0 6px ${C.danger}22, 0 0 0 12px ${C.danger}12, ${C.shadow}`,
          border: `3px solid ${C.danger}`,
        }}
      >
        <Img
          src={staticFile(src)}
          style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: "center 30%" }}
        />
      </div>
      <div
        style={{
          fontFamily: orbitron,
          fontWeight: 800,
          fontSize: 30,
          color: C.ink,
          textAlign: "center",
          maxWidth: size + 120,
          lineHeight: 1.1,
        }}
      >
        {name}
      </div>
    </div>
  );
};

// ---------------------------------------------------------------------------
// Themed picture-background card (fallback / gradient cards)
// ---------------------------------------------------------------------------
export const ThemeCard: React.FC<{
  tint: string;
  emoji: string;
  delay?: number;
  width?: number;
  height?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ tint, emoji, delay = 0, width = 344, height = 264, children, style }) => {
  const pop = usePop(delay);
  const f = useCurrentFrame();
  const breathe = 1 + 0.05 * (0.5 + 0.5 * M.sin((f - delay) / 30));
  const drift = M.sin((f - delay) / 34) * 5;
  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: 32,
        overflow: "hidden",
        background: `linear-gradient(150deg, ${tint}1f 0%, #ffffff 62%)`,
        border: `1px solid ${tint}33`,
        boxShadow: C.shadow,
        opacity: pop,
        transform: `translateY(${(1 - pop) * 34}px) scale(${0.94 + pop * 0.06})`,
        ...style,
      }}
    >
      <div
        style={{
          position: "absolute",
          right: -70,
          top: -70,
          width: 240,
          height: 240,
          borderRadius: "50%",
          background: tint,
          opacity: 0.16,
          filter: "blur(24px)",
        }}
      />
      <div
        style={{
          position: "absolute",
          right: -6,
          bottom: -22,
          fontSize: height * 0.62,
          lineHeight: 1,
          opacity: 0.2,
          transform: `translateY(${drift}px) scale(${breathe})`,
          filter: "saturate(1.1)",
        }}
      >
        {emoji}
      </div>
      <div style={{ position: "relative", padding: 30, height: "100%", boxSizing: "border-box" }}>
        {children}
      </div>
    </div>
  );
};

// ---------------------------------------------------------------------------
// AI backdrop — generated AI image, melted into the page bg on the left/edges
// so the heading sits over clean space and the network shows on the right.
// ---------------------------------------------------------------------------
export const AIBackdrop: React.FC = () => {
  const f = useCurrentFrame();
  const appear = useReveal(0, 26);
  const zoom = 1.04 + 0.03 * M.sin(f / 90); // subtle slow drift
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", opacity: appear }}>
      <Img
        src={staticFile("ai_bg.jpg")}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: "right center",
          transform: `scale(${zoom})`,
        }}
      />
      {/* fade the left/centre into the page bg → clean area for the centered heading */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `linear-gradient(to right, ${C.bg} 0%, ${C.bg}dd 24%, ${C.bg}66 44%, ${C.bg}00 60%)`,
        }}
      />
      {/* soft top/bottom fade so the image melts into the page */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `linear-gradient(to bottom, ${C.bg} 0%, ${C.bg}00 12%, ${C.bg}00 88%, ${C.bg} 100%)`,
        }}
      />
    </div>
  );
};

// ---------------------------------------------------------------------------
// Big image plate — a framed picture (used for the vitamins image)
// ---------------------------------------------------------------------------
export const ImagePlate: React.FC<{ src: string; width: number; delay?: number; style?: React.CSSProperties }> = ({
  src,
  width,
  delay = 0,
  style,
}) => {
  const pop = usePop(delay);
  return (
    <div
      style={{
        background: "#ffffff",
        borderRadius: 30,
        padding: 22,
        boxShadow: C.shadow,
        border: `1px solid ${C.line}`,
        opacity: pop,
        transform: `translateY(${(1 - pop) * 30}px) scale(${0.96 + pop * 0.04})`,
        ...style,
      }}
    >
      <Img src={staticFile(src)} style={{ width, display: "block", objectFit: "contain" }} />
    </div>
  );
};

// ---------------------------------------------------------------------------
// Bare image — a transparent PNG shown with just a soft drop shadow (no frame)
// ---------------------------------------------------------------------------
export const BareImage: React.FC<{ src: string; width: number; delay?: number; style?: React.CSSProperties }> = ({
  src,
  width,
  delay = 0,
  style,
}) => {
  const pop = usePop(delay);
  return (
    <Img
      src={staticFile(src)}
      style={{
        width,
        display: "block",
        objectFit: "contain",
        opacity: pop,
        transform: `translateY(${(1 - pop) * 30}px) scale(${0.96 + pop * 0.04})`,
        filter: "drop-shadow(0 18px 32px rgba(16,60,40,0.20))",
        ...style,
      }}
    />
  );
};

export { orbitron, rajdhani };
