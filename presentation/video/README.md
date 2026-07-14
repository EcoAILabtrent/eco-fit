# Eco Health — video presentation (Remotion)

Video montage for the Eco Health app: the phone screen recording is placed inside a
realistic phone mockup on the left, and animated content panels (formulas, charts,
captions) play on the right — synced to the Uzbek voiceover.

- **Output:** `out/eco-health-promo.mp4` (1920×1080, 30 fps, ~124 s, H.264)
- **Composition id:** `EcoHealthPromo`

## Commands

```bash
npm run dev       # open Remotion Studio (live preview + scrubbing)
npm run render    # render out/eco-health-promo.mp4
npm run probe     # print source video/audio duration & dimensions
```

Render a single frame to check a moment:
```bash
npx remotion still src/index.ts EcoHealthPromo out/test.png --frame=810
```

## Assets (`public/`)
- `screen.mp4` — the phone screen recording (1080×2264, muted in the video)
- `voice.mp3`  — Uzbek voiceover (this is the master audio)
- `bmr.jpeg`, `tdee.jpeg`, `macros.jpeg` — the original infographics (reference only;
  the formulas/charts are re-drawn natively in `src/scenes.tsx`)

## Sync model (important)

The **voiceover is the master** and plays at natural speed. The **phone recording is
re-timed** to match it via `PHONE_SEGMENTS` in `src/theme.ts`:

```
{ w: [wallStart, wallEnd], s: [srcIn, srcOut] }   // playbackRate = (srcOut-srcIn)/(wallEnd-wallStart)
```

Each entry plays source seconds `srcIn..srcOut` during composition seconds `wallStart..wallEnd`,
so slow sections (onboarding, the ring "filling live") are slowed and long scrolls (vitamin
list, AI advice) are sped up. Dead home-screen filler is dropped (one hard cut, src 105→111,
to reach the steps screen on the "qadamlar" line). The last entry `freeze: true` holds
`public/phone_end.png` for the outro.

The composition seconds come from **transcribing the voiceover** (`node transcribe.mjs`,
Whisper via `@huggingface/transformers`). Verified line starts:
intro 0 · setup 6.1 · onboarding 14.1 · norm 26 · **home 39** · food 45.4 · autocalc 59.3 ·
**vitamins 66** · AI-intro 79.75 · AI-advice 89.4 · AI-vitamins 103.4 · **steps 112** ·
**outro 119.6–123.6**.

To re-sync a moment: find when the phone should show something (source seconds via
`npm run probe` / a still) and when the voice says it (composition seconds), then edit that
segment's `w`/`s`. `SCENES` and `CAPTIONS` (also in `theme.ts`) use the same composition
seconds — keep them aligned to the segment windows.

## Other tweaks
- **Colours / brand:** the `C` object in `src/theme.ts` (light, flat — no gradients).
- **Captions:** `CAPTIONS` in `src/theme.ts` (start/end seconds + text).
- **Phone size/position:** `SCREEN_H` in `src/Phone.tsx`, `cx/cy` in `src/EcoHealthPromo.tsx`.
- **A scene's content:** each scene is a component in `src/scenes.tsx`.

## Notes
- Fonts (Manrope, Lora) are pulled from Google Fonts at render time → needs internet.
- `ffmpeg`/`ffprobe` come from the `ffmpeg-static` / `ffprobe-static` packages (see
  `npm run` helpers); no system ffmpeg needed.
