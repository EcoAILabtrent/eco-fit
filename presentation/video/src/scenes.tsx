import React from "react";
import { AbsoluteFill, Sequence, useCurrentFrame, interpolate, Easing } from "remotion";
import { C, SCENES, sec } from "./theme";
import {
  Rise,
  Chip,
  Card,
  Kicker,
  Title,
  CountUp,
  Math,
  V,
  Op,
  Num,
  Frac,
  Donut,
  Bars,
  Lines,
  manrope,
  usePop,
} from "./lib";

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

const Col: React.FC<{ children: React.ReactNode; gap?: number; style?: React.CSSProperties }> = ({
  children,
  gap = 30,
  style,
}) => (
  <div style={{ display: "flex", flexDirection: "column", gap, alignItems: "flex-start", ...style }}>
    {children}
  </div>
);

const IconTile: React.FC<{ emoji: string; color: string; size?: number }> = ({ emoji, color, size = 92 }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: 24,
      display: "grid",
      placeItems: "center",
      fontSize: size * 0.5,
      background: `${color}22`,
      border: `1px solid ${color}55`,
    }}
  >
    {emoji}
  </div>
);

const Leaf: React.FC<{ size?: number }> = ({ size = 96 }) => (
  <svg width={size} height={size} viewBox="0 0 100 100">
    <circle cx="50" cy="50" r="46" fill={C.green} opacity="0.12" />
    <path
      d="M50 20 C30 30 24 52 30 72 C50 70 70 56 72 30 C64 30 56 33 50 40 C50 40 51 30 50 20 Z"
      fill={C.green}
    />
    <path d="M34 68 C42 56 54 46 66 40" stroke="#ffffff" strokeWidth="2.5" fill="none" strokeLinecap="round" />
  </svg>
);

// ---------------------------------------------------------------------------
// 1 — Intro
// ---------------------------------------------------------------------------
const SceneIntro: React.FC = () => {
  const pop = usePop(4);
  return (
    <Col gap={34}>
      <div style={{ display: "flex", alignItems: "center", gap: 24, transform: `scale(${pop})`, transformOrigin: "left" }}>
        <Leaf size={120} />
        <div>
          <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 84, color: C.ink, lineHeight: 1 }}>
            Eco <span style={{ color: C.green }}>Health</span>
          </div>
          <div style={{ fontFamily: manrope, fontWeight: 600, fontSize: 30, color: C.sub, marginTop: 8 }}>
            Salomatlik cho‘ntagingizda
          </div>
        </div>
      </div>
      <Rise delay={22}>
        <Title size={58} style={{ maxWidth: 900 }}>
          Sog‘lom hayot sari <span style={{ color: C.lime }}>birinchi qadam</span>
        </Title>
      </Rise>
      <Rise delay={34} style={{ display: "flex", gap: 16 }}>
        <Chip color={C.ink}>🥗 Ovqatlanish</Chip>
        <Chip color={C.ink}>🔥 Faollik</Chip>
        <Chip color={C.ink}>💚 Salomatlik</Chip>
      </Rise>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 2 — All in one
// ---------------------------------------------------------------------------
const SceneAllInOne: React.FC = () => (
  <Col gap={40}>
    <Rise>
      <Kicker>Bitta ilova</Kicker>
    </Rise>
    <Rise delay={6}>
      <Title size={66}>Barchasi bir joyda</Title>
    </Rise>
    <div style={{ display: "flex", gap: 26 }}>
      {[
        { e: "🍽️", t: "Ovqatlanish", s: "Kaloriya va BJU", c: C.carb },
        { e: "👟", t: "Faollik", s: "Qadam va kaloriya", c: C.teal },
        { e: "💚", t: "Salomatlik", s: "Vitamin va mineral", c: C.green },
      ].map((f, i) => (
        <Rise key={i} delay={14 + i * 8}>
          <Card style={{ width: 300 }}>
            <IconTile emoji={f.e} color={f.c} />
            <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 34, color: C.ink, marginTop: 20 }}>{f.t}</div>
            <div style={{ fontFamily: manrope, fontSize: 24, color: C.sub, marginTop: 6 }}>{f.s}</div>
          </Card>
        </Rise>
      ))}
    </div>
  </Col>
);

