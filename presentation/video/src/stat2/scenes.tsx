import React from "react";
import { AbsoluteFill, Sequence, Img, staticFile, useCurrentFrame, interpolate, Easing } from "remotion";
import { C, SCENES, sec } from "../theme";
import { Rise, Chip, Card, CountUp, Math, V, Op, Num, Frac, Donut, Bars, Lines } from "../lib";
import { Logo, Tag, Pill, PhotoCard, PhotoStatCard, DiseaseCircle, AIBackdrop, ImagePlate } from "./ui";
import { orbitron, rajdhani } from "./fonts";

// ---------------------------------------------------------------------------
// Shared bits — content is centered within the right panel
// ---------------------------------------------------------------------------

const Col: React.FC<{ children: React.ReactNode; gap?: number; style?: React.CSSProperties }> = ({
  children,
  gap = 30,
  style,
}) => (
  <div style={{ display: "flex", flexDirection: "column", gap, alignItems: "center", ...style }}>
    {children}
  </div>
);

const Title: React.FC<{ children: React.ReactNode; size?: number; style?: React.CSSProperties }> = ({
  children,
  size = 72,
  style,
}) => (
  <h1
    style={{
      fontFamily: orbitron,
      fontWeight: 800,
      fontSize: size,
      lineHeight: 1.08,
      letterSpacing: 0,
      color: C.ink,
      margin: 0,
      textAlign: "center",
      textWrap: "balance",
      ...style,
    }}
  >
    {children}
  </h1>
);

const num = (size: number, color = C.ink): React.CSSProperties => ({
  fontFamily: orbitron,
  fontWeight: 800,
  fontSize: size,
  color,
});

