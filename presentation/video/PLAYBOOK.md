# 🎬 PLAYBOOK — how to build the Eco Health promo video (fast, high quality)

**Read this first when the user sends a new screen recording + voiceover.** It captures the
whole pipeline, the exact commands, the design system, and — most importantly — the
**synchronization method** and the mistakes already made and fixed. Follow it and you can
reproduce a polished, perfectly-synced 2K video without re-discovering anything.

Project lives in `C:\Project\EcoHealth\presentation\video\` (Remotion). The **code/components
are reusable**; usually only the assets, timings, and panel numbers change per job.

---

## 0. TL;DR — the loop

1. Drop `screen.mp4`, `voice.mp3` (and any infographics) into `public/`.
2. `npm install` → run the 3 blocked postinstalls (esbuild, ffmpeg-static, onnxruntime-node).
3. **Probe** durations/dims (`node probe.mjs`).
4. **Map the phone recording** timeline (scene-detect + contact sheet).
5. **Transcribe the voiceover with timestamps** (`node transcribe.mjs`) → get real line start times. *This is the crux — never guess timings.*
6. Edit `src/theme.ts`: `PHONE_SEGMENTS`, `SCENES`, `CAPTIONS`, `DURATION_S`.
7. **Verify with stills at every spoken-line moment** (phone screen must match caption+panel).
8. Render 2K: `--scale=1.5`.

The finished file is `out/eco-health-promo.mp4` (2880×1620, ~124 s, H.264 + voice).

### Variants (stat1 / stat2)
`src/Root.tsx` now registers **two** compositions:
- **`stat1`** — the original baseline cut (`src/EcoHealthPromo.tsx` + `src/scenes.tsx` + `Phone` with island). Rendered to `out/stat1.mp4`.
- **`stat2`** — the edited variant (`src/stat2/` = `Promo.tsx` + `scenes.tsx` + `ui.tsx`; reuses `theme.ts`, `lib.tsx`, and `Phone` with `island={false}`). Rendered to `out/stat2.mp4`.

The composition **id changed from `EcoHealthPromo` → `stat1`/`stat2`** — use those ids in `remotion still` / `remotion render`. stat2 differences: no top brand mark, app-logo tile + lowercase "Eco health" in intro/outro, borderless **typewriter** captions raised to phone-bottom level, no phone dynamic island, kickers de-duplicated (`ui.Tag`, no dash), **neonblade fonts** (`stat2/fonts.ts` = Orbitron headings + Rajdhani body via @remotion/google-fonts), full-bleed **photo** cards on all-in-one (`ui.PhotoCard`) and home (`ui.PhotoStatCard`), `vitamini.png` on the vitamins slide, and the AI slide is a photo backdrop (`ui.AIBackdrop` → `ai_bg.jpg`, robot tile + chip removed). New assets in `public/`: `ecohealthlogo.png`, `vitamini.png`, `ovqatlanish.jpg`, `faollik.jpg`, `salomatlik.jpg`, `kaloriya.jpg`, `suv.jpg`, `qadam.jpg`, `tana.jpg`, `ai_bg.jpg`.
Batch stills from one bundle: `node stills.mjs stat2 <frame> <frame> …` → `out/stat2_stills/`.

---

## 1. Environment gotchas (this machine)

- **npm blocks postinstall scripts.** After `npm install`, run manually:
  ```bash
  node node_modules/esbuild/install.js                 # Remotion bundler needs this
  node node_modules/ffmpeg-static/install.js            # ffmpeg.exe
  node node_modules/onnxruntime-node/script/install.js  # whisper (transformers.js) native binary
  ```
- **No system ffmpeg/ffprobe.** Use the package binaries:
  - `node_modules/ffmpeg-static/ffmpeg.exe`
  - `node_modules/ffprobe-static/bin/win32/x64/ffprobe.exe`
  In scripts I set `FF=node_modules/ffmpeg-static/ffmpeg.exe`.
- **Transcription:** Python here is 3.14 → too new for Whisper/torch wheels. Use
  **`@huggingface/transformers`** in Node instead (see `transcribe.mjs`). Model `Xenova/whisper-small`,
  `language: "uzbek"`, `return_timestamps: true`.
- **Fonts** (Manrope + Lora) come from Google Fonts **at render time → needs internet.**
- **@remotion/media-parser** prints a license note — pass `acknowledgeRemotionLicense: true`.
- Shell is Git Bash; paths with spaces/parentheses need quoting.

---

## 2. Project structure

```
presentation/video/
  package.json           deps: remotion@4.0.370, @remotion/{cli,google-fonts,shapes,media-parser},
                               react@19, ffmpeg-static, ffprobe-static, @huggingface/transformers, typescript
  remotion.config.ts     jpeg quality 100, codec h264, CRF 16, overwrite
  probe.mjs              prints source video/audio duration + dimensions (media-parser)
  transcribe.mjs         Whisper (transformers.js) → TSV of [start, end, text]
  src/
    index.ts             registerRoot(RemotionRoot)
    Root.tsx             <Composition id="stat1"> + <Composition id="stat2">  (1920x1080 30fps, DURATION_FRAMES)
    theme.ts             ★ ALL TUNABLES: FPS, DURATION_S, palette C, PHONE_SEGMENTS, SCENES, CAPTIONS (shared)
    lib.tsx              fonts + anim helpers + UI + Formula renderer + charts (Donut/Bars/Lines-with-axes) (shared)
    Phone.tsx            phone frame + segmented OffthreadVideo playback + emphasis zoom + freeze outro; island? prop
    scenes.tsx           stat1: 13 scene components + SidePanel switcher + Shell (fade in/out)
    EcoHealthPromo.tsx   stat1 composition: Background, Phone, SidePanel, BrandMark, Captions, ProgressBar, Audio
    stat2/               edited variant: Promo.tsx (no brand mark, typewriter captions) + scenes.tsx + ui.tsx
  public/
    screen.mp4  voice.mp3  phone_end.png  ecohealthlogo.png  vitamini.png  (+ bmr/tdee/macros.jpeg reference only)
  out/                   renders, stills, transcript, contact sheet (gitignored)
