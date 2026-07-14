// ---------------------------------------------------------------------------
// Eco Health — brand theme, timeline & captions  (LIGHT, flat / no gradients)
// ---------------------------------------------------------------------------

export const FPS = 30;

// New voice (voice-uz2.mp3) = 114.55s; outro spoken 110.86–114.3s (verified). Play full voice.
export const DURATION_S = 114.6;
export const DURATION_FRAMES = Math.round(DURATION_S * FPS);

export const VOICE_OFFSET_S = 0;

export const REC = { w: 1080, h: 2264, durationS: 120.3 };

export const sec = (s: number) => Math.round(s * FPS);

// --- Brand palette — light & flat ---
export const C = {
  bg: "#eef4ef", // flat page background (soft mint)
  bgAlt: "#e7f0e9",
  panel: "#ffffff", // cards
  panelSoft: "#f4f9f5",
  ink: "#123227", // primary text (near-black green)
  sub: "#4f7263", // muted text
  faint: "rgba(18,50,39,0.30)", // hairlines / fraction bars
  line: "#dce8e0", // borders
  green: "#0f9d63", // primary accent (accessible on white)
  emerald: "#0e9f6e",
  greenDark: "#0b7a4d",
  teal: "#0ea5a5",
  lime: "#2f9e2f", // "highlight" green — readable as bold text on light
  limeFill: "#7bd23f", // bright fill only (never small text)
  // macro colours (fills)
  carb: "#f59e0b",
  protein: "#3b82f6",
  fat: "#22c55e",
  male: "#2563eb",
  female: "#ec4899",
  warn: "#d97706",
  danger: "#e11d48",
  good: "#16a34a",
  shadow: "0 14px 40px rgba(16,60,40,0.10)",
  shadowSoft: "0 8px 24px rgba(16,60,40,0.08)",
  // light-theme aliases (cards read as solid white on the mint page)
  glass: "#ffffff",
  glassStrong: "#ffffff",
  glassBorder: "#dce8e0",
};

// --- Phone video segments: retime the recording to the (natural) voiceover ---
// w = wall-clock window on the composition timeline; s = source in/out (seconds).
// Playback rate is derived as (s1-s0)/(w1-w0). Dead "home-screen" filler is dropped.
export type PhoneSeg = { w: [number, number]; s: [number, number]; freeze?: boolean };
// Voice line starts (verified via transcription of voice-uz2.mp3):
// intro 0 · allInOne 5.80 · onboarding 12.52 · norm 22.28 · home 34.50 · food 40.50 ·
// autocalc 53.00 · vitamins 59.38 · AI-intro 71.40 · AI-advice 80.60 · AI-vitamins 96.00 ·
// steps 103.00 · outro 110.86 (voice ends 114.3).
export const PHONE_SEGMENTS: PhoneSeg[] = [
  { w: [0.0, 5.80], s: [0.58, 6.0] }, //    splash + language (skip launcher)   0.93x
  { w: [5.80, 22.28], s: [6.0, 16.0] }, //  onboarding forms (allInOne+quiz)    0.61x
  { w: [22.28, 34.50], s: [16.0, 26.0] }, // home w/ norm ring (norm voice)     0.82x
  { w: [34.50, 40.50], s: [26.0, 30.0] }, // home dashboard (home voice)        0.67x
  { w: [40.50, 53.00], s: [30.0, 45.0] }, // add food: omlet + portion          1.20x
  { w: [53.00, 59.38], s: [45.0, 52.0] }, // ring fills + summary               1.10x
  { w: [59.38, 71.40], s: [52.0, 66.0] }, // vitamin summary scroll             1.16x
  { w: [71.40, 80.60], s: [66.0, 77.0] }, // open AI + generating               1.20x
  { w: [80.60, 96.00], s: [77.0, 95.0] }, // AI advice lists                    1.17x
  { w: [96.00, 103.00], s: [95.0, 105.0] }, // AI advice cont. / AI vitamins    1.43x
  { w: [103.00, 110.86], s: [111.0, 120.0] }, // steps screen [cut src 105→111] 1.14x
  { w: [110.86, DURATION_S], s: [110.86, 110.86], freeze: true }, // outro — hold home hero
];

// --- Scene timeline (side panels), aligned to the phone + voice ---
export type SceneId =
  | "intro" | "allInOne" | "onboarding" | "bmr" | "home" | "addFood"
  | "macros" | "vitamins" | "aiIntro" | "aiAdvice" | "aiVitamins" | "steps" | "outro";

export const SCENES: { id: SceneId; start: number; end: number }[] = [
  { id: "intro", start: 0.0, end: 5.80 },
  { id: "allInOne", start: 5.80, end: 12.52 },
  { id: "onboarding", start: 12.52, end: 22.28 },
  { id: "bmr", start: 22.28, end: 34.50 },
  { id: "home", start: 34.50, end: 40.50 },
  { id: "addFood", start: 40.50, end: 53.00 },
  { id: "macros", start: 53.00, end: 59.38 },
  { id: "vitamins", start: 59.38, end: 71.40 },
  { id: "aiIntro", start: 71.40, end: 80.60 },
  { id: "aiAdvice", start: 80.60, end: 96.00 },
  { id: "aiVitamins", start: 96.00, end: 103.00 },
  { id: "steps", start: 103.00, end: 110.86 },
  { id: "outro", start: 110.86, end: DURATION_S },
];

// --- Captions (uzbek) — timed to the spoken words ---
export const CAPTIONS: { start: number; end: number; text: string }[] = [
  { start: 0.3, end: 5.80, text: "Salomatlik kichik odatlardan boshlanadi. Tanishing — Eco Health." },
  { start: 5.80, end: 12.52, text: "Ovqatlanish, faollik va salomatlik — barchasi bitta ilovada." },
  { start: 12.52, end: 22.28, text: "Bir necha savol: bo‘y, vazn, faollik darajasi va maqsad." },
  { start: 22.28, end: 34.50, text: "Eco Health kunlik normani hisoblaydi — Mifflin–St Jeor formulasi bo‘yicha." },
  { start: 34.50, end: 40.50, text: "Bosh ekranda hammasi bir joyda: kaloriya, tana, qadamlar va suv." },
  { start: 40.50, end: 53.00, text: "Ovqat qo‘shish oson: 1000+ mahsulotdan tanlang va porsiyani belgilang." },
  { start: 53.00, end: 59.38, text: "Kaloriya va barcha moddalar avtomatik hisoblanadi, norma real vaqtda to‘ladi." },
  { start: 59.38, end: 71.40, text: "Faqat kaloriya emas — o‘nlab vitamin va minerallar ham hisoblanadi." },
  { start: 71.40, end: 80.60, text: "Endi eng qizig‘i — sun’iy intellekt yordamchisi." },
  { start: 80.60, end: 96.00, text: "Aniq maslahat: 581 kkal va 43 g oqsil yetishmayapti — tuxum, baliq yoki dukkakli mahsulotlar qo‘shing." },
  { start: 96.00, end: 103.00, text: "AI har bir vitamin bo‘yicha nima yetishmasligini va nima bilan to‘ldirishni aytadi." },
  { start: 103.00, end: 110.86, text: "Qadamlar, sarflangan kaloriya va faollik vaqti — hammasi nazoratda." },
  // outro — no subtitle on the final slide (per request)
];