// ---------------------------------------------------------------------------
// 3 — Onboarding / personalization
// ---------------------------------------------------------------------------
const SceneOnboarding: React.FC = () => {
  const rows = [
    { e: "📏", t: "Bo‘y", v: "178 sm" },
    { e: "⚖️", t: "Vazn", v: "66 kg" },
    { e: "🏃", t: "Faollik darajasi", v: "O‘rta" },
    { e: "🎯", t: "Maqsad", v: "Vazn saqlash" },
  ];
  return (
    <Col gap={30}>
      <Rise>
        <Kicker>Sozlash • 1 daqiqa</Kicker>
      </Rise>
      <Rise delay={6}>
        <Title size={64}>
          Sizga <span style={{ color: C.green }}>moslashadi</span>
        </Title>
      </Rise>
      <Col gap={18} style={{ width: 640 }}>
        {rows.map((r, i) => (
          <Rise key={i} delay={16 + i * 10}>
            <Card pad={22} style={{ display: "flex", alignItems: "center", gap: 22, width: 640 }}>
              <div style={{ fontSize: 40 }}>{r.e}</div>
              <div style={{ fontFamily: manrope, fontSize: 30, fontWeight: 700, color: C.ink, flex: 1 }}>{r.t}</div>
              <div style={{ fontFamily: manrope, fontSize: 30, fontWeight: 800, color: C.lime }}>{r.v}</div>
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
// 4 — BMR formula (Mifflin–St Jeor)   ★ wow
// ---------------------------------------------------------------------------
const SceneBMR: React.FC = () => (
  <Col gap={26}>
    <Rise>
      <Kicker>Kunlik norma • Mifflin–St Jeor · 1990</Kicker>
    </Rise>
    <Rise delay={6}>
      <Title size={60}>Asosiy almashinuv (BMR)</Title>
    </Rise>
    <Rise delay={14}>
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
        <div style={{ fontFamily: manrope, fontSize: 22, color: C.sub, marginTop: 18, lineHeight: 1.6 }}>
          <b style={{ color: C.ink }}>m</b> — vazn (kg) · <b style={{ color: C.ink }}>h</b> — bo‘y (sm) ·{" "}
          <b style={{ color: C.ink }}>a</b> — yosh · <b style={{ color: C.ink }}>s</b> = +5 (erkak) / −161 (ayol)
        </div>
      </Card>
    </Rise>
    <Rise delay={26} style={{ display: "flex", alignItems: "center", gap: 24 }}>
      <Lines
        width={700}
        height={250}
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
      <div>
        <div style={{ fontFamily: manrope, fontSize: 24, color: C.sub }}>Natija</div>
        <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 56, color: C.lime }}>
          <CountUp to={2397} delay={30} /> <span style={{ fontSize: 28, color: C.sub }}>kkal</span>
        </div>
      </div>
    </Rise>
  </Col>
);

// ---------------------------------------------------------------------------
// 5 — Home dashboard
// ---------------------------------------------------------------------------
const SceneHome: React.FC = () => {
  const cards = [
    { e: "🔥", t: "Kaloriya", v: 2397, u: "kkal", c: C.carb },
    { e: "💧", t: "Suv", v: 2400, u: "ml", c: C.teal },
    { e: "👟", t: "Qadamlar", v: 8420, u: "", c: C.green },
    { e: "💪", t: "Tana", v: 66, u: "kg", c: C.protein },
  ];
  return (
    <Col gap={30}>
      <Rise>
        <Kicker>Bosh ekran</Kicker>
      </Rise>
      <Rise delay={6}>
        <Title size={64}>Hammasi bir qarashda</Title>
      </Rise>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 24, width: 660 }}>
        {cards.map((c, i) => (
          <Rise key={i} delay={14 + i * 8}>
            <Card pad={26} style={{ display: "flex", alignItems: "center", gap: 20 }}>
              <IconTile emoji={c.e} color={c.c} size={72} />
              <div>
                <div style={{ fontFamily: manrope, fontSize: 24, color: C.sub }}>{c.t}</div>
                <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 42, color: C.ink }}>
                  <CountUp to={c.v} delay={16 + i * 8} /> <span style={{ fontSize: 22, color: C.sub }}>{c.u}</span>
                </div>
              </div>
            </Card>
          </Rise>
        ))}
      </div>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 6 — Add food
// ---------------------------------------------------------------------------
const SceneAddFood: React.FC = () => (
  <Col gap={30}>
    <Rise>
      <Kicker>Ovqat qo‘shish</Kicker>
    </Rise>
    <Rise delay={6}>
      <Title size={62}>
        <span style={{ color: C.green }}>1000+</span> mahsulotdan tanlang
      </Title>
    </Rise>
    <Rise delay={14}>
      <Card pad={22} style={{ width: 640, display: "flex", alignItems: "center", gap: 18 }}>
        <div style={{ fontSize: 34 }}>🔍</div>
        <div style={{ fontFamily: manrope, fontSize: 30, color: C.ink, fontWeight: 600 }}>Tuxum omlet</div>
        <div style={{ marginLeft: "auto", fontFamily: manrope, fontSize: 26, color: C.lime, fontWeight: 700 }}>154 kkal</div>
      </Card>
    </Rise>
    <Rise delay={22}>
      <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub, marginBottom: 4 }}>Porsiya hajmi</div>
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
            <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 34, color: p.active ? C.panel : C.ink }}>{p.t}</div>
            <div style={{ fontFamily: manrope, fontSize: 26, color: p.active ? C.panel : C.sub, marginTop: 4 }}>{p.s}</div>
          </Card>
        </Rise>
      ))}
    </div>
  </Col>
);

