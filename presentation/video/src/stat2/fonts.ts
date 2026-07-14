// Neonblade font pack — Orbitron (headings / numbers) + Rajdhani (body / UI).
// Both are Google Fonts, loaded the same way the rest of the project loads fonts.
import { loadFont as loadOrbitron } from "@remotion/google-fonts/Orbitron";
import { loadFont as loadRajdhani } from "@remotion/google-fonts/Rajdhani";

const opts = { subsets: ["latin"], ignoreTooManyRequestsWarning: true } as const;

const orb = loadOrbitron("normal", { weights: ["500", "600", "700", "800", "900"], ...opts }).fontFamily;
const raj = loadRajdhani("normal", { weights: ["400", "500", "600", "700"], ...opts }).fontFamily;

// Orbitron lacks a few punctuation glyphs (e.g. ‘ ) → fall back to Rajdhani, then sans.
export const orbitron = `${orb}, ${raj}, sans-serif`;
export const rajdhani = `${raj}, sans-serif`;