```

Composition is authored at **1920×1080 @ 30fps**; final quality comes from rendering at
`--scale=1.5` → **2880×1620 (2K)**. Never change the composition dims (layout is in absolute
1920×1080 coords) — scale up at render time instead.

---

## 3. The synchronization method  ★★★ (this is what makes it good)

**Voiceover is the master and plays at natural speed, untouched** (audio is what viewers
scrutinize most). The **phone recording is re-timed** to land the right screen under each
spoken line. Panels + captions follow the voice.

`PHONE_SEGMENTS` in `theme.ts` — each entry:
```ts
{ w: [wallStart, wallEnd], s: [srcIn, srcOut] }   // playbackRate = (srcOut-srcIn)/(wallEnd-wallStart)
```
plays source seconds `srcIn..srcOut` during composition seconds `wallStart..wallEnd`.
Rules that worked:
- **Chain the source** so `srcOut` of one segment = `srcIn` of the next → seamless. A deliberate
  jump (skip dead filler) is fine; keep it to **one clean cut**.
- **Slow (down to ~0.5×)** where the voice lingers on a near-static screen (onboarding forms, the
  calorie ring "filling live"). Static screens tolerate slow-mo well.
- **Speed up (up to ~1.7×)** long repetitive scrolls (vitamin/mineral list, AI advice list).
- **Drop dead "home-screen" filler** between sections.
- `freeze: true` on the last entry → shows `public/phone_end.png` (a clean hero frame you extract)
  for the outro, since recordings usually end abruptly.
- Keep playback rate roughly in **[0.5, 1.7]**; beyond that it looks off.

**Landmarks that MUST line up** (if these hit, it feels synced even if between-bits drift ~1 s):
daily-norm/ring, add-food, vitamins/minerals summary, AI assistant open, AI advice, steps.

`SCENES` (right-panel content) and `CAPTIONS` use the **same wall-clock seconds** — keep all
three arrays aligned to the segment windows.

### Mistakes already made — do NOT repeat
1. **Never derive voice timings from silence gaps alone.** I did, and was **8–10 s off** in the
   second half. Always transcribe. Silence detection is only a *secondary* aid to split lines that
   the transcript merged.
2. **Set `DURATION_S` to the full spoken length.** I once cut it at 120.5 s and truncated the
   outro (real outro was 119.6–123.6 s). Check where speech actually ends in the transcript.
3. **Caption must not overlap the phone.** Keep it in the right column (`left: 690, right: 40`).
4. **Charts need labeled axes** (ticks + titles). A bare line chart reads as "axes missing".
5. **Background:** light, flat, **no gradients, no thin stroked shapes** — a 2px outlined circle
   near the phone read as a "hair on the screen". Use soft *blurred filled* blobs + a phone halo.
6. **Verify with stills at each spoken-line moment before the full render.** Confirm the phone
   screen matches the caption/panel at that instant.

---

## 4. Step-by-step

### 4.1 Assets + install
Copy new files into `public/` as `screen.mp4`, `voice.mp3`. Then:
```bash
cd C:/Project/EcoHealth/presentation/video
npm install
node node_modules/esbuild/install.js
node node_modules/ffmpeg-static/install.js
node node_modules/onnxruntime-node/script/install.js
```

### 4.2 Probe
```bash
node probe.mjs        # prints VIDEO {dimensions,fps,durationInSeconds} + VOICE {durationInSeconds}
```
Note the video dims (portrait phone, e.g. 1080×2264 → aspect 0.477) and both durations.
If aspect differs, update `SCREEN_W = round(SCREEN_H * w/h)` in `Phone.tsx`.

### 4.3 Map the phone recording (what screen is shown when)
```bash
FF=node_modules/ffmpeg-static/ffmpeg.exe
# scene-change timestamps:
"$FF" -i public/screen.mp4 -filter:v "select='gt(scene,0.22)',showinfo" -f null - 2>&1 \
  | grep -oE "pts_time:[0-9.]+"