// ---------------------------------------------------------------------------
// 7 — Macronutrients (Atwater)   ★ formula + donut
// ---------------------------------------------------------------------------
const SceneMacros: React.FC = () => (
  <Col gap={22}>
    <Rise>
      <Kicker>Makronutrientlar balansi • Atwater 4·4·9</Kicker>
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
              <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 56, color: C.ink }}>
                <CountUp to={2581} delay={14} />
              </div>
              <div style={{ fontFamily: manrope, fontSize: 24, color: C.sub }}>kkal / kun</div>
            </>
          }
        />
      </Rise>
      <Col gap={22}>
        {[
          { c: C.carb, t: "Uglevodlar", p: "45%", g: "290 g" },
          { c: C.protein, t: "Oqsillar", p: "30%", g: "194 g" },
          { c: C.fat, t: "Yog‘lar", p: "25%", g: "72 g" },
        ].map((m, i) => (
          <Rise key={i} delay={18 + i * 8} style={{ display: "flex", alignItems: "center", gap: 16 }}>
            <div style={{ width: 20, height: 20, borderRadius: 6, background: m.c }} />
            <div style={{ fontFamily: manrope, fontSize: 30, fontWeight: 700, color: C.ink, width: 210 }}>{m.t}</div>
            <div style={{ fontFamily: manrope, fontSize: 30, fontWeight: 800, color: m.c }}>{m.p}</div>
            <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub }}>· {m.g}</div>
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
// 8 — Vitamins & minerals
// ---------------------------------------------------------------------------
const SceneVitamins: React.FC = () => {
  const items = [
    "Temir", "Kaliy", "Kalsiy", "Magniy", "Rux", "Vitamin A",
    "Vitamin C", "Vitamin D", "Vitamin B12", "Folat", "Yod", "Omega-3",
  ];
  return (
    <Col gap={26}>
      <Rise>
        <Kicker>Ovqatlanish xulosasi</Kicker>
      </Rise>
      <Rise delay={6}>
        <Title size={62}>
          <span style={{ color: C.lime }}>40+</span> vitamin va mineral
        </Title>
      </Rise>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 16, maxWidth: 760 }}>
        {items.map((t, i) => (
          <Rise key={i} delay={12 + i * 4}>
            <Chip color={C.ink} style={{ fontSize: 28 }}>
              <span style={{ width: 12, height: 12, borderRadius: 999, background: C.green, display: "inline-block" }} />
              {t}
            </Chip>
          </Rise>
        ))}
      </div>
      <Rise delay={70}>
        <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub }}>
          Har bir taomdan keyin — avtomatik hisob-kitob.
        </div>
      </Rise>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 9 — AI intro