// ---------------------------------------------------------------------------
// 1 — Intro (app logo + "Eco health" + animated pills)
// ---------------------------------------------------------------------------
const SceneIntro: React.FC = () => {
  const pop = interpolate(useCurrentFrame(), [4, 22], [0.9, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  return (
    <Col gap={30}>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 8,
          transform: `scale(${pop})`,
        }}
      >
        <Logo size={224} />
        <div style={{ fontFamily: orbitron, fontWeight: 800, fontSize: 90, color: C.ink, lineHeight: 1 }}>
          Eco <span style={{ color: C.green }}>health</span>
        </div>
        <div style={{ fontFamily: rajdhani, fontWeight: 600, fontSize: 34, color: C.sub, marginTop: 4 }}>
          Salomatlik cho‘ntagingizda
        </div>
      </div>
      <Rise delay={22}>
        <Title size={52} style={{ maxWidth: 900 }}>
          Sog‘lom hayot sari <span style={{ color: C.lime }}>birinchi qadam</span>
        </Title>
      </Rise>
      <div style={{ display: "flex", gap: 18 }}>
        <Pill color={C.carb} delay={34}>Ovqatlanish</Pill>
        <Pill color={C.teal} delay={40}>Faollik</Pill>
        <Pill color={C.green} delay={46}>Salomatlik</Pill>
      </div>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 2 — All in one (real photo cards)   [kicker removed — in caption]
// ---------------------------------------------------------------------------
const SceneAllInOne: React.FC = () => (
  <Col gap={40}>
    <Rise>
      <Title size={68}>Barchasi bir joyda</Title>
    </Rise>
    <div style={{ display: "flex", gap: 26 }}>
      {[
        { src: "ovqatlanish2.jpg", t: "Ovqatlanish", s: "Kaloriya va makronutrientlar", pos: "center" },
        { src: "faollik.jpg", t: "Faollik", s: "Qadam va kaloriya", pos: "center" },
        { src: "salomatlik.jpg", t: "Salomatlik", s: "Vitamin va minerallar", pos: "center" },
      ].map((f, i) => (
        <PhotoCard
          key={i}
          src={f.src}
          title={f.t}
          subtitle={f.s}
          objectPosition={f.pos}
          delay={14 + i * 9}
          width={344}
          height={300}
        />
      ))}
    </div>
  </Col>
);

// ---------------------------------------------------------------------------
// 3 — Onboarding / personalization   [heading removed per request]
// ---------------------------------------------------------------------------
const SceneOnboarding: React.FC = () => {
  const rows = [
    { img: "boy_t.png", t: "Bo‘y", v: "178 sm" },
    { img: "vazn_t.png", t: "Vazn", v: "66 kg" },
    { img: "faollik_t.png", t: "Faollik darajasi", v: "O‘rta" },
    { img: "maqsad_t.png", t: "Maqsad", v: "Vazn saqlash" },
  ];
  return (
    <Col gap={28}>
      <Rise>
        <Title size={62}>
          Sizga <span style={{ color: C.green }}>moslashadi</span>
        </Title>
      </Rise>
      <Col gap={16} style={{ width: 680 }}>
        {rows.map((r, i) => (
          <Rise key={i} delay={12 + i * 10}>
            <Card pad={16} style={{ display: "flex", alignItems: "center", gap: 24, width: 680 }}>
              <Img
                src={staticFile(r.img)}
                style={{ width: 84, height: 84, objectFit: "contain", flexShrink: 0 }}
              />
              <div style={{ fontFamily: rajdhani, fontSize: 33, fontWeight: 600, color: C.ink, flex: 1 }}>{r.t}</div>
              <div style={{ ...num(31, C.lime) }}>{r.v}</div>
              <div
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: 999,
                  background: C.emerald,
                  color: C.panel,
                  display: "grid",
                  placeItems: "center",
                  fontWeight: 900,
                  fontSize: 24,
                }}
              >
                ✓
              </div>
            </Card>
          </Rise>
        ))}
      </Col>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 4 — BMR formula   [kicker removed — norm & Mifflin–St Jeor are in caption]
// ---------------------------------------------------------------------------
const SceneBMR: React.FC = () => (
  <Col gap={26}>
    <Rise>
      <Title size={58}>Asosiy almashinuv (BMR)</Title>
    </Rise>
    <Rise delay={10}>
      <Card style={{ padding: "30px 40px" }}>
        <Math size={62}>
          <V color={C.green}>BMR</V>
          <Op>=</Op>
          <Num>10</Num>
          <Op>·</Op>
          <V>m</V>
          <Op>+</Op>
          <Num>6.25</Num>
          <Op>·</Op>
          <V>h</V>
          <Op>−</Op>
          <Num>5</Num>
          <Op>·</Op>
          <V>a</V>
          <Op>+</Op>
          <V color={C.teal}>s</V>
        </Math>
        <div style={{ fontFamily: rajdhani, fontSize: 24, color: C.sub, marginTop: 18, lineHeight: 1.5 }}>
          <b style={{ color: C.ink }}>m</b> — vazn (kg) · <b style={{ color: C.ink }}>h</b> — bo‘y (sm) ·{" "}
          <b style={{ color: C.ink }}>a</b> — yosh · <b style={{ color: C.ink }}>s</b> = +5 (erkak) / −161 (ayol)
        </div>
      </Card>
    </Rise>
    <Rise delay={22} style={{ display: "flex", alignItems: "center", gap: 24 }}>
      <Lines
        width={700}
        height={250}
        delay={40}
        font={rajdhani}
        xRange={[50, 110]}
        yRange={[1000, 2500]}
        xTicks={[50, 70, 90, 110]}
        yTicks={[1000, 1500, 2000, 2500]}
        xTitle="Vazn (kg)"
        yTitle="kkal / kun"
        series={[
          { color: C.male, label: "Erkaklar", points: [[50, 1350], [110, 2350]] },
          { color: C.female, label: "Ayollar", dashed: true, points: [[50, 1150], [110, 1950]] },
        ]}
      />
      {/* fixed width + tabular figures → the counting number never resizes the
          row, so the chart no longer shifts/jitters while it counts up */}
      <div style={{ width: 250, flexShrink: 0 }}>
        <div style={{ fontFamily: rajdhani, fontSize: 26, color: C.sub }}>Natija</div>
        <div style={{ ...num(56, C.lime), fontVariantNumeric: "tabular-nums" }}>
          <CountUp to={2397} delay={40} /> <span style={{ fontSize: 28, color: C.sub, fontFamily: rajdhani }}>kkal</span>
        </div>
      </div>
    </Rise>
  </Col>
);

// ---------------------------------------------------------------------------
// 5 — Home dashboard (metric cards)   [kicker removed]
// ---------------------------------------------------------------------------
const SceneHome: React.FC = () => {
  const cards = [
    { src: "kaloriya.jpg", t: "Kaloriya", v: 2397, u: "kkal", pos: "center 58%" },
    { src: "suv.jpg", t: "Suv", v: 2400, u: "ml", pos: "center" },
    { src: "qadam.jpg", t: "Qadamlar", v: 8420, u: "", pos: "center 62%" },
    { src: "tana.jpg", t: "Tana", v: 66, u: "kg", pos: "center 46%" },
  ];
  return (
    <Col gap={30}>
      <Rise>
        <Title size={62}>Hammasi bir qarashda</Title>
      </Rise>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 26, width: 742 }}>
        {cards.map((c, i) => (
          <PhotoStatCard
            key={i}
            src={c.src}
            label={c.t}
            value={c.v}
            unit={c.u}
            objectPosition={c.pos}
            delay={14 + i * 8}
            width={358}
            height={200}
          />
        ))}
      </div>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 6 — Add food   [kicker removed — "Ovqat qo‘shish" is in caption]
// ---------------------------------------------------------------------------
const SceneAddFood: React.FC = () => (
  <Col gap={30}>
    <Rise>
      <Title size={60}>
        <span style={{ color: C.green }}>1000+</span> mahsulotdan tanlang
      </Title>
    </Rise>
    <Rise delay={14}>
      <Card pad={22} style={{ width: 640, display: "flex", alignItems: "center", gap: 18 }}>
        <div style={{ fontSize: 34 }}>🔍</div>
        <div style={{ fontFamily: rajdhani, fontSize: 32, color: C.ink, fontWeight: 600 }}>Tuxum omlet</div>
        <div style={{ marginLeft: "auto", ...num(28, C.lime) }}>154 <span style={{ fontSize: 22, fontFamily: rajdhani, color: C.sub }}>kkal</span></div>
      </Card>
    </Rise>
    <Rise delay={22}>
      <div style={{ fontFamily: rajdhani, fontSize: 28, color: C.sub, marginBottom: 4 }}>Porsiya hajmi</div>
    </Rise>
    <div style={{ display: "flex", gap: 18 }}>
      {[
        { t: "Kichik", s: "0.5×" },
        { t: "O‘rta", s: "1×", active: true },
        { t: "Katta", s: "1.5×" },
      ].map((p, i) => (
        <Rise key={i} delay={26 + i * 6}>
          <Card
            pad={24}
            style={{
              width: 190,
              textAlign: "center",
              background: p.active ? C.emerald : C.glass,
              border: p.active ? `1px solid ${C.lime}` : `1px solid ${C.glassBorder}`,
            }}
          >
            <div style={{ fontFamily: orbitron, fontWeight: 700, fontSize: 32, color: p.active ? C.panel : C.ink }}>{p.t}</div>
            <div style={{ fontFamily: rajdhani, fontSize: 26, color: p.active ? C.panel : C.sub, marginTop: 4 }}>{p.s}</div>
          </Card>
        </Rise>
      ))}
    </div>
  </Col>
);

// ---------------------------------------------------------------------------
// 7 — Macronutrients   [tag kept — not in caption]
// ---------------------------------------------------------------------------
const SceneMacros: React.FC = () => (
  <Col gap={22}>
    <Rise>
      <Tag size={34}>Makronutrientlar balansi • Atwater 4·4·9</Tag>
    </Rise>
    <div style={{ display: "flex", alignItems: "center", gap: 40 }}>
      <Rise delay={8}>
        <Donut
          size={320}
          delay={12}
          segments={[
            { value: 45, color: C.carb },
            { value: 30, color: C.protein },
            { value: 25, color: C.fat },
          ]}
          center={
            <>
              <div style={{ ...num(56) }}>
                <CountUp to={2581} delay={14} />
              </div>
              <div style={{ fontFamily: rajdhani, fontSize: 25, color: C.sub }}>kkal / kun</div>
            </>
          }
        />
      </Rise>
      <Col gap={22} style={{ alignItems: "flex-start" }}>
        {[
          { c: C.carb, t: "Uglevodlar", p: "45%", g: "290 g" },
          { c: C.protein, t: "Oqsillar", p: "30%", g: "194 g" },
          { c: C.fat, t: "Yog‘lar", p: "25%", g: "72 g" },
        ].map((m, i) => (
          <Rise key={i} delay={18 + i * 8} style={{ display: "flex", alignItems: "center", gap: 16 }}>
            <div style={{ width: 20, height: 20, borderRadius: 6, background: m.c }} />
            <div style={{ fontFamily: rajdhani, fontSize: 32, fontWeight: 600, color: C.ink, width: 210 }}>{m.t}</div>
            <div style={{ ...num(30, m.c) }}>{m.p}</div>
            <div style={{ fontFamily: rajdhani, fontSize: 27, color: C.sub }}>· {m.g}</div>
          </Rise>
        ))}
      </Col>
    </div>
    <Rise delay={34}>
      <Card style={{ padding: "22px 34px" }}>
        <Math size={40} style={{ gap: 40 }}>
          <span style={{ display: "flex", alignItems: "center" }}>
            <V color={C.carb}>C</V>
            <Op>=</Op>
            <Frac num={<><V>E</V><Op>·</Op><Num>0.45</Num></>} den={<Num>4</Num>} />
          </span>
          <span style={{ display: "flex", alignItems: "center" }}>
            <V color={C.protein}>P</V>
            <Op>=</Op>
            <Frac num={<><V>E</V><Op>·</Op><Num>0.30</Num></>} den={<Num>4</Num>} />
          </span>
          <span style={{ display: "flex", alignItems: "center" }}>
            <V color={C.fat}>F</V>
            <Op>=</Op>
            <Frac num={<><V>E</V><Op>·</Op><Num>0.25</Num></>} den={<Num>9</Num>} />
          </span>
        </Math>
      </Card>
    </Rise>
  </Col>
);

// ---------------------------------------------------------------------------
// 8 — Vitamins & minerals (big picture instead of the text list)
// ---------------------------------------------------------------------------
const SceneVitamins: React.FC = () => (
  <Col gap={30}>
    <Rise>
      <Title size={60}>
        <span style={{ color: C.lime }}>30+</span> vitamin va minerallar
      </Title>
    </Rise>
    <Rise delay={10}>
      <ImagePlate src="vitamini.png" width={600} delay={12} />
    </Rise>
    <Rise delay={24}>
      <div style={{ fontFamily: rajdhani, fontSize: 28, color: C.sub }}>
        Har bir taomdan keyin — avtomatik hisob-kitob.
      </div>
    </Rise>
  </Col>
);

// ---------------------------------------------------------------------------
// 9 — AI intro (AI backdrop + "AI assistent")   [robot + chip removed]
// ---------------------------------------------------------------------------
const SceneAIIntro: React.FC = () => {
  const pop = interpolate(useCurrentFrame(), [6, 24], [0.92, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  return (
    <>
      <AIBackdrop />
      <Col gap={22} style={{ position: "relative", transform: `scale(${pop})`, transformOrigin: "center" }}>
        <Title size={96}>
          AI <span style={{ color: C.teal }}>assistent</span>
        </Title>
        <div style={{ fontFamily: rajdhani, fontSize: 36, color: C.sub, maxWidth: 820, textAlign: "center" }}>
          Bir zumda ratsioningizni tahlil qiladi
        </div>
      </Col>
    </>
  );
};

// ---------------------------------------------------------------------------
// 10 — AI advice   [tag kept — not in caption]
// ---------------------------------------------------------------------------
const SceneAIAdvice: React.FC = () => (
  <Col gap={26}>
    <Rise>
      <Title size={56}>Aniq va shaxsiy maslahat</Title>
    </Rise>
    <div style={{ display: "flex", gap: 22 }}>
      <Rise delay={12}>
        <Card pad={28} style={{ width: 300 }}>
          <div style={{ fontFamily: rajdhani, fontSize: 27, color: C.sub }}>Kaloriya yetishmaydi</div>
          <div style={{ ...num(56, C.warn) }}>
            −<CountUp to={581} delay={16} /> <span style={{ fontSize: 26, color: C.sub, fontFamily: rajdhani }}>kkal</span>
          </div>
        </Card>
      </Rise>
      <Rise delay={20}>
        <Card pad={28} style={{ width: 300 }}>
          <div style={{ fontFamily: rajdhani, fontSize: 27, color: C.sub }}>Oqsil yetishmaydi</div>
          <div style={{ ...num(56, C.danger) }}>
            −<CountUp to={43} delay={24} /> <span style={{ fontSize: 26, color: C.sub, fontFamily: rajdhani }}>g</span>
          </div>
        </Card>
      </Rise>
    </div>
    <Rise delay={30}>
      <div style={{ fontFamily: rajdhani, fontSize: 27, color: C.sub, marginTop: 4 }}>Tavsiya etilgan mahsulotlar</div>
    </Rise>
    <div style={{ display: "flex", gap: 16 }}>
      {[
        { e: "🥚", t: "Tuxum" },
        { e: "🐟", t: "Baliq" },
        { e: "🫘", t: "Dukkakli mahsulotlar" },
      ].map((s, i) => (
        <Rise key={i} delay={36 + i * 7}>
          <Chip color={C.ink} bg={`${C.emerald}22`} style={{ fontSize: 30, padding: "16px 26px", fontFamily: rajdhani, fontWeight: 600 }}>
            {s.e} {s.t}
          </Chip>
        </Rise>
      ))}
      <Rise delay={57}>
        <Chip color={C.panel} bg={C.warn} style={{ fontSize: 30, padding: "16px 26px", fontFamily: rajdhani, fontWeight: 600 }}>
          🧈 Yog‘ — bir oz ortiqcha
        </Chip>
      </Rise>
    </div>
  </Col>
);

// ---------------------------------------------------------------------------
// 11 — AI vitamin advice   [tag kept — not in caption]
// ---------------------------------------------------------------------------
const SceneAIVitamins: React.FC = () => {
  const rows = [
    { t: "Temir", fix: "Jigar, dukkakli" },
    { t: "Vitamin D", fix: "Baliq, tuxum" },
    { t: "Kaliy", fix: "Banan, kartoshka" },
    { t: "Kalsiy", fix: "Sut, pishloq" },
  ];
  return (
    <Col gap={22}>
      <Rise>
        <Title size={54}>Nima yetishmasa — aytadi</Title>
      </Rise>
      <div style={{ display: "flex", alignItems: "center", gap: 44 }}>
        <Col gap={14} style={{ width: 520, alignItems: "stretch" }}>
          {rows.map((r, i) => (
            <Rise key={i} delay={12 + i * 7}>
              <Card pad={18} style={{ display: "flex", alignItems: "center", gap: 14, width: 520 }}>
                <div style={{ fontFamily: orbitron, fontSize: 25, fontWeight: 700, color: C.ink, width: 170 }}>{r.t}</div>
                <Chip color={C.panel} bg={C.warn} style={{ fontSize: 20, padding: "5px 14px", fontFamily: rajdhani, fontWeight: 600 }}>
                  Kam
                </Chip>
                <div style={{ fontFamily: rajdhani, fontSize: 24, color: C.sub, flex: 1 }}>→ {r.fix}</div>
              </Card>
            </Rise>
          ))}
        </Col>
        <DiseaseCircle src="kasallik.jpg" name="Kamqonlik (anemiya)" caption="Ehtimoliy oqibat" size={286} delay={20} />
      </div>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 12 — Steps & TDEE   [tag kept — not in caption]
// ---------------------------------------------------------------------------
const SceneSteps: React.FC = () => (
  <Col gap={22}>
    <Rise>
      <Tag size={40}>Kunlik energiya sarfi (TDEE)</Tag>
    </Rise>
    <Rise delay={6}>
      <Card style={{ padding: "22px 36px" }}>
        <Math size={52}>
          <V color={C.green}>TDEE</V>
          <Op>=</Op>
          <V>BMR</V>
          <Op>×</Op>
          <V color={C.teal}>PAL</V>
          <span style={{ fontFamily: rajdhani, fontSize: 34, color: C.sub, marginLeft: 24 }}>
            PAL ∈ {"{"} 1.2 ; 1.45 ; 1.725 {"}"}
          </span>
        </Math>
      </Card>
    </Rise>
    <Rise delay={16} style={{ display: "flex", alignItems: "flex-end", gap: 40 }}>
      <Bars
        width={560}
        height={330}
        max={3300}
        unit=""
        delay={18}
        font={rajdhani}
        data={[
          { label: "Past", note: "×1.2", value: 2136, color: "#9ca3af" },
          { label: "O‘rta", note: "×1.45", value: 2581, color: C.emerald },
          { label: "Yuqori", note: "×1.725", value: 3071, color: "#9ca3af" },
        ]}
      />
      <Col gap={16}>
        <PhotoStatCard
          src="qadamlar.jpg"
          label="Qadamlar"
          value={8420}
          objectPosition="center 62%"
          width={252}
          height={132}
          labelSize={22}
          numSize={38}
          pad={20}
          delay={22}
        />
        <PhotoStatCard
          src="yoqilgan.jpg"
          label="Yoqilgan"
          value={412}
          unit="kkal"
          objectPosition="center"
          width={252}
          height={132}
          labelSize={22}
          numSize={38}
          pad={20}
          delay={26}
        />
      </Col>
    </Rise>
  </Col>
);

// ---------------------------------------------------------------------------
// 13 — Outro (app logo + "Eco health")
// ---------------------------------------------------------------------------
const SceneOutro: React.FC = () => {
  const pop = interpolate(useCurrentFrame(), [4, 22], [0.9, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  return (
    <Col gap={28}>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 8,
          transform: `scale(${pop})`,
        }}
      >
        <Logo size={200} />
        <div style={{ fontFamily: orbitron, fontWeight: 800, fontSize: 86, color: C.ink, lineHeight: 1 }}>
          Eco <span style={{ color: C.green }}>health</span>
        </div>
      </div>
      <Rise delay={18}>
        <Title size={52}>
          Sog‘lom hayot sari <span style={{ color: C.lime }}>birinchi qadam</span>
        </Title>
      </Rise>
      <div style={{ display: "flex", gap: 18 }}>
        <Pill color={C.green} delay={30}>Bugun boshlang</Pill>
        <Pill color={C.teal} delay={36}>AI-yordamchi bilan</Pill>
      </div>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// Scene registry + shell (fade in/out)
// ---------------------------------------------------------------------------

const REGISTRY: Record<string, React.FC> = {
  intro: SceneIntro,
  allInOne: SceneAllInOne,
  onboarding: SceneOnboarding,
  bmr: SceneBMR,
  home: SceneHome,
  addFood: SceneAddFood,
  macros: SceneMacros,
  vitamins: SceneVitamins,
  aiIntro: SceneAIIntro,
  aiAdvice: SceneAIAdvice,
  aiVitamins: SceneAIVitamins,
  steps: SceneSteps,
  outro: SceneOutro,
};

const Shell: React.FC<{ len: number; children: React.ReactNode }> = ({ len, children }) => {
  const f = useCurrentFrame();
  const op = interpolate(f, [0, 12, len - 12, len], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.ease),
  });
  const slide = interpolate(f, [0, 14], [40, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  return (
    <AbsoluteFill
      style={{
        opacity: op,
        transform: `translateX(${slide}px)`,
        justifyContent: "center",
        alignItems: "center",
        padding: "0 20px",
      }}
    >
      {children}
    </AbsoluteFill>
  );
};

export const SidePanel: React.FC = () => (
  <>
    {SCENES.map((s) => {
      const from = sec(s.start);
      const len = sec(s.end) - sec(s.start);
      const Comp = REGISTRY[s.id];
      return (
        <Sequence key={s.id} from={from} durationInFrames={len} layout="none">
          <Shell len={len}>
            <Comp />
          </Shell>
        </Sequence>
      );
    })}
  </>
);