# contact sheet (tile i ≈ i*3 s), then Read it:
"$FF" -y -i public/screen.mp4 -vf "fps=1/3,scale=200:-1,tile=7x6:margin=6:padding=6:color=white" \
  -frames:v 1 out/contact.png -loglevel error
```
Read `out/contact.png` and write down `source_seconds → screen` (splash, language, onboarding
questions, home/dashboard, add-food, nutrition summary, AI, steps, …).

### 4.4 Transcribe the voiceover (the important one)
```bash
FF=node_modules/ffmpeg-static/ffmpeg.exe
"$FF" -y -i public/voice.mp3 -ac 1 -ar 16000 -c:a pcm_f32le out/voice16k.wav -loglevel error
node transcribe.mjs > out/transcript.tsv 2> out/transcribe.err
cat out/transcript.tsv     # columns: start  end  text
```
Whisper-small on Uzbek is phonetically rough and **may hallucinate repeated tokens on steady
sections** — that's fine, you only need the **clear anchor lines** (they carry accurate start
times). For any line lost in a hallucinated block, bound it with the big silence gaps:
```bash
"$FF" -i public/voice.mp3 -af "silencedetect=noise=-30dB:d=0.35" -f null - 2>&1 | grep silence_
```
Line boundaries ≈ the largest pauses (≥ ~1.0 s). Cross-check against the transcript anchors.

### 4.5 Extract the outro hero frame
Pick a clean end frame (usually the home screen near the end):
```bash
"$FF" -y -ss 119.6 -i public/screen.mp4 -frames:v 1 -q:v 3 public/phone_end.png -loglevel error
```
Read it to confirm it's a good hero shot.

### 4.6 Build the timeline in `src/theme.ts`
From §4.3 (phone) + §4.4 (voice) write three aligned arrays:
- `PHONE_SEGMENTS` — map each phone section (source in/out) onto the voice window where its line
  is spoken; chain the source; slow/speed per §3; last entry `freeze: true`.
- `SCENES` — the 13 right-panel scenes at the same wall-clock windows.
- `CAPTIONS` — the concise Uzbek dub of each line, at the spoken start/end.
- `DURATION_S` — the full spoken length (+ a small tail).

### 4.7 Verify with stills (do this every time)
```bash
# frame = seconds * 30   (composition id is now stat1 or stat2)
npx remotion still src/index.ts stat2 out/s/f1200.png --frame=1200 --log=error
```
Render one still at the **start of each spoken line** and Read it. Every frame must have
**phone screen + panel + caption all describing the same thing.** Fix segment `w`/`s` until they do.

### 4.8 Full render (2K)
```bash
npx remotion render src/index.ts stat2 out/stat2.mp4 \
  --scale=1.5 --concurrency=3 --log=info
```
Run it in the background. Then verify: probe the output (dims 2880×1620, duration, audio channels
= 2) and pull 1–2 frames straight from the MP4 with ffmpeg to confirm end-to-end.
(scale 1.5 → 2K and the phone gets ~50% more pixels; scale 2 → true 4K if they want sharper.)

---

## 5. Design system

- **Layout (1920×1080):** phone on the left, content panel on the right.
  - Phone: `cx=400, cy=540`; `SCREEN_H=904`, `SCREEN_W=431` (from 1080×2264), `BEZEL=15`.
    Dark metal body, dynamic island, side buttons, soft shadow. Video `object-fit: cover`, `muted`.
  - Panel container: `left:700, top:96, width:1160, bottom:150`.
  - Brand mark: top of panel (`726, 46`). Caption: right column (`left:690, right:40, bottom:60`) —
    never over the phone. Progress bar: flat green fill at the very bottom.
- **Theme (light, flat — object `C` in theme.ts):**
  `bg #eef4ef · panel #fff · line #dce8e0 · ink #123227 · sub #4f7263 · green #0f9d63 ·
  lime(highlight) #2f9e2f · teal #0ea5a5 · carb #f59e0b · protein #3b82f6 · fat #22c55e ·
  warn #d97706 · danger #e11d48`. Soft shadows; **no gradients, no thin stroked shapes.**
  Background = flat mint + blurred filled blobs + a white blurred halo grounding the phone.