// ---------------------------------------------------------------------------
const SceneAIIntro: React.FC = () => {
  const pop = usePop(6);
  return (
    <Col gap={34}>
      <Rise>
        <Kicker color={C.teal}>Sun’iy intellekt</Kicker>
      </Rise>
      <div style={{ display: "flex", alignItems: "center", gap: 28, transform: `scale(${pop})`, transformOrigin: "left" }}>
        <div
          style={{
            width: 140,
            height: 140,
            borderRadius: 40,
            display: "grid",
            placeItems: "center",
            fontSize: 78,
            background: `${C.teal}18`,
            border: `1px solid ${C.teal}55`,
          }}
        >
          🤖
        </div>
        <div>
          <Title size={64}>AI-yordamchi</Title>
          <div style={{ fontFamily: manrope, fontSize: 30, color: C.sub, marginTop: 8 }}>
            Bir tugma bilan ratsioningizni tahlil qiladi
          </div>
        </div>
      </div>
      <Rise delay={24}>
        <Chip color={C.teal} bg={`${C.teal}18`}>⚡ Bir tugma bilan tahlil</Chip>
      </Rise>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 10 — AI advice   ★ wow
// ---------------------------------------------------------------------------
const SceneAIAdvice: React.FC = () => (
  <Col gap={26}>
    <Rise>
      <Kicker color={C.teal}>AI tavsiya • Shaxsiy nutritsiolog</Kicker>
    </Rise>
    <Rise delay={6}>
      <Title size={58}>Aniq va shaxsiy maslahat</Title>
    </Rise>
    <div style={{ display: "flex", gap: 22 }}>
      <Rise delay={12}>
        <Card pad={28} style={{ width: 300 }}>
          <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub }}>Kaloriya yetishmaydi</div>
          <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 56, color: C.warn }}>
            −<CountUp to={981} delay={16} /> <span style={{ fontSize: 26, color: C.sub }}>kkal</span>
          </div>
        </Card>
      </Rise>
      <Rise delay={20}>
        <Card pad={28} style={{ width: 300 }}>
          <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub }}>Oqsil yetishmaydi</div>
          <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 56, color: C.danger }}>
            −<CountUp to={123} delay={24} /> <span style={{ fontSize: 26, color: C.sub }}>g</span>
          </div>
        </Card>
      </Rise>
    </div>
    <Rise delay={30}>
      <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub, marginTop: 4 }}>Tavsiya etilgan mahsulotlar</div>
    </Rise>
    <div style={{ display: "flex", gap: 16 }}>
      {[
        { e: "🥚", t: "Tuxum" },
        { e: "🐟", t: "Baliq" },
        { e: "🫘", t: "Dukkakli" },
      ].map((s, i) => (
        <Rise key={i} delay={36 + i * 7}>
          <Chip color={C.ink} bg={`${C.emerald}22`} style={{ fontSize: 30, padding: "16px 26px" }}>
            {s.e} {s.t}
          </Chip>
        </Rise>
      ))}
      <Rise delay={57}>
        <Chip color={C.panel} bg={C.warn} style={{ fontSize: 30, padding: "16px 26px" }}>
          🧈 Yog‘ — bir oz ortiqcha
        </Chip>
      </Rise>
    </div>
  </Col>
);

