import React from "react";
import {
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { loadFont as loadManrope } from "@remotion/google-fonts/Manrope";
import { loadFont as loadLora } from "@remotion/google-fonts/Lora";
import { C } from "./theme";

const fontOpts = { subsets: ["latin", "latin-ext"], ignoreTooManyRequestsWarning: true } as const;
export const manrope = loadManrope("normal", { weights: ["600", "700", "800"], ...fontOpts }).fontFamily;
loadLora("normal", { weights: ["500", "600"], ...fontOpts });
export const lora = loadLora("italic", { weights: ["500", "600"], ...fontOpts }).fontFamily;

// ---------------------------------------------------------------------------
// Animation helpers
// ---------------------------------------------------------------------------

/** Eased 0→1 progress that starts at `delay` frames and lasts `dur` frames. */
export const useReveal = (delay = 0, dur = 18) => {
  const frame = useCurrentFrame();
  return interpolate(frame, [delay, delay + dur], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
};

/** Springy pop 0→1 with a small overshoot. */
export const usePop = (delay = 0, damping = 14) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping, mass: 0.7, stiffness: 130 } });
};

/** Fade + rise wrapper. */
export const Rise: React.FC<{
  delay?: number;
  dur?: number;
  y?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ delay = 0, dur = 18, y = 26, children, style }) => {
  const p = useReveal(delay, dur);
  return (
    <div
      style={{
        opacity: p,
        transform: `translateY(${(1 - p) * y}px)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

// ---------------------------------------------------------------------------
// UI primitives
// ---------------------------------------------------------------------------

export const Chip: React.FC<{
  children: React.ReactNode;
  color?: string;
  bg?: string;
  style?: React.CSSProperties;
}> = ({ children, color = C.sub, bg = C.glass, style }) => (
  <span
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 10,
      padding: "10px 20px",
      borderRadius: 999,
      background: bg,
      border: `1px solid ${C.line}`,
      color,
      fontFamily: manrope,
      fontWeight: 600,
      fontSize: 26,
      whiteSpace: "nowrap",
      ...style,
    }}
  >
    {children}
  </span>
);

export const Card: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
  pad?: number;
}> = ({ children, style, pad = 34 }) => (
  <div
    style={{
      background: C.panel,
      border: `1px solid ${C.line}`,
      borderRadius: 30,
      padding: pad,
      boxShadow: C.shadow,
      ...style,
    }}
  >
    {children}
  </div>
);

export const Kicker: React.FC<{ children: React.ReactNode; color?: string }> = ({
  children,
  color = C.green,
}) => (
  <div
    style={{
      fontFamily: manrope,
      fontWeight: 800,
      letterSpacing: 3,
      textTransform: "uppercase",
      fontSize: 22,
      color,
      display: "flex",
      alignItems: "center",
      gap: 12,
    }}
  >
    <span style={{ width: 34, height: 3, background: color, borderRadius: 2 }} />
    {children}
  </div>
);

export const Title: React.FC<{ children: React.ReactNode; size?: number; style?: React.CSSProperties }> = ({
  children,
  size = 72,
  style,
}) => (
  <h1
    style={{
      fontFamily: manrope,
      fontWeight: 800,
      fontSize: size,
      lineHeight: 1.04,
      letterSpacing: -1.5,
      color: C.ink,
      margin: 0,
      ...style,
    }}
  >
    {children}
  </h1>
);

/** Count-up number. `to` reached over [delay, delay+dur]. */
export const CountUp: React.FC<{
  to: number;
  delay?: number;
  dur?: number;
  decimals?: number;
  suffix?: string;
  prefix?: string;
  style?: React.CSSProperties;
}> = ({ to, delay = 0, dur = 26, decimals = 0, suffix = "", prefix = "", style }) => {
  const frame = useCurrentFrame();
  const v = interpolate(frame, [delay, delay + dur], [0, to], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  return (
    <span style={style}>
      {prefix}
      {v.toLocaleString("en-US", {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
      })}
      {suffix}
    </span>
  );
};

// ---------------------------------------------------------------------------
// Math formula renderer (LaTeX-ish, native)
// ---------------------------------------------------------------------------

export const V: React.FC<{ children: React.ReactNode; color?: string }> = ({ children, color = C.ink }) => (
  <span style={{ fontFamily: lora, fontStyle: "italic", fontWeight: 600, color }}>{children}</span>
);

export const Op: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <span style={{ fontFamily: lora, margin: "0 0.28em", color: C.sub, fontWeight: 500 }}>{children}</span>
);

export const Num: React.FC<{ children: React.ReactNode; color?: string }> = ({ children, color = C.lime }) => (
  <span style={{ fontFamily: lora, fontWeight: 600, color }}>{children}</span>
);

/** Vertical fraction. */
export const Frac: React.FC<{ num: React.ReactNode; den: React.ReactNode }> = ({ num, den }) => (
  <span
    style={{
      display: "inline-flex",
      flexDirection: "column",
      alignItems: "center",
      verticalAlign: "middle",
      margin: "0 0.18em",
    }}
  >
    <span style={{ padding: "0 0.35em 0.08em" }}>{num}</span>
    <span style={{ height: 3, alignSelf: "stretch", background: C.faint, borderRadius: 2 }} />
    <span style={{ padding: "0.08em 0.35em 0" }}>{den}</span>
  </span>
);

export const Math: React.FC<{ children: React.ReactNode; size?: number; style?: React.CSSProperties }> = ({
  children,
  size = 56,
  style,
}) => (
  <div
    style={{
      fontFamily: lora,
      fontSize: size,
      color: C.ink,
      display: "flex",
      alignItems: "center",
      flexWrap: "wrap",
      lineHeight: 1.1,
      ...style,
    }}
  >
    {children}
  </div>
);

// ---------------------------------------------------------------------------
// Charts (animated SVG)
// ---------------------------------------------------------------------------

const polar = (cx: number, cy: number, r: number, aDeg: number) => {
  const a = ((aDeg - 90) * globalThis.Math.PI) / 180;
  return { x: cx + r * globalThis.Math.cos(a), y: cy + r * globalThis.Math.sin(a) };
};
const arcPath = (cx: number, cy: number, r: number, start: number, end: number) => {
  const s = polar(cx, cy, r, end);
  const e = polar(cx, cy, r, start);
  const large = end - start <= 180 ? 0 : 1;
  return `M ${s.x} ${s.y} A ${r} ${r} 0 ${large} 0 ${e.x} ${e.y}`;
};

export const Donut: React.FC<{
  size: number;
  segments: { value: number; color: string }[];
  delay?: number;
  center?: React.ReactNode;
}> = ({ size, segments, delay = 0, center }) => {
  const frame = useCurrentFrame();
  const grow = interpolate(frame, [delay, delay + 34], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  const total = segments.reduce((s, x) => s + x.value, 0);
  const r = size / 2 - 18;
  const cx = size / 2;
  const cy = size / 2;
  let acc = 0;
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: "rotate(0deg)" }}>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="#e7efe9" strokeWidth={34} />
        {segments.map((seg, i) => {
          const startAngle = (acc / total) * 360;
          acc += seg.value;
          const endAngle = (acc / total) * 360 * grow + startAngle * (1 - grow);
          return (
            <path
              key={i}
              d={arcPath(cx, cy, r, startAngle, globalThis.Math.max(startAngle + 0.001, endAngle))}
              fill="none"
              stroke={seg.color}
              strokeWidth={34}
              strokeLinecap="round"
            />
          );
        })}
      </svg>
      {center && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flexDirection: "column",
          }}
        >
          {center}
        </div>
      )}
    </div>
  );
};

export const Bars: React.FC<{
  width: number;
  height: number;
  data: { label: string; value: number; color: string; note?: string }[];
  max: number;
  delay?: number;
  unit?: string;
  font?: string;
}> = ({ width, height, data, max, delay = 0, unit = "", font = manrope }) => {
  const frame = useCurrentFrame();
  const gap = 40;
  const bw = (width - gap * (data.length - 1)) / data.length;
  const baseY = height - 64;
  const top = 40;
  return (
    <svg width={width} height={height} style={{ fontFamily: font }}>
      {data.map((d, i) => {
        const grow = interpolate(
          frame,
          [delay + i * 6, delay + i * 6 + 22],
          [0, 1],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) }
        );
        const full = ((baseY - top) * d.value) / max;
        const h = full * grow;
        const x = i * (bw + gap);
        const y = baseY - h;
        return (
          <g key={i}>
            <rect x={x} y={y} width={bw} height={h} rx={16} fill={d.color} />
            <text x={x + bw / 2} y={y - 16} fill={C.ink} fontSize={30} fontWeight={800} textAnchor="middle" opacity={grow}>
              {globalThis.Math.round(d.value).toLocaleString("en-US")}
              {unit}
            </text>
            <text x={x + bw / 2} y={baseY + 34} fill={C.sub} fontSize={24} fontWeight={700} textAnchor="middle">
              {d.label}
            </text>
            {d.note && (
              <text x={x + bw / 2} y={baseY + 62} fill={C.faint} fontSize={19} textAnchor="middle">
                {d.note}
              </text>
            )}
          </g>
        );
      })}
      <line x1={0} y1={baseY} x2={width} y2={baseY} stroke={C.line} strokeWidth={2} />
    </svg>
  );
};

/** Animated line chart (two series) with labelled axes — for BMR vs weight. */
export const Lines: React.FC<{
  width: number;
  height: number;
  series: { color: string; label: string; points: [number, number][]; dashed?: boolean }[];
  xRange: [number, number];
  yRange: [number, number];
  xTicks?: number[];
  yTicks?: number[];
  xTitle?: string;
  yTitle?: string;
  delay?: number;
  font?: string;
}> = ({ width, height, series, xRange, yRange, xTicks = [], yTicks = [], xTitle, yTitle, delay = 0, font = manrope }) => {
  const frame = useCurrentFrame();
  // steady left→right reveal so the chart "fills up in real time"
  const draw = interpolate(frame, [delay, delay + 54], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.linear,
  });
  const padL = 74; // room for y tick labels
  const padR = 150; // room for series end labels
  const padT = 22; // room for y-axis title
  const padB = 52; // room for x ticks + title
  const plotW = width - padL - padR;
  const plotH = height - padT - padB;
  const x0 = padL;
  const y0 = padT + plotH; // baseline
  const sx = (x: number) => x0 + ((x - xRange[0]) / (xRange[1] - xRange[0])) * plotW;
  const sy = (y: number) => padT + plotH - ((y - yRange[0]) / (yRange[1] - yRange[0])) * plotH;
  return (
    <svg width={width} height={height} style={{ fontFamily: font }}>
      {/* horizontal gridlines + y tick labels */}
      {yTicks.map((t, i) => (
        <g key={"y" + i}>
          <line x1={x0} y1={sy(t)} x2={x0 + plotW} y2={sy(t)} stroke="#e7efe9" strokeWidth={1.5} />
          <text x={x0 - 12} y={sy(t) + 7} fill={C.sub} fontSize={20} fontWeight={600} textAnchor="end">
            {t.toLocaleString("en-US")}
          </text>
        </g>
      ))}
      {/* axes */}
      <line x1={x0} y1={padT} x2={x0} y2={y0} stroke={C.faint} strokeWidth={2} />
      <line x1={x0} y1={y0} x2={x0 + plotW} y2={y0} stroke={C.faint} strokeWidth={2} />
      {/* x tick labels */}
      {xTicks.map((t, i) => (
        <text key={"x" + i} x={sx(t)} y={y0 + 30} fill={C.sub} fontSize={20} fontWeight={600} textAnchor="middle">
          {t}
        </text>
      ))}
      {/* axis titles */}
      {yTitle && (
        <text x={x0 - 4} y={padT - 6} fill={C.faint} fontSize={19} fontWeight={700} textAnchor="start">
          {yTitle}
        </text>
      )}
      {xTitle && (
        <text x={x0 + plotW / 2} y={y0 + 50} fill={C.faint} fontSize={19} fontWeight={700} textAnchor="middle">
          {xTitle}
        </text>
      )}
      {/* series — line + soft area fill, revealed left→right in real time */}
      <defs>
        <clipPath id="linesReveal">
          <rect x={x0} y={0} width={globalThis.Math.max(0, plotW * draw)} height={height} />
        </clipPath>
        {series.map((s, i) =>
          s.dashed ? null : (
            <linearGradient key={i} id={`linesArea${i}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={s.color} stopOpacity={0.26} />
              <stop offset="100%" stopColor={s.color} stopOpacity={0.02} />
            </linearGradient>
          )
        )}
      </defs>
      <g clipPath="url(#linesReveal)">
        {series.map((s, i) => {
          const line = s.points.map((p, j) => `${j === 0 ? "M" : "L"} ${sx(p[0])} ${sy(p[1])}`).join(" ");
          const first = s.points[0];
          const last = s.points[s.points.length - 1];
          const area = `${line} L ${sx(last[0])} ${y0} L ${sx(first[0])} ${y0} Z`;
          return (
            <g key={i}>
              {!s.dashed && <path d={area} fill={`url(#linesArea${i})`} />}
              <path
                d={line}
                fill="none"
                stroke={s.color}
                strokeWidth={5}
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeDasharray={s.dashed ? "2 14" : undefined}
              />
            </g>
          );
        })}
      </g>
      {/* end markers + labels (fade in as the fill reaches the right edge) */}
      {series.map((s, i) => {
        const last = s.points[s.points.length - 1];
        return (
          <g key={"lbl" + i} opacity={interpolate(draw, [0.75, 1], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })}>
            <circle cx={sx(last[0])} cy={sy(last[1])} r={7} fill={s.color} />
            <text x={sx(last[0]) + 14} y={sy(last[1]) + 7} fill={s.color} fontSize={22} fontWeight={800} textAnchor="start">
              {s.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
};