- **Fonts:** Manrope (UI, weights 600/700/800), Lora italic (math variables). Loaded via
  `@remotion/google-fonts` with `subsets:["latin","latin-ext"]`, `ignoreTooManyRequestsWarning`.
- **Reusable building blocks in `lib.tsx`:** `Rise` (fade+rise), `usePop`, `CountUp`, `Chip`,
  `Card`, `Kicker`, `Title`; formula renderer `Math/V/Op/Num/Frac`; charts `Donut`, `Bars`,
  `Lines` (with labelled axes — pass `xTicks/yTicks/xTitle/yTitle`).
- **Emphasis:** subtle phone zoom (~1.05×) on the two "wow" moments (daily-norm, AI advice) —
  windows are in `Phone.tsx useEmphasis`; update them to the new timings.

---

## 6. Content reference (Eco Health)

Re-draw the 3 infographics **natively** (clean + animated) rather than using the AI JPEGs.

- **BMR (Mifflin–St Jeor, 1990):** `BMR = 10·m + 6.25·h − 5·a + s`
  (m vazn kg · h bo'y sm · a yosh · s = +5 erkak / −161 ayol). Line chart BMR vs weight
  (Erkaklar / Ayollar), Y = kkal/kun, X = Vazn (kg). Result ≈ **2397 kkal**.
- **TDEE:** `TDEE = BMR × PAL`, `PAL ∈ {1.2, 1.45, 1.725}` → bars **2136 / 2581 / 3071**.
- **Macros (Atwater 4·4·9):** `C=(E·0.45)/4  P=(E·0.30)/4  F=(E·0.25)/9`; donut **45 / 30 / 25 %**
  → **290 g / 194 g / 72 g**, center **2581 kkal/kun**. Colors: carbs amber, protein blue, fat green.
- **App numbers seen in the demo:** norm 2397 kkal · 66 kg / BMI 20.8 · water 2400 ml · steps goal
  10000 · AI advice **−981 kkal, −123 g oqsil**, suggest **tuxum / baliq / dukkakli**, "yog' ortiqcha".
- **Narrative order** (see `../Eco-Health-video-scenariy.md`): intro → all-in-one → onboarding →
  daily norm (BMR) → home dashboard → add food → auto-calc/macros → vitamins → AI intro →
  AI advice → AI vitamins → steps (TDEE) → outro. Scene components in `scenes.tsx` follow this.
  If the new recording shows a **different flow or numbers**, adjust the relevant scene component
  and the app numbers above.

---

## 7. New-job checklist

- [ ] Assets in `public/` (screen.mp4, voice.mp3); postinstalls run
- [ ] Probed dims/durations; `SCREEN_W` updated if aspect changed
- [ ] Phone timeline mapped (contact sheet + scene-detect)
- [ ] Voiceover transcribed; real line-start times written down
- [ ] `phone_end.png` extracted (clean outro hero)
- [ ] `PHONE_SEGMENTS` / `SCENES` / `CAPTIONS` / `DURATION_S` rebuilt & aligned
- [ ] Panel numbers/formulas match the new app state
- [ ] Stills verified at every spoken-line moment (phone = panel = caption)
- [ ] Background clean (no hair), captions off the phone, charts have axes
- [ ] 2K render done; output probed + 1–2 frames spot-checked from the MP4
- [ ] Offer: 9:16 vertical cut for Reels/Stories, background music (−18 dB under voice)

---

## 8. Command cheat-sheet
```bash
FF=node_modules/ffmpeg-static/ffmpeg.exe
node probe.mjs
"$FF" -i public/screen.mp4 -filter:v "select='gt(scene,0.22)',showinfo" -f null - 2>&1 | grep pts_time
"$FF" -y -i public/screen.mp4 -vf "fps=1/3,scale=200:-1,tile=7x6:margin=6:padding=6:color=white" -frames:v 1 out/contact.png -loglevel error
"$FF" -y -i public/voice.mp3 -ac 1 -ar 16000 -c:a pcm_f32le out/voice16k.wav -loglevel error
node transcribe.mjs > out/transcript.tsv
"$FF" -i public/voice.mp3 -af "silencedetect=noise=-30dB:d=0.35" -f null - 2>&1 | grep silence_
"$FF" -y -ss 119.6 -i public/screen.mp4 -frames:v 1 -q:v 3 public/phone_end.png -loglevel error
node stills.mjs stat2 1200 2160 3660           # batch stills from one bundle → out/stat2_stills/
npx remotion still src/index.ts stat2 out/s/f1200.png --frame=1200 --log=error
npx remotion render src/index.ts stat2 out/stat2.mp4 --scale=1.5 --concurrency=3 --log=info
```