// ---------------------------------------------------------------------------
// 11 — AI vitamin advice
// ---------------------------------------------------------------------------
const SceneAIVitamins: React.FC = () => {
  const rows = [
    { t: "Temir", fix: "Jigar, dukkakli", pct: 62 },
    { t: "Vitamin D", fix: "Baliq, tuxum", pct: 48 },
    { t: "Kaliy", fix: "Banan, kartoshka", pct: 71 },
    { t: "Kalsiy", fix: "Sut, pishloq", pct: 55 },
  ];
  return (
    <Col gap={26}>
      <Rise>
        <Kicker color={C.teal}>AI • nutrient tavsiyalari</Kicker>
      </Rise>
      <Rise delay={6}>
        <Title size={58}>Nima yetishmasa — aytadi</Title>
      </Rise>
      <Col gap={16} style={{ width: 720 }}>
        {rows.map((r, i) => {
          return (
            <Rise key={i} delay={14 + i * 9}>
              <Card pad={22} style={{ display: "flex", alignItems: "center", gap: 20, width: 720 }}>
                <div style={{ fontFamily: manrope, fontSize: 30, fontWeight: 800, color: C.ink, width: 160 }}>{r.t}</div>
                <Chip color={C.panel} bg={C.warn} style={{ fontSize: 22, padding: "6px 16px" }}>
                  Kam
                </Chip>
                <div style={{ fontFamily: manrope, fontSize: 26, color: C.sub, flex: 1 }}>→ {r.fix}</div>
              </Card>
            </Rise>
          );
        })}
      </Col>
    </Col>
  );
};

// ---------------------------------------------------------------------------
// 12 — Steps & TDEE   ★ formula
// ---------------------------------------------------------------------------
const SceneSteps: React.FC = () => (
  <Col gap={22}>
    <Rise>
      <Kicker>Faollik • Kunlik energiya sarfi (TDEE)</Kicker>
    </Rise>
    <Rise delay={6}>
      <Card style={{ padding: "22px 36px" }}>
        <Math size={52}>
          <V color={C.green}>TDEE</V>
          <Op>=</Op>
          <V>BMR</V>
          <Op>×</Op>
          <V color={C.teal}>PAL</V>
          <span style={{ fontSize: 34, color: C.sub, marginLeft: 24 }}>
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
        data={[
          { label: "Past", note: "×1.2", value: 2136, color: "#9ca3af" },
          { label: "O‘rta", note: "×1.45", value: 2581, color: C.emerald },
          { label: "Yuqori", note: "×1.725", value: 3071, color: "#9ca3af" },
        ]}
      />
      <Col gap={16}>
        <Card pad={22} style={{ width: 220 }}>
          <div style={{ fontFamily: manrope, fontSize: 22, color: C.sub }}>👟 Qadamlar</div>
          <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 42, color: C.ink }}>
            <CountUp to={8420} delay={22} />
          </div>
        </Card>
        <Card pad={22} style={{ width: 220 }}>
          <div style={{ fontFamily: manrope, fontSize: 22, color: C.sub }}>🔥 Yoqilgan</div>
          <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 42, color: C.carb }}>
            <CountUp to={412} delay={26} /> <span style={{ fontSize: 22, color: C.sub }}>kkal</span>
          </div>
        </Card>
      </Col>
    </Rise>
  </Col>
);

// ---------------------------------------------------------------------------
// 13 — Outro
// ---------------------------------------------------------------------------
const SceneOutro: React.FC = () => {
  const pop = usePop(4);
  return (
    <Col gap={30} style={{ alignItems: "flex-start" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 24, transform: `scale(${pop})`, transformOrigin: "left" }}>
        <Leaf size={110} />
        <div style={{ fontFamily: manrope, fontWeight: 800, fontSize: 82, color: C.ink }}>
          Eco <span style={{ color: C.green }}>Health</span>
        </div>
      </div>
      <Rise delay={18}>
        <Title size={58}>
          Sog‘lom hayot sari <span style={{ color: C.lime }}>birinchi qadam</span>
        </Title>
      </Rise>
      <Rise delay={30} style={{ display: "flex", gap: 16 }}>
        <Chip color={C.ink} bg={`${C.emerald}22`}>📲 Bugun boshlang</Chip>
        <Chip color={C.ink}>🤖 AI-yordamchi bilan</Chip>
      </Rise>
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
